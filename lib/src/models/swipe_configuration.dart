import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../utils/swipe_constants.dart';

/// All tunable parameters for [SwipeableListItem] behavior and animation.
///
/// Pass a custom [SwipeConfiguration] to any [SwipeableListItem] to override
/// defaults. Use [SwipeConfiguration.defaults()] for iOS-matched behavior.
class SwipeConfiguration {
  /// Fraction of action panel width the user must drag past to snap open.
  ///
  /// Range: 0.0–1.0. Default: 0.15 of the panel width.
  final double actionRevealThreshold;

  /// Fraction of the row width the drag must reach to trigger a full swipe.
  ///
  /// Range: 0.0–1.0. Default: 0.70. The trigger stays past the open panel.
  final double fullSwipeThreshold;

  /// Opening velocity in pixels per second that can trigger a full swipe.
  ///
  /// Default: 1200.0 px/s.
  final double fullSwipeVelocityThreshold;

  /// Ratio of horizontal to vertical movement required to claim the gesture.
  ///
  /// Higher values make horizontal swipes harder to trigger during scrolling.
  /// Default: 1.5.
  final double gestureHorizontalBias;

  /// Minimum total movement before gesture discrimination fires.
  ///
  /// Default: 8.0 px.
  final double gestureStartThreshold;

  /// Divisor applied to drag delta past the row's edge.
  ///
  /// Higher = more resistance. Default: 3.5 (iOS-matched).
  final double rubberBandFactor;

  /// Duration of the eased open and close animations.
  final Duration snapDuration;

  /// Spring damping ratio. A value of 1 is critically damped.
  ///
  /// Defaults to 0.7. A value of 0 uses eased settling.
  final double springDamping;

  /// Spring response time in seconds. Lower values feel snappier.
  ///
  /// Also controls the maximum duration of the full-swipe exit.
  final double springResponse;

  /// Uses a spring simulation for opening and closing. Defaults to false.
  final bool useSpringPhysics;

  /// Easing curve applied to snap animations.
  ///
  /// Default: [Curves.easeOutCubic], approximating iOS curve feel.
  final Curve snapCurve;

  /// Master switch for all haptic feedback in this item. Default: true.
  final bool enableHaptics;

  /// Auto-close the item when the parent [ScrollView] scrolls. Default: true.
  final bool closeOnScroll;

  /// Allow multiple items to be open simultaneously. Default: false.
  ///
  /// When false, opening one item will close all others via [SwipeController].
  final bool allowSimultaneousSwipe;

  /// Whether right-to-left swipes, revealing actions on the right, are active.
  final bool enableLeftActions;

  /// Whether left-to-right swipes, revealing actions on the left, are active.
  final bool enableRightActions;

  /// Allows a right-to-left gesture to invoke an action on release.
  final bool enableFullSwipeLeft;

  /// Allows a left-to-right gesture to invoke an action on release.
  final bool enableFullSwipeRight;

  /// Natural width (in pixels) allocated per action at flex = 1.0.
  ///
  /// Total panel width = [actionWidth] × sum of all action flex values.
  final double actionWidth;

  /// Space between the action panel and the edges of the exposed area.
  ///
  /// Leave at zero for a full-height panel. Add horizontal and vertical
  /// padding for inset buttons that grow into view during the reveal.
  final EdgeInsets actionInsets;

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
    this.useSpringPhysics = false,
    this.snapCurve = Curves.easeOutCubic,
    this.enableHaptics = true,
    this.closeOnScroll = true,
    this.allowSimultaneousSwipe = false,
    this.enableLeftActions = true,
    this.enableRightActions = true,
    this.enableFullSwipeLeft = true,
    this.enableFullSwipeRight = true,
    this.actionWidth = SwipeConstants.defaultActionButtonMaxWidth,
    this.actionInsets = EdgeInsets.zero,
  }) : assert(actionRevealThreshold >= 0 && actionRevealThreshold <= 1),
       assert(fullSwipeThreshold >= 0 && fullSwipeThreshold <= 1),
       assert(fullSwipeVelocityThreshold > 0),
       assert(gestureHorizontalBias > 0),
       assert(gestureStartThreshold >= 0),
       assert(rubberBandFactor >= 1),
       assert(springDamping >= 0 && springDamping < double.infinity),
       assert(springResponse > 0 && springResponse < double.infinity),
       assert(actionWidth > 0 && actionWidth < double.infinity);

  /// Constructs a [SwipeConfiguration] with all iOS-matched defaults.
  const SwipeConfiguration.defaults() : this();
}
