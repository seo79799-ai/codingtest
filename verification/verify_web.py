import asyncio
import os
import threading
from http.server import SimpleHTTPRequestHandler, HTTPServer
from playwright.async_api import async_playwright

class ReusableTCPServer(HTTPServer):
    allow_reuse_address = True

def run_server():
    server_address = ('', 8001)
    # SimpleHTTPRequestHandler serves files from the current working directory.
    # In this context, it will be the repository root if we don't change it.
    # We'll use a handler that serves from the 'web' directory.
    class WebHandler(SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory="web", **kwargs)

    httpd = ReusableTCPServer(server_address, WebHandler)
    httpd.serve_forever()

async def verify_web():
    # Start local server in a separate thread
    server_thread = threading.Thread(target=run_server, daemon=True)
    server_thread.start()
    await asyncio.sleep(2)  # Wait for server to start

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context(
            permissions=['geolocation'],
            geolocation={'latitude': 37.5665, 'longitude': 126.9780}, # Seoul
        )
        page = await context.new_page()

        # Mock Google Maps API
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
            // Mock confirm to return true
            window.confirm = () => true;
        """)

        await page.goto('http://localhost:8001/index.html')

        # 1. 초기 상태 확인
        await page.wait_for_selector('#getLocationBtn')
        await page.screenshot(path='verification/screenshots/initial_state.png')

        # 2. 버튼 클릭 및 결과 확인
        await page.click('#getLocationBtn')

        # 결과가 나타날 때까지 대기
        await page.wait_for_selector('#resultArea', state='visible')

        # 주소와 우편번호가 올바르게 표시되는지 확인
        address = await page.inner_text('#address')
        zipcode = await page.inner_text('#zipcode')

        print(f"Detected Address: {address}")
        print(f"Detected Zipcode: {zipcode}")

        await page.screenshot(path='verification/screenshots/result_state.png')

        if "서울특별시" in address and "04524" in zipcode:
            print("Web Verification Successful!")
        else:
            print("Web Verification Failed!")
            exit(1)

        await browser.close()

if __name__ == "__main__":
    asyncio.run(verify_web())
