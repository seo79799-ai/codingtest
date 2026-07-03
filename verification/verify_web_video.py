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

async def run_cuj(page):
    await page.goto(f"http://localhost:{PORT}/index.html")
    await page.wait_for_timeout(1000)

    # 1. Select Device (Mobile)
    await page.click('input[value="mobile"]')
    await page.wait_for_timeout(1000)

    # 2. Click Check Button
    await page.click("#check-btn")
    await page.wait_for_timeout(2000)

    # 3. Take screenshot at the final state
    await page.screenshot(path="/home/jules/verification/screenshots/final_result.png")
    await page.wait_for_timeout(2000)

async def verify():
    # Start server in a thread
    server_thread = threading.Thread(target=run_server, daemon=True)
    server_thread.start()
    time.sleep(1) # Wait for server to start

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(
            record_video_dir="/home/jules/verification/videos"
        )

        # Mocking Geolocation and Google Maps API
        await context.add_init_script("""
            // Mock navigator.geolocation
            navigator.geolocation.getCurrentPosition = (success) => {
                setTimeout(() => {
                    success({
                        coords: {
                            latitude: 37.5665,
                            longitude: 126.9780
                        }
                    });
                }, 500);
            };

            // Mock window.confirm to always return true
            window.confirm = () => true;

            // Mock Google Maps Geocoder
            window.google = {
                maps: {
                    Geocoder: class {
                        geocode(request, callback) {
                            setTimeout(() => {
                                callback([
                                    {
                                        formatted_address: "서울특별시 중구 세종대로 110",
                                        address_components: [
                                            { long_name: "04524", types: ["postal_code"] }
                                        ]
                                    }
                                ], "OK");
                            }, 500);
                        }
                    }
                }
            };
        """)

        page = await context.new_page()
        try:
            await run_cuj(page)
        finally:
            await context.close()
            await browser.close()

        print("Verification with video successful!")

if __name__ == "__main__":
    os.makedirs("/home/jules/verification/screenshots", exist_ok=True)
    os.makedirs("/home/jules/verification/videos", exist_ok=True)
    asyncio.run(verify())
