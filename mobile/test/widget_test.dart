import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('UI elements smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const LocationServiceApp());

    // Verify that the title is displayed.
    expect(find.text('간편 위치 확인 서비스'), findsWidgets);

    // Verify that the check button is displayed.
    expect(find.text('현재 위치 확인할까요?'), findsOneWidget);

    // Verify that the device selection radios are displayed.
    expect(find.text('컴퓨터 위치'), findsOneWidget);
    expect(find.text('휴대폰 위치'), findsOneWidget);
  });
}
