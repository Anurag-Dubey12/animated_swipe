import 'package:flutter/physics.dart';

/// Pure computation utilities for swipe gesture physics.
///
/// No Flutter widgets, no state — only math. All methods are static.
abstract final class SwipePhysics {
  /// Applies rubber-band resistance to [rawOffset] past [resistanceStart].
  ///
  /// When the absolute drag is below [resistanceStart], returns [rawOffset]
  /// unchanged. Beyond that, additional movement is divided by [rubberBandFactor],
  /// giving the iOS "elastic pull" sensation.
  ///
  /// The result preserves the sign of [rawOffset] (direction).
  static double applyRubberBand({
    required double rawOffset,
    required double resistanceStart,
    required double rubberBandFactor,
  }) {
    final abs = rawOffset.abs();
    if (abs <= resistanceStart) return rawOffset;
    final sign = rawOffset.sign;
    final overshoot = abs - resistanceStart;
    final dampened = resistanceStart + overshoot / rubberBandFactor;
    return sign * dampened;
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
  static double resolveSnapTarget({
    required double currentOffset,
    required double velocity,
    required double openOffset,
    required double revealThreshold,
    required double fullSwipeThreshold,
    required double screenWidth,
    required double fullSwipeVelocityThreshold,
    bool allowFullSwipe = true,
  }) {
    final abs = currentOffset.abs();
    if (abs == 0 || openOffset <= 0 || velocity < -200) return 0.0;

    if (allowFullSwipe &&
        (abs >= fullSwipeThreshold * screenWidth ||
            (abs > 10 && velocity >= fullSwipeVelocityThreshold))) {
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
