import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('Location app smoke test', (WidgetTester tester) async {
    // 앱을 빌드하고 초기 상태 확인
    await tester.pumpWidget(const MyApp());

    // '위치 정보 확인' 타이틀이 있는지 확인
    expect(find.text('위치 정보 확인'), findsOneWidget);

    // '컴퓨터 위치'와 '휴대폰 위치' 라디오 버튼이 있는지 확인
    expect(find.text('컴퓨터 위치'), findsOneWidget);
    expect(find.text('휴대폰 위치'), findsOneWidget);

    // '현재 위치 확인할까요?' 버튼이 있는지 확인
    expect(find.text('현재 위치 확인할까요?'), findsOneWidget);

    // 초기 상태에서 주소 결과가 없는지 확인
    expect(find.textContaining('도로명 주소:'), findsNothing);
  });
}
