import asyncio
import os
import threading
from http.server import SimpleHTTPRequestHandler
from socketserver import TCPServer
from playwright.async_api import async_playwright

class ReusableTCPServer(TCPServer):
    allow_reuse_address = True

def run_server():
    handler = lambda *args, **kwargs: SimpleHTTPRequestHandler(*args, directory='web', **kwargs)
    with ReusableTCPServer(("", 8001), handler) as httpd:
        print("Server started at localhost:8001")
        httpd.serve_forever()

async def verify_web():
    # 서버를 별도 스레드에서 실행
    server_thread = threading.Thread(target=run_server, daemon=True)
    server_thread.start()
    await asyncio.sleep(1) # 서버 시작 대기

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context()
        page = await context.new_page()

        # 콘솔 로그 출력
        page.on("console", lambda msg: print(f"PAGE LOG: {msg.text}"))
        page.on("pageerror", lambda exc: print(f"PAGE ERROR: {exc}"))

        # 실제 Google Maps 스크립트 로드 차단
        await page.route("https://maps.googleapis.com/**", lambda route: route.abort())

        # Google Maps 및 Geolocation 모킹
        await page.add_init_script("""
            window.confirm = () => true;

            navigator.geolocation.getCurrentPosition = (success) => {
                console.log("Mocked Geolocation called");
                success({
                    coords: {
                        latitude: 37.5665,
                        longitude: 126.9780
                    }
                });
            };

            const mockGoogle = {
                maps: {
                    Geocoder: class {
                        geocode(request, callback) {
                            console.log("Mocked Geocode called");
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

            Object.defineProperty(window, 'google', {
                value: mockGoogle,
                writable: false,
                configurable: false
            });
        """)

        await page.goto("http://localhost:8001/index.html")

        # 버튼 클릭 전 상태 확인
        print("Initial state check...")
        address_before = await page.inner_text("#address")
        print(f"Address before: {address_before}")

        # 버튼 클릭
        await page.click("#getLocationBtn")

        # 결과 대기
        await page.wait_for_timeout(1000)

        # 결과 확인
        address_after = await page.inner_text("#address")
        zipcode = await page.inner_text("#zipcode")
        print(f"Address after: {address_after}")
        print(f"Zipcode: {zipcode}")

        # 스크린샷 저장 (절대 경로 사용 권장)
        screenshot_path = os.path.join(os.getcwd(), "verification/screenshots/web_result.png")
        print(f"Saving screenshot to: {screenshot_path}")
        await page.screenshot(path=screenshot_path)

        await browser.close()

if __name__ == "__main__":
    asyncio.run(verify_web())
