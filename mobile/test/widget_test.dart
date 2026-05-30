import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('Location app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the title and main button are present.
    expect(find.text('위치 정보 서비스'), findsAtLeast(1));
    expect(find.text('현재 위치 확인할까요?'), findsOneWidget);

    // Verify that device selection radios are present.
    expect(find.text('컴퓨터 위치'), findsOneWidget);
    expect(find.text('휴대폰 위치'), findsOneWidget);

    // Verify initial result text.
    expect(find.textContaining('도로명 주소:'), findsOneWidget);
    expect(find.textContaining('우편번호:'), findsOneWidget);
  });
}
