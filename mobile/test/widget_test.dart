import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('Initial UI check', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SimpleLocationApp());

    // Verify that our title exists.
    expect(find.text('내 위치 확인'), findsOneWidget);

    // Verify that the radio buttons exist.
    expect(find.text('컴퓨터 위치'), findsOneWidget);
    expect(find.text('휴대폰 위치'), findsOneWidget);

    // Verify that the main button exists.
    expect(find.text('현재 위치 확인할까요?'), findsOneWidget);

    // Verify initial result text.
    expect(find.text('현재 위치를 확인해 보세요'), findsOneWidget);
  });
}
