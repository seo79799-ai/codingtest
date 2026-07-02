/**
 * 위치 정보 확인 서비스 - 메인 로직 (script.js)
 */

document.addEventListener('DOMContentLoaded', () => {
    const btn = document.getElementById('getLocationBtn');
    const addressSpan = document.querySelector('#addressResult span');
    const zipSpan = document.querySelector('#zipResult span');

    // '현재 위치 확인할까요?' 버튼 클릭 이벤트 리스너
    btn.addEventListener('click', () => {
        // [위치정보법 준수] 사용자에게 위치 정보 수집 동의를 구하는 팝업
        const consent = confirm("사용자의 위치 정보를 수집하여 주소를 확인하시겠습니까?\n이 정보는 주소 변환 목적으로만 사용됩니다.");

        if (!consent) {
            alert("위치 정보 동의가 거부되었습니다.");
            return;
        }

        // 로딩 상태 표시
        addressSpan.textContent = "가져오는 중...";
        zipSpan.textContent = "가져오는 중...";

        // 1단계: 브라우저의 Geolocation API를 통해 위도/경도 수집
        if (!navigator.geolocation) {
            alert("이 브라우저는 위치 정보를 지원하지 않습니다.");
            updateResults("지원 불가", "지원 불가");
            return;
        }

        navigator.geolocation.getCurrentPosition(
            (position) => {
                const lat = position.coords.latitude;
                const lng = position.coords.longitude;

                // 2단계: 수집된 좌표를 Google Maps Geocoder로 변환
                reverseGeocode(lat, lng);
            },
            (error) => {
                console.error("위치 획득 실패:", error);
                alert("위치 정보를 가져오는 데 실패했습니다: " + error.message);
                updateResults("획득 실패", "획득 실패");
            },
            {
                enableHighAccuracy: true,
                timeout: 10000,
                maximumAge: 0
            }
        );
    });

    /**
     * Google Maps Reverse Geocoding API를 사용하여 좌표를 주소로 변환
     */
    function reverseGeocode(lat, lng) {
        // Geocoder 라이브러리 로드 확인
        if (typeof google === 'undefined' || !google.maps || !google.maps.Geocoder) {
            console.error("Google Maps API가 로드되지 않았습니다.");
            alert("Google Maps 서비스를 이용할 수 없습니다.");
            updateResults("API 오류", "API 오류");
            return;
        }

        const geocoder = new google.maps.Geocoder();
        const latlng = { lat: parseFloat(lat), lng: parseFloat(lng) };

        // 3단계: Geocoding 서비스 호출 (한국어 설정은 index.html 스크립트 로드 시 포함됨)
        geocoder.geocode({ location: latlng }, (results, status) => {
            if (status === "OK") {
                if (results[0]) {
                    // 결과에서 전체 주소와 우편번호 추출
                    const formattedAddress = results[0].formatted_address;
                    let zipCode = "제공되지 않음";

                    // 주소 구성 요소 중 'postal_code' 찾기
                    for (const component of results[0].address_components) {
                        if (component.types.includes("postal_code")) {
                            zipCode = component.long_name;
                            break;
                        }
                    }

                    // 선택된 기기 유형 접두사 추가
                    const deviceType = document.querySelector('input[name="device"]:checked').value;
                    const finalAddress = `[${deviceType} 위치] ${formattedAddress}`;

                    // 최종 결과 반영
                    updateResults(finalAddress, zipCode);
                } else {
                    updateResults("주소를 찾을 수 없음", "결과 없음");
                }
            } else {
                console.error("Geocode 실패 원인: " + status);
                updateResults("변환 실패 (" + status + ")", "변환 실패");
            }
        });
    }

    function updateResults(address, zip) {
        addressSpan.textContent = address;
        zipSpan.textContent = zip;
        // 로딩 스타일 제거
        addressSpan.classList.remove('loading');
        zipSpan.classList.remove('loading');
    }
});
