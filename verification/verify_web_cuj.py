import asyncio
from playwright.async_api import async_playwright
import os
import http.server
import socketserver
import threading
import time

PORT = 8000
DIRECTORY = "web"

class MyHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

def run_server():
    with socketserver.TCPServer(("", PORT), MyHandler) as httpd:
        httpd.allow_reuse_address = True
        print(f"Serving at port {PORT}")
        httpd.serve_forever()

async def verify_web():
    # Start server in a thread
    server_thread = threading.Thread(target=run_server, daemon=True)
    server_thread.start()
    time.sleep(1) # Wait for server to start

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context(
            permissions=['geolocation'],
        )
        page = await context.new_page()

        # Mock Geolocation and Google Maps
        await page.add_init_script("""
            // Mock navigator.geolocation
            navigator.geolocation.getCurrentPosition = (success, error) => {
                success({
                    coords: {
                        latitude: 37.5665,
                        longitude: 126.9780
                    }
                });
            };

            // Mock window.confirm
            window.confirm = () => true;

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
                    },
                    GeocoderStatus: { OK: "OK" }
                }
            };
        """)

        await page.goto(f"http://localhost:{PORT}/index.html")

        # Initial screenshot
        await page.screenshot(path="verification/screenshots/web_initial.png")
        print("Initial page captured.")

        # Click check button
        await page.click("#checkLocationBtn")

        # Wait for results
        await page.wait_for_selector("text=서울특별시 중구 세종대로 110")

        # Final screenshot
        await page.screenshot(path="verification/screenshots/web_result.png")
        print("Result page captured.")

        # Verify text
        address_text = await page.inner_text("#addressResult")
        zipcode_text = await page.inner_text("#zipcodeResult")

        print(f"Address Result: {address_text}")
        print(f"Zipcode Result: {zipcode_text}")

        assert "서울특별시 중구 세종대로 110" in address_text
        assert "04524" in zipcode_text

        await browser.close()

if __name__ == "__main__":
    asyncio.run(verify_web())
