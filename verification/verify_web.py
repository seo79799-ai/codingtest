import asyncio
import os
from playwright.async_api import async_playwright
import http.server
import socketserver
import threading

# 1. 간단한 웹 서버 실행 (web 디렉토리 서비스)
PORT = 8000
DIRECTORY = "web"

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

def run_server():
    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        httpd.allow_reuse_address = True
        print(f"Serving at port {PORT}")
        httpd.serve_forever()

async def verify_web():
    # 서버를 별도 스레드에서 시작
    server_thread = threading.Thread(target=run_server, daemon=True)
    server_thread.start()
    await asyncio.sleep(2)  # 서버 시작 대기

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context(
            permissions=['geolocation'],
            geolocation={'latitude': 37.5665, 'longitude': 126.9780} # 서울 시청 위치
        )
        page = await context.new_page()

        # Mocking Geolocation and Google Maps SDK
        await page.add_init_script("""
            // Mock confirm
            window.confirm = () => true;

            // Mock Google Maps Geocoder
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
        """)

        await page.goto(f"http://localhost:{PORT}/index.html")

        # 기기 선택 (휴대폰 선택해보기)
        await page.check('input[value="휴대폰"]')

        # 버튼 클릭
        await page.click('#getLocationBtn')

        # 결과 대기
        await page.wait_for_selector('#roadAddress:has-text("도로명 주소: [휴대폰 위치] 서울특별시 중구 세종대로 110 (태평로1가)")')

        # 스크린샷 저장
        os.makedirs("verification/screenshots", exist_ok=True)
        await page.screenshot(path="verification/screenshots/web_verification.png")
        print("Web verification screenshot saved.")

        await browser.close()

if __name__ == "__main__":
    asyncio.run(verify_web())
