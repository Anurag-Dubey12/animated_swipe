import 'package:flutter/material.dart';

import '../controller/swipe_controller.dart';
import '../gestures/swipe_gesture_recognizer.dart';
import '../haptics/haptic_service.dart';
import '../models/swipe_action.dart';
import '../models/swipe_configuration.dart';
import '../models/swipe_item_state.dart';
import '../physics/swipe_physics.dart';
import '../utils/swipe_constants.dart';
import 'swipe_action_panel.dart';

/// A list item widget that supports iOS-style horizontal swipe actions.
///
/// Wrap any list tile with [SwipeableListItem] to reveal configurable action
/// buttons on left and/or right swipe, with smooth eased animations, haptic feedback,
/// and optional full-swipe auto-trigger — all matching native iOS Mail feel.
///
/// Provide a [SwipeController] to enable automatic mutual exclusion across
/// multiple items in the same list.
class SwipeableListItem extends StatefulWidget {
  /// Unique identifier for this item — used by [SwipeController] for registry.
  final String itemId;

  /// The list tile or any widget displayed in the foreground.
  final Widget child;

  /// Actions revealed by a right-to-left drag (appear on the right side).
  final List<SwipeAction> leftActions;

  /// Actions revealed by a left-to-right drag (appear on the left side).
  final List<SwipeAction> rightActions;

  /// Optional controller for coordinating multiple items in the same list.
  final SwipeController? controller;

  /// Animation, gesture, and haptic configuration.
  final SwipeConfiguration configuration;

  /// Fixed height for this item. When null, uses the child's intrinsic height.
  final double? itemHeight;

  /// Override callback for a full left-swipe (right-to-left).
  final VoidCallback? onFullSwipeLeft;

  /// Override callback for a full right-swipe (left-to-right).
  final VoidCallback? onFullSwipeRight;

  /// Whether swipe gestures are active. Defaults to true.
  final bool enabled;

  /// Corner radius applied to the outermost action button edge. Defaults to 12.
  final double cornerRadius;

  const SwipeableListItem({
    super.key,
    required this.itemId,
    required this.child,
    this.leftActions = const [],
    this.rightActions = const [],
    this.controller,
    this.configuration = const SwipeConfiguration.defaults(),
    this.itemHeight,
    this.onFullSwipeLeft,
    this.onFullSwipeRight,
    this.enabled = true,
    this.cornerRadius = 12.0,
  });

  @override
  State<SwipeableListItem> createState() => _SwipeableListItemState();
}

