import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('Location service UI test', (WidgetTester tester) async {
    // 앱 로드
    await tester.pumpWidget(const MyApp());

    // 타이틀 확인
    expect(find.text('위치 정보 확인'), findsOneWidget);

    // 라디오 버튼 존재 확인
    expect(find.text('컴퓨터 위치'), findsOneWidget);
    expect(find.text('휴대폰 위치'), findsOneWidget);

    // 확인 버튼 존재 확인
    expect(find.text('현재 위치 확인할까요?'), findsOneWidget);

    // 결과 텍스트 초기 상태 확인
    expect(find.textContaining('도로명 주소: [결과 기다리는 중]'), findsOneWidget);
  });
}
