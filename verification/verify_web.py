import asyncio
import os
import http.server
import socketserver
import threading
from playwright.async_api import async_playwright

# 1단계: 간단한 HTTP 서버 설정
PORT = 8001
DIRECTORY = "web"

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

def run_server():
    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        print(f"Serving at port {PORT}")
        httpd.serve_forever()

async def verify():
    # 서버를 별도 스레드에서 실행
    server_thread = threading.Thread(target=run_server, daemon=True)
    server_thread.start()
    await asyncio.sleep(2)  # 서버가 뜰 때까지 대기

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context()
        page = await context.new_page()

        # 2단계: Geolocation 및 Google Maps API 모킹
        await page.add_init_script("""
            // Geolocation 모킹
            navigator.geolocation.getCurrentPosition = (success) => {
                success({
                    coords: {
                        latitude: 37.5665,
                        longitude: 126.9780
                    }
                });
            };

            // Google Maps API 모킹
            Object.defineProperty(window, 'google', {
                value: {
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
                                ], 'OK');
                            }
                        }
                    }
                },
                writable: false,
                configurable: false
            });
        """)

        # 3단계: 페이지 접속 및 동작 테스트
        # 실제 Google Maps SDK 로드를 차단하여 모킹이 덮어씌워지는 것을 방지
        await page.route("https://maps.googleapis.com/**", lambda route: route.abort())

        await page.goto(f"http://localhost:{PORT}/index.html")

        # '컴퓨터 위치' 선택됨 확인
        await page.click("#getLocationBtn")

        # 동의 팝업 확인 및 클릭
        await page.wait_for_selector("#consentModal", state="visible")
        await page.click("#agreeBtn")

        # 결과 표시 대기
        await page.wait_for_selector("#resultArea", state="visible")

        # 결과 텍스트 검증
        road_address = await page.inner_text("#roadAddress")
        zip_code = await page.inner_text("#zipCode")

        print(f"검증 결과 - {road_address}")
        print(f"검증 결과 - {zip_code}")

        # 스크린샷 저장
        os.makedirs("verification/screenshots", exist_ok=True)
        await page.screenshot(path="verification/screenshots/web_result.png")

        if "서울특별시 중구 세종대로 110" in road_address and "04524" in zip_code:
            print("웹 버전 검증 성공!")
        else:
            print("웹 버전 검증 실패: 결과가 예상과 다릅니다.")
            exit(1)

        await browser.close()

if __name__ == "__main__":
    asyncio.run(verify())
