from playwright.sync_api import sync_playwright
import os
import time
import threading
from http.server import SimpleHTTPRequestHandler, HTTPServer

def run_server():
    os.chdir("web")
    server_address = ('', 8000)
    httpd = HTTPServer(server_address, SimpleHTTPRequestHandler)
    httpd.serve_forever()

def run_cuj(page):
    # Geolocation 및 Google Maps API 모킹
    page.add_init_script("""
        // navigator.geolocation 모킹
        navigator.geolocation.getCurrentPosition = (success, error, options) => {
            success({
                coords: {
                    latitude: 37.5665,
                    longitude: 126.9780,
                    accuracy: 10
                },
                timestamp: Date.now()
            });
        };

        // confirm 모킹 (자동 동의)
        window.confirm = () => true;

        // google.maps.Geocoder 모킹
        window.google = {
            maps: {
                Geocoder: class {
                    geocode(request, callback) {
                        const results = [{
                            formatted_address: "서울특별시 중구 세종대로 110 (태평로1가)",
                            address_components: [
                                { long_name: "110", types: ["street_number"] },
                                { long_name: "세종대로", types: ["route"] },
                                { long_name: "04524", types: ["postal_code"] }
                            ]
                        }];
                        callback(results, "OK");
                    }
                }
            }
        };
    """)

    # 페이지 접속
    page.goto("http://localhost:8000/index.html")
    page.wait_for_timeout(1000)

    # 1. 기기 선택 (휴대폰 위치로 변경해보기)
    page.check("#mobile")
    page.wait_for_timeout(500)

    # 2. 확인 버튼 클릭
    page.click("button.main-button")
    page.wait_for_timeout(2000) # 주소 변환 대기

    # 3. 결과 확인
    address_text = page.inner_text("#address")
    postcode_text = page.inner_text("#postcode")

    print(f"결과 확인 - 도로명 주소: {address_text}")
    print(f"결과 확인 - 우편번호: {postcode_text}")

    # 스크린샷 저장
    page.screenshot(path="/home/jules/verification/screenshots/web_verification.png")
    page.wait_for_timeout(1000)

if __name__ == "__main__":
    # 서버 실행 (별도 스레드)
    server_thread = threading.Thread(target=run_server, daemon=True)
    server_thread.start()
    time.sleep(2) # 서버 시작 대기

    os.makedirs("/home/jules/verification/videos", exist_ok=True)
    os.makedirs("/home/jules/verification/screenshots", exist_ok=True)

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            record_video_dir="/home/jules/verification/videos"
        )
        page = context.new_page()
        try:
            run_cuj(page)
        finally:
            context.close()
            browser.close()
