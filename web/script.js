document.getElementById('getLocationBtn').addEventListener('click', async () => {
    // 1. 위치 정보 수집 동의 팝업 (위치정보법 준수)
    const consent = confirm("서비스 제공을 위해 현재 위치 정보를 수집합니다. 동의하시겠습니까?");
    if (!consent) {
        alert("위치 정보 수집에 동의하셔야 서비스를 이용하실 수 있습니다.");
        return;
    }

    // 결과 표시 영역 초기화 및 로딩 표시
    const resultArea = document.getElementById('resultArea');
    const addressSpan = document.getElementById('address');
    const zipcodeSpan = document.getElementById('zipcode');
    const deviceLabel = document.getElementById('deviceLabel');

    resultArea.style.display = 'block';
    addressSpan.innerText = "조회 중...";
    zipcodeSpan.innerText = "조회 중...";

    // 선택된 기기 확인
    const selectedDevice = document.querySelector('input[name="device"]:checked').value;
    const deviceText = selectedDevice === 'computer' ? '[컴퓨터 위치]' : '[휴대폰 위치]';
    deviceLabel.innerText = deviceText;

    // 2. Geolocation API를 사용하여 좌표 수집
    if (!navigator.geolocation) {
        alert("이 브라우저는 위치 정보를 지원하지 않습니다.");
        return;
    }

    navigator.geolocation.getCurrentPosition(
        async (position) => {
            const lat = position.coords.latitude;
            const lng = position.coords.longitude;

            try {
                // 3. Google Maps Reverse Geocoding API를 사용하여 주소 변환
                await reverseGeocode(lat, lng);
            } catch (error) {
                console.error("주소 변환 실패:", error);
                addressSpan.innerText = "주소를 불러올 수 없습니다.";
                zipcodeSpan.innerText = "오류 발생";
            }
        },
        (error) => {
            console.error("위치 수집 실패:", error);
            alert("위치 정보를 가져오는 데 실패했습니다.");
            addressSpan.innerText = "위치 정보 접근 거부";
            zipcodeSpan.innerText = "-";
        }
    );
});

/**
 * Google Maps SDK의 Geocoder를 사용하여 좌표를 주소와 우편번호로 변환합니다.
 */
async function reverseGeocode(lat, lng) {
    if (typeof google === 'undefined' || !google.maps || !google.maps.Geocoder) {
        throw new Error("Google Maps SDK가 로드되지 않았습니다.");
    }

    const geocoder = new google.maps.Geocoder();
    const latlng = { lat: parseFloat(lat), lng: parseFloat(lng) };

    geocoder.geocode({ location: latlng, language: 'ko' }, (results, status) => {
        const addressSpan = document.getElementById('address');
        const zipcodeSpan = document.getElementById('zipcode');

        if (status === "OK") {
            if (results[0]) {
                // 전체 주소 (도로명 주소 포함)
                addressSpan.innerText = results[0].formatted_address;

                // 우편번호(postal_code) 추출
                let postalCode = "-";
                for (let component of results[0].address_components) {
                    if (component.types.includes("postal_code")) {
                        postalCode = component.long_name;
                        break;
                    }
                }
                zipcodeSpan.innerText = postalCode;
            } else {
                addressSpan.innerText = "결과를 찾을 수 없습니다.";
                zipcodeSpan.innerText = "-";
            }
        } else {
            addressSpan.innerText = "Geocoder 실패: " + status;
            zipcodeSpan.innerText = "-";
        }
    });
}
