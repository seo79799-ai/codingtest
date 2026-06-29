/**
 * 위치 정보 확인 서비스 로직
 */

document.getElementById('checkLocationBtn').addEventListener('click', async () => {
    // 1단계: 위치정보법 준수를 위한 동의 팝업
    const consent = confirm("정확한 주소 확인을 위해 현재 위치 정보를 수집합니다. 동의하시겠습니까?");

    if (!consent) {
        alert("위치 정보 수집에 동의하지 않으시면 서비스를 이용하실 수 없습니다.");
        return;
    }

    // 2단계: 브라우저 Geolocation API를 통한 좌표 수집
    if (!navigator.geolocation) {
        alert("이 브라우저는 위치 정보를 지원하지 않습니다.");
        return;
    }

    navigator.geolocation.getCurrentPosition(
        async (position) => {
            const lat = position.coords.latitude;
            const lng = position.coords.longitude;

            // 기기 선택 값 가져오기
            const deviceType = document.querySelector('input[name="device"]:checked').value;
            const prefix = deviceType === 'computer' ? '[컴퓨터 위치] ' : '[휴대폰 위치] ';

            try {
                // 3단계: Google Maps Reverse Geocoding API 호출
                await convertCoordsToAddress(lat, lng, prefix);
            } catch (error) {
                console.error(error);
                alert("주소 변환 중 오류가 발생했습니다.");
            }
        },
        (error) => {
            alert("위치 정보를 가져오는 데 실패했습니다: " + error.message);
        }
    );
});

/**
 * 좌표를 주소와 우편번호로 변환하는 함수
 */
async function convertCoordsToAddress(lat, lng, prefix) {
    if (!window.google || !window.google.maps) {
        throw new Error("Google Maps SDK가 로드되지 않았습니다.");
    }

    const geocoder = new google.maps.Geocoder();
    const latlng = { lat: parseFloat(lat), lng: parseFloat(lng) };

    geocoder.geocode({ location: latlng, language: 'ko' }, (results, status) => {
        if (status === "OK") {
            if (results[0]) {
                // 결과 표시
                const address = results[0].formatted_address;
                let zipCode = "정보 없음";

                // 우편번호 추출 (address_components에서 'postal_code' 찾기)
                for (const component of results[0].address_components) {
                    if (component.types.includes("postal_code")) {
                        zipCode = component.long_name;
                        break;
                    }
                }

                document.getElementById('addressResult').innerText = `도로명 주소: ${prefix}${address}`;
                document.getElementById('zipCodeResult').innerText = `우편번호: ${zipCode}`;
            } else {
                alert("결과를 찾을 수 없습니다.");
            }
        } else {
            alert("Geocoder 실패: " + status);
        }
    });
}
