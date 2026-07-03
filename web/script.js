/**
 * 위치 정보 확인 서비스 로직 (웹용)
 * 1단계: 사용자 위치 수집 동의 확인
 * 2단계: Geolocation API를 통한 좌표 수집
 * 3단계: Google Maps Reverse Geocoding API를 통한 주소 변환
 */

document.getElementById('check-btn').addEventListener('click', function() {
    // [보안] 위치정보법 준수: 수집 전 사용자 동의 구하기
    const consent = confirm("정확한 주소 확인을 위해 위치 정보 접근 권한이 필요합니다. 동의하시겠습니까?");

    if (consent) {
        // [위치 수집] Geolocation API 사용
        if ("geolocation" in navigator) {
            navigator.geolocation.getCurrentPosition(success, error, {
                enableHighAccuracy: true,
                timeout: 5000,
                maximumAge: 0
            });
        } else {
            alert("이 브라우저는 위치 정보를 지원하지 않습니다.");
        }
    }
});

function success(position) {
    const lat = position.coords.latitude;
    const lng = position.coords.longitude;

    // 선택된 기기 유형 확인
    const deviceType = document.querySelector('input[name="device"]:checked').value;
    const prefix = deviceType === 'computer' ? '[컴퓨터 위치] ' : '[휴대폰 위치] ';

    // [주소 변환] Google Maps Reverse Geocoding 호출
    reverseGeocode(lat, lng, prefix);
}

function error() {
    alert("위치 정보를 가져오는 데 실패했습니다.");
}

/**
 * Google Maps Geocoder를 사용하여 좌표를 주소로 변환
 */
function reverseGeocode(lat, lng, prefix) {
    // Google Maps API가 로드되었는지 확인
    if (typeof google === 'undefined' || typeof google.maps === 'undefined') {
        alert("Google Maps API가 아직 로드되지 않았습니다.");
        return;
    }

    const geocoder = new google.maps.Geocoder();
    const latlng = { lat: parseFloat(lat), lng: parseFloat(lng) };

    geocoder.geocode({ location: latlng, language: 'ko' }, (results, status) => {
        if (status === "OK") {
            if (results[0]) {
                // 도로명 주소 추출 (formatted_address)
                const address = results[0].formatted_address;

                // 우편번호 추출 (address_components에서 'postal_code' 찾기)
                let postcode = "정보 없음";
                for (let component of results[0].address_components) {
                    if (component.types.includes("postal_code")) {
                        postcode = component.long_name;
                        break;
                    }
                }

                // 결과 표시
                document.getElementById('address').innerText = `도로명 주소: ${prefix}${address}`;
                document.getElementById('postcode').innerText = `우편번호: ${postcode}`;
            } else {
                alert("결과를 찾을 수 없습니다.");
            }
        } else {
            alert("Geocoder 실패: " + status);
        }
    });
}
