import os
import asyncio
from playwright.async_api import async_playwright
import threading
import http.server
import socketserver

def start_server():
    os.chdir('/app/web')
    handler = http.server.SimpleHTTPRequestHandler
    with socketserver.TCPServer(("", 8000), handler) as httpd:
        httpd.serve_forever()

async def verify_web():
    # 서버 실행 (별도 스레드)
    server_thread = threading.Thread(target=start_server, daemon=True)
    server_thread.start()
    await asyncio.sleep(2)  # 서버 시작 대기

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context(
            permissions=['geolocation'],
            geolocation={'latitude': 37.5665, 'longitude': 126.9780} # 서울 시청 좌표
        )
        page = await context.new_page()

        # Google Maps API 및 Geolocation 모킹
        await page.add_init_script("""
            window.confirm = () => true;

            // Google Maps Geocoder Mock
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

        await page.goto('http://localhost:8000/index.html')

        # 1. UI 요소 확인
        await page.wait_for_selector('#checkLocationBtn')

        # 2. 버튼 클릭
        await page.click('#checkLocationBtn')

        # 3. 결과 확인
        await page.wait_for_function('document.getElementById("address").innerText.includes("서울특별시")')

        address = await page.inner_text('#address')
        zipcode = await page.inner_text('#zipcode')

        print(f"Address: {address}")
        print(f"Zipcode: {zipcode}")

        # 스크린샷 저장
        os.makedirs('/app/verification/screenshots', exist_ok=True)
        await page.screenshot(path='/app/verification/screenshots/web_verification.png')

        await browser.close()

if __name__ == "__main__":
    asyncio.run(verify_web())
