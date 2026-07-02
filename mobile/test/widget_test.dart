import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('단순 위치 확인 서비스 UI 테스트', (WidgetTester tester) async {
    // 앱 빌드
    await tester.pumpWidget(const MyApp());

    // 초기 텍스트 확인
    expect(find.text('단순 위치 확인'), findsOneWidget);
    expect(find.text('컴퓨터 위치'), findsOneWidget);
    expect(find.text('휴대폰 위치'), findsOneWidget);
    expect(find.text('현재 위치 확인할까요?'), findsOneWidget);

    // 초기 결과 값 확인
    expect(find.textContaining('도로명 주소: 확인 전'), findsOneWidget);
    expect(find.textContaining('우편번호: 확인 전'), findsOneWidget);
  });
}
