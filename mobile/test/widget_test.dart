import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('위치 정보 확인 서비스 UI 테스트', (WidgetTester tester) async {
    // 앱 빌드
    await tester.pumpWidget(const MyApp());

    // 1. 제목 확인
    expect(find.text('위치 정보 확인 서비스'), findsAtLeast(1));

    // 2. 기기 선택 라디오 버튼 확인
    expect(find.text('컴퓨터 위치'), findsOneWidget);
    expect(find.text('휴대폰 위치'), findsOneWidget);

    // 3. 중앙 확인 버튼 확인
    expect(find.text('현재 위치 확인할까요?'), findsOneWidget);

    // 4. 결과 표시 텍스트 초기 상태 확인
    expect(find.textContaining('도로명 주소: [결과]'), findsOneWidget);
    expect(find.textContaining('우편번호: [결과]'), findsOneWidget);
  });
}
