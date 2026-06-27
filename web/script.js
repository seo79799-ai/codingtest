/**
 * 단순 위치 정보 확인 서비스 - JavaScript 로직
 */

document.getElementById('getLocationBtn').addEventListener('click', function() {
    // 1단계: 사용자 동의 팝업 (위치정보법 준수)
    const deviceType = document.querySelector('input[name="device"]:checked').value;
    const userConsent = confirm(`${deviceType}의 현재 위치 정보를 수집하시겠습니까?\n이 정보는 주소 변환을 위해서만 사용됩니다.`);

    if (userConsent) {
        startLocationProcess(deviceType);
    } else {
        alert("위치 정보 수집 동의가 필요합니다.");
    }
});

/**
 * 위치 수집 및 주소 변환 프로세스 시작
 */
function startLocationProcess(deviceType) {
    const addressResult = document.getElementById('addressResult');
    const zipResult = document.getElementById('zipResult');

    addressResult.innerHTML = "도로명 주소: <span class='loading'>위치 찾는 중...</span>";
    zipResult.innerHTML = "우편번호: <span class='loading'>위치 찾는 중...</span>";

    // 2단계: 웹 브라우저 Geolocation API 사용
    if ("geolocation" in navigator) {
        navigator.geolocation.getCurrentPosition(
            (position) => {
                const lat = position.coords.latitude;
                const lng = position.coords.longitude;

                // 3단계: Google Maps Reverse Geocoding API 호출
                reverseGeocode(lat, lng, deviceType);
            },
            (error) => {
                console.error("위치 획득 실패:", error);
                alert("위치 정보를 가져오는데 실패했습니다: " + error.message);
                resetResults();
            },
            {
                enableHighAccuracy: true,
                timeout: 5000,
                maximumAge: 0
            }
        );
    } else {
        alert("이 브라우저는 위치 정보를 지원하지 않습니다.");
    }
}

/**
 * 좌표를 주소로 변환 (Google Maps Geocoder)
 */
function reverseGeocode(lat, lng, deviceType) {
    const geocoder = new google.maps.Geocoder();
    const latlng = { lat: parseFloat(lat), lng: parseFloat(lng) };

    geocoder.geocode({ location: latlng }, (results, status) => {
        if (status === "OK") {
            if (results[0]) {
                // 결과에서 도로명 주소와 우편번호 추출
                const formattedAddress = results[0].formatted_address;
                let postalCode = "정보 없음";

                // address_components에서 우편번호(postal_code) 찾기
                for (let component of results[0].address_components) {
                    if (component.types.includes("postal_code")) {
                        postalCode = component.long_name;
                        break;
                    }
                }

                // 4단계: 결과 화면에 표시
                document.getElementById('addressResult').innerText = `도로명 주소: [${deviceType} 위치] ${formattedAddress}`;
                document.getElementById('zipResult').innerText = `우편번호: ${postalCode}`;
            } else {
                alert("주소 결과가 없습니다.");
                resetResults();
            }
        } else {
            console.error("Geocoder 실패:", status);
            alert("주소 변환에 실패했습니다: " + status);
            resetResults();
        }
    });
}

function resetResults() {
    document.getElementById('addressResult').innerText = "도로명 주소: [결과 오류]";
    document.getElementById('zipResult').innerText = "우편번호: [결과 오류]";
}
