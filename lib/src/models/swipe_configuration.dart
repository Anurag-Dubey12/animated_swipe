import 'package:flutter/animation.dart';
import '../utils/swipe_constants.dart';

/// All tunable parameters for [SwipeableListItem] behavior and animation.
///
/// Pass a custom [SwipeConfiguration] to any [SwipeableListItem] to override
/// defaults. Use [SwipeConfiguration.defaults()] for iOS-matched behavior.
class SwipeConfiguration {
  // ── Thresholds ──────────────────────────────────────────────────────────────

  /// Fraction of action panel width the user must drag past to snap open.
  ///
  /// Range: 0.0–1.0. Default: 0.5 (halfway through the panel).
  final double actionRevealThreshold;

  /// Fraction of screen width the drag must exceed to trigger a full swipe.
  ///
  /// Range: 0.0–1.0. Default: 0.75.
  final double fullSwipeThreshold;

  /// Pixels-per-second velocity that triggers a full swipe regardless of offset.
  ///
  /// Default: 1200.0 px/s.
  final double fullSwipeVelocityThreshold;

  // ── Gesture discrimination ───────────────────────────────────────────────

  /// Ratio of horizontal to vertical movement required to claim the gesture.
  ///
  /// Higher values make horizontal swipes harder to trigger during scrolling.
  /// Default: 1.5.
  final double gestureHorizontalBias;

  /// Minimum horizontal pixels of movement before gesture discrimination fires.
  ///
  /// Default: 8.0 px.
  final double gestureStartThreshold;

  // ── Elastic resistance ───────────────────────────────────────────────────

  /// Divisor applied to drag delta past the action panel boundary.
  ///
  /// Higher = more resistance. Default: 3.5 (iOS-matched).
  final double rubberBandFactor;

  // ── Animation ────────────────────────────────────────────────────────────

  /// Fallback snap animation duration when spring simulation is not used.
  final Duration snapDuration;

  /// Spring damping ratio. 0 = undamped, 1 = critically damped.
  ///
  /// Default: 0.7, matching iOS UISpringTimingParameters.
  final double springDamping;

  /// Spring response time in seconds. Lower values feel snappier.
  ///
  /// Default: 0.4 s, matching iOS UISpringTimingParameters.
  final double springResponse;

  /// Easing curve applied to snap animations.
  ///
  /// Default: [Curves.easeOutCubic], approximating iOS curve feel.
  final Curve snapCurve;

  // ── Haptics ──────────────────────────────────────────────────────────────

  /// Master switch for all haptic feedback in this item. Default: true.
  final bool enableHaptics;

  // ── Behavior ─────────────────────────────────────────────────────────────

  /// Auto-close the item when the parent [ScrollView] scrolls. Default: true.
  final bool closeOnScroll;

  /// Allow multiple items to be open simultaneously. Default: false.
  ///
  /// When false, opening one item will close all others via [SwipeController].
  final bool allowSimultaneousSwipe;

  /// Whether right-to-left swipes (revealing left-side actions) are active.
  final bool enableLeftActions;

  /// Whether left-to-right swipes (revealing right-side actions) are active.
  final bool enableRightActions;

  /// Natural width (in pixels) allocated per action at flex = 1.0.
  ///
  /// Total panel width = [actionWidth] × sum of all action flex values.
  final double actionWidth;

  const SwipeConfiguration({
    this.actionRevealThreshold = SwipeConstants.defaultRevealThreshold,
    this.fullSwipeThreshold = SwipeConstants.defaultFullSwipeThreshold,
    this.fullSwipeVelocityThreshold =
        SwipeConstants.defaultFullSwipeVelocityThreshold,
    this.gestureHorizontalBias = SwipeConstants.defaultHorizontalBias,
    this.gestureStartThreshold = SwipeConstants.defaultGestureStartThreshold,
    this.rubberBandFactor = SwipeConstants.defaultRubberBandFactor,
    this.snapDuration = SwipeConstants.snapAnimationDuration,
    this.springDamping = SwipeConstants.defaultSpringDamping,
    this.springResponse = SwipeConstants.defaultSpringResponse,
    this.snapCurve = Curves.easeOutCubic,
    this.enableHaptics = true,
    this.closeOnScroll = true,
    this.allowSimultaneousSwipe = false,
    this.enableLeftActions = true,
    this.enableRightActions = true,
    this.actionWidth = SwipeConstants.defaultActionButtonMaxWidth,
  });

  /// Constructs a [SwipeConfiguration] with all iOS-matched defaults.
  const SwipeConfiguration.defaults() : this();
}