class _SwipeableListItemState extends State<SwipeableListItem>
    with TickerProviderStateMixin {
  late final ValueNotifier<SwipeItemState> _stateNotifier;
  late final AnimationController _snapController;
  late HapticService _hapticService;

  double _leftPanelMaxWidth = 0.0;
  double _rightPanelMaxWidth = 0.0;

  double _rawDragOffset = 0.0;
  SwipeDirection _lockedDirection = SwipeDirection.none;
  bool _hapticFiredAtPanelEdge = false;

  @override
  void initState() {
    super.initState();
    _stateNotifier = ValueNotifier(const SwipeItemState.closed());
    _hapticService = HapticService(enabled: widget.configuration.enableHaptics);

    _snapController = AnimationController.unbounded(vsync: this);
    _snapController.addListener(_onSnapTick);

    _recomputePanelWidths();
    widget.controller?.register(widget.itemId, _stateNotifier);
    _stateNotifier.addListener(_onStateChangedExternally);
  }

  @override
  void didUpdateWidget(SwipeableListItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.itemId != widget.itemId) {
      oldWidget.controller?.unregister(oldWidget.itemId);
      widget.controller?.register(widget.itemId, _stateNotifier);
    } else if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.unregister(widget.itemId);
      widget.controller?.register(widget.itemId, _stateNotifier);
    }

    if (oldWidget.leftActions != widget.leftActions ||
        oldWidget.rightActions != widget.rightActions ||
        oldWidget.configuration.actionWidth !=
            widget.configuration.actionWidth) {
      _recomputePanelWidths();
    }

    if (oldWidget.configuration.enableHaptics !=
        widget.configuration.enableHaptics) {
      _hapticService = HapticService(
        enabled: widget.configuration.enableHaptics,
      );
    }
  }

  @override
  void dispose() {
    _stateNotifier.removeListener(_onStateChangedExternally);
    widget.controller?.unregister(widget.itemId);
    _snapController
      ..removeListener(_onSnapTick)
      ..dispose();
    _stateNotifier.dispose();
    super.dispose();
  }

  void _recomputePanelWidths() {
    _leftPanelMaxWidth = _computePanelWidth(widget.leftActions);
    _rightPanelMaxWidth = _computePanelWidth(widget.rightActions);
  }

  double _computePanelWidth(List<SwipeAction> actions) {
    if (actions.isEmpty) return 0.0;
    final totalFlex = actions.fold<double>(0.0, (s, a) => s + a.flex);
    return totalFlex * widget.configuration.actionWidth;
  }

  void _onStateChangedExternally() {
    final state = _stateNotifier.value;
    if (state.openState == SwipeOpenState.closing &&
        !_snapController.isAnimating) {
      _snapClosed(initialVelocity: 0.0);
    }
  }

  // ---------------------------------------------------------------------------
  // Drag handlers
  // ---------------------------------------------------------------------------

  void _onDragStart(DragStartDetails details) {
    if (!widget.enabled) return;
    _snapController.stop();

    final currentState = _stateNotifier.value;
    _rawDragOffset = currentState.dragOffset;
    _lockedDirection = currentState.activeDirection;
    _hapticFiredAtPanelEdge = false;

    _stateNotifier.value = currentState.copyWith(
      openState: SwipeOpenState.opening,
      hapticFiredAtThreshold: false,
      hapticFiredAtFullSwipe: false,
    );
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;

    final config = widget.configuration;
    _rawDragOffset += details.delta.dx;

    SwipeDirection dir;
    if (_lockedDirection != SwipeDirection.none) {
      dir = _lockedDirection;
      // Clamp so the drag can't cross zero into the other direction,
      // but *can* return to zero (allowing the user to close by dragging back).
      if (dir == SwipeDirection.right) {
        _rawDragOffset = _rawDragOffset.clamp(0.0, double.infinity);
      } else {
        _rawDragOffset = _rawDragOffset.clamp(double.negativeInfinity, 0.0);
      }
      // If the user drags all the way back, unlock direction.
      if (_rawDragOffset == 0.0) {
        _lockedDirection = SwipeDirection.none;
        dir = SwipeDirection.none;
      }
    } else {
      if (_rawDragOffset > 0) {
        dir = SwipeDirection.right;
      } else if (_rawDragOffset < 0) {
        dir = SwipeDirection.left;
      } else {
        dir = SwipeDirection.none;
      }

      if (dir == SwipeDirection.right &&
          (!config.enableRightActions || widget.rightActions.isEmpty)) {
        _rawDragOffset = _rawDragOffset.clamp(double.negativeInfinity, 0.0);
        dir = _rawDragOffset < 0 ? SwipeDirection.left : SwipeDirection.none;
      }
      if (dir == SwipeDirection.left &&
          (!config.enableLeftActions || widget.leftActions.isEmpty)) {
        _rawDragOffset = _rawDragOffset.clamp(0.0, double.infinity);
        dir = _rawDragOffset > 0 ? SwipeDirection.right : SwipeDirection.none;
      }

      if (dir != SwipeDirection.none) {
        _lockedDirection = dir;
      }
    }

    final itemWidth = context.size?.width ?? MediaQuery.of(context).size.width;
    final panelMaxWidth = dir == SwipeDirection.right
        ? _rightPanelMaxWidth
        : _leftPanelMaxWidth;

    // Follow the finger 1:1 across the full horizontal space.
    // Only apply light rubber-band resistance once past the screen width.
    final effectiveOffset = dir == SwipeDirection.none
        ? 0.0
        : SwipePhysics.applyRubberBand(
            rawOffset: _rawDragOffset,
            resistanceStart: itemWidth,
            rubberBandFactor: config.rubberBandFactor,
          );

    final prevState = _stateNotifier.value;
    _stateNotifier.value = prevState.copyWith(
      dragOffset: effectiveOffset,
      activeDirection: dir,
      openState: SwipeOpenState.opening,
    );

    _checkAndFireHaptics(effectiveOffset.abs(), panelMaxWidth, prevState);
  }

  void _onDragEnd(DragEndDetails details) {
    if (!widget.enabled) return;

    final state = _stateNotifier.value;
    final config = widget.configuration;
    final velocity = details.primaryVelocity ?? 0.0;
    final dir = state.activeDirection;

    _lockedDirection = SwipeDirection.none;
    _hapticFiredAtPanelEdge = false;

    if (dir == SwipeDirection.none) {
      _snapClosed(initialVelocity: 0.0);
      return;
    }

    final itemWidth = context.size?.width ?? MediaQuery.of(context).size.width;
    final dragRatio = state.absOffset / itemWidth;
    final absVelocity = velocity.abs();

    // Full swipe: dragged >= 70% of screen width OR strong fling velocity.
    if (dragRatio >= 0.70 || absVelocity >= config.fullSwipeVelocityThreshold) {
      _runFullSwipeAnimation(direction: dir, velocity: velocity);
      return;
    }

    final panelMaxWidth = dir == SwipeDirection.right
        ? _rightPanelMaxWidth
        : _leftPanelMaxWidth;

    // Signed velocity relative to swipe direction (positive = opening).
    final signedVelocity = dir == SwipeDirection.right ? velocity : -velocity;

    // Snap closed on a reverse flick (dragging back toward closed).
    if (signedVelocity < -200) {
      _snapClosed(initialVelocity: velocity);
      return;
    }

    // Snap open on moderate fling in the swipe direction.
    if (signedVelocity > 200 && state.absOffset > 10) {
      widget.controller?.notifyOpened(widget.itemId, allowSimultaneous: false);
      _runSnapAnimation(
        fromOffset: state.dragOffset,
        toOffset: dir == SwipeDirection.right ? panelMaxWidth : -panelMaxWidth,
        velocity: velocity,
        targetOpenState: SwipeOpenState.open,
      );
      return;
    }

    // Snap open if offset exceeds reveal threshold.
    if (state.absOffset >= panelMaxWidth * config.actionRevealThreshold) {
      widget.controller?.notifyOpened(widget.itemId, allowSimultaneous: false);
      _runSnapAnimation(
        fromOffset: state.dragOffset,
        toOffset: dir == SwipeDirection.right ? panelMaxWidth : -panelMaxWidth,
        velocity: velocity,
        targetOpenState: SwipeOpenState.open,
      );
      return;
    }

    // Otherwise snap closed.
    _snapClosed(initialVelocity: velocity);
  }

  // ---------------------------------------------------------------------------
  // Haptics
  // ---------------------------------------------------------------------------

  void _checkAndFireHaptics(
    double absOffset,
    double panelMaxWidth,
    SwipeItemState prevState,
  ) {
    if (panelMaxWidth == 0) return;
    final config = widget.configuration;

    final thresholdPx = panelMaxWidth * config.actionRevealThreshold;
    if (!prevState.hapticFiredAtThreshold && absOffset >= thresholdPx) {
      _stateNotifier.value = _stateNotifier.value.copyWith(
        hapticFiredAtThreshold: true,
      );
      _hapticService.onThresholdReached();
    }

    if (!_hapticFiredAtPanelEdge && absOffset >= panelMaxWidth) {
      _hapticFiredAtPanelEdge = true;
      _hapticService.onFullSwipeReached();
    }

    final fullSwipePx =
        config.fullSwipeThreshold * (context.size?.width ?? 400);
    if (!prevState.hapticFiredAtFullSwipe && absOffset >= fullSwipePx) {
      _stateNotifier.value = _stateNotifier.value.copyWith(
        hapticFiredAtFullSwipe: true,
      );
      _hapticService.onFullSwipeReached();
    }
  }

  // ---------------------------------------------------------------------------
  // Animations
  // ---------------------------------------------------------------------------

  void _runSnapAnimation({
    required double fromOffset,
    required double toOffset,
    required double velocity,
    required SwipeOpenState targetOpenState,
  }) {
    _snapController.stop();

    final config = widget.configuration;
    final duration = Duration(
      milliseconds: (config.springResponse * 1000).round(),
    );

    _snapController.value = fromOffset;
    final future = _snapController.animateTo(
      toOffset,
      duration: duration,
      curve: Curves.easeOut,
    );

    _stateNotifier.value = _stateNotifier.value.copyWith(
      openState: targetOpenState == SwipeOpenState.open
          ? SwipeOpenState.opening
          : SwipeOpenState.closing,
    );

    future.then((_) {
      if (!mounted) return;
      _stateNotifier.value = _stateNotifier.value.copyWith(
        dragOffset: toOffset,
        openState: targetOpenState,
        activeDirection: toOffset == 0.0
            ? SwipeDirection.none
            : _stateNotifier.value.activeDirection,
        hapticFiredAtThreshold: false,
        hapticFiredAtFullSwipe: false,
      );
      if (targetOpenState == SwipeOpenState.closed) {
        _hapticService.onSnapClose();
        widget.controller?.notifyClosedSelf(widget.itemId);
      }
    });
  }

  void _snapClosed({required double initialVelocity}) {
    _runSnapAnimation(
      fromOffset: _stateNotifier.value.dragOffset,
      toOffset: 0.0,
      velocity: initialVelocity,
      targetOpenState: SwipeOpenState.closed,
    );
  }

  void _runFullSwipeAnimation({
    required SwipeDirection direction,
    double velocity = 0.0,
  }) {
    final itemWidth = context.size?.width ?? MediaQuery.of(context).size.width;
    final targetOffset = direction == SwipeDirection.right
        ? itemWidth
        : -itemWidth;
    final config = widget.configuration;
    final fromOffset = _stateNotifier.value.dragOffset;

    _snapController.stop();

    final duration = Duration(
      milliseconds: (config.springResponse * 800).round(),
    );

    _snapController.value = fromOffset;
    final future = _snapController.animateTo(
      targetOffset,
      duration: duration,
      curve: Curves.easeIn,
    );

    _stateNotifier.value = _stateNotifier.value.copyWith(
      isFullSwiping: true,
      openState: SwipeOpenState.fullSwiping,
    );

    future.then((_) {
      if (!mounted) return;
      _firePrimaryAction(direction);
    });
  }

  void _firePrimaryAction(SwipeDirection direction) {
    final actions = direction == SwipeDirection.right
        ? widget.rightActions
        : widget.leftActions;
    final overrideCallback = direction == SwipeDirection.right
        ? widget.onFullSwipeRight
        : widget.onFullSwipeLeft;

    if (overrideCallback != null) {
      overrideCallback();
    } else {
      final primary = actions.cast<SwipeAction?>().firstWhere(
        (a) => a!.isPrimary,
        orElse: () => actions.isNotEmpty ? actions.first : null,
      );
      primary?.onTap();
    }

    _stateNotifier.value = _stateNotifier.value.copyWith(
      isFullSwiping: false,
      hapticFiredAtThreshold: false,
      hapticFiredAtFullSwipe: false,
    );
    _rawDragOffset = _stateNotifier.value.dragOffset;
    _snapClosed(initialVelocity: 0.0);
    widget.controller?.notifyClosedSelf(widget.itemId);
  }

  void _onSnapTick() {
    if (_snapController.isAnimating) {
      _stateNotifier.value = _stateNotifier.value.copyWith(
        dragOffset: _snapController.value,
      );
    }
  }

  void _onActionTap(SwipeAction action) {
    _hapticService.onActionTap();
    action.onTap();
    if (action.closeOnTap) {
      _snapClosed(initialVelocity: 0.0);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: widget.enabled
          ? <Type, GestureRecognizerFactory>{
              SwipeGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<SwipeGestureRecognizer>(
                    () => SwipeGestureRecognizer(
                      horizontalBias:
                          widget.configuration.gestureHorizontalBias,
                      startThreshold:
                          widget.configuration.gestureStartThreshold,
                    ),
                    (SwipeGestureRecognizer instance) {
                      instance
                        ..onStart = _onDragStart
                        ..onUpdate = _onDragUpdate
                        ..onEnd = _onDragEnd;
                    },
                  ),
            }
          : const {},
      behavior: HitTestBehavior.opaque,
      child: ValueListenableBuilder<SwipeItemState>(
        valueListenable: _stateNotifier,
        builder: (context, state, _) => _buildContent(state),
      ),
    );
  }

  Widget _buildContent(SwipeItemState state) {
    final offset = state.dragOffset;

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemH =
            widget.itemHeight ??
            (constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : SwipeConstants.defaultItemHeight);

        return ClipRect(
          child: Stack(
            children: [
              // Invisible copy to provide intrinsic sizing for the Stack.
              Opacity(opacity: 0, child: widget.child),

              if (offset < 0 && widget.leftActions.isNotEmpty)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: SwipeActionPanel(
                    actions: widget.leftActions,
                    totalWidth: offset.abs(),
                    maxWidth: _leftPanelMaxWidth,
                    itemHeight: widget.itemHeight ?? itemH,
                    direction: SwipeDirection.left,
                    cornerRadius: widget.cornerRadius,
                    onActionTap: _onActionTap,
                  ),
                ),

              if (offset > 0 && widget.rightActions.isNotEmpty)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: SwipeActionPanel(
                    actions: widget.rightActions,
                    totalWidth: offset,
                    maxWidth: _rightPanelMaxWidth,
                    itemHeight: widget.itemHeight ?? itemH,
                    direction: SwipeDirection.right,
                    cornerRadius: widget.cornerRadius,
                    onActionTap: _onActionTap,
                  ),
                ),

              // Foreground on top so it covers action edges cleanly.
              Transform.translate(
                offset: Offset(offset, 0),
                child: widget.child,
              ),
            ],
          ),
        );
      },
    );
  }
}
