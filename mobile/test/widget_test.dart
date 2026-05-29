import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('Location service UI test', (WidgetTester tester) async {
    // 앱 빌드
    await tester.pumpWidget(const MyApp());

    // UI 요소 확인
    expect(find.text('컴퓨터 위치'), findsOneWidget);
    expect(find.text('휴대폰 위치'), findsOneWidget);
    expect(find.text('현재 위치 확인할까요?'), findsOneWidget);
    expect(find.textContaining('도로명 주소:'), findsOneWidget);
    expect(find.textContaining('우편번호:'), findsOneWidget);

    // 버튼 클릭 시뮬레이션 (Geolocator 등은 모킹이 필요하지만 여기서는 UI만 확인)
    await tester.tap(find.text('현재 위치 확인할까요?'));
    await tester.pump();

    // 로딩 텍스트 확인 (Geolocator가 비동기로 동작하므로 즉시 나타남)
    expect(find.textContaining('위치 정보를 찾는 중...'), findsOneWidget);
  });
}
