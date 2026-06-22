import asyncio
import os
import http.server
import socketserver
import threading
from playwright.async_api import async_playwright

def run_server(port):
    web_dir = os.path.join(os.getcwd(), 'web')
    class Handler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=web_dir, **kwargs)

    with socketserver.TCPServer(("", port), Handler) as httpd:
        httpd.serve_forever()

async def verify_web():
    port = 8010
    server_thread = threading.Thread(target=run_server, args=(port,), daemon=True)
    server_thread.start()
    await asyncio.sleep(2)

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context()
        page = await context.new_page()

        # Mocking: Google Maps SDK 로드 시도 자체를 막고, 전역 google 객체를 직접 정의
        await page.route("https://maps.googleapis.com/maps/api/js*", lambda route: route.fulfill(
            status=200,
            content_type="application/javascript",
            body="console.log('Google Maps API script blocked and replaced by mock');"
        ))

        await page.add_init_script("""
            window.confirm = () => true;

            // navigator.geolocation 모킹
            Object.defineProperty(navigator, 'geolocation', {
                value: {
                    getCurrentPosition: (success, error) => {
                        success({
                            coords: {
                                latitude: 37.5665,
                                longitude: 126.9780
                            }
                        });
                    }
                },
                writable: false
            });

            // google.maps 객체 모킹
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
            Object.defineProperty(window, 'google', { writable: false, configurable: false });
        """)

        await page.goto(f'http://localhost:{port}/index.html')

        await page.click('#check-btn')

        # 주소 값이 채워질 때까지 대기
        await page.wait_for_function("document.getElementById('address-val').innerText !== ''", timeout=10000)

        await page.screenshot(path='verification/result_web.png')

        address = await page.inner_text('#address-val')
        zip_code = await page.inner_text('#zip-val')

        print(f"Address: {address}")
        print(f"Zip Code: {zip_code}")

        success = '서울특별시 중구 세종대로 110' in address and '04524' in zip_code
        print(f"Verification {'Successful' if success else 'Failed'}!")

        await browser.close()

if __name__ == "__main__":
    asyncio.run(verify_web())
