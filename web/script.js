/**
 * 1단계: DOM 요소 참조 및 초기화
 */
const getLocationBtn = document.getElementById('getLocationBtn');
const consentModal = document.getElementById('consentModal');
const agreeBtn = document.getElementById('agreeBtn');
const denyBtn = document.getElementById('denyBtn');
const resultArea = document.getElementById('resultArea');
const roadAddressTxt = document.getElementById('roadAddress');
const zipCodeTxt = document.getElementById('zipCode');

// Google Maps API 로딩 확인 및 Geocoder 초기화 (API 키가 없어도 목업 등으로 테스트 가능하도록 구성)
let geocoder;

/**
 * 2단계: 위치 정보 확인 버튼 클릭 시 동의 팝업 표시
 */
getLocationBtn.addEventListener('click', () => {
    consentModal.style.display = 'block';
});

/**
 * 3단계: 사용자 동의 처리
 */
denyBtn.addEventListener('click', () => {
    consentModal.style.display = 'none';
    alert('위치 정보 접근이 거부되었습니다.');
});

agreeBtn.addEventListener('click', () => {
    consentModal.style.display = 'none';
    requestLocation();
});

/**
 * 4단계: 브라우저 Geolocation API를 사용하여 좌표 수집
 */
function requestLocation() {
    if (!navigator.geolocation) {
        alert('이 브라우저는 위치 정보를 지원하지 않습니다.');
        return;
    }

    navigator.geolocation.getCurrentPosition(
        (position) => {
            const lat = position.coords.latitude;
            const lng = position.coords.longitude;

            // 기기 선택 값 가져오기 (결과에 프리픽스 추가용)
            const device = document.querySelector('input[name="device"]:checked').value;
            const prefix = device === 'computer' ? '[컴퓨터 위치]' : '[휴대폰 위치]';

            // Google Maps Reverse Geocoding 호출
            convertToAddress(lat, lng, prefix);
        },
        (error) => {
            console.error('위치 획득 실패:', error);
            alert('위치 정보를 가져오지 못했습니다.');
        },
        { enableHighAccuracy: true }
    );
}

/**
 * 5단계: Google Maps Reverse Geocoding API를 사용하여 주소로 변환
 */
function convertToAddress(lat, lng, prefix) {
    // google 객체가 없는 경우(API 미로드 시)를 대비한 예외 처리
    if (typeof google === 'undefined' || !google.maps) {
        console.warn('Google Maps API가 로드되지 않았습니다.');
        // 테스트용 더미 데이터 표시
        displayResult(prefix + " 서울특별시 중구 세종대로 110", "04524");
        return;
    }

    if (!geocoder) {
        geocoder = new google.maps.Geocoder();
    }

    const latlng = { lat: lat, lng: lng };

    geocoder.geocode({ location: latlng, language: 'ko' }, (results, status) => {
        if (status === 'OK') {
            if (results[0]) {
                const address = results[0].formatted_address;
                let postalCode = '알 수 없음';

                // 주소 컴포넌트에서 우편번호 추출
                for (const component of results[0].address_components) {
                    if (component.types.includes('postal_code')) {
                        postalCode = component.long_name;
                        break;
                    }
                }

                displayResult(prefix + " " + address, postalCode);
            } else {
                alert('결과를 찾을 수 없습니다.');
            }
        } else {
            console.error('Geocoder 실패:', status);
            alert('주소 변환에 실패했습니다.');
        }
    });
}

/**
 * 6단계: 결과를 화면에 표시
 */
function displayResult(address, zip) {
    roadAddressTxt.innerText = `도로명 주소: ${address}`;
    zipCodeTxt.innerText = `우편번호: ${zip}`;
    resultArea.style.display = 'block';
}
