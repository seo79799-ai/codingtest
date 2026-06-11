import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('UI elements presence test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the title is present.
    expect(find.text('위치 정보 확인 서비스'), findsOneWidget);

    // Verify that radio buttons are present.
    expect(find.text('컴퓨터 위치'), findsOneWidget);
    expect(find.text('휴대폰 위치'), findsOneWidget);
    expect(find.byType(Radio<String>), findsNWidgets(2));

    // Verify that the main button is present.
    expect(find.text('현재 위치 확인할까요?'), findsOneWidget);

    // Verify that initial result texts are present.
    expect(find.text('도로명 주소: '), findsOneWidget);
    expect(find.text('우편번호: '), findsOneWidget);
  });
}
