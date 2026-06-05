import asyncio
from playwright.async_api import async_playwright
import os
import subprocess
import time

async def verify_web():
    # 1. 서버 시작
    server_process = subprocess.Popen(['python3', '-m', 'http.server', '8000'], cwd='web')
    time.sleep(2)  # 서버가 뜰 때까지 대기

    try:
        async with async_playwright() as p:
            browser = await p.chromium.launch()
            # geolocation 권한 허용
            context = await browser.new_context(
                permissions=['geolocation'],
                geolocation={'latitude': 37.5665, 'longitude': 126.9780}
            )

            # 초기 스크립트 설정 (페이지 로드 전)
            await context.add_init_script("""
                window.confirm = () => {
                    console.log("CONFIRM_CALLED");
                    return true;
                };

                // Geolocation 모킹
                navigator.geolocation.getCurrentPosition = (success, error) => {
                    console.log("GEOLOCATION_CALLED");
                    success({
                        coords: {
                            latitude: 37.5665,
                            longitude: 126.9780
                        }
                    });
                };

                const originalFetch = window.fetch;
                window.fetch = async (...args) => {
                    console.log("FETCH_CALLED: " + args[0]);
                    if (args[0].includes('maps.googleapis.com')) {
                        return {
                            ok: true,
                            status: 200,
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

            page = await context.new_page()

            # 콘솔 로그 출력
            page.on("console", lambda msg: print(f"BROWSER: {msg.text}"))

            # 2. 페이지 접속
            await page.goto('http://localhost:8000/index.html')

            # 3. 버튼 클릭
            print("버튼 클릭 중...")
            await page.click('button:has-text("현재 위치 확인할까요?")')

            # 결과 표시 대기
            try:
                await page.wait_for_selector('text=서울특별시 중구 세종대로 110', timeout=5000)
                print("결과 확인 성공!")
                await page.screenshot(path='verification/web_success.png')
            except Exception as e:
                print(f"결과 확인 실패: {e}")
                await page.screenshot(path='verification/web_error.png')

            await browser.close()
    finally:
        server_process.terminate()

if __name__ == "__main__":
    asyncio.run(verify_web())
