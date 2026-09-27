# 맥 없이 iOS 빌드하기 (GitHub Actions)

이 저장소의 `.github/workflows/ios.yml` 은 GitHub 의 macOS 러너에서 iOS 앱을 빌드한다.
로컬에 맥이나 Xcode 가 없어도 된다.

## 1. 서명 없는 빌드 (바로 가능)

- `main` 브랜치 push, `v*` 태그, 또는 Actions 탭에서 수동 실행(workflow_dispatch).
- 결과 아티팩트
  - `ios-unsigned-ipa`: 서명 안 된 `.ipa`. 그대로는 기기에 설치되지 않는다.
  - `ios-simulator-app`: 시뮬레이터용 `.app` (맥에서만 실행 가능).
- 서명 안 된 IPA 를 실제 아이폰에 넣는 방법
  - Windows/Linux 에서 **Sideloadly** 또는 **AltStore** 로 본인 Apple ID 로 서명해 설치 (무료 계정은 7일마다 재서명, 앱 3개 제한).
  - 유료 개발자 계정이 있으면 아래 2번이 정석.

## 2. 서명된 빌드 + TestFlight (Apple Developer Program 필요, 연 $99)

맥 없이도 인증서와 프로비저닝 프로파일을 만들 수 있다.

### 2-1. 인증서(.p12) 만들기 — Linux/Windows 에서 openssl 사용

```bash
# 개인 키 + CSR 생성
openssl genrsa -out ios_dist.key 2048
openssl req -new -key ios_dist.key -out ios_dist.csr \
  -subj "/emailAddress=you@example.com/CN=Card Chess Dist/C=KR"
```

1. https://developer.apple.com/account/resources/certificates → `+` → **Apple Distribution** → `ios_dist.csr` 업로드 → `distribution.cer` 다운로드.
2. `.cer` → `.p12` 변환:

```bash
openssl x509 -in distribution.cer -inform DER -out distribution.pem -outform PEM
openssl pkcs12 -export -inkey ios_dist.key -in distribution.pem -out ios_dist.p12 -legacy
# 비밀번호를 입력하라고 하면 정한다 → IOS_CERTIFICATE_PASSWORD
base64 -w0 ios_dist.p12 > ios_dist.p12.b64   # macOS 라면 base64 -i ios_dist.p12
```

### 2-2. App ID 와 프로비저닝 프로파일

1. Identifiers → `+` → App IDs → Bundle ID 는 `ios/Runner.xcodeproj/project.pbxproj` 의 `PRODUCT_BUNDLE_IDENTIFIER` (기본 `com.sangmin.cardChess`) 와 같게.
2. Profiles → `+` → **App Store Connect** → 위 App ID 와 Distribution 인증서 선택 → `.mobileprovision` 다운로드.
3. `base64 -w0 CardChess.mobileprovision > profile.b64`

### 2-3. App Store Connect API 키 (TestFlight 자동 업로드용)

App Store Connect → Users and Access → Integrations → App Store Connect API → `+`
(Access: App Manager). Key ID, Issuer ID, `.p8` 파일을 받는다. `.p8` 은 한 번만 내려받을 수 있다.

### 2-4. GitHub Secrets 등록

Settings → Secrets and variables → Actions → New repository secret

| 이름 | 값 |
|---|---|
| `IOS_CERTIFICATE_P12_BASE64` | `ios_dist.p12.b64` 내용 |
| `IOS_CERTIFICATE_PASSWORD` | p12 비밀번호 |
| `IOS_PROVISION_PROFILE_BASE64` | `profile.b64` 내용 |
| `IOS_TEAM_ID` | Membership 페이지의 Team ID |
| `APPSTORE_ISSUER_ID` | API 키 Issuer ID |
| `APPSTORE_KEY_ID` | API 키 ID |
| `APPSTORE_PRIVATE_KEY` | `.p8` 파일 전체 내용 |

시크릿이 채워지면 `signed` 잡이 자동으로 서명된 IPA 를 만든다. TestFlight 업로드는
`v1.0.0` 같은 태그를 push 하거나, 수동 실행 시 `upload_testflight` 를 켜면 된다.
App Store Connect 에 앱(같은 Bundle ID)이 먼저 만들어져 있어야 업로드가 성공한다.

## 3. 자주 막히는 곳

- **Bundle ID 불일치**: 프로파일의 App ID 와 프로젝트의 `PRODUCT_BUNDLE_IDENTIFIER` 가 다르면 서명 실패.
- **CocoaPods**: 현재 의존성이 순수 Dart 뿐이라 Pod 가 없다. 플러그인을 추가하면 러너가 `pod install` 을 자동으로 돌린다.
- **Xcode 버전**: `macos-latest` 러너의 Xcode 가 Flutter 요구 버전보다 낮으면 `maxim-lobanov/setup-xcode` 로 고정한다.
- **버전 번호**: `pubspec.yaml` 의 `version: 1.0.0+1` 에서 `+` 뒤가 빌드 번호. 워크플로우는 `github.run_number` 로 덮어써서 TestFlight 중복을 피한다.
