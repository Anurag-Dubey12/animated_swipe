import 'package:flutter_test/flutter_test.dart';
import 'package:animated_swipe_example/main.dart';

void main() {
  testWidgets('MailInboxPage renders without error', (WidgetTester tester) async {
    await tester.pumpWidget(const AnimatedSwipeExampleApp());
    expect(find.text('Inbox'), findsOneWidget);
  });
}
