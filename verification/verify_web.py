import asyncio
import os
from playwright.async_api import async_playwright
import subprocess
import time

async def verify_web():
    # 1. 서버 시작
    os.system("fuser -k 8002/tcp || true")
    server_process = subprocess.Popen(['python3', '-m', 'http.server', '8002'], cwd='web')
    time.sleep(2)

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context()
        page = await context.new_page()

        # 페이지 로드 전 모든 것을 모킹
        await page.add_init_script("""
            window.confirm = () => true;

            // Geolocation 모킹
            Object.defineProperty(navigator, 'geolocation', {
                value: {
                    getCurrentPosition: (success) => {
                        success({
                            coords: {
                                latitude: 37.5665,
                                longitude: 126.9780
                            }
                        });
                    }
                }
            });

            // Google Maps Geocoder 모킹
            // 실제 스크립트 로드 후에 덮어씌워지지 않도록 처리
            const mockGeocoder = class {
                geocode(request, callback) {
                    callback([
                        {
                            formatted_address: '서울특별시 중구 세종대로 110 (태평로1가)',
                            address_components: [
                                { long_name: '04524', types: ['postal_code'] }
                            ]
                        }
                    ], 'OK');
                }
            };

            window.google = {
                maps: {
                    Geocoder: mockGeocoder
                }
            };

            // 스크립트 태그에 의해 window.google이 덮어씌워지는 것을 방지
            Object.defineProperty(window, 'google', {
                get: () => ({
                    maps: {
                        Geocoder: mockGeocoder
                    }
                }),
                set: () => {} // 무시
            });
        """)

        # 네트워크 요청 차단 (실제 Google Maps API 로드 방지)
        await page.route("https://maps.googleapis.com/**", lambda route: route.fulfill(status=200, body=""))

        await page.goto('http://localhost:8002/index.html')

        # 버튼 클릭
        await page.click('#check-btn')

        # 결과 대기
        await page.wait_for_selector('text=서울특별시 중구 세종대로 110', timeout=5000)

        # 검증 및 스크린샷
        address = await page.inner_text('#address')
        zipcode = await page.inner_text('#zipcode')
        print(f"Address: {address}")
        print(f"Zipcode: {zipcode}")

        await page.screenshot(path='verification/screenshots/web_result.png')

        await browser.close()

    server_process.terminate()

if __name__ == "__main__":
    asyncio.run(verify_web())
