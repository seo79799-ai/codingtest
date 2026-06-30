import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('UI 구성 요소 확인 테스트', (WidgetTester tester) async {
    // 앱 빌드
    await tester.pumpWidget(const MyApp());

    // 1. 타이틀 확인
    expect(find.text('위치 정보 확인'), findsOneWidget);

    // 2. 기기 선택 라디오 버튼 텍스트 확인
    expect(find.text('컴퓨터 위치'), findsOneWidget);
    expect(find.text('휴대폰 위치'), findsOneWidget);

    // 3. 메인 확인 버튼 확인
    expect(find.text('현재 위치 확인할까요?'), findsOneWidget);

    // 4. 결과 영역 초기 상태 확인
    expect(find.text('도로명 주소: -'), findsOneWidget);
    expect(find.text('우편번호: -'), findsOneWidget);
  });
}
