import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

import '../utils/swipe_constants.dart';

/// Pure computation utilities for swipe gesture physics.
///
/// No Flutter widgets, no state — only math. All methods are static.
abstract final class SwipePhysics {
  /// Progressively slows the drag beyond [resistanceStart] and limits the
  /// visible stretch to [maxStretch].
  static double applyRubberBand({
    required double rawOffset,
    required double resistanceStart,
    required double maxStretch,
  }) {
    final abs = rawOffset.abs();
    if (abs <= resistanceStart) return rawOffset;
    final overshoot = abs - resistanceStart;
    return rawOffset.sign *
        (resistanceStart + maxStretch * overshoot / (maxStretch + overshoot));
  }

  /// Recovers the drag position when the user grabs a moving row again.
  static double resumeRubberBand({
    required double offset,
    required double resistanceStart,
    required double maxStretch,
  }) {
    final overshoot = offset.abs() - resistanceStart;
    if (overshoot <= 0 || maxStretch <= 0) return offset;

    // A previous configuration or spring can leave the row outside its range.
    final stretch = math.min(overshoot, maxStretch * 0.99);
    return offset.sign *
        (resistanceStart + maxStretch * stretch / (maxStretch - stretch));
  }

  /// Carries velocity toward the target into a monotonic slide with a soft stop.
  static ({Duration duration, Curve curve}) releaseMotion({
    required double from,
    required double to,
    required double velocity,
    required double referenceDistance,
    required Duration maxDuration,
  }) {
    final distance = (to - from).abs();
    if (distance == 0) return (duration: Duration.zero, curve: Curves.linear);

    final fraction = (distance / referenceDistance).clamp(0.0, 1.0);
    final speed = math.max(0.0, velocity * (to - from).sign);
    final travel = 0.28 + 0.72 * math.pow(fraction, 0.7);
    final duration = Duration(
      microseconds: (maxDuration.inMicroseconds * travel / (1 + speed / 4000))
          .round(),
    );
    final initialSlope = (speed * duration.inMicroseconds / 1000000 / distance)
        .clamp(0.0, 3.0);
    return (duration: duration, curve: _ReleaseCurve(initialSlope));
  }

  /// Resolves the snap target offset after a drag gesture ends.
  ///
  /// Returns:
  /// - `double.infinity` if a full swipe should be triggered.
  /// - [openOffset] if the item should snap open.
  /// - `0.0` if the item should snap closed.
  ///
  /// Decision logic (in priority order):
  /// Positive [velocity] opens the active side and negative velocity closes it.
  /// A closing flick takes priority over the full-swipe distance.
  /// An opening flick can commit once the row is halfway open and this drag
  /// has moved it outward by at least 15% of its width.
  static double resolveSnapTarget({
    required double currentOffset,
    required double velocity,
    required double openOffset,
    required double revealThreshold,
    required double fullSwipeThreshold,
    required double screenWidth,
    required double fullSwipeVelocityThreshold,
    double dragStartOffset = 0,
    bool allowFullSwipe = true,
  }) {
    final abs = currentOffset.abs();
    if (abs == 0 || openOffset <= 0 || velocity < -200) return 0.0;

    final outwardDistance = abs - currentOffset.sign * dragStartOffset;
    if (allowFullSwipe &&
        (abs >= fullSwipeThreshold * screenWidth ||
            (abs >= screenWidth * SwipeConstants.takeoverThreshold &&
                outwardDistance >= screenWidth * 0.15 &&
                velocity >= fullSwipeVelocityThreshold))) {
      return double.infinity;
    }
    // A moderate flick in the swipe direction snaps open even with small offset.
    if (velocity > 200 && abs > 10) {
      return openOffset;
    }
    if (abs >= openOffset * revealThreshold) {
      return openOffset;
    }
    return 0.0;
  }

  /// Constructs a [SpringSimulation] that mimics iOS spring timing parameters.
  ///
  /// [dampingRatio] corresponds to UISpringTimingParameters.dampingRatio.
  /// [response] corresponds to UISpringTimingParameters.duration (in seconds).
  ///
  /// The spring stiffness and damping coefficient are derived from these:
  ///   ω₀ = 2π / response
  ///   stiffness = ω₀²
  ///   damping = 2 × dampingRatio × ω₀
  static SpringSimulation buildSpring({
    required double from,
    required double to,
    required double initialVelocity,
    required double dampingRatio,
    required double response,
  }) {
    final omega = 2 * 3.141592653589793 / response;
    final stiffness = omega * omega;
    final damping = 2 * dampingRatio * omega;

    return SpringSimulation(
      SpringDescription(mass: 1.0, stiffness: stiffness, damping: damping),
      from,
      to,
      initialVelocity,
    );
  }

  /// Returns a 0.0–1.0 progress value for a full-swipe exit animation.
  ///
  /// 0.0 = at [fullSwipeStartOffset], 1.0 = at [screenWidth].
  static double fullSwipeProgress({
    required double currentOffset,
    required double fullSwipeStartOffset,
    required double screenWidth,
  }) {
    if (screenWidth <= fullSwipeStartOffset) return 1.0;
    return ((currentOffset - fullSwipeStartOffset) /
            (screenWidth - fullSwipeStartOffset))
        .clamp(0.0, 1.0);
  }
}

class _ReleaseCurve extends Curve {
  const _ReleaseCurve(this.initialSlope);

  final double initialSlope;

  @override
  double transformInternal(double t) {
    // Cubic Hermite interpolation with the initial velocity and zero end velocity.
    final remaining = 1 - t;
    return t * t * (3 - 2 * t) + initialSlope * t * remaining * remaining;
  }
}
