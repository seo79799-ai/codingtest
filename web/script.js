/**
 * 단순 위치 확인 서비스 로직 (Web)
 */

document.getElementById('check-location-btn').addEventListener('click', async () => {
    // 단계 1: 위치 정보 수집 전 사용자 동의 확인 (위치정보법 준수)
    const userConsent = confirm("정확한 주소 확인을 위해 현재 위치 정보를 수집하는 것에 동의하십니까?");

    if (!userConsent) {
        alert("위치 정보 수집에 동의하셔야 서비스 이용이 가능합니다.");
        return;
    }

    const deviceType = document.querySelector('input[name="device"]:checked').value;
    const addressElement = document.getElementById('address');
    const zipcodeElement = document.getElementById('zipcode');

    addressElement.innerText = "가져오는 중...";
    zipcodeElement.innerText = "가져오는 중...";

    // 단계 2: 브라우저 Geolocation API를 통한 좌표(위도, 경도) 수집
    if ("geolocation" in navigator) {
        navigator.geolocation.getCurrentPosition(
            async (position) => {
                const lat = position.coords.latitude;
                const lng = position.coords.longitude;

                // 단계 3: Google Maps Reverse Geocoding API를 사용하여 주소로 변환
                try {
                    await reverseGeocode(lat, lng, deviceType);
                } catch (error) {
                    console.error(error);
                    alert("주소 변환 중 오류가 발생했습니다.");
                }
            },
            (error) => {
                console.error(error);
                alert("위치 정보를 가져올 수 없습니다. 브라우저 설정을 확인해주세요.");
            },
            { enableHighAccuracy: true, timeout: 5000, maximumAge: 0 }
        );
    } else {
        alert("이 브라우저는 위치 정보를 지원하지 않습니다.");
    }
});

/**
 * Google Maps SDK를 사용한 좌표 -> 주소 변환 함수
 */
async function reverseGeocode(lat, lng, deviceType) {
    if (!window.google || !window.google.maps) {
        throw new Error("Google Maps SDK가 로드되지 않았습니다.");
    }

    const geocoder = new google.maps.Geocoder();
    const latlng = { lat: parseFloat(lat), lng: parseFloat(lng) };

    geocoder.geocode({ location: latlng, language: 'ko' }, (results, status) => {
        if (status === "OK") {
            if (results[0]) {
                // 단계 4: 결과 데이터 추출 및 UI 표시
                // 결과에 [컴퓨터 위치] 또는 [휴대폰 위치] 접두사 추가
                const formattedAddress = `[${deviceType} 위치] ${results[0].formatted_address}`;
                let postalCode = "-";

                // 주소 구성 요소에서 우편번호(postal_code) 찾기
                for (const component of results[0].address_components) {
                    if (component.types.includes("postal_code")) {
                        postalCode = component.long_name;
                        break;
                    }
                }

                document.getElementById('address').innerText = formattedAddress;
                document.getElementById('zipcode').innerText = postalCode;
            } else {
                alert("결과를 찾을 수 없습니다.");
            }
        } else {
            alert("Geocoder 실패: " + status);
        }
    });
}
