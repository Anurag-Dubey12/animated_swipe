/// The direction the user is swiping.
enum SwipeDirection {
  /// No active swipe.
  none,

  /// Swiping from right to left (reveals left-side actions).
  left,

  /// Swiping from left to right (reveals right-side actions).
  right,
}

/// Lifecycle state of a swipeable item.
enum SwipeOpenState {
  /// Item is fully closed (no actions visible).
  closed,

  /// Item is being dragged open.
  opening,

  /// Item is snapped open (actions fully visible, finger lifted).
  open,

  /// Item is animating back to closed.
  closing,

  /// Item is performing a full-swipe exit animation.
  fullSwiping,
}

/// Immutable snapshot of a [SwipeableListItem]'s swipe state.
///
/// Every frame during a drag, a new [SwipeItemState] is emitted through the
/// item's [ValueNotifier]. Widgets use [copyWith] to produce updated values.
class SwipeItemState {
  /// Pixel offset from resting position. Positive = right swipe, negative = left.
  final double dragOffset;

  /// Current lifecycle stage of this item.
  final SwipeOpenState openState;

  /// Which direction is actively being swiped.
  final SwipeDirection activeDirection;

  /// Whether the drag has crossed the full-swipe threshold.
  final bool isFullSwiping;

  /// Guards against firing the threshold haptic more than once per gesture.
  final bool hapticFiredAtThreshold;

  /// Guards against firing the full-swipe haptic more than once per gesture.
  final bool hapticFiredAtFullSwipe;

  const SwipeItemState({
    required this.dragOffset,
    required this.openState,
    required this.activeDirection,
    this.isFullSwiping = false,
    this.hapticFiredAtThreshold = false,
    this.hapticFiredAtFullSwipe = false,
  });

  /// Fully closed resting state.
  const SwipeItemState.closed()
      : dragOffset = 0.0,
        openState = SwipeOpenState.closed,
        activeDirection = SwipeDirection.none,
        isFullSwiping = false,
        hapticFiredAtThreshold = false,
        hapticFiredAtFullSwipe = false;

  /// Absolute pixel offset regardless of swipe direction.
  double get absOffset => dragOffset.abs();

  /// Whether the item is currently at rest in the open position.
  bool get isOpen => openState == SwipeOpenState.open;

  /// Whether the item is fully closed.
  bool get isClosed => openState == SwipeOpenState.closed;

  /// Whether any swipe gesture is active.
  bool get isAnimating =>
      openState == SwipeOpenState.opening ||
      openState == SwipeOpenState.closing ||
      openState == SwipeOpenState.fullSwiping;

  /// Returns a copy with any provided fields replaced.
  SwipeItemState copyWith({
    double? dragOffset,
    SwipeOpenState? openState,
    SwipeDirection? activeDirection,
    bool? isFullSwiping,
    bool? hapticFiredAtThreshold,
    bool? hapticFiredAtFullSwipe,
  }) {
    return SwipeItemState(
      dragOffset: dragOffset ?? this.dragOffset,
      openState: openState ?? this.openState,
      activeDirection: activeDirection ?? this.activeDirection,
      isFullSwiping: isFullSwiping ?? this.isFullSwiping,
      hapticFiredAtThreshold:
          hapticFiredAtThreshold ?? this.hapticFiredAtThreshold,
      hapticFiredAtFullSwipe:
          hapticFiredAtFullSwipe ?? this.hapticFiredAtFullSwipe,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SwipeItemState &&
          dragOffset == other.dragOffset &&
          openState == other.openState &&
          activeDirection == other.activeDirection &&
          isFullSwiping == other.isFullSwiping &&
          hapticFiredAtThreshold == other.hapticFiredAtThreshold &&
          hapticFiredAtFullSwipe == other.hapticFiredAtFullSwipe;

  @override
  int get hashCode => Object.hash(
        dragOffset,
        openState,
        activeDirection,
        isFullSwiping,
        hapticFiredAtThreshold,
        hapticFiredAtFullSwipe,
      );
}
