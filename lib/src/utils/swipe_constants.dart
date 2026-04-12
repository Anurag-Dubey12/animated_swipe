/// Compile-time constants used throughout the animated_swipe package.
///
/// All values are tuned to match iOS UIKit swipe interaction defaults.
abstract final class SwipeConstants {
  /// Minimum width for an action button.
  static const double defaultActionButtonMinWidth = 64.0;

  /// Maximum natural width for an action button.
  static const double defaultActionButtonMaxWidth = 120.0;

  /// Default list item height when none is specified.
  static const double defaultItemHeight = 56.0;

  /// Duration for snap-to-open / snap-to-closed spring animations.
  static const Duration snapAnimationDuration = Duration(milliseconds: 300);

  /// Duration for full-swipe exit animation.
  static const Duration fullSwipeAnimationDuration = Duration(milliseconds: 250);

  /// Duration for auto-close animations triggered by the controller.
  static const Duration closeAnimationDuration = Duration(milliseconds: 220);

  /// Spring damping ratio (0 = no damping, 1 = critically damped).
  /// 0.7 matches iOS UISpringTimingParameters default feel.
  static const double defaultSpringDamping = 0.7;

  /// Spring response time in seconds. Lower = snappier.
  static const double defaultSpringResponse = 0.4;

  /// Divisor applied to drag delta past the action reveal threshold.
  /// Higher = more resistance.
  static const double defaultRubberBandFactor = 3.5;

  /// Pixel-per-second velocity threshold that triggers a full swipe.
  static const double defaultFullSwipeVelocityThreshold = 1200.0;

  /// Fraction of action panel width the user must drag past to lock open.
  static const double defaultRevealThreshold = 0.5;

  /// Fraction of screen width drag needed to trigger full swipe.
  static const double defaultFullSwipeThreshold = 0.75;

  /// Ratio of horizontal/vertical movement required to claim the gesture.
  static const double defaultHorizontalBias = 1.5;

  /// Minimum horizontal pixels before gesture discrimination fires.
  static const double defaultGestureStartThreshold = 8.0;
}
