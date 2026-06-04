import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('위치 정보 확인 서비스 UI 테스트', (WidgetTester tester) async {
    // 앱 빌드
    await tester.pumpWidget(const MyApp());

    // 타이틀 확인
    expect(find.text('위치 정보 확인 서비스'), findsOneWidget);

    // 라디오 버튼 및 텍스트 확인
    expect(find.text('컴퓨터 위치'), findsOneWidget);
    expect(find.text('휴대폰 위치'), findsOneWidget);

    // 메인 버튼 확인
    expect(find.text('현재 위치 확인할까요?'), findsOneWidget);

    // 초기 결과 텍스트 확인
    expect(find.text('도로명 주소: -'), findsOneWidget);
    expect(find.text('우편번호: -'), findsOneWidget);
  });
}
