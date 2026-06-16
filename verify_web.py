import os
import time
import subprocess
import threading
from playwright.sync_api import sync_playwright

def run_server():
    os.chdir("web")
    subprocess.run(["python3", "-m", "http.server", "8000"])

def verify_web():
    # 서버 실행 (별도 스레드)
    server_thread = threading.Thread(target=run_server, daemon=True)
    server_thread.start()
    time.sleep(2) # 서버 부팅 대기

    with sync_playwright() as p:
        browser = p.chromium.launch()
        context = browser.new_context(
            permissions=['geolocation'],
            geolocation={'latitude': 37.5665, 'longitude': 126.9780}, # 서울특별시청 좌표
        )

        page = context.new_page()

        # Google Maps SDK 및 Geolocation 모킹
        page.add_init_script("""
            window.confirm = () => true;

            // Google Maps Mock
            window.google = {
                maps: {
                    Geocoder: class {
                        geocode(request, callback) {
                            callback([
                                {
                                    formatted_address: "대한민국 서울특별시 중구 세종대로 110",
                                    address_components: [
                                        { long_name: "04524", types: ["postal_code"] }
                                    ]
                                }
                            ], "OK");
                        }
                    }
                }
            };
        """)

        page.goto("http://localhost:8000/index.html")

        # 1. 초기 UI 검증
        if "위치 정보 확인 서비스" not in page.title():
            raise Exception("Title mismatch")

        # 2. 버튼 클릭 시뮬레이션
        page.click("#check-btn")

        # 3. 결과 대기 및 확인
        page.wait_for_selector("#address:has-text('서울특별시')")

        address_text = page.inner_text("#address")
        zipcode_text = page.inner_text("#zipcode")

        print(f"Address: {address_text}")
        print(f"Zipcode: {zipcode_text}")

        if "서울특별시" not in address_text or "04524" not in zipcode_text:
            raise Exception("Verification failed: Unexpected results")

        # 스크린샷 저장
        os.makedirs("verification/screenshots", exist_ok=True)
        page.screenshot(path="verification/screenshots/web_result.png")
        print("Screenshot saved to verification/screenshots/web_result.png")

        browser.close()

if __name__ == "__main__":
    verify_web()
