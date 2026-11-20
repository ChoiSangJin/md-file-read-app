# MD 파일 리더

Android 기기와 Google Drive의 Markdown 문서를 읽는 Flutter 앱입니다. 로컬 파일은 Android Storage Access Framework(SAF)로 선택하며, Drive 인증이 구성되지 않아도 독립적으로 동작합니다.

## 주요 기능

- 최근 읽은 파일과 마지막 열람 시간
- 로컬 `.md` 파일 선택 및 Markdown 렌더링
- 자동 목차와 헤더 이동
- 라이트, 다크, 세피아 테마와 글자 크기·줄 간격 설정
- 문서별 마지막 스크롤 위치 저장 및 복원
- Google Drive 읽기 전용 폴더 탐색과 `.md` 필터링
- Drive 파일 내부 캐시 및 오프라인 재열람
- Android ARM64(`arm64-v8a`) 전용 배포

## 개발 환경

- Flutter 3.50.1 Stable
- Dart 3.14.0
- Android SDK 및 JDK 17 이상

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Google Drive OAuth 설정

앱은 다음 스코프만 요청합니다.

```text
https://www.googleapis.com/auth/drive.readonly
```

1. [Google Cloud Console](https://console.cloud.google.com/)에서 프로젝트를 선택하거나 생성합니다.
2. Google Drive API를 활성화합니다.
3. OAuth 동의 화면을 구성하고 필요한 테스트 사용자를 등록합니다.
4. Android OAuth 클라이언트를 생성합니다.
   - 패키지 이름: `com.choisangjin.md_file_read_app`
   - SHA-1: 실제 디버그 또는 릴리스 서명 키의 인증서 지문
5. 웹 OAuth 클라이언트도 생성하고 클라이언트 ID를 빌드 시 전달합니다. 클라이언트 ID는 비밀번호가 아니지만 환경별 구성을 분리하기 위해 저장소에 하드코딩하지 않습니다.

```bash
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID
flutter build apk --release --target-platform android-arm64 \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID
```

Firebase의 `google-services.json`과 Google Services Gradle 플러그인으로 웹 클라이언트 ID를 제공하는 방식도 사용할 수 있습니다. 이 경우 `--dart-define`을 생략할 수 있습니다. `google-services.json`에는 프로젝트 식별 정보가 포함되므로 조직 정책에 따라 저장소 커밋 여부를 결정하세요.

OAuth 설정이 없거나 잘못되어도 로컬 파일 기능은 정상 동작하며, Drive 탭에 설정 안내 오류만 표시됩니다. 클라이언트 비밀값이나 서비스 계정 키를 Dart 코드, Gradle 파일 또는 Git에 넣지 마세요.

서명 키 지문 확인 예시:

```bash
keytool -list -v -alias androiddebugkey \
  -keystore "$HOME/.android/debug.keystore" \
  -storepass android -keypass android
```

## ARM64 APK 빌드

프로젝트의 Android Gradle 설정은 `arm64-v8a` ABI만 포함합니다.

```bash
flutter build apk --release --target-platform android-arm64
```

출력 파일:

```text
build/app/outputs/flutter-apk/app-release.apk
```

크기를 더 줄인 ABI 분리 빌드는 다음과 같습니다.

```bash
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

## 릴리스 서명

현재 초기 개발 설정은 릴리스 빌드에도 Android 디버그 키를 사용하므로 테스트 설치용입니다. Play Store 또는 외부 배포 전에는 별도 업로드 키를 안전한 CI 시크릿/키 저장소에 두고 `signingConfigs.release`로 연결해야 합니다. 키스토어, 암호, OAuth 비밀값은 저장소에 커밋하지 마세요.

## 프로젝트 구조

```text
lib/
├── app/             # 앱 진입점과 전역 테마 연결
├── core/            # 색상 및 공통 테마
├── data/            # 모델, 환경설정, Drive 및 캐시 저장소
└── presentation/    # 라이브러리, Drive 탐색, Markdown 뷰어, Riverpod
```
