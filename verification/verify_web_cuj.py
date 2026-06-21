import asyncio
import os
import threading
from http.server import SimpleHTTPRequestHandler, HTTPServer
from playwright.async_api import async_playwright

class RootDirectoryHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory="web", **kwargs)

def run_server():
    server_address = ('', 8000)
    httpd = HTTPServer(server_address, RootDirectoryHandler)
    print("Serving at port 8000")
    httpd.serve_forever()

async def verify_web():
    # Start server in a separate thread
    threading.Thread(target=run_server, daemon=True).start()
    await asyncio.sleep(1)  # Wait for server to start

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context(
            permissions=['geolocation'],
            geolocation={'latitude': 37.5665, 'longitude': 126.9780}, # Seoul
            record_video_dir="verification/videos"
        )

        # Mock Google Maps Geocoder
        await context.add_init_script("""
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
                    },
                    GeocoderStatus: { OK: "OK" }
                }
            };
            // Mock confirm
            window.confirm = () => true;
        """)

        page = await context.new_page()
        await page.goto("http://localhost:8000/index.html")

        # Capture initial state
        await page.screenshot(path="verification/screenshots/web_initial.png")

        # Click the button
        await page.click("button.main-button")

        # Wait for result
        await page.wait_for_selector("text=도로명 주소: [컴퓨터 위치]")

        # Capture result state
        await page.screenshot(path="verification/screenshots/web_result.png")

        print("Verification complete. Results:")
        address_text = await page.inner_text("#addressResult")
        postcode_text = await page.inner_text("#postcodeResult")
        print(f"Address: {address_text}")
        print(f"Postcode: {postcode_text}")

        await browser.close()

if __name__ == "__main__":
    asyncio.run(verify_web())
