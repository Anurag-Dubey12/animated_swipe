import 'package:echo_animated_swipe/echo_animated_swipe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:animated_swipe_example/main.dart';

void main() {
  testWidgets('MailInboxPage renders without error', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AnimatedSwipeExampleApp());
    expect(find.text('Inbox'), findsOneWidget);
  });

  testWidgets('demo controls change both sides and toggle haptics', (
    tester,
  ) async {
    await tester.pumpWidget(const AnimatedSwipeExampleApp());
    SwipeableListItem firstRow() =>
        tester.widget(find.byType(SwipeableListItem).first);

    for (final title in [
      'Text only',
      'Icon only',
      'Icon and text',
      'Custom widget',
    ]) {
      await tester.tap(find.byTooltip('Action content'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.ancestor(
          of: find.text(title),
          matching: find.byWidgetPredicate(
            (widget) => widget is CheckedPopupMenuItem,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final row = firstRow();
      for (final action in [row.leftActions.first, row.rightActions.first]) {
        expect(
          action.label != null,
          title == 'Text only' || title == 'Icon and text',
        );
        expect(
          action.icon != null,
          title == 'Icon only' || title == 'Icon and text',
        );
        expect(action.customWidget != null, title == 'Custom widget');
      }
    }

    await tester.tap(find.byTooltip('Turn haptics off'));
    await tester.pump();
    expect(firstRow().configuration.enableHaptics, isFalse);
  });
}
