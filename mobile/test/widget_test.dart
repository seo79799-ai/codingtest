import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('위치 확인 서비스 UI 테스트', (WidgetTester tester) async {
    // 앱 실행
    await tester.pumpWidget(const MyApp());

    // UI 요소들이 존재하는지 확인
    expect(find.text('위치 확인 서비스'), findsOneWidget);
    expect(find.text('컴퓨터 위치'), findsOneWidget);
    expect(find.text('휴대폰 위치'), findsOneWidget);
    expect(find.text('현재 위치 확인할까요?'), findsOneWidget);
    expect(find.text('도로명 주소: [결과]'), findsOneWidget);
    expect(find.text('우편번호: [결과]'), findsOneWidget);
  });
}
