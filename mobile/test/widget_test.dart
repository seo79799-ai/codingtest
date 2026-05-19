import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_service/main.dart';

void main() {
  testWidgets('Check if the main button exists', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the main button is present.
    expect(find.text('현재 위치 확인할까요?'), findsOneWidget);

    // Verify that initial address and zipcode are '-'
    expect(find.text('도로명 주소: -'), findsOneWidget);
    expect(find.text('우편번호: -'), findsOneWidget);
  });
}
