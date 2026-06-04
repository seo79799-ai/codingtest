import asyncio
import os
from playwright.async_api import async_playwright

async def run_verification():
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        # Geolocation 권한을 사전에 부여한 컨텍스트 생성
        context = await browser.new_context(
            permissions=["geolocation"],
            geolocation={"latitude": 37.5665, "longitude": 126.9780} # 서울 시청 좌표
        )
        page = await context.new_page()
        page.on("console", lambda msg: print(f"PAGE LOG: {msg.text}"))

        # 로컬 서버가 실행 중이라고 가정하거나 파일 경로 직접 열기
        file_path = f"file://{os.getcwd()}/web/index.html"
        await page.goto(file_path)

        # 1. 초기 상태 확인
        print("초기 상태 확인 중...")
        await page.wait_for_selector("text=현재 위치 확인할까요?")

        # 2. Google Maps API 및 Geolocation 모킹
        await page.evaluate("""() => {
            // confirm 팝업 자동 승인
            window.confirm = () => true;

            // Google Maps Geocoder 모킹
            window.google = {
                maps: {
                    Geocoder: class {
                        geocode(request, callback) {
                            callback([
                                {
                                    formatted_address: "대한민국 서울특별시 중구 세종대로 110",
                                    address_components: [
                                        { long_name: "04524", types: ["postal_code"] }
                                    ]
                                }
                            ], "OK");
                        }
                    },
                    GeocoderStatus: { OK: "OK" }
                }
            };

            console.log("Mocking Geolocation and fetch...");
            // fetch 모킹 (Google Maps API 호출 가로채기)
            const originalFetch = window.fetch;
            window.fetch = async (...args) => {
                console.log("Fetch intercepted:", args[0]);
                if (args[0] && typeof args[0] === 'string' && args[0].includes("maps.googleapis.com")) {
                    return {
                        json: async () => ({
                            status: "OK",
                            results: [{
                                formatted_address: "대한민국 서울특별시 중구 세종대로 110",
                                address_components: [{ long_name: "04524", types: ["postal_code"] }]
                            }]
                        })
                    };
                }
                return originalFetch(...args);
            };
        }""")

        # 3. 버튼 클릭 및 결과 확인
        print("버튼 클릭 및 결과 확인 중...")
        await page.click("text=현재 위치 확인할까요?")

        # 결과가 나타날 때까지 대기
        await page.wait_for_function('document.getElementById("address").innerText.includes("서울특별시")')

        address = await page.inner_text("#address")
        zipcode = await page.inner_text("#zipcode")

        print(f"결과 도로명 주소: {address}")
        print(f"결과 우편번호: {zipcode}")

        # 4. 스크린샷 캡처
        screenshot_path = "verification/web_result.png"
        await page.screenshot(path=screenshot_path)
        print(f"스크린샷 저장됨: {screenshot_path}")

        await browser.close()
        return screenshot_path

if __name__ == "__main__":
    asyncio.run(run_verification())
