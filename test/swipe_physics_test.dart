import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_animated_swipe/echo_animated_swipe.dart';
import 'package:echo_animated_swipe/src/physics/swipe_physics.dart';

void main() {
  group('SwipePhysics.applyRubberBand', () {
    test('returns offset unchanged when below resistance start', () {
      final result = SwipePhysics.applyRubberBand(
        rawOffset: 50.0,
        resistanceStart: 80.0,
        maxStretch: 32,
      );
      expect(result, equals(50.0));
    });

    test('returns offset unchanged at exactly resistance start', () {
      final result = SwipePhysics.applyRubberBand(
        rawOffset: 80.0,
        resistanceStart: 80.0,
        maxStretch: 32,
      );
      expect(result, equals(80.0));
    });

    test('dampens overshoot past resistance start', () {
      final result = SwipePhysics.applyRubberBand(
        rawOffset: 120.0,
        resistanceStart: 80.0,
        maxStretch: 40,
      );
      expect(result, closeTo(100.0, 0.001));
    });

    test('preserves negative sign for left swipe', () {
      final result = SwipePhysics.applyRubberBand(
        rawOffset: -120.0,
        resistanceStart: 80.0,
        maxStretch: 40,
      );
      expect(result, closeTo(-100.0, 0.001));
    });

    test('resumes an interrupted stretch at the same visible offset', () {
      final rawOffset = SwipePhysics.resumeRubberBand(
        offset: -100,
        resistanceStart: 80,
        maxStretch: 40,
      );
      final offset = SwipePhysics.applyRubberBand(
        rawOffset: rawOffset,
        resistanceStart: 80,
        maxStretch: 40,
      );
      expect(offset, closeTo(-100, 0.001));
    });
  });

  group('SwipePhysics.releaseMotion', () {
    test('carries release speed and decelerates to rest', () {
      const maxDuration = Duration(milliseconds: 300);
      final glide = SwipePhysics.releaseMotion(
        from: 0,
        to: -100,
        velocity: -900,
        referenceDistance: 200,
        maxDuration: maxDuration,
      );
      final stationary = SwipePhysics.releaseMotion(
        from: 0,
        to: -100,
        velocity: 0,
        referenceDistance: 200,
        maxDuration: maxDuration,
      );

      const step = 0.001;
      final seconds = glide.duration.inMicroseconds / 1000000;
      final initialSpeed = glide.curve.transform(step) * 100 / (step * seconds);
      final finalSpeed =
          (1 - glide.curve.transform(1 - step)) * 100 / (step * seconds);
      expect(initialSpeed, closeTo(900, 5));
      expect(finalSpeed, closeTo(0, 5));
      expect(glide.duration, lessThan(stationary.duration));
      expect(stationary.duration, lessThan(maxDuration));
    });
  });

  group('SwipePhysics.resolveSnapTarget', () {
    const screenWidth = 400.0;
    const panelWidth = 160.0;

    test('returns 0 when offset is below reveal threshold', () {
      final target = SwipePhysics.resolveSnapTarget(
        currentOffset: 5.0,
        velocity: 0.0,
        openOffset: panelWidth,
        revealThreshold: 0.15,
        fullSwipeThreshold: 0.4,
        screenWidth: screenWidth,
        fullSwipeVelocityThreshold: 1200.0,
      );
      expect(target, equals(0.0));
    });

    test('returns panelWidth when offset exceeds reveal threshold', () {
      final target = SwipePhysics.resolveSnapTarget(
        currentOffset: 30.0,
        velocity: 0.0,
        openOffset: panelWidth,
        revealThreshold: 0.15,
        fullSwipeThreshold: 0.4,
        screenWidth: screenWidth,
        fullSwipeVelocityThreshold: 1200.0,
      );
      expect(target, equals(panelWidth));
    });

    test('returns panelWidth on moderate flick velocity', () {
      final target = SwipePhysics.resolveSnapTarget(
        currentOffset: 15.0,
        velocity: 300.0,
        openOffset: panelWidth,
        revealThreshold: 0.15,
        fullSwipeThreshold: 0.4,
        screenWidth: screenWidth,
        fullSwipeVelocityThreshold: 1200.0,
      );
      expect(target, equals(panelWidth));
    });

    test('a short fast flick only reveals the actions', () {
      final target = SwipePhysics.resolveSnapTarget(
        currentOffset: 50.0,
        velocity: 1500.0,
        openOffset: panelWidth,
        revealThreshold: 0.15,
        fullSwipeThreshold: 0.4,
        screenWidth: screenWidth,
        fullSwipeVelocityThreshold: 1200.0,
      );
      expect(target, equals(panelWidth));
    });

    test(
      'a fast flick past halfway can commit before the distance threshold',
      () {
        final target = SwipePhysics.resolveSnapTarget(
          currentOffset: -210,
          velocity: 1500,
          openOffset: panelWidth,
          revealThreshold: 0.15,
          fullSwipeThreshold: 0.70,
          screenWidth: screenWidth,
          fullSwipeVelocityThreshold: 1200,
        );
        expect(target, equals(double.infinity));
      },
    );

    test('a small additional flick on an open row cannot commit', () {
      final target = SwipePhysics.resolveSnapTarget(
        currentOffset: -220,
        dragStartOffset: -200,
        velocity: 1500,
        openOffset: 200,
        revealThreshold: 0.15,
        fullSwipeThreshold: 0.70,
        screenWidth: screenWidth,
        fullSwipeVelocityThreshold: 1200,
      );
      expect(target, equals(200));
    });

    test('returns infinity when offset exceeds full swipe threshold', () {
      final target = SwipePhysics.resolveSnapTarget(
        currentOffset: 170.0, // > 0.4 * 400
        velocity: 0.0,
        openOffset: panelWidth,
        revealThreshold: 0.15,
        fullSwipeThreshold: 0.4,
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
      final n1 = ValueNotifier(
        const SwipeItemState(
          dragOffset: 80,
          openState: SwipeOpenState.open,
          activeDirection: SwipeDirection.left,
        ),
      );
      final n2 = ValueNotifier(const SwipeItemState.closed());

      controller.register('a', n1);
      controller.register('b', n2);

      controller.closeAll();

      expect(n1.value.openState, SwipeOpenState.closing);
      expect(
        n2.value.openState,
        SwipeOpenState.closed,
      ); // already closed, unchanged

      controller.dispose();
    });

    test('notifyOpened closes all other items', () {
      final controller = SwipeController();
      final n1 = ValueNotifier(
        const SwipeItemState(
          dragOffset: 80,
          openState: SwipeOpenState.open,
          activeDirection: SwipeDirection.left,
        ),
      );
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
