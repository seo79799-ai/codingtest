import asyncio
import os
from playwright.async_api import async_playwright
import http.server
import socketserver
import threading
import time

PORT = 8001
DIRECTORY = "web"

class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True

def run_server():
    handler = lambda *args, **kwargs: http.server.SimpleHTTPRequestHandler(*args, directory=DIRECTORY, **kwargs)
    with ReusableTCPServer(("", PORT), handler) as httpd:
        print(f"Serving at port {PORT}")
        httpd.serve_forever()

async def verify():
    # Start server in a separate thread
    server_thread = threading.Thread(target=run_server, daemon=True)
    server_thread.start()
    time.sleep(2)  # Wait for server to start

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context(
            permissions=['geolocation'],
            geolocation={'latitude': 37.5665, 'longitude': 126.9780}, # Seoul coordinates
        )
        page = await context.new_page()

        # Mock Google Maps Geocoder and confirm dialog
        await page.add_init_script("""
            window.confirm = () => true;
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

        await page.goto(f"http://localhost:{PORT}/index.html")

        # Click the button
        await page.click("#check-location-btn")

        # Wait for results
        await page.wait_for_selector("#address:has-text('서울특별시')")

        # Take screenshot
        os.makedirs("verification/screenshots", exist_ok=True)
        await page.screenshot(path="verification/screenshots/web_result.png")
        print("Screenshot saved to verification/screenshots/web_result.png")

        await browser.close()

if __name__ == "__main__":
    asyncio.run(verify())
