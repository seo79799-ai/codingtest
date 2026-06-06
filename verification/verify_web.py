import asyncio
import os
from playwright.async_api import async_playwright
import subprocess
import time

async def verify_web():
    # 1. 로컬 서버 시작
    server_process = subprocess.Popen(['python3', '-m', 'http.server', '8000'], cwd='web')
    time.sleep(2)  # 서버 구동 대기

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context(
            permissions=['geolocation'],
            geolocation={'latitude': 37.5665, 'longitude': 126.9780} # 서울 시청 좌표
        )
        page = await context.new_page()

        # Geolocation 및 Fetch 모킹
        await page.add_init_script("""
            // confirm 팝업 항상 true 반환
            window.confirm = () => true;

            // navigator.geolocation 모킹
            navigator.geolocation.getCurrentPosition = (success) => {
                success({
                    coords: {
                        latitude: 37.5665,
                        longitude: 126.9780
                    }
                });
            };

            // fetch 모킹 (Google Geocoding API 결과 시뮬레이션)
            const originalFetch = window.fetch;
            window.fetch = async (...args) => {
                if (args[0].includes('maps.googleapis.com')) {
                    return {
                        ok: true,
                        json: async () => ({
                            status: 'OK',
                            results: [{
                                formatted_address: '서울특별시 중구 세종대로 110',
                                address_components: [{
                                    long_name: '04524',
                                    types: ['postal_code']
                                }]
                            }]
                        })
                    };
                }
                return originalFetch(...args);
            };
        """)

        await page.goto('http://localhost:8000/index.html')

        # 버튼 클릭 시뮬레이션
        await page.click('button.main-button')

        # 결과가 나타날 때까지 대기
        await page.wait_for_selector('#roadAddress:has-text("서울특별시")')

        # 스크린샷 저장
        os.makedirs('verification/screenshots', exist_ok=True)
        await page.screenshot(path='verification/screenshots/web_result.png')

        # 결과 확인
        road_address = await page.inner_text('#roadAddress')
        zip_code = await page.inner_text('#zipCode')

        print(f"Road Address Result: {road_address}")
        print(f"Zip Code Result: {zip_code}")

        await browser.close()

    # 서버 종료
    server_process.terminate()

if __name__ == '__main__':
    asyncio.run(verify_web())
