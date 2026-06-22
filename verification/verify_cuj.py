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

async def run_cuj():
    port = 8012
    server_thread = threading.Thread(target=run_server, args=(port,), daemon=True)
    server_thread.start()
    await asyncio.sleep(2)

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        # 비디오 녹화 설정
        context = await browser.new_context(
            record_video_dir="/home/jules/verification/videos"
        )
        page = await context.new_page()

        # Mocking
        await page.route("https://maps.googleapis.com/maps/api/js*", lambda route: route.fulfill(
            status=200,
            content_type="application/javascript",
            body="console.log('Google Maps API mocked');"
        ))

        await page.add_init_script("""
            window.confirm = () => true;

            Object.defineProperty(navigator, 'geolocation', {
                value: {
                    getCurrentPosition: (success, error) => {
                        setTimeout(() => {
                            success({
                                coords: {
                                    latitude: 37.5665,
                                    longitude: 126.9780
                                }
                            });
                        }, 500);
                    }
                },
                writable: false
            });

            window.google = {
                maps: {
                    Geocoder: class {
                        geocode(request, callback) {
                            setTimeout(() => {
                                callback([
                                    {
                                        formatted_address: '서울특별시 중구 세종대로 110 (태평로1가)',
                                        address_components: [
                                            { long_name: '04524', types: ['postal_code'] }
                                        ]
                                    }
                                ], 'OK');
                            }, 500);
                        }
                    }
                }
            };
            Object.defineProperty(window, 'google', { writable: false, configurable: false });
        """)

        await page.goto(f'http://localhost:{port}/index.html')
        await asyncio.sleep(1) # Load time

        # 1. '컴퓨터 위치' 선택된 상태로 확인 버튼 클릭
        await page.click('#check-btn')
        await asyncio.sleep(0.5)

        # 2. 결과 나타날 때까지 대기
        await page.wait_for_function("document.getElementById('address-val').innerText !== ''", timeout=10000)
        await asyncio.sleep(1)

        # 캡처
        await page.screenshot(path='/home/jules/verification/screenshots/web_pc_result.png')

        # 3. '휴대폰 위치'로 변경하고 다시 확인
        await page.click('label[for="mobile"]')
        await asyncio.sleep(0.5)
        await page.click('#check-btn')
        await asyncio.sleep(0.5)

        # 결과 업데이트 대기 (접두어가 바뀌는지 확인)
        await page.wait_for_function("document.getElementById('address-val').innerText.includes('[휴대폰 위치]')", timeout=10000)
        await asyncio.sleep(1)

        # 최종 캡처
        await page.screenshot(path='/home/jules/verification/screenshots/web_mobile_result.png')
        await asyncio.sleep(1)

        await context.close()
        await browser.close()

if __name__ == "__main__":
    asyncio.run(run_cuj())
