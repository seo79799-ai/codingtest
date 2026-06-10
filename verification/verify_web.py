import asyncio
import os
from playwright.async_api import async_playwright
import subprocess
import time

async def verify_web():
    # 1. 로컬 서버 시작
    server_process = subprocess.Popen(['python3', '-m', 'http.server', '8000'], cwd='web')
    time.sleep(2)  # 서버가 뜰 때까지 대기

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context(
            permissions=['geolocation'],
            geolocation={'latitude': 37.5665, 'longitude': 126.9780} # 서울 시청 좌표
        )
        page = await context.new_page()

        # 2. Geolocation 및 Fetch API 모킹
        await page.add_init_script("""
            // window.confirm 모킹
            window.confirm = () => true;

            // navigator.geolocation.getCurrentPosition 모킹
            navigator.geolocation.getCurrentPosition = (success) => {
                success({
                    coords: {
                        latitude: 37.5665,
                        longitude: 126.9780
                    }
                });
            };

            // fetch API 모킹 (Google Maps Geocoding API)
            const originalFetch = window.fetch;
            window.fetch = async (...args) => {
                if (args[0].includes('maps.googleapis.com')) {
                    return {
                        json: async () => ({
                            status: 'OK',
                            results: [{
                                formatted_address: '대한민국 서울특별시 중구 세종대로 110',
                                address_components: [
                                    { long_name: '04524', types: ['postal_code'] }
                                ]
                            }]
                        })
                    };
                }
                return originalFetch(...args);
            };
        """)

        # 3. 페이지 접속 및 동작 수행
        await page.goto('http://localhost:8000/index.html')

        # '컴퓨터 위치' 선택 확인 (기본값)
        await page.click('button:has-text("현재 위치 확인할까요?")')

        # 4. 결과 대기 및 확인
        await page.wait_for_selector('text=도로명 주소: [Computer]')

        # 스크린샷 저장
        os.makedirs('verification', exist_ok=True)
        await page.screenshot(path='verification/web_result.png')
        print("Verification screenshot saved to verification/web_result.png")

        await browser.close()

    server_process.terminate()

if __name__ == "__main__":
    asyncio.run(verify_web())
