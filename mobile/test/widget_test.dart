import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('UI elements check', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify UI components exist
    expect(find.text('컴퓨터 위치'), findsOneWidget);
    expect(find.text('휴대폰 위치'), findsOneWidget);
    expect(find.text('현재 위치 확인할까요?'), findsOneWidget);

    // Check for Radios
    expect(find.byType(Radio<String>), findsNWidgets(2));

    // Check for Button
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
