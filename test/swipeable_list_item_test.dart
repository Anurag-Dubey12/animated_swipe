import 'package:echo_animated_swipe/echo_animated_swipe.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'a screen reader can invoke an icon-only action on a closed row',
    (tester) async {
      var calls = 0;
      await _mount(
        tester,
        _row(
          'a',
          leftActions: [
            SwipeAction(
              id: 'delete',
              icon: const Icon(Icons.delete),
              semanticLabel: 'Delete message',
              backgroundColor: Colors.red,
              onTap: () => calls++,
            ),
          ],
          rightActions: [],
        ),
      );

      final node = tester.getSemantics(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              (widget.properties.customSemanticsActions?.isNotEmpty ?? false),
        ),
      );
      final actionIds = node.getSemanticsData().customSemanticsActionIds!;
      expect(
        actionIds.map((id) => CustomSemanticsAction.getAction(id)?.label),
        ['Delete message'],
      );
      node.owner!.performAction(
        node.id,
        SemanticsAction.customAction,
        actionIds.single,
      );
      expect(calls, 1);
      expect(find.byKey(const ValueKey('delete')), findsNothing);
    },
  );

  testWidgets('keyboard users can select an action without opening the panel', (
    tester,
  ) async {
    var calls = 0;
    await _mount(
      tester,
      _row(
        'a',
        leftActions: [_action('Archive', onTap: () => calls++)],
        rightActions: [],
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(find.text('Archive'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Archive'), findsNothing);
  });

  testWidgets('only the foreground can start another swipe', (tester) async {
    var taps = 0;
    await _mount(tester, _row('a', onLeft: () => taps++));
    final action = find.byKey(const ValueKey('a-primary'));
    final foreground = find.byKey(const ValueKey('a-content'));
    await _reveal(tester, 'a', -100);
    final openPosition = tester.getTopLeft(foreground);

    await tester.drag(action, const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(foreground), openPosition);
    expect(taps, 0);

    await tester.drag(action, const Offset(-12, 0), touchSlopX: 0);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(foreground), openPosition);
    expect(taps, 0);

    await tester.drag(foreground, const Offset(176, 0));
    await tester.pumpAndSettle();
    expect(action, findsNothing);

    await _reveal(tester, 'a', -100);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('a scroll starting over an action leaves its panel open', (
    tester,
  ) async {
    final controller = SwipeController();
    addTearDown(controller.dispose);
    await _mount(
      tester,
      SizedBox(
        width: 400,
        height: 280,
        child: ListView(
          children: [
            const SizedBox(height: 100),
            _row('a', controller: controller),
            const SizedBox(height: 500),
          ],
        ),
      ),
    );
    await _reveal(tester, 'a', -100);
    final action = find.byKey(const ValueKey('a-primary'));
    final start = tester.getCenter(action);
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(-10, -40));
    await gesture.moveBy(const Offset(0, -15));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.openItemId, 'a');
    expect(tester.getCenter(action).dy, lessThan(start.dy));
  });

  for (final direction in [-1, 1]) {
    testWidgets('four actions can be provided on only swipe side $direction', (
      tester,
    ) async {
      final actions = List.generate(4, (index) => _action('option-$index'));
      await _mount(
        tester,
        _row(
          'a',
          leftActions: direction < 0 ? actions : [],
          rightActions: direction > 0 ? actions : [],
        ),
      );
      await _reveal(tester, 'a', -110.0 * direction);
      expect(find.byKey(const ValueKey('option-0')), findsNothing);

      await _reveal(tester, 'a', 110.0 * direction);
      for (final action in actions) {
        expect(tester.getSize(find.byKey(ValueKey(action.id))).width, 50);
      }
    });
  }

  for (final direction in [-1, 1]) {
    testWidgets('halfway takeover is mirrored for drag direction $direction', (
      tester,
    ) async {
      await _mount(tester, _row('a'));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('a-content'))),
      );
      final second = find.byKey(
        ValueKey(direction < 0 ? 'a-secondary' : 'a-right-secondary'),
      );

      await gesture.moveBy(Offset(200.0 * direction, 0));
      await tester.pump();
      expect(tester.getSize(second).width, closeTo(100, 0.01));

      await gesture.moveBy(Offset(40.0 * direction, 0));
      await tester.pump();
      expect(tester.getSize(second).width, inExclusiveRange(0, 100));

      await gesture.moveBy(Offset(20.0 * direction, 0));
      await tester.pump();
      expect(tester.getSize(second).width, 0);
      await gesture.cancel();
      await tester.pumpAndSettle();
    });
  }

  testWidgets('a short reveal shows one action then settles with both', (
    tester,
  ) async {
    await _mount(tester, _row('a'));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('a-content'))),
    );
    final first = find.byKey(const ValueKey('a-primary'));
    final second = find.byKey(const ValueKey('a-secondary'));

    await gesture.moveBy(const Offset(-32, 0));
    await tester.pump();
    expect(tester.getSize(first).width, 32);
    expect(tester.getSize(second).width, 0);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getSize(first).width, 88);
    expect(tester.getSize(second).width, 88);
  });

  testWidgets(
    'takeover compresses and restores secondary actions as you drag',
    (tester) async {
      var commits = 0;
      await _mount(tester, _row('a', onLeft: () => commits++));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('a-content'))),
      );
      await gesture.moveBy(const Offset(-152, 0));
      await tester.pump();

      final secondary = find.byKey(const ValueKey('a-secondary'));
      final primary = find.byKey(const ValueKey('a-primary'));
      final secondaryElement = tester.element(secondary);
      final revealSize = tester.getSize(secondary);
      expect(revealSize.height, 64);
      expect(revealSize.width, greaterThan(60));

      await gesture.moveBy(const Offset(-136, 0));
      await tester.pump();
      expect(tester.getSize(secondary).width, lessThan(revealSize.width));
      expect(tester.getSize(primary).width, greaterThan(200));
      expect(commits, 0);

      await gesture.moveBy(const Offset(-112, 0));
      await tester.pump();
      expect(tester.getSize(secondary).width, 0);
      final label = find.text('a-primary');
      expect(
        tester.getCenter(label).dx - tester.getTopLeft(primary).dx,
        closeTo(36, 1),
      );

      await gesture.moveBy(const Offset(248, 0));
      await tester.pump();
      expect(tester.element(secondary), same(secondaryElement));
      expect(tester.getSize(secondary).width, closeTo(revealSize.width, 0.1));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(commits, 0);
      expect(tester.getSize(secondary).width, 88);
    },
  );

  testWidgets(
    'reversing past the row edge brings the foreground back at once',
    (tester) async {
      await _mount(tester, _row('a'));
      final foreground = find.byKey(const ValueKey('a-content'));
      final gesture = await tester.startGesture(tester.getCenter(foreground));
      await gesture.moveBy(const Offset(-460, 0));
      await tester.pump();
      expect(tester.getTopLeft(foreground).dx, -400);

      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      expect(tester.getTopLeft(foreground).dx, -380);

      await gesture.cancel();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('inset actions expand in height with one foreground child', (
    tester,
  ) async {
    const label = ValueKey('foreground');
    var calls = 0;
    await _mount(
      tester,
      SizedBox(
        width: 400,
        child: SwipeableListItem(
          itemId: 'inset',
          configuration: const SwipeConfiguration(
            actionInsets: EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            enableHaptics: false,
          ),
          leftActions: [_action('hide', onTap: () => calls++)],
          child: const SizedBox(key: label, height: 64),
        ),
      ),
    );

    final row = find.byKey(label);
    expect(row, findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(row));
    await gesture.moveBy(const Offset(-32, 0));
    await tester.pump();

    final button = find.byKey(const ValueKey('hide'));
    final initialHeight = tester.getSize(button).height;
    expect(initialHeight, greaterThan(0));
    expect(initialHeight, lessThan(46));
    expect(tester.getTopRight(button).dx, tester.getTopRight(row).dx + 24);

    await gesture.moveBy(const Offset(-80, 0));
    await tester.pump();
    expect(tester.getSize(button).height, 46);
    expect(row, findsOneWidget);

    await gesture.moveBy(const Offset(-205, 0));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(button, findsNothing);
    expect(row, findsOneWidget);
  });

  testWidgets('short custom full-swipe exit invokes the override once', (
    tester,
  ) async {
    var leftCalls = 0;
    var overrides = 0;
    await _mount(
      tester,
      _row(
        'a',
        onLeft: () => leftCalls++,
        onFullSwipeLeft: () => overrides++,
        configuration: const SwipeConfiguration(
          actionWidth: 88,
          enableHaptics: false,
          fullSwipeThreshold: 0.55,
          springResponse: 0.12,
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('a-content'))),
    );
    await gesture.moveBy(const Offset(-245, 0));
    await tester.pump();
    expect(overrides, 0);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(overrides, 1);
    expect(leftCalls, 0);
    expect(find.byKey(const ValueKey('a-primary')), findsNothing);
  });

  testWidgets('a side can reveal buttons without committing a full swipe', (
    tester,
  ) async {
    var calls = 0;
    await _mount(
      tester,
      _row(
        'a',
        onLeft: () => calls++,
        configuration: const SwipeConfiguration(
          actionWidth: 88,
          enableHaptics: false,
          enableFullSwipeLeft: false,
        ),
      ),
    );

    await _reveal(tester, 'a', -330);
    expect(calls, 0);

    await tester.tap(find.byKey(const ValueKey('a-primary')));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byKey(const ValueKey('a-primary')), findsNothing);
  });

  testWidgets('a reverse fling closes a previously opened row', (tester) async {
    var calls = 0;
    await _mount(tester, _row('a', onLeft: () => calls++));
    await _reveal(tester, 'a', -120);

    await tester.flingFrom(
      tester.getTopLeft(find.byKey(const ValueKey('a'))) +
          const Offset(100, 32),
      const Offset(65, 0),
      2000,
    );
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.byKey(const ValueKey('a-primary')), findsNothing);
  });

  testWidgets('shared controller closes a settling row when another opens', (
    tester,
  ) async {
    final controller = SwipeController();
    addTearDown(controller.dispose);
    await _mount(
      tester,
      Column(
        children: [
          _row('a', controller: controller),
          _row('b', controller: controller),
        ],
      ),
    );

    await tester.drag(find.byKey(const ValueKey('a')), const Offset(-100, 0));
    await tester.drag(find.byKey(const ValueKey('b')), const Offset(100, 0));
    await tester.pumpAndSettle();

    expect(controller.openItemId, 'b');
    expect(find.byKey(const ValueKey('a-primary')), findsNothing);
    expect(find.byKey(const ValueKey('b-right')), findsOneWidget);
  });

  testWidgets('vertical scrolling closes an open row', (tester) async {
    final controller = SwipeController();
    addTearDown(controller.dispose);
    await _mount(
      tester,
      SizedBox(
        width: 400,
        height: 250,
        child: ListView(
          key: const ValueKey('list'),
          children: [
            _row('a', controller: controller),
            const SizedBox(height: 500),
          ],
        ),
      ),
    );

    await _reveal(tester, 'a', -100);
    expect(controller.openItemId, 'a');
    await tester.drag(
      find.byKey(const ValueKey('list')),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();
    expect(controller.hasOpenItem, isFalse);
    expect(find.byKey(const ValueKey('a-primary')), findsNothing);
  });

  testWidgets('simultaneous rows remain tracked when one row closes', (
    tester,
  ) async {
    final controller = SwipeController();
    addTearDown(controller.dispose);
    const config = SwipeConfiguration(
      actionWidth: 88,
      allowSimultaneousSwipe: true,
      enableHaptics: false,
    );
    await _mount(
      tester,
      Column(
        children: [
          _row('a', controller: controller, configuration: config),
          _row('b', controller: controller, configuration: config),
        ],
      ),
    );

    await _reveal(tester, 'a', -100);
    await _reveal(tester, 'b', 65);
    expect(controller.openItemId, 'b');

    controller.close('b');
    await tester.pumpAndSettle();
    expect(controller.openItemId, 'a');
    expect(find.byKey(const ValueKey('a-primary')), findsOneWidget);
  });
}

