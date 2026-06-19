import asyncio
import os
from playwright.async_api import async_playwright
import threading
import http.server
import socketserver
import time

def run_server(web_dir):
    class MyHandler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=web_dir, **kwargs)

    try:
        with socketserver.TCPServer(("", 8002), MyHandler) as httpd:
            httpd.serve_forever()
    except Exception as e:
        print(f"Server error: {e}")

async def verify_web():
    web_dir = os.path.abspath('web')
    server_thread = threading.Thread(target=run_server, args=(web_dir,), daemon=True)
    server_thread.start()
    await asyncio.sleep(2)

    screenshot_dir = 'verification/screenshots'
    os.makedirs(screenshot_dir, exist_ok=True)

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context(
            permissions=['geolocation']
        )

        page = await context.new_page()

        await page.add_init_script("""
            navigator.geolocation.getCurrentPosition = (success) => {
                success({
                    coords: {
                        latitude: 37.5665,
                        longitude: 126.9780
                    }
                });
            };
            window.confirm = () => true;
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
            Object.defineProperty(window, 'google', { writable: false, configurable: false });
        """)

        await page.goto("http://localhost:8002/index.html")

        await page.screenshot(path=os.path.join(screenshot_dir, "web_initial.png"))
        await page.click("#get-location-btn")
        await page.wait_for_selector("#result-area", state="visible")
        await asyncio.sleep(1)
        await page.screenshot(path=os.path.join(screenshot_dir, "web_result.png"))

        address = await page.inner_text("#address-text")
        zipcode = await page.inner_text("#zipcode-text")

        print(f"Address: {address}")
        print(f"Zipcode: {zipcode}")

        if "서울특별시 중구 세종대로 110" in address and "04524" in zipcode:
            print("Web Verification Successful!")
        else:
            print("Web Verification Failed!")

        await browser.close()

if __name__ == "__main__":
    asyncio.run(verify_web())
