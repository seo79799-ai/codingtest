import asyncio
import os
from playwright.async_api import async_playwright
import threading
import http.server
import socketserver

class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True

def start_server():
    # 서버 실행 시 디렉토리를 절대 경로로 지정하거나 SimpleHTTPRequestHandler의 directory 인자를 사용
    web_dir = os.path.join(os.getcwd(), 'web')
    handler = lambda *args: http.server.SimpleHTTPRequestHandler(*args, directory=web_dir)
    try:
        with ReusableTCPServer(("", 8003), handler) as httpd:
            print("서버 시작: http://localhost:8003")
            httpd.serve_forever()
    except Exception as e:
        print(f"서버 에러: {e}")

async def verify_web():
    # 백그라운드에서 서버 시작
    server_thread = threading.Thread(target=start_server, daemon=True)
    server_thread.start()
    await asyncio.sleep(2)

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context()

        await context.add_init_script("""
            navigator.geolocation.getCurrentPosition = (success, error) => {
                setTimeout(() => {
                    success({
                        coords: {
                            latitude: 37.5665,
                            longitude: 126.9780
                        }
                    });
                }, 100);
            };
            window.confirm = () => true;
            const mockGoogle = {
                maps: {
                    Geocoder: class {
                        geocode(request, callback) {
                            setTimeout(() => {
                                callback([
                                    {
                                        formatted_address: "서울특별시 중구 세종대로 110 (태평로1가)",
                                        address_components: [
                                            { long_name: "04524", types: ["postal_code"] }
                                        ]
                                    }
                                ], "OK");
                            }, 100);
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

        page = await context.new_page()
        await page.goto("http://localhost:8003/index.html")

        # 버튼 클릭
        await page.wait_for_selector("#checkLocationBtn")
        await page.click("#checkLocationBtn")

        # 결과 대기
        await page.wait_for_selector("text=서울특별시 중구", timeout=10000)

        # 절대 경로로 스크린샷 저장
        screenshot_path = os.path.join(os.getcwd(), "verification/screenshots/web_verify.png")
        await page.screenshot(path=screenshot_path)
        print(f"검증 완료: {screenshot_path}")

        await browser.close()

if __name__ == "__main__":
    asyncio.run(verify_web())
