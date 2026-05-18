import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_location_service/main.dart';

void main() {
  testWidgets('UI elements check', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify UI elements exist
    expect(find.text('컴퓨터 위치'), findsOneWidget);
    expect(find.text('휴대폰 위치'), findsOneWidget);
    expect(find.text('현재 위치 확인할까요?'), findsOneWidget);

    // Check for RichText content using find.byWidgetPredicate
    expect(find.byWidgetPredicate((widget) => widget is RichText && widget.text.toPlainText().contains('도로명 주소:')), findsOneWidget);
    expect(find.byWidgetPredicate((widget) => widget is RichText && widget.text.toPlainText().contains('우편번호:')), findsOneWidget);
  });
}
