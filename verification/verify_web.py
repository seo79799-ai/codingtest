import asyncio
import os
import json
from playwright.async_api import async_playwright

async def verify_web_app():
    async with async_playwright() as p:
        # 브라우저 실행
        browser = await p.chromium.launch(headless=True)
        # 위치 정보 권한 부여
        context = await browser.new_context(
            permissions=['geolocation'],
            geolocation={'latitude': 37.5665, 'longitude': 126.9780} # 서울시청 좌표
        )
        page = await context.new_page()

        # 로컬 서버 대용으로 파일 경로 직접 접속
        file_path = f"file://{os.path.abspath('web/index.html')}"
        await page.goto(file_path)

        # 1. 초기 UI 상태 확인
        await page.wait_for_selector('#checkLocationBtn')
        print("UI Loaded successfully.")

        # 2. Google Maps API 모킹
        # 실제 API 호출을 가로채서 가상의 응답 반환
        await page.route("**/maps/api/geocode/json?*", lambda route: route.fulfill(
            status=200,
            content_type="application/json",
            body=json.dumps({
                "status": "OK",
                "results": [{
                    "formatted_address": "대한민국 서울특별시 중구 세종대로 110",
                    "address_components": [
                        {"long_name": "04524", "types": ["postal_code"]}
                    ]
                }]
            })
        ))

        # 3. 버튼 클릭 시뮬레이션
        await page.click('#checkLocationBtn')

        # 4. 결과 업데이트 대기 및 확인
        # "가져오는 중..."에서 실제 주소로 바뀔 때까지 대기
        await page.wait_for_function(
            "document.getElementById('addressResult').innerText.includes('서울특별시')"
        )

        address_text = await page.inner_text('#addressResult')
        zip_text = await page.inner_text('#zipResult')

        print(f"Captured Address: {address_text}")
        print(f"Captured ZipCode: {zip_text}")

        # 검증
        if "서울특별시" in address_text and "04524" in zip_text:
            print("Verification PASSED: Address and ZipCode are displayed correctly.")
        else:
            print("Verification FAILED: Result mismatch.")
            exit(1)

        # 스크린샷 저장
        await page.screenshot(path="verification/web_result.png")
        print("Screenshot saved to verification/web_result.png")

        await browser.close()

if __name__ == "__main__":
    asyncio.run(verify_web_app())
