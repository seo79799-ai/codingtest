# 단순 위치 정보 확인 서비스 (Web & Flutter)

컴퓨터나 핸드폰의 위치 좌표(위도, 경도)를 수집하고, Google Reverse Geocoding API를 사용하여 한국의 도로명 주소와 우편번호로 변환해주는 서비스입니다.

## 🚀 사전 준비 사항 (Prerequisites)

이 코드를 실행하려면 **Google Maps Platform API 키**가 필요합니다.

1.  [Google Cloud Console](https://console.cloud.google.com/)에 접속합니다.
2.  새 프로젝트를 생성하거나 기존 프로젝트를 선택합니다.
3.  **API 및 서비스 > 라이브러리**에서 **"Geocoding API"**를 찾아 **사용 설정(Enable)**합니다.
4.  **API 및 서비스 > 사용자 인증 정보**에서 API 키를 생성합니다.
5.  코드 내의 `YOUR_GOOGLE_MAPS_API_KEY` 부분을 생성한 API 키로 교체합니다.
    -   Web: `index.html` 내의 `GOOGLE_MAPS_API_KEY` 변수
    -   Flutter: `lib/main.dart` 내의 `_googleMapsApiKey` 변수

---

## 🌐 Web 버전 실행 방법 (HTML/JS)

1.  `index.html` 파일을 브라우저(Chrome, Edge 등)로 엽니다.
2.  화면 상단에서 '컴퓨터 위치' 또는 '휴대폰 위치'를 선택합니다.
3.  **"현재 위치 확인할까요?"** 버튼을 클릭합니다.
4.  브라우저의 위치 정보 접근 권한 팝업이 뜨면 **'허용'**을 누릅니다.
5.  하단에 도로명 주소와 우편번호가 나타납니다.

---

## 📱 App 버전 실행 방법 (Flutter)

### 1. 의존성 설치
터미널에서 다음 명령어를 실행합니다:
```bash
flutter pub get
```

### 2. 플랫폼별 설정 (중요)

#### Android (`android/app/src/main/AndroidManifest.xml`)
다음 권한을 `<manifest>` 태그 안에 추가해야 합니다:
```xml
<uses-permission name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission name="android.permission.ACCESS_COARSE_LOCATION" />
```

#### iOS (`ios/Runner/Info.plist`)
다음 항목을 `<dict>` 태그 안에 추가해야 합니다:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>이 앱은 현재 위치의 주소를 확인하기 위해 위치 권한이 필요합니다.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>이 앱은 현재 위치의 주소를 확인하기 위해 위치 권한이 필요합니다.</string>
```

### 3. 실행
```bash
flutter run
```

---

## 🛠 주요 기술 스택
-   **Web**: HTML5 Geolocation API, Vanilla JavaScript (ES6+)
-   **App**: Flutter, `geolocator` 패키지, `http` 패키지
-   **API**: Google Maps Reverse Geocoding API
