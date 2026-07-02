import asyncio
import os
import http.server
import socketserver
import threading
from playwright.async_api import async_playwright

# 포트 설정
PORT = 8001
DIRECTORY = "web"

class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True

def start_server():
    handler = lambda *args, **kwargs: http.server.SimpleHTTPRequestHandler(*args, directory=DIRECTORY, **kwargs)
    with ReusableTCPServer(("", PORT), handler) as httpd:
        print(f"Serving at port {PORT}")
        httpd.serve_forever()

async def verify():
    # 서버를 별도 스레드에서 실행
    server_thread = threading.Thread(target=start_server, daemon=True)
    server_thread.start()
    await asyncio.sleep(2) # 서버 시작 대기

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context(
            permissions=['geolocation'],
            record_video_dir="verification/videos"
        )
        page = await context.new_page()

        # Google Maps API 요청 차단 및 모킹
        await page.route("https://maps.googleapis.com/**", lambda route: route.abort())

        # Geolocation 및 Google Maps Geocoder 모킹 주입
        await page.add_init_script("""
            // 1. Geolocation 모킹
            navigator.geolocation.getCurrentPosition = (success, error, options) => {
                success({
                    coords: {
                        latitude: 37.5665,
                        longitude: 126.9780,
                        accuracy: 10
                    }
                });
            };

            // 2. confirm 팝업 자동 승인
            window.confirm = () => true;

            // 3. Google Maps SDK 모킹
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

        # 페이지 접속
        await page.goto(f"http://localhost:{PORT}/index.html")

        # '컴퓨터 위치' 라디오 버튼 확인 (기본값)
        is_computer_checked = await page.is_checked('input[value="컴퓨터"]')
        print(f"Computer radio checked: {is_computer_checked}")

        # 버튼 클릭
        await page.click("#getLocationBtn")

        # 결과 대기 및 확인
        await page.wait_for_selector('#addressResult span:not(.loading)')

        address_text = await page.inner_text("#addressResult")
        zip_text = await page.inner_text("#zipResult")

        print(f"Result Address: {address_text}")
        print(f"Result Zip Code: {zip_text}")

        # 스크린샷 저장
        os.makedirs("verification/screenshots", exist_ok=True)
        await page.screenshot(path="verification/screenshots/web_result.png")

        await browser.close()

if __name__ == "__main__":
    asyncio.run(verify())
