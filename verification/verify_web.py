import asyncio
import os
import http.server
import socketserver
import threading
from playwright.async_api import async_playwright

class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True

def run_server(port):
    handler = http.server.SimpleHTTPRequestHandler
    with ReusableTCPServer(("", port), handler) as httpd:
        httpd.serve_forever()

async def verify_web():
    port = 8001
    server_thread = threading.Thread(target=run_server, args=(port,), daemon=True)
    server_thread.start()

    # 서버 기동 대기
    await asyncio.sleep(2)

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context(
            permissions=['geolocation'],
            geolocation={'latitude': 37.5665, 'longitude': 126.9780}, # 서울 좌표
        )
        page = await context.new_page()

        # Google Maps Mocking
        await page.add_init_script("""
            window.google = {
                maps: {
                    Geocoder: class {
                        geocode(request, callback) {
                            callback([
                                {
                                    formatted_address: '서울특별시 중구 세종대로 110',
                                    address_components: [
                                        { long_name: '04524', types: ['postal_code'] }
                                    ]
                                }
                            ], 'OK');
                        }
                    }
                }
            };
            // window.confirm mocking
            window.confirm = () => true;
        """)

        # 페이지 접속 (web 디렉토리를 root로 서빙한다고 가정)
        await page.goto(f"http://localhost:{port}/web/index.html")

        # 기기 선택 및 버튼 클릭
        await page.click('#checkLocationBtn')

        # 결과 대기
        await page.wait_for_selector('#address:has-text("서울특별시")')

        # 스크린샷 저장
        os.makedirs('verification/screenshots', exist_ok=True)
        await page.screenshot(path='verification/screenshots/web_result.png')

        address_text = await page.inner_text('#address')
        zipcode_text = await page.inner_text('#zipcode')

        print(f"검증된 주소: {address_text}")
        print(f"검증된 우편번호: {zipcode_text}")

        assert "서울특별시" in address_text
        assert "04524" in zipcode_text
        print("웹 버전 검증 성공!")

        await browser.close()

if __name__ == "__main__":
    asyncio.run(verify_web())
