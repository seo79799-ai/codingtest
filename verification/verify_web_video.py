import asyncio
import os
import http.server
import socketserver
import threading
from playwright.async_api import async_playwright

class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True

def run_server(port):
    handler = http.server.SimpleHTTPRequestHandler
    with ReusableTCPServer(("", port), handler) as httpd:
        httpd.serve_forever()

async def verify_web_video():
    port = 8001
    server_thread = threading.Thread(target=run_server, args=(port,), daemon=True)
    server_thread.start()

    await asyncio.sleep(2)

    video_dir = '/home/jules/verification/videos'
    screenshot_dir = '/home/jules/verification/screenshots'
    os.makedirs(video_dir, exist_ok=True)
    os.makedirs(screenshot_dir, exist_ok=True)

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(
            permissions=['geolocation'],
            geolocation={'latitude': 37.5665, 'longitude': 126.9780},
            record_video_dir=video_dir
        )
        page = await context.new_page()

        # Google Maps & Geolocation Mocking
        await page.add_init_script("""
            window.google = {
                maps: {
                    Geocoder: class {
                        geocode(request, callback) {
                            callback([
                                {
                                    formatted_address: '서울특별시 중구 세종대로 110 (태평로1가)',
                                    address_components: [
                                        { long_name: '04524', types: ['postal_code'] }
                                    ]
                                }
                            ], 'OK');
                        }
                    }
                }
            };
            window.confirm = () => true;
        """)

        # 1. 페이지 접속
        await page.goto(f"http://localhost:{port}/web/index.html")
        await page.wait_for_timeout(1000)

        # 2. 기기 선택 변경 (휴대폰 위치로 변경해보기)
        await page.click('input[value="mobile"]')
        await page.wait_for_timeout(500)

        # 3. 버튼 클릭
        await page.click('#checkLocationBtn')
        await page.wait_for_timeout(1000)

        # 4. 결과 확인 및 스크린샷
        await page.wait_for_selector('#address:has-text("서울특별시")')
        await page.screenshot(path=f"{screenshot_dir}/web_final_verification.png")
        await page.wait_for_timeout(2000)

        await context.close()
        await browser.close()

if __name__ == "__main__":
    asyncio.run(verify_web_video())
