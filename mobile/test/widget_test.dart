import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('Location Home Page UI Test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // 1. 초기 UI 요소 확인
    expect(find.text('컴퓨터 위치'), findsOneWidget);
    expect(find.text('휴대폰 위치'), findsOneWidget);
    expect(find.text('현재 위치 확인할까요?'), findsOneWidget);
    expect(find.text('도로명 주소: '), findsOneWidget);
    expect(find.text('우편번호: '), findsOneWidget);

    // 2. 버튼 클릭 시 로딩 텍스트 표시 확인
    // 실제 위치 수집은 모킹 없이 테스트하기 어려우므로 UI 전이만 확인
    await tester.tap(find.text('현재 위치 확인할까요?'));
    await tester.pump();

    // 로딩 중 텍스트가 나타나는지 확인 (비동기 처리가 시작됨을 의미)
    expect(find.text('확인 중...'), findsOneWidget);
  });
}
