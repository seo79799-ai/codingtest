import asyncio
from playwright.async_api import async_playwright
import os
import subprocess
import time

async def verify_web():
    async with async_playwright() as p:
        # 로컬 서버 실행 (포트 8000)
        server_process = subprocess.Popen(["python3", "-m", "http.server", "8000", "--directory", "web"])
        time.sleep(2) # 서버 시작 대기

        try:
            browser = await p.chromium.launch()
            context = await browser.new_context(
                permissions=["geolocation"],
                geolocation={"latitude": 37.5665, "longitude": 126.9780} # 서울 시청 좌표
            )
            page = await context.new_page()
            page.on("console", lambda msg: print(f"BROWSER CONSOLE: {msg.text}"))
            page.on("pageerror", lambda exc: print(f"BROWSER ERROR: {exc}"))

            # window.confirm 및 google.maps.Geocoder 모킹
            await page.add_init_script("""
                window.confirm = () => true;

                const mockGoogle = {
                    maps: {
                        Geocoder: class {
                            geocode(query, callback) {
                                console.log('Mock Geocoder called');
                                callback([
                                    {
                                        formatted_address: '서울특별시 중구 태평로1가 31',
                                        address_components: [
                                            { long_name: '04524', types: ['postal_code'] }
                                        ]
                                    }
                                ], 'OK');
                            }
                        },
                        GeocoderStatus: {
                            OK: 'OK'
                        }
                    }
                };

                // google.maps 객체를 고정하기 위한 Proxy 사용
                window.google = new Proxy({}, {
                    get: (target, prop) => {
                        if (prop === 'maps') return mockGoogle.maps;
                        return target[prop];
                    },
                    set: (target, prop, value) => {
                        console.log('Attempt to set google.' + prop);
                        if (prop === 'maps') {
                             console.log('Blocking maps override');
                             return true;
                        }
                        target[prop] = value;
                        return true;
                    }
                });

                // geocoder가 호출되었는지 확인하기 위한 디버깅용
                window.onerror = (msg, url, line) => {
                    console.log('WINDOW ERROR: ' + msg);
                };

                // navigator.geolocation 모킹
                const mockGeolocation = {
                    getCurrentPosition: (success, error, options) => {
                        console.log('Mock getCurrentPosition called');
                        success({
                            coords: {
                                latitude: 37.5665,
                                longitude: 126.9780
                            }
                        });
                    }
                };
                Object.defineProperty(navigator, 'geolocation', {
                    get: () => mockGeolocation,
                    configurable: true
                });
            """)

            await page.goto("http://localhost:8000/index.html")

            # 버튼 클릭
            await page.click("button.main-button")

            # 결과 대기
            await page.wait_for_selector("#address-result:has-text('도로명 주소: [컴퓨터]')")

            # 스크린샷 캡처
            os.makedirs("verification/screenshots", exist_ok=True)
            await page.screenshot(path="verification/screenshots/web_result.png")

            address = await page.inner_text("#address-result")
            postcode = await page.inner_text("#postcode-result")

            print(f"Verified Address: {address}")
            print(f"Verified Postcode: {postcode}")

            assert "서울특별시 중구 태평로1가 31" in address
            assert "04524" in postcode

            print("Web Verification Successful!")

        finally:
            await browser.close()
            server_process.terminate()

if __name__ == "__main__":
    asyncio.run(verify_web())