Future<void> _mount(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  );
}

Future<void> _reveal(WidgetTester tester, String id, double offset) async {
  await tester.drag(find.byKey(ValueKey(id)), Offset(offset, 0));
  await tester.pumpAndSettle();
}

Widget _row(
  String id, {
  SwipeController? controller,
  SwipeConfiguration configuration = const SwipeConfiguration(
    actionWidth: 88,
    enableHaptics: false,
  ),
  VoidCallback? onLeft,
  VoidCallback? onFullSwipeLeft,
  List<SwipeAction>? leftActions,
  List<SwipeAction>? rightActions,
}) {
  return SizedBox(
    width: 400,
    child: SwipeableListItem(
      key: ValueKey(id),
      itemId: id,
      itemHeight: 64,
      cornerRadius: 0,
      controller: controller,
      configuration: configuration,
      onFullSwipeLeft: onFullSwipeLeft,
      leftActions:
          leftActions ??
          [
            _action('$id-primary', primary: true, onTap: onLeft),
            _action('$id-secondary'),
          ],
      rightActions:
          rightActions ??
          [_action('$id-right'), _action('$id-right-secondary')],
      child: ColoredBox(key: ValueKey('$id-content'), color: Colors.white),
    ),
  );
}

SwipeAction _action(String id, {bool primary = false, VoidCallback? onTap}) {
  return SwipeAction(
    id: id,
    backgroundColor: primary ? Colors.red : Colors.blue,
    label: id,
    isPrimary: primary,
    onTap: onTap ?? () {},
  );
}
