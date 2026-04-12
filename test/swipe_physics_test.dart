import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:animated_swipe/animated_swipe.dart';
import 'package:animated_swipe/src/physics/swipe_physics.dart';

void main() {
  group('SwipePhysics.applyRubberBand', () {
    test('returns offset unchanged when below resistance start', () {
      final result = SwipePhysics.applyRubberBand(
        rawOffset: 50.0,
        resistanceStart: 80.0,
        rubberBandFactor: 3.5,
      );
      expect(result, equals(50.0));
    });

    test('returns offset unchanged at exactly resistance start', () {
      final result = SwipePhysics.applyRubberBand(
        rawOffset: 80.0,
        resistanceStart: 80.0,
        rubberBandFactor: 3.5,
      );
      expect(result, equals(80.0));
    });

    test('dampens overshoot past resistance start', () {
      final result = SwipePhysics.applyRubberBand(
        rawOffset: 120.0,
        resistanceStart: 80.0,
        rubberBandFactor: 4.0,
      );
      // 80 + (40 / 4) = 90
      expect(result, closeTo(90.0, 0.001));
    });

    test('preserves negative sign for left swipe', () {
      final result = SwipePhysics.applyRubberBand(
        rawOffset: -120.0,
        resistanceStart: 80.0,
        rubberBandFactor: 4.0,
      );
      expect(result, closeTo(-90.0, 0.001));
    });
  });

  group('SwipePhysics.resolveSnapTarget', () {
    const screenWidth = 400.0;
    const panelWidth = 160.0;

    test('returns 0 when offset is below reveal threshold', () {
      final target = SwipePhysics.resolveSnapTarget(
        currentOffset: 60.0,
        velocity: 0.0,
        openOffset: panelWidth,
        revealThreshold: 0.5,
        fullSwipeThreshold: 0.75,
        screenWidth: screenWidth,
        fullSwipeVelocityThreshold: 1200.0,
      );
      expect(target, equals(0.0));
    });

    test('returns panelWidth when offset exceeds reveal threshold', () {
      final target = SwipePhysics.resolveSnapTarget(
        currentOffset: 90.0,
        velocity: 0.0,
        openOffset: panelWidth,
        revealThreshold: 0.5,
        fullSwipeThreshold: 0.75,
        screenWidth: screenWidth,
        fullSwipeVelocityThreshold: 1200.0,
      );
      expect(target, equals(panelWidth));
    });

    test('returns infinity when velocity exceeds full swipe threshold', () {
      final target = SwipePhysics.resolveSnapTarget(
        currentOffset: 50.0,
        velocity: 1500.0,
        openOffset: panelWidth,
        revealThreshold: 0.5,
        fullSwipeThreshold: 0.75,
        screenWidth: screenWidth,
        fullSwipeVelocityThreshold: 1200.0,
      );
      expect(target, equals(double.infinity));
    });

    test('returns infinity when offset exceeds full swipe threshold', () {
      final target = SwipePhysics.resolveSnapTarget(
        currentOffset: 320.0, // > 0.75 * 400
        velocity: 0.0,
        openOffset: panelWidth,
        revealThreshold: 0.5,
        fullSwipeThreshold: 0.75,
        screenWidth: screenWidth,
        fullSwipeVelocityThreshold: 1200.0,
      );
      expect(target, equals(double.infinity));
    });
  });

  group('SwipePhysics.buildSpring', () {
    test('creates a valid SpringSimulation', () {
      final sim = SwipePhysics.buildSpring(
        from: 0.0,
        to: 160.0,
        initialVelocity: 0.0,
        dampingRatio: 0.7,
        response: 0.4,
      );
      // Simulation should start near `from` and converge toward `to`.
      expect(sim.x(0.0), closeTo(0.0, 0.001));
      expect(sim.isDone(10.0), isTrue); // well past settling time
    });
  });

  group('SwipeItemState', () {
    test('closed factory initialises all fields to resting values', () {
      const state = SwipeItemState.closed();
      expect(state.dragOffset, 0.0);
      expect(state.openState, SwipeOpenState.closed);
      expect(state.activeDirection, SwipeDirection.none);
      expect(state.isClosed, isTrue);
      expect(state.isOpen, isFalse);
    });

    test('copyWith only changes specified fields', () {
      const original = SwipeItemState.closed();
      final updated = original.copyWith(
        dragOffset: 80.0,
        openState: SwipeOpenState.opening,
        activeDirection: SwipeDirection.left,
      );
      expect(updated.dragOffset, 80.0);
      expect(updated.openState, SwipeOpenState.opening);
      expect(updated.activeDirection, SwipeDirection.left);
      expect(updated.hapticFiredAtThreshold, false);
    });
  });

  group('SwipeController', () {
    test('registers and unregisters items', () {
      final controller = SwipeController();
      final notifier = ValueNotifier(const SwipeItemState.closed());

      controller.register('item_1', notifier);
      controller.unregister('item_1');
      // No error thrown means registry managed correctly.
      controller.dispose();
    });

    test('closeAll sets all items to closing state', () {
      final controller = SwipeController();
      final n1 = ValueNotifier(const SwipeItemState(
        dragOffset: 80,
        openState: SwipeOpenState.open,
        activeDirection: SwipeDirection.left,
      ));
      final n2 = ValueNotifier(const SwipeItemState.closed());

      controller.register('a', n1);
      controller.register('b', n2);

      controller.closeAll();

      expect(n1.value.openState, SwipeOpenState.closing);
      expect(n2.value.openState, SwipeOpenState.closed); // already closed, unchanged

      controller.dispose();
    });

    test('notifyOpened closes all other items', () {
      final controller = SwipeController();
      final n1 = ValueNotifier(const SwipeItemState(
        dragOffset: 80,
        openState: SwipeOpenState.open,
        activeDirection: SwipeDirection.left,
      ));
      final n2 = ValueNotifier(const SwipeItemState.closed());

      controller.register('a', n1);
      controller.register('b', n2);

      controller.notifyOpened('b');

      expect(n1.value.openState, SwipeOpenState.closing);
      expect(controller.openItemId, 'b');

      controller.dispose();
    });
  });
}

