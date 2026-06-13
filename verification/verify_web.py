import asyncio
import os
from playwright.async_api import async_playwright
import http.server
import socketserver
import threading

def run_server():
    os.chdir('web')
    handler = http.server.SimpleHTTPRequestHandler
    with socketserver.TCPServer(("", 8000), handler) as httpd:
        httpd.serve_forever()

async def verify():
    # 서버 실행 (별도 스레드)
    server_thread = threading.Thread(target=run_server, daemon=True)
    server_thread.start()
    await asyncio.sleep(2)  # 서버 구동 대기

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context(
            permissions=['geolocation'],
            geolocation={'latitude': 37.5665, 'longitude': 126.9780} # 서울 시청 좌표
        )
        page = await context.new_page()

        # Geolocation 및 Fetch API 모킹
        await page.add_init_script("""
            // confirm() 모킹 - 항상 true 반환
            window.confirm = () => true;

            // navigator.geolocation 모킹
            const mockGeolocation = {
                getCurrentPosition: (success) => {
                    success({
                        coords: {
                            latitude: 37.5665,
                            longitude: 126.9780,
                            accuracy: 10
                        }
                    });
                }
            };
            navigator.geolocation.getCurrentPosition = mockGeolocation.getCurrentPosition;

            // fetch API 모킹 - Google Maps 응답 시뮬레이션
            const originalFetch = window.fetch;
            window.fetch = async (...args) => {
                if (args[0].includes('maps.googleapis.com')) {
                    return {
                        ok: true,
                        json: async () => ({
                            status: "OK",
                            results: [{
                                formatted_address: "대한민국 서울특별시 중구 세종대로 110",
                                address_components: [
                                    { long_name: "04524", types: ["postal_code"] }
                                ]
                            }]
                        })
                    };
                }
                return originalFetch(...args);
            };
        """)

        await page.goto('http://localhost:8000/index.html')

        # 버튼 클릭
        await page.click('button.main-button')

        # 결과 대기 (잠시 대기하여 텍스트가 렌더링되도록 함)
        await page.wait_for_selector('#result', state='visible')

        # 결과 확인
        address = await page.inner_text('#addressLine')
        zip_code = await page.inner_text('#zipCodeLine')

        print(f"Verified Address: {address}")
        print(f"Verified Zip Code: {zip_code}")

        # 스크린샷 저장
        os.makedirs('verification/screenshots', exist_ok=True)
        await page.screenshot(path='verification/screenshots/web_result.png')

        await browser.close()

if __name__ == "__main__":
    asyncio.run(verify())
