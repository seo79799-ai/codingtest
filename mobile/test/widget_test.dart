import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('Location check button display test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the main button is displayed.
    expect(find.text('현재 위치 확인할까요?'), findsOneWidget);

    // Verify that device selection radio buttons are displayed.
    expect(find.text('컴퓨터 위치'), findsOneWidget);
    expect(find.text('휴대폰 위치'), findsOneWidget);

    // Verify that initial result text is displayed.
    expect(find.text('대기 중...'), findsAtLeast(1));
  });
}
