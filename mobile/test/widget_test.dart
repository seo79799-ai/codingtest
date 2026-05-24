import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('Location check button test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the button is present.
    expect(find.text('현재 위치 확인할까요?'), findsOneWidget);

    // Verify that the initial result text is present.
    expect(find.text('도로명 주소: [결과 기다리는 중...]'), findsOneWidget);
  });
}
