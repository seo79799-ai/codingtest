document.getElementById('getLocationBtn').addEventListener('click', async () => {
    // 0. Google Maps SDK 로드 여부 확인
    if (typeof google === 'undefined' || !google.maps || !google.maps.Geocoder) {
        alert("Google Maps 서비스가 아직 로드되지 않았습니다. 잠시 후 다시 시도해주세요.");
        return;
    }

    // 1. 위치 정보 수집 전 사용자 동의 확인 (위치정보법 준수)
    const consent = confirm("사용자의 현재 위치 정보를 수집하여 주소로 변환하는 서비스입니다. 위치 정보 접근에 동의하십니까?");

    if (!consent) {
        alert("위치 정보 접근 동의가 필요합니다.");
        return;
    }

    // 2. 브라우저의 Geolocation API 사용
    if (!navigator.geolocation) {
        alert("이 브라우저는 위치 정보를 지원하지 않습니다.");
        return;
    }

    navigator.geolocation.getCurrentPosition(
        async (position) => {
            const lat = position.coords.latitude;
            const lng = position.coords.longitude;

            // 선택된 기기 값 가져오기
            const device = document.querySelector('input[name="device"]:checked').value;
            const prefix = `[${device} 위치] `;

            try {
                // 3. Google Maps Reverse Geocoding 수행
                const addressData = await reverseGeocode(lat, lng);

                // 4. 결과 표시
                document.getElementById('roadAddress').innerText = `도로명 주소: ${prefix}${addressData.roadAddress}`;
                document.getElementById('zipCode').innerText = `우편번호: ${addressData.zipCode}`;
            } catch (error) {
                console.error(error);
                alert("주소 변환 중 오류가 발생했습니다.");
            }
        },
        (error) => {
            console.error(error);
            alert("위치 정보를 가져오는 데 실패했습니다.");
        },
        { enableHighAccuracy: true }
    );
});

/**
 * Google Maps API를 사용하여 좌표를 주소로 변환합니다.
 */
function reverseGeocode(lat, lng) {
    return new Promise((resolve, reject) => {
        const geocoder = new google.maps.Geocoder();
        const latlng = { lat: parseFloat(lat), lng: parseFloat(lng) };

        geocoder.geocode({ location: latlng }, (results, status) => {
            if (status === "OK") {
                if (results[0]) {
                    // 결과에서 도로명 주소와 우편번호 추출
                    const roadAddress = results[0].formatted_address;
                    let zipCode = "정보 없음";

                    // address_components에서 postal_code 찾기
                    for (const component of results[0].address_components) {
                        if (component.types.includes("postal_code")) {
                            zipCode = component.long_name;
                            break;
                        }
                    }

                    resolve({ roadAddress, zipCode });
                } else {
                    reject("결과를 찾을 수 없습니다.");
                }
            } else {
                reject("Geocoder failed due to: " + status);
            }
        });
    });
}
