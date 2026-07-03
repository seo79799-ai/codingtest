import asyncio
from playwright.async_api import async_playwright
import os
import http.server
import socketserver
import threading
import time

PORT = 8001
DIRECTORY = "web"

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True

def run_server():
    with ReusableTCPServer(("", PORT), Handler) as httpd:
        print(f"Serving at port {PORT}")
        httpd.serve_forever()

async def verify():
    # Start server in a thread
    server_thread = threading.Thread(target=run_server, daemon=True)
    server_thread.start()
    time.sleep(1) # Wait for server to start

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context()

        # Mocking Geolocation and Google Maps API
        await context.add_init_script("""
            // Mock navigator.geolocation
            navigator.geolocation.getCurrentPosition = (success) => {
                success({
                    coords: {
                        latitude: 37.5665,
                        longitude: 126.9780
                    }
                });
            };

            // Mock window.confirm to always return true
            window.confirm = () => true;

            // Mock Google Maps Geocoder
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
        """)

        page = await context.new_page()
        await page.goto(f"http://localhost:{PORT}/index.html")

        # Capture initial state
        await page.screenshot(path="verification/screenshots/initial.png")

        # Click the button
        await page.click("#check-btn")

        # Wait for result
        await page.wait_for_selector("text=도로명 주소: [컴퓨터 위치] 서울특별시 중구 세종대로 110")

        # Capture result
        await page.screenshot(path="verification/screenshots/web_result.png")

        print("Verification successful!")
        await browser.close()

if __name__ == "__main__":
    os.makedirs("verification/screenshots", exist_ok=True)
    asyncio.run(verify())
