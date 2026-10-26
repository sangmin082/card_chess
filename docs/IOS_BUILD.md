# 맥 없이 iPhone 에 설치하기 (GitHub Actions + TestFlight)

맥, Xcode, openssl 이 전혀 필요 없다. 인증서와 프로비저닝 프로파일은 GitHub Actions 가
App Store Connect API 로 직접 만들고, 빌드와 TestFlight 업로드도 GitHub 의 macOS 러너가 한다.
사용자가 하는 일은 웹 화면에서 키를 만들어 붙여넣는 것뿐이다. PC 브라우저를 권장한다.

준비물: Apple Developer Program 가입 계정 (Account Holder 또는 Admin), iPhone, GitHub 계정.

---

## 1단계. App Store Connect API 키 만들기 (5분)

1. https://appstoreconnect.apple.com/access/integrations/api 에 접속한다.
   (사용자 및 액세스 → 통합 → App Store Connect API → 팀 키)
2. 처음이면 **Request Access(액세스 요청)** 버튼이 보인다. Account Holder 가 누르면 바로 승인된다.
3. **Generate API Key(+)** → 이름 `GitHub Actions`, 액세스 **Admin** → 생성.
   - Admin 이어야 인증서와 프로파일을 만들 수 있다.
4. 화면에서 두 값을 적어 둔다.
   - **Issuer ID** (표 위쪽, UUID 형태)
   - **Key ID** (방금 만든 키의 10자리)
5. **Download API Key** 로 `AuthKey_XXXXXXXXXX.p8` 을 받는다. **한 번만** 받을 수 있다.
   메모장으로 열면 `-----BEGIN PRIVATE KEY-----` 로 시작하는 텍스트가 보인다.

## 2단계. GitHub 토큰 만들기 (2분)

설정 워크플로우가 만든 인증서를 저장소 시크릿에 자동으로 넣기 위한 임시 토큰이다.

1. https://github.com/settings/personal-access-tokens/new
2. Token name `card_chess signing`, Expiration **7 days**
3. Repository access → **Only select repositories** → `card_chess`
4. Permissions → Repository permissions → **Secrets: Read and write**
5. Generate token → `github_pat_...` 값을 복사한다.

## 3단계. 저장소 시크릿 4개 등록 (3분)

https://github.com/sangmin082/card_chess/settings/secrets/actions → **New repository secret**

| 이름 | 값 |
|---|---|
| `APPSTORE_ISSUER_ID` | 1단계의 Issuer ID |
| `APPSTORE_KEY_ID` | 1단계의 Key ID |
| `APPSTORE_PRIVATE_KEY` | `.p8` 파일 내용 전체 (BEGIN/END 줄 포함) |
| `GH_PAT` | 2단계의 토큰 |

## 4단계. 서명 자동 설정 실행 (2분)

1. https://github.com/sangmin082/card_chess/actions/workflows/ios-signing-setup.yml
2. **Run workflow** → Run.
3. 성공하면 시크릿 4개가 자동으로 생긴다:
   `IOS_CERTIFICATE_P12_BASE64`, `IOS_CERTIFICATE_PASSWORD`, `IOS_PROVISION_PROFILE_BASE64`, `IOS_TEAM_ID`.
   이 워크플로우는 Bundle ID(`com.sangmin.cardChess`) 등록, Apple Distribution 인증서 발급,
   App Store 프로비저닝 프로파일 생성까지 한다.
4. 이제 `GH_PAT` 시크릿과 2단계 토큰은 지워도 된다.

## 5단계. App Store Connect 에 앱 만들기 (처음 한 번, 3분)

API 로는 앱 레코드를 만들 수 없어서 웹에서 한 번 만들어야 한다.

1. https://appstoreconnect.apple.com/apps → **+** → **신규 앱**
2. 플랫폼 **iOS**, 이름(App Store 전체에서 겹치면 안 된다. 예: `카드 체스 5x5`),
   기본 언어 한국어, 번들 ID **com.sangmin.cardChess** 선택, SKU `card-chess`, 사용자 액세스 전체.
3. 생성만 하면 된다. 다른 정보는 TestFlight 내부 테스트에는 필요 없다.

## 6단계. 빌드하고 TestFlight 에 올리기 (15분)

1. https://github.com/sangmin082/card_chess/actions/workflows/ios.yml
2. **Run workflow** → `TestFlight 에 업로드` 체크 확인 → Run.
3. `Build iOS (signed) & TestFlight` 잡이 초록색이 되면 업로드 완료.
4. App Store Connect 가 빌드를 처리하는 데 5~30분 걸린다. 처리가 끝나면 이메일이 온다.

이후에는 `v1.0.1` 같은 태그를 push 하거나 Run workflow 를 누를 때마다 새 빌드가 올라간다.
빌드 번호는 워크플로우 실행 번호로 자동 증가한다.

## 7단계. iPhone 에 설치 (5분)

1. App Store 에서 **TestFlight** 앱을 설치한다.
2. App Store Connect → 앱 → **TestFlight** 탭 → 내부 테스트 → **+** 로 그룹을 만들고 본인 계정을 테스터로 추가한다.
   빌드를 그 그룹에 추가한다 (처리 완료 후 선택 가능).
3. iPhone 의 TestFlight 앱(같은 Apple ID 로 로그인)에 카드 체스가 나타난다 → **설치**.

수출 규정 질문(암호화 사용 여부)은 `Info.plist` 에 `ITSAppUsesNonExemptEncryption = NO` 를 넣어 두어 나오지 않는다.

---

## 1년 뒤 (인증서 만료)

Apple Distribution 인증서와 프로파일은 1년짜리다. 만료되면 2단계 토큰을 다시 만들어 `GH_PAT` 에 넣고
4단계를 다시 실행한다. 업로드된 TestFlight/App Store 빌드에는 영향이 없다.

## 문제 해결

| 증상 | 원인과 조치 |
|---|---|
| 설정 워크플로우 `401` | Issuer ID / Key ID / `.p8` 내용이 틀렸다. 붙여넣을 때 앞뒤 줄이 빠지지 않았는지 확인. |
| 설정 워크플로우 `403` | API 키 액세스가 Admin 이 아니다. Admin 키를 새로 만든다. |
| `인증서 개수 한도` 오류 | Apple Distribution 인증서는 개수 제한이 있다. Run workflow 에서 `revoke_existing` 을 켜고 다시 실행한다. 다른 곳에서 쓰는 인증서가 있다면 developer.apple.com 에서 쓰지 않는 것만 직접 폐기한다. |
| `gh: HTTP 403` (시크릿 저장 실패) | `GH_PAT` 에 Secrets: Read and write 권한이 없거나 저장소 선택이 빠졌다. |
| 업로드 시 `No suitable application records were found` | 5단계 앱을 만들지 않았거나 번들 ID 가 다르다. |
| 업로드 시 `bundle version must be higher` | 같은 빌드 번호가 이미 있다. 워크플로우를 다시 실행하면 번호가 올라간다. |
| 서명 빌드 잡이 건너뛰어짐 | 4단계 시크릿 4개가 없다. 설정 워크플로우를 실행한다. |

## 서명 없는 빌드

서명 시크릿이 없어도 `Build iOS (unsigned)` 잡은 항상 돈다. 결과물 `ios-unsigned-ipa` 는
그대로는 설치되지 않고, Windows 의 Sideloadly 같은 도구로 본인 Apple ID 서명을 해야 한다.
개발자 계정이 있으면 위 TestFlight 경로가 훨씬 편하다.
