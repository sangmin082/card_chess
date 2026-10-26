#!/usr/bin/env python3
"""App Store Connect API 로 iOS 배포 서명 자산을 만든다. 맥이 필요 없다.

하는 일
  1. Bundle ID 를 등록한다 (이미 있으면 그대로 쓴다).
  2. 개인 키와 CSR 을 만들어 Apple Distribution 인증서를 발급받는다.
  3. 그 인증서로 App Store 배포용 프로비저닝 프로파일을 만든다.
  4. .p12(무작위 비밀번호), 프로파일, 팀 ID 를 --out 디렉터리에 파일로 쓴다.

환경 변수
  ASC_ISSUER_ID    App Store Connect API Issuer ID
  ASC_KEY_ID       API 키 ID
  ASC_PRIVATE_KEY  API 키(.p8) 내용 전체

출력 파일 (--out)
  p12_base64.txt, p12_password.txt, profile_base64.txt, team_id.txt  ← 비밀
  summary.json                                                       ← 공개해도 되는 요약
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import secrets
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature

API_BASE = "https://api.appstoreconnect.apple.com"
PROFILE_NAME = "Card Chess App Store (CI)"


class ASCError(Exception):
    def __init__(self, status: int, body: str):
        super().__init__(f"HTTP {status}: {body}")
        self.status = status
        self.body = body

    def detail(self) -> str:
        try:
            errors = json.loads(self.body).get("errors", [])
            return "; ".join(
                f"{e.get('title', '')} - {e.get('detail', '')}".strip(" -") for e in errors
            ) or self.body
        except (ValueError, AttributeError):
            return self.body


# ---------------------------------------------------------------- 인증 (JWT)


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def normalize_p8(text: str) -> str:
    """시크릿에 붙여넣은 .p8 내용을 PEM 으로 정리한다."""
    t = text.strip().replace("\\n", "\n").replace("\r", "")
    if "BEGIN PRIVATE KEY" not in t:
        body = re.sub(r"\s+", "", t)
        lines = [body[i : i + 64] for i in range(0, len(body), 64)]
        t = "-----BEGIN PRIVATE KEY-----\n" + "\n".join(lines) + "\n-----END PRIVATE KEY-----"
    return t + "\n"


def make_jwt(issuer_id: str, key_id: str, p8_pem: str, now: int | None = None) -> str:
    now = int(time.time()) if now is None else now
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    payload = {"iss": issuer_id, "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"}
    signing_input = (
        _b64url(json.dumps(header, separators=(",", ":")).encode())
        + "."
        + _b64url(json.dumps(payload, separators=(",", ":")).encode())
    )
    key = serialization.load_pem_private_key(p8_pem.encode(), password=None)
    if not isinstance(key, ec.EllipticCurvePrivateKey):
        raise ValueError("ASC_PRIVATE_KEY 가 EC(.p8) 키가 아닙니다.")
    der = key.sign(signing_input.encode(), ec.ECDSA(hashes.SHA256()))
    r, s = decode_dss_signature(der)
    return signing_input + "." + _b64url(r.to_bytes(32, "big") + s.to_bytes(32, "big"))


class ASC:
    """App Store Connect API 최소 클라이언트."""

    def __init__(self, issuer_id: str, key_id: str, p8_pem: str):
        self.issuer_id = issuer_id
        self.key_id = key_id
        self.p8_pem = p8_pem
        self._token = ""
        self._token_exp = 0.0

    def _auth(self) -> str:
        if time.time() > self._token_exp - 60:
            self._token = make_jwt(self.issuer_id, self.key_id, self.p8_pem)
            self._token_exp = time.time() + 1100
        return self._token

    def request(self, method: str, path: str, body: dict | None = None, params: dict | None = None) -> dict:
        url = API_BASE + path
        if params:
            url += "?" + urllib.parse.urlencode(params)
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(
            url,
            data=data,
            method=method,
            headers={"Authorization": f"Bearer {self._auth()}", "Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                raw = resp.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as e:
            raise ASCError(e.code, e.read().decode(errors="replace")) from None


# ---------------------------------------------------------------- API 작업


def find_bundle_id(asc: ASC, identifier: str) -> dict | None:
    res = asc.request("GET", "/v1/bundleIds", params={"filter[identifier]": identifier, "limit": 200})
    for item in res.get("data", []):
        if item["attributes"]["identifier"] == identifier:
            return item
    return None


def ensure_bundle_id(asc: ASC, identifier: str, name: str) -> dict:
    found = find_bundle_id(asc, identifier)
    if found:
        print(f"• Bundle ID 이미 등록됨: {identifier} ({found['id']})")
        return found
    body = {
        "data": {
            "type": "bundleIds",
            "attributes": {"identifier": identifier, "name": name, "platform": "IOS"},
        }
    }
    created = asc.request("POST", "/v1/bundleIds", body=body)["data"]
    print(f"• Bundle ID 등록함: {identifier} ({created['id']})")
    return created


def list_distribution_certs(asc: ASC) -> list[dict]:
    res = asc.request(
        "GET", "/v1/certificates", params={"filter[certificateType]": "DISTRIBUTION", "limit": 200}
    )
    return res.get("data", [])


def revoke_cert(asc: ASC, cert_id: str) -> None:
    asc.request("DELETE", f"/v1/certificates/{cert_id}")


def create_distribution_cert(asc: ASC, csr_pem: str) -> dict:
    body = {
        "data": {
            "type": "certificates",
            "attributes": {"certificateType": "DISTRIBUTION", "csrContent": csr_pem},
        }
    }
    return asc.request("POST", "/v1/certificates", body=body)["data"]


def delete_profiles_named(asc: ASC, name: str) -> int:
    res = asc.request("GET", "/v1/profiles", params={"filter[name]": name, "limit": 200})
    n = 0
    for item in res.get("data", []):
        if item["attributes"].get("name") == name:
            asc.request("DELETE", f"/v1/profiles/{item['id']}")
            n += 1
    return n


def create_app_store_profile(asc: ASC, name: str, bundle_id_res: str, cert_id: str) -> dict:
    body = {
        "data": {
            "type": "profiles",
            "attributes": {"name": name, "profileType": "IOS_APP_STORE"},
            "relationships": {
                "bundleId": {"data": {"type": "bundleIds", "id": bundle_id_res}},
                "certificates": {"data": [{"type": "certificates", "id": cert_id}]},
            },
        }
    }
    return asc.request("POST", "/v1/profiles", body=body)["data"]


# ---------------------------------------------------------------- 로컬 파일 작업


def run(cmd: list[str], env: dict | None = None) -> None:
    subprocess.run(cmd, check=True, env={**os.environ, **(env or {})}, capture_output=True)


def make_key_and_csr(workdir: Path) -> tuple[Path, str]:
    key = workdir / "dist.key"
    csr = workdir / "dist.csr"
    run(["openssl", "genrsa", "-out", str(key), "2048"])
    run(["openssl", "req", "-new", "-key", str(key), "-out", str(csr), "-subj", "/CN=Card Chess CI/C=KR"])
    return key, csr.read_text()


def make_p12(workdir: Path, key: Path, cert_der_b64: str, password: str) -> bytes:
    der = workdir / "dist.cer"
    pem = workdir / "dist.pem"
    p12 = workdir / "dist.p12"
    der.write_bytes(base64.b64decode(cert_der_b64))
    run(["openssl", "x509", "-inform", "DER", "-in", str(der), "-out", str(pem)])
    base = [
        "openssl", "pkcs12", "-export", "-inkey", str(key), "-in", str(pem),
        "-out", str(p12), "-name", "Apple Distribution", "-passout", "env:P12_PASSWORD",
    ]
    # macOS 키체인은 OpenSSL 3 의 기본(AES) p12 를 못 읽는 경우가 있어 legacy 형식을 쓴다.
    try:
        run(base + ["-legacy"], env={"P12_PASSWORD": password})
    except subprocess.CalledProcessError:
        run(base, env={"P12_PASSWORD": password})
    return p12.read_bytes()


def parse_profile(profile: bytes) -> dict:
    """서명된 .mobileprovision 안의 plist 에서 팀 ID, 이름, UUID 를 뽑는다."""
    text = profile.decode("latin-1")

    def grab(pattern: str) -> str | None:
        m = re.search(pattern, text, re.S)
        return m.group(1).strip() if m else None

    return {
        "team_id": grab(r"<key>TeamIdentifier</key>\s*<array>\s*<string>([^<]+)</string>"),
        "name": grab(r"<key>Name</key>\s*<string>([^<]+)</string>"),
        "uuid": grab(r"<key>UUID</key>\s*<string>([^<]+)</string>"),
    }


def read_bundle_id(pbxproj: Path) -> str:
    ids = set(re.findall(r"PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);", pbxproj.read_text()))
    ids = {i.strip().strip('"') for i in ids if "RunnerTests" not in i}
    if len(ids) != 1:
        raise SystemExit(f"Runner 의 Bundle ID 를 하나로 정할 수 없습니다: {sorted(ids)}")
    return ids.pop()


# ---------------------------------------------------------------- 메인


def main(argv: list[str] | None = None, asc: ASC | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", required=True, help="결과 파일을 쓸 디렉터리")
    ap.add_argument("--bundle-id", help="생략하면 ios/Runner.xcodeproj 에서 읽는다")
    ap.add_argument("--app-name", default="Card Chess")
    ap.add_argument("--profile-name", default=PROFILE_NAME)
    ap.add_argument("--revoke-existing", action="store_true",
                    help="기존 Apple Distribution 인증서를 모두 폐기한 뒤 새로 만든다")
    args = ap.parse_args(argv)

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    root = Path(__file__).resolve().parent.parent
    bundle_id = args.bundle_id or read_bundle_id(root / "ios/Runner.xcodeproj/project.pbxproj")

    if asc is None:
        missing = [k for k in ("ASC_ISSUER_ID", "ASC_KEY_ID", "ASC_PRIVATE_KEY") if not os.environ.get(k)]
        if missing:
            print(f"::error::환경 변수가 없습니다: {', '.join(missing)}")
            return 2
        asc = ASC(
            os.environ["ASC_ISSUER_ID"].strip(),
            os.environ["ASC_KEY_ID"].strip(),
            normalize_p8(os.environ["ASC_PRIVATE_KEY"]),
        )

    try:
        print(f"Bundle ID: {bundle_id}")
        bundle = ensure_bundle_id(asc, bundle_id, args.app_name)

        existing = list_distribution_certs(asc)
        print(f"• 기존 Apple Distribution 인증서 {len(existing)}개")
        for c in existing:
            a = c["attributes"]
            print(f"    - {a.get('name')} / 만료 {a.get('expirationDate')} / id {c['id']}")
        if args.revoke_existing:
            for c in existing:
                revoke_cert(asc, c["id"])
                print(f"• 폐기함: {c['id']}")

        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            key, csr_pem = make_key_and_csr(work)
            try:
                cert = create_distribution_cert(asc, csr_pem)
            except ASCError as e:
                if e.status in (400, 409):
                    print("::error::인증서를 만들 수 없습니다: " + e.detail())
                    print("::error::Apple Distribution 인증서 개수 한도일 가능성이 큽니다. "
                          "Run workflow 에서 'revoke_existing' 을 켜고 다시 실행하거나, "
                          "developer.apple.com 에서 쓰지 않는 인증서를 폐기하세요.")
                    return 3
                raise
            ca = cert["attributes"]
            print(f"• 인증서 발급: {ca.get('name')} / 만료 {ca.get('expirationDate')} / id {cert['id']}")

            removed = delete_profiles_named(asc, args.profile_name)
            if removed:
                print(f"• 같은 이름의 기존 프로파일 {removed}개 삭제")
            profile = create_app_store_profile(asc, args.profile_name, bundle["id"], cert["id"])
            profile_bytes = base64.b64decode(profile["attributes"]["profileContent"])
            info = parse_profile(profile_bytes)
            if not info["team_id"]:
                print("::error::프로파일에서 팀 ID 를 찾지 못했습니다.")
                return 4
            print(f"• 프로파일 생성: {info['name']} ({info['uuid']}) / 팀 {info['team_id']}")

            password = secrets.token_urlsafe(24)
            p12 = make_p12(work, key, ca["certificateContent"], password)

        (out / "p12_base64.txt").write_text(base64.b64encode(p12).decode())
        (out / "p12_password.txt").write_text(password)
        (out / "profile_base64.txt").write_text(base64.b64encode(profile_bytes).decode())
        (out / "team_id.txt").write_text(info["team_id"])
        summary = {
            "bundle_id": bundle_id,
            "team_id": info["team_id"],
            "certificate_id": cert["id"],
            "certificate_expires": ca.get("expirationDate"),
            "profile_name": info["name"],
            "profile_uuid": info["uuid"],
        }
        (out / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2))
        print("완료.")
        return 0
    except ASCError as e:
        hint = ""
        if e.status == 401:
            hint = " (Issuer ID / Key ID / .p8 내용이 맞는지 확인하세요)"
        elif e.status == 403:
            hint = " (API 키 역할을 Admin 으로 만들어야 인증서·프로파일을 만들 수 있습니다)"
        print(f"::error::App Store Connect API 오류 {e.status}: {e.detail()}{hint}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
