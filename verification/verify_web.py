import asyncio
import os
from playwright.async_api import async_playwright

async def verify_web():
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        # Geolocation 권한 및 위치 모킹
        context = await browser.new_context(
            permissions=['geolocation'],
            geolocation={'latitude': 37.5665, 'longitude': 126.9780} # 서울시청
        )
        page = await context.new_page()

        # 파일 경로 설정
        file_path = f"file://{os.getcwd()}/web/index.html"
        await page.goto(file_path)

        # 1. UI 확인
        print("UI 요소 확인 중...")
        await page.wait_for_selector("text=컴퓨터 위치")
        await page.wait_for_selector("text=현재 위치 확인할까요?")

        # 2. confirm 팝업 처리 (수락)
        page.on("dialog", lambda dialog: asyncio.create_task(dialog.accept()))

        # 3. 버튼 클릭 (Google Maps API 키가 없어서 실제 변환은 실패하겠지만 로직 흐름 확인)
        print("버튼 클릭 및 로직 확인 중...")
        await page.click("text=현재 위치 확인할까요?")

        # 4. 결과 텍스트 변화 확인 (로딩 상태)
        await page.wait_for_selector("text=도로명 주소: 위치 정보를 찾는 중...")

        # 스크린샷 저장
        await page.screenshot(path="web_verification.png")
        print("스크린샷 저장 완료: web_verification.png")

        await browser.close()

if __name__ == "__main__":
    asyncio.run(verify_web())
