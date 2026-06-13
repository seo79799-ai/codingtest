import asyncio
import os
from playwright.async_api import async_playwright
import http.server
import socketserver
import threading

def run_server():
    os.chdir('web')
    handler = http.server.SimpleHTTPRequestHandler
    try:
        with socketserver.TCPServer(("", 8001), handler) as httpd:
            httpd.serve_forever()
    except Exception as e:
        print(f"Server error: {e}")

async def verify():
    # 서버 실행 (별도 스레드)
    server_thread = threading.Thread(target=run_server, daemon=True)
    server_thread.start()
    await asyncio.sleep(2)  # 서버 구동 대기

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context(
            permissions=['geolocation'],
            geolocation={'latitude': 37.5665, 'longitude': 126.9780} # 서울 시청 좌표
        )
        page = await context.new_page()

        # Geolocation 및 Google Maps SDK 모킹
        await page.add_init_script("""
            window.confirm = () => true;

            // google.maps.Geocoder 모킹
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

            const mockGeolocation = {
                getCurrentPosition: (success) => {
                    success({
                        coords: {
                            latitude: 37.5665,
                            longitude: 126.9780,
                            accuracy: 10
                        }
                    });
                }
            };
            navigator.geolocation.getCurrentPosition = mockGeolocation.getCurrentPosition;
        """)

        await page.goto('http://localhost:8001/index.html')

        # 버튼 클릭
        await page.click('button.main-button')

        # 결과 대기
        await page.wait_for_selector('#result', state='visible')

        # 결과 확인
        address = await page.inner_text('#addressLine')
        zip_code = await page.inner_text('#zipCodeLine')

        print(f"Verified Address: {address}")
        print(f"Verified Zip Code: {zip_code}")

        # 스크린샷 저장
        os.makedirs('../verification/screenshots', exist_ok=True)
        await page.screenshot(path='../verification/screenshots/web_result_v2.png')

        await browser.close()

if __name__ == "__main__":
    asyncio.run(verify())
