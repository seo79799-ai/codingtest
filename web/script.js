/**
 * 위치 정보 확인 서비스 Logic
 */

document.getElementById('checkLocationBtn').addEventListener('click', async () => {
    // 단계 1: 위치정보법 준수를 위한 사용자 동의 팝업
    const consent = confirm("서비스 제공을 위해 현재 위치 정보를 수집합니다. 동의하시겠습니까?");

    if (!consent) {
        alert("위치 정보 수집에 동의하지 않으시면 주소를 확인할 수 없습니다.");
        return;
    }

    // 선택된 기기 타입 확인
    const deviceType = document.querySelector('input[name="device"]:checked').value;
    const deviceLabel = deviceType === 'computer' ? '[컴퓨터 위치]' : '[휴대폰 위치]';

    // 단계 2: 브라우저 Geolocation API를 통한 좌표 수집
    if (!navigator.geolocation) {
        alert("이 브라우저는 위치 정보를 지원하지 않습니다.");
        return;
    }

    navigator.geolocation.getCurrentPosition(
        async (position) => {
            const { latitude, longitude } = position.coords;

            // 단계 3: Google Maps Reverse Geocoding API를 사용하여 주소 변환
            try {
                const addressData = await reverseGeocode(latitude, longitude);

                // 결과 표시
                document.getElementById('address').textContent = `${deviceLabel} ${addressData.formattedAddress}`;
                document.getElementById('zipcode').textContent = addressData.postalCode;
            } catch (error) {
                console.error(error);
                alert("주소 변환 중 오류가 발생했습니다.");
            }
        },
        (error) => {
            console.error(error);
            alert("위치 정보를 가져오는 데 실패했습니다.");
        }
    );
});

/**
 * Google Maps Geocoder를 사용하여 위도/경도를 주소로 변환하는 함수
 */
async function reverseGeocode(lat, lng) {
    return new Promise((resolve, reject) => {
        // Google Maps SDK가 로드되었는지 확인
        if (typeof google === 'undefined' || !google.maps || !google.maps.Geocoder) {
            reject("Google Maps API가 로드되지 않았습니다.");
            return;
        }

        const geocoder = new google.maps.Geocoder();
        const latlng = { lat: parseFloat(lat), lng: parseFloat(lng) };

        geocoder.geocode({ location: latlng, language: 'ko' }, (results, status) => {
            if (status === "OK") {
                if (results[0]) {
                    const formattedAddress = results[0].formatted_address;
                    let postalCode = "-";

                    // 주소 구성 요소에서 우편번호(postal_code) 추출
                    for (let component of results[0].address_components) {
                        if (component.types.includes("postal_code")) {
                            postalCode = component.long_name;
                            break;
                        }
                    }

                    resolve({
                        formattedAddress: formattedAddress,
                        postalCode: postalCode
                    });
                } else {
                    reject("결과를 찾을 수 없습니다.");
                }
            } else {
                reject("Geocoder failed due to: " + status);
            }
        });
    });
}
