import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('UI 요소 존재 여부 확인 테스트', (WidgetTester tester) async {
    // 앱 빌드
    await tester.pumpWidget(const MyApp());

    // 1. 앱바 타이틀 확인
    expect(find.text('단순 위치 확인'), findsOneWidget);

    // 2. 기기 선택 라디오 버튼 및 텍스트 확인
    expect(find.text('컴퓨터 위치'), findsOneWidget);
    expect(find.text('휴대폰 위치'), findsOneWidget);
    expect(find.byType(Radio<String>), findsNWidgets(2));

    // 3. 메인 확인 버튼 확인
    expect(find.text('현재 위치 확인할까요?'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);

    // 4. 결과 표시 영역 초기 텍스트 확인
    expect(find.textContaining('도로명 주소: [결과 대기 중]'), findsOneWidget);
    expect(find.textContaining('우편번호: [결과 대기 중]'), findsOneWidget);
  });
}
