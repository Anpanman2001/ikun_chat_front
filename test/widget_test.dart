import 'package:flutter_test/flutter_test.dart';

import 'package:chatfront/main.dart';

void main() {
  testWidgets('App loads splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatApp());
    await tester.pump();

    // 启动时显示加载中
    expect(find.text('加载中...'), findsOneWidget);
  });
}
