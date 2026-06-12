import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('Location app smoke test', (WidgetTester tester) async {
    // 앱 로드
    await tester.pumpWidget(const MyApp());

    // 초기 텍스트 확인
    expect(find.text('위치 정보 서비스'), findsOneWidget);
    expect(find.text('현재 위치 확인할까요?'), findsOneWidget);
    expect(find.textContaining('도로명 주소: [결과 대기 중]'), findsOneWidget);

    // 라디오 버튼 확인
    expect(find.text('컴퓨터 위치'), findsOneWidget);
    expect(find.text('휴대폰 위치'), findsOneWidget);
  });
}
