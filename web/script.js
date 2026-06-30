/**
 * 단순 위치 정보 확인 서비스 - JavaScript 로직
 */

document.getElementById('getLocationBtn').addEventListener('click', function() {
    // 1단계: 사용자 동의 확인 (위치정보법 준수)
    const consent = confirm("사용자의 현재 위치 정보를 수집하여 주소를 확인하시겠습니까?");

    if (consent) {
        getCurrentLocation();
    } else {
        alert("위치 정보 수집에 동의하지 않으셨습니다.");
    }
});

/**
 * 브라우저 Geolocation API를 사용하여 좌표 수집
 */
function getCurrentLocation() {
    if (!navigator.geolocation) {
        alert("이 브라우저는 위치 정보를 지원하지 않습니다.");
        return;
    }

    navigator.geolocation.getCurrentPosition(
        (position) => {
            const lat = position.coords.latitude;
            const lng = position.coords.longitude;

            // 2단계: 좌표를 주소로 변환 (Reverse Geocoding)
            convertToAddress(lat, lng);
        },
        (error) => {
            console.error("위치 획득 실패:", error);
            alert("위치 정보를 가져오는 데 실패했습니다.");
        }
    );
}

/**
 * Google Maps Geocoder를 사용하여 좌표를 주소와 우편번호로 변환
 */
function convertToAddress(lat, lng) {
    // Google Maps API 로드 여부 확인
    if (typeof google === 'undefined' || !google.maps || !google.maps.Geocoder) {
        alert("Google Maps API를 로드할 수 없습니다. API 키를 확인해 주세요.");
        return;
    }

    const geocoder = new google.maps.Geocoder();
    const latlng = { lat: parseFloat(lat), lng: parseFloat(lng) };

    geocoder.geocode({ location: latlng, language: 'ko' }, (results, status) => {
        if (status === "OK") {
            if (results[0]) {
                // 선택된 기기 정보 가져오기
                const deviceType = document.querySelector('input[name="device"]:checked').value;

                // 도로명 주소 및 우편번호 추출
                const formattedAddress = `[${deviceType} 위치] ${results[0].formatted_address}`;
                let zipCode = "-";

                // 주소 구성 요소에서 우편번호(postal_code) 찾기
                for (let component of results[0].address_components) {
                    if (component.types.includes("postal_code")) {
                        zipCode = component.long_name;
                        break;
                    }
                }

                // 3단계: 화면에 결과 표시
                document.getElementById('address').textContent = formattedAddress;
                document.getElementById('zipcode').textContent = zipCode;
            } else {
                alert("결과를 찾을 수 없습니다.");
            }
        } else {
            console.error("Geocoder failed due to: " + status);
            alert("주소 변환에 실패했습니다.");
        }
    });
}
