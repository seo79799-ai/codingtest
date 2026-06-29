import asyncio
from playwright.async_api import async_playwright
import os
import http.server
import socketserver
import threading

class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True

def run_server(directory):
    class Handler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=directory, **kwargs)

    with ReusableTCPServer(("", 8001), Handler) as httpd:
        httpd.serve_forever()

async def verify_web():
    # Start server in a thread without changing os.chdir
    server_thread = threading.Thread(target=run_server, args=('web',), daemon=True)
    server_thread.start()
    await asyncio.sleep(2)

    root_dir = os.getcwd()
    screenshot_dir = os.path.join(root_dir, "verification/screenshots")
    os.makedirs(screenshot_dir, exist_ok=True)

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context()

        # Mocking geolocation and Google Maps Geocoder
        await context.add_init_script("""
            // Mock navigator.geolocation
            navigator.geolocation.getCurrentPosition = (success, error) => {
                success({
                    coords: {
                        latitude: 37.5665,
                        longitude: 126.9780
                    }
                });
            };

            // Mock google.maps.Geocoder
            window.google = {
                maps: {
                    Geocoder: class {
                        geocode(request, callback) {
                            callback([
                                {
                                    formatted_address: "서울특별시 중구 세종대로 110",
                                    address_components: [
                                        { long_name: "04524", types: ["postal_code"] }
                                    ]
                                }
                            ], "OK");
                        }
                    }
                }
            };

            // Mock window.confirm
            window.confirm = () => true;
        """)

        page = await context.new_page()
        await page.goto("http://localhost:8001/index.html")

        # 1. 기기 선택 확인 (기본 컴퓨터 위치)
        await page.click("#checkLocationBtn")
        await asyncio.sleep(1)

        # 2. 결과 캡처
        await page.screenshot(path=os.path.join(screenshot_dir, "web_result_computer.png"))

        # 3. 휴대폰 위치 선택 후 확인
        await page.check('input[value="mobile"]')
        await page.click("#checkLocationBtn")
        await asyncio.sleep(1)
        await page.screenshot(path=os.path.join(screenshot_dir, "web_result_mobile.png"))

        await browser.close()

if __name__ == "__main__":
    asyncio.run(verify_web())
