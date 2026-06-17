import asyncio
import os
import subprocess
import time
from playwright.async_api import async_playwright

async def verify_web():
    # 1. 로컬 서버 시작
    server_process = subprocess.Popen(['python3', '-m', 'http.server', '8000'], cwd='web')
    time.sleep(2)  # 서버 시작 대기

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context()
        page = await context.new_page()

        # 2. Geolocation 및 Google Maps API 모킹
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

            // window.confirm 모킹
            window.confirm = () => true;

            // Google Maps Geocoder 모킹
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
                    }
                }
            };
        """)

        # 3. 페이지 접속 및 동작 수행
        await page.goto("http://localhost:8000/index.html")
        await page.click("button:has-text('현재 위치 확인할까요?')")

        # 4. 결과 확인
        await page.wait_for_selector("p:has-text('도로명 주소: [컴퓨터 위치]')")

        # 스크린샷 저장
        os.makedirs("verification/screenshots", exist_ok=True)
        await page.screenshot(path="verification/screenshots/web_verification.png")

        print("Web verification successful!")

        await browser.close()

    server_process.terminate()

if __name__ == "__main__":
    asyncio.run(verify_web())
