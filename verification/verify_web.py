import asyncio
from playwright.async_api import async_playwright
import os
import http.server
import socketserver
import threading
import time

# 간단한 HTTP 서버 설정
PORT = 8001
DIRECTORY = "web"

class MyTCPServer(socketserver.TCPServer):
    allow_reuse_address = True

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

def run_server():
    try:
        with MyTCPServer(("", PORT), Handler) as httpd:
            print(f"Serving at port {PORT}")
            httpd.serve_forever()
    except Exception as e:
        print(f"Server error: {e}")

async def verify_web():
    # 서버를 별도 스레드에서 실행
    server_thread = threading.Thread(target=run_server, daemon=True)
    server_thread.start()
    time.sleep(2)  # 서버 시작 대기

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        # 위치 정보 권한 및 좌표 mock 설정
        context = await browser.new_context(
            permissions=['geolocation'],
            geolocation={'latitude': 37.5665, 'longitude': 126.9780}, # 서울 시청
            viewport={'width': 1280, 'height': 720}
        )
        page = await context.new_page()

        # 외부 구글 맵 스크립트 차단 및 mock
        await page.route("https://maps.googleapis.com/**", lambda route: route.fulfill(
            status=200,
            content_type="application/javascript",
            body="window.google = { maps: { Geocoder: class { geocode(req, cb) { cb([{formatted_address: '대한민국 서울특별시 중구 세종대로 110', address_components: [{long_name: '04524', types: ['postal_code']}]}], 'OK'); } } } };"
        ))

        # confirm 팝업 자동 승인 및 google mock 보강
        await page.add_init_script("""
            window.confirm = () => {
                console.log("Confirm called");
                return true;
            };
            // 만약 스크립트 로드 전에 실행될 경우를 대비
            if (!window.google) {
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
            }
        """)

        await page.goto(f"http://localhost:{PORT}/index.html")

        # 버튼 클릭 전 스크린샷
        await page.screenshot(path="verification/web_initial.png")

        # 확인 버튼 클릭
        await page.click("#getLocationBtn")

        # 결과 대기
        await page.wait_for_selector("text=서울특별시 중구 세종대로 110", timeout=5000)

        # 결과 확인 스크린샷
        await page.screenshot(path="verification/web_result.png")

        # 텍스트 검증
        address_text = await page.inner_text("#addressResult")
        zip_text = await page.inner_text("#zipResult")

        print(f"Address Result: {address_text}")
        print(f"Zip Result: {zip_text}")

        assert "서울특별시 중구 세종대로 110" in address_text
        assert "04524" in zip_text

        await browser.close()

if __name__ == "__main__":
    asyncio.run(verify_web())
