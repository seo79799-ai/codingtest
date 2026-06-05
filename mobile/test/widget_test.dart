import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('위치 정보 확인 서비스 UI 테스트', (WidgetTester tester) async {
    // 앱 빌드
    await tester.pumpWidget(const MyApp());

    // 초기 텍스트 확인
    expect(find.text('컴퓨터 위치'), findsOneWidget);
    expect(find.text('휴대폰 위치'), findsOneWidget);
    expect(find.text('현재 위치 확인할까요?'), findsOneWidget);
    expect(find.textContaining('도로명 주소:'), findsOneWidget);
    expect(find.textContaining('우편번호:'), findsOneWidget);

    // 라디오 버튼 전환 테스트
    await tester.tap(find.text('휴대폰 위치'));
    await tester.pump();

    // 버튼 클릭 시 로직은 API 호출이 포함되므로 여기서는 UI 요소 존재 여부만 확인
  });
}
