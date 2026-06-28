/**
 * 단계별 설명:
 * 1. 위치 정보 수집 전 사용자 동의 확인 (위치정보법 준수)
 * 2. 브라우저 Geolocation API를 사용하여 현재 좌표(위도, 경도) 획득
 * 3. Google Maps Reverse Geocoding API를 호출하여 좌표를 주소로 변환
 * 4. 선택된 기기 정보와 함께 화면에 결과 출력
 */

document.getElementById('checkLocationBtn').addEventListener('click', () => {
    // 1단계: 사용자 권한 동의 확인 팝업
    const consent = confirm("서비스 제공을 위해 현재 위치 정보를 수집하고 Google에 제공하는 것에 동의하십니까?\n(수집된 정보는 주소 변환 목적으로만 사용됩니다)");

    if (!consent) {
        alert("위치 정보 수집에 동의해야 서비스를 이용할 수 있습니다.");
        return;
    }

    // 결과 및 에러 메시지 초기화
    const addressEl = document.getElementById('addressResult');
    const zipcodeEl = document.getElementById('zipcodeResult');
    const errorEl = document.getElementById('errorMsg');

    addressEl.innerText = "도로명 주소: [위치 확인 중...]";
    zipcodeEl.innerText = "우편번호: [위치 확인 중...]";
    errorEl.innerText = "";

    // 2단계: Geolocation API 사용
    if (!navigator.geolocation) {
        errorEl.innerText = "이 브라우저는 위치 정보를 지원하지 않습니다.";
        return;
    }

    navigator.geolocation.getCurrentPosition(
        (position) => {
            const lat = position.coords.latitude;
            const lng = position.coords.longitude;

            // 3단계: Google Maps Geocoder 연동
            reverseGeocode(lat, lng);
        },
        (error) => {
            let msg = "위치 정보를 가져올 수 없습니다.";
            switch(error.code) {
                case error.PERMISSION_DENIED:
                    msg = "위치 정보 접근 권한이 거부되었습니다.";
                    break;
                case error.POSITION_UNAVAILABLE:
                    msg = "위치 정보를 사용할 수 없습니다.";
                    break;
                case error.TIMEOUT:
                    msg = "위치 정보 요청 시간이 초과되었습니다.";
                    break;
            }
            errorEl.innerText = msg;
        }
    );
});

/**
 * Reverse Geocoding 수행 함수
 */
function reverseGeocode(lat, lng) {
    const geocoder = new google.maps.Geocoder();
    const latlng = { lat: parseFloat(lat), lng: parseFloat(lng) };

    geocoder.geocode({ location: latlng }, (results, status) => {
        const addressEl = document.getElementById('addressResult');
        const zipcodeEl = document.getElementById('zipcodeResult');
        const errorEl = document.getElementById('errorMsg');

        if (status === "OK") {
            if (results[0]) {
                // 기기 선택 값 확인
                const device = document.querySelector('input[name="device"]:checked').value;
                const prefix = device === 'computer' ? '[컴퓨터 위치] ' : '[휴대폰 위치] ';

                // 결과 분석 (formatted_address와 postal_code 추출)
                const formattedAddress = results[0].formatted_address;
                let postalCode = "정보 없음";

                for (const component of results[0].address_components) {
                    if (component.types.includes("postal_code")) {
                        postalCode = component.long_name;
                        break;
                    }
                }

                // 4단계: 화면에 결과 출력
                addressEl.innerText = `도로명 주소: ${prefix}${formattedAddress}`;
                zipcodeEl.innerText = `우편번호: ${postalCode}`;
            } else {
                errorEl.innerText = "주소를 찾을 수 없습니다.";
            }
        } else {
            errorEl.innerText = "Geocode 서비스 실패: " + status;
        }
    });
}
