import 'package:flutter_test/flutter_test.dart';

import 'package:chatfront/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatApp());
    await tester.pumpAndSettle();

    // 验证聊天室标题存在
    expect(find.text('聊天室'), findsOneWidget);
  });
}
