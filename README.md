# 단순 위치 정보 확인 서비스

이 프로젝트는 Google Maps Platform의 Reverse Geocoding API를 사용하여 현재 위치의 도로명 주소와 우편번호를 확인하는 웹 및 모바일 앱 서비스를 제공합니다.

## 프로젝트 구조

- `web/`: 웹 브라우저용 HTML/JS 구현체
- `mobile/`: Flutter 기반 모바일 앱 구현체

## 공통 설정 (Google Maps API Key)

두 버전 모두 Google Maps Reverse Geocoding API를 사용하므로, 유효한 API 키가 필요합니다.

1. [Google Cloud Console](https://console.cloud.google.com/)에서 프로젝트를 생성합니다.
2. **Geocoding API**를 활성화합니다.
3. 사용자 인증 정보에서 API 키를 생성합니다.
4. 각 코드의 `YOUR_GOOGLE_MAPS_API_KEY` 부분을 생성한 API 키로 교체합니다.
   - Web: `web/index.html` 내 JavaScript 코드
   - Mobile: `mobile/lib/main.dart` 내 `_googleMapsApiKey` 변수

## 실행 방법

### 웹 버전 (Web)

1. `web/` 디렉토리로 이동합니다.
2. `index.html` 파일을 브라우저로 엽니다. (로컬 서버 환경 권장: `python3 -m http.server`)
3. 브라우저에서 위치 권한 요청 시 '동의'를 선택합니다.

### 모바일 버전 (Mobile)

1. [Flutter SDK](https://docs.flutter.dev/get-started/install)가 설치되어 있어야 합니다.
2. `mobile/` 디렉토리에서 다음 명령어를 실행합니다:
   ```bash
   flutter pub get
   flutter run
   ```
3. 앱 실행 후 위치 권한 및 정보 수집 동의 팝업에서 '동의'를 선택합니다.

## 주요 기능 및 특징

- **단순한 UI**: "현재 위치 확인할까요?" 버튼 하나로 즉각적인 결과 확인.
- **기기 선택**: 상단 선택을 통해 의도 명시 (라디오 버튼).
- **한국어 지원**: 모든 라벨 및 결과값이 한국어로 표시됩니다.
- **보안 및 법규 준수**: 위치 정보 수집 전 반드시 사용자 동의를 구하는 절차를 포함합니다.
