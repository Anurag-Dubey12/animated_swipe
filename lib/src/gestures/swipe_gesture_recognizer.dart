import 'package:flutter/gestures.dart';

/// A horizontal drag recognizer that discriminates between horizontal swipes
/// and vertical scrolls using a configurable bias ratio.
///
/// During the first few pixels of movement, this recognizer compares the
/// horizontal vs. vertical displacement components. If the horizontal component
/// dominates by at least [horizontalBias]×, the gesture is accepted and the
/// competing [ScrollView] recognizer is rejected from the arena.
///
/// This eliminates jank from simultaneous competing recognizers and replicates
/// the iOS scroll-vs-swipe discrimination behaviour.
class SwipeGestureRecognizer extends HorizontalDragGestureRecognizer {
  /// Minimum ratio of |dx|/|dy| required to accept as a horizontal swipe.
  double horizontalBias;

  /// Minimum total horizontal pixels before discrimination fires.
  double startThreshold;

  double _accumulatedDx = 0.0;
  double _accumulatedDy = 0.0;
  bool _decided = false;

  SwipeGestureRecognizer({
    required this.horizontalBias,
    required this.startThreshold,
    super.debugOwner,
  });

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _accumulatedDx = 0.0;
    _accumulatedDy = 0.0;
    _decided = false;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerCancelEvent && onCancel != null) {
      // Flutter ends an accepted drag on pointer cancellation. Give the row a
      // chance to close before that end callback can commit an action.
      invokeCallback<void>('onCancel', onCancel!);
    }
    if (!_decided && event is PointerMoveEvent) {
      _accumulatedDx += event.delta.dx.abs();
      _accumulatedDy += event.delta.dy.abs();

      final totalMoved = _accumulatedDx + _accumulatedDy;
      if (totalMoved >= startThreshold) {
        _decided = true;
        if (_accumulatedDy == 0.0 ||
            (_accumulatedDx / _accumulatedDy) >= horizontalBias) {
          // Horizontal intent — accept and let the scroll view lose.
          resolve(GestureDisposition.accepted);
        } else {
          // Vertical intent — reject so the scroll view can handle it.
          resolve(GestureDisposition.rejected);
          return;
        }
      }
    }
    super.handleEvent(event);
  }

  @override
  void rejectGesture(int pointer) {
    _decided = true;
    super.rejectGesture(pointer);
  }

  @override
  void acceptGesture(int pointer) {
    _decided = true;
    super.acceptGesture(pointer);
  }
}
