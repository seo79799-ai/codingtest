import asyncio
import os
from playwright.async_api import async_playwright

async def verify_web():
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        # Geolocation 권한 부여
        context = await browser.new_context(
            permissions=['geolocation'],
            record_video_dir="verification/videos"
        )
        page = await context.new_page()

        # Mock Geolocation and Google Maps API
        await page.add_init_script("""
            // Mock window.confirm to always return true
            window.confirm = () => true;

            // Mock navigator.geolocation
            const mockGeolocation = {
                getCurrentPosition: (success) => {
                    setTimeout(() => {
                        success({
                            coords: {
                                latitude: 37.5665,
                                longitude: 126.9780
                            }
                        });
                    }, 100);
                }
            };
            navigator.geolocation.getCurrentPosition = mockGeolocation.getCurrentPosition;

            // Mock fetch for Google Maps API
            const originalFetch = window.fetch;
            window.fetch = async (...args) => {
                if (args[0].includes('maps.googleapis.com/maps/api/geocode/json')) {
                    return {
                        ok: true,
                        json: async () => ({
                            status: "OK",
                            results: [{
                                formatted_address: "서울특별시 중구 세종대로 110 (태평로1가)",
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

        # 서버가 실행 중이라고 가정하고 파일 경로로 직접 접근 (python http.server 사용 가능)
        # 여기서는 파일 경로를 직접 사용
        file_path = f"file://{os.getcwd()}/web/index.html"
        await page.goto(file_path)

        # 1. 초기 화면 캡처
        await page.screenshot(path="verification/initial_view.png")
        print("초기 화면 캡처 완료")

        # 2. '휴대폰 위치' 선택
        await page.click('label[for="mobile"]')

        # 3. 버튼 클릭
        await page.click('#check-btn')

        # 4. 결과 대기 (비동기 처리를 고려하여 잠시 대기)
        await page.wait_for_selector('text=서울특별시 중구 세종대로 110')

        # 5. 결과 화면 캡처
        await page.screenshot(path="verification/result_view.png")
        print("결과 화면 캡처 완료")

        # 결과 텍스트 확인
        address_text = await page.inner_text('#address-display')
        zipcode_text = await page.inner_text('#zipcode-display')

        print(f"결과 주소: {address_text}")
        print(f"결과 우편번호: {zipcode_text}")

        if "서울특별시 중구" in address_text and "04524" in zipcode_text:
            print("검증 성공: 주소와 우편번호가 올바르게 표시됩니다.")
        else:
            print("검증 실패: 결과가 예상과 다릅니다.")

        await browser.close()

if __name__ == "__main__":
    asyncio.run(verify_web())
