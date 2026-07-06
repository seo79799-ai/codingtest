import asyncio
import os
import threading
from http.server import SimpleHTTPRequestHandler, HTTPServer
from playwright.async_api import async_playwright

class ReusableTCPServer(HTTPServer):
    allow_reuse_address = True

def run_server():
    server_address = ('', 8001)
    class WebHandler(SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory="web", **kwargs)

    httpd = ReusableTCPServer(server_address, WebHandler)
    httpd.serve_forever()

async def verify_web_video():
    # Start local server in a separate thread
    server_thread = threading.Thread(target=run_server, daemon=True)
    server_thread.start()
    await asyncio.sleep(2)  # Wait for server to start

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        # Video is a context-level feature
        context = await browser.new_context(
            permissions=['geolocation'],
            geolocation={'latitude': 37.5665, 'longitude': 126.9780}, # Seoul
            record_video_dir="verification/videos"
        )
        page = await context.new_page()

        # Mock Google Maps API and confirm dialog
        await page.add_init_script("""
            window.google = {
                maps: {
                    Geocoder: class {
                        geocode(request, callback) {
                            callback([
                                {
                                    formatted_address: "서울특별시 중구 세종대로 110 (태평로1가)",
                                    address_components: [
                                        { long_name: "04524", types: ["postal_code"] },
                                        { long_name: "서울특별시", types: ["administrative_area_level_1"] }
                                    ]
                                }
                            ], "OK");
                        }
                    }
                }
            };
            window.confirm = () => true;
        """)

        await page.goto('http://localhost:8001/index.html')
        await page.wait_for_timeout(1000)

        # 1. 초기 상태 스크린샷
        await page.screenshot(path='verification/screenshots/initial_state.png')
        await page.wait_for_timeout(500)

        # 2. 버튼 클릭
        await page.click('#getLocationBtn')
        await page.wait_for_timeout(500)

        # 결과가 나타날 때까지 대기
        await page.wait_for_selector('#resultArea', state='visible')
        await page.wait_for_timeout(1000)

        # 3. 결과 상태 스크린샷
        await page.screenshot(path='verification/screenshots/final_result.png')
        await page.wait_for_timeout(1000) # Hold final state for video

        await context.close()
        await browser.close()

if __name__ == "__main__":
    asyncio.run(verify_web_video())
