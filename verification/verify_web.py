import json
from playwright.sync_api import sync_playwright

def run_cuj(page):
    # API 호출을 모의(Mock)하기 위해 인터셉트 설정
    def handle_route(route):
        if "maps.googleapis.com" in route.request.url:
            mock_response = {
                "status": "OK",
                "results": [
                    {
                        "formatted_address": "서울특별시 강남구 테헤란로 123",
                        "address_components": [
                            {"long_name": "06123", "types": ["postal_code"]}
                        ]
                    }
                ]
            }
            route.fulfill(
                content_type="application/json",
                body=json.dumps(mock_response)
            )
        else:
            route.continue_()

    page.route("**/*", handle_route)

    # 위치 권한 모의(Mock)
    context = page.context
    context.grant_permissions(["geolocation"])
    context.set_geolocation({"latitude": 37.5, "longitude": 127.0})

    # 브라우저 confirm 창 자동 수락
    page.on("dialog", lambda dialog: dialog.accept())

    # 페이지 접속
    page.goto("http://localhost:8000/index.html")
    page.wait_for_timeout(1000)

    # 1. '휴대폰 위치' 선택
    page.get_by_label("휴대폰 위치").check()
    page.wait_for_timeout(500)

    # 2. 버튼 클릭
    page.get_by_role("button", name="현재 위치 확인할까요?").click()
    page.wait_for_timeout(2000) # API 응답 및 결과 반영 대기

    # 결과 확인 스크린샷
    page.screenshot(path="/home/jules/verification/screenshots/web_verification.png")
    page.wait_for_timeout(1000)

if __name__ == "__main__":
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            record_video_dir="/home/jules/verification/videos"
        )
        page = context.new_page()
        try:
            run_cuj(page)
        finally:
            context.close()
            browser.close()
