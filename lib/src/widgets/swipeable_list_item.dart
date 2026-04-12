import 'package:flutter/material.dart';

import '../controller/swipe_controller.dart';
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
/// buttons on left and/or right swipe, with spring physics, haptic feedback,
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

    _snapController = AnimationController(vsync: this);
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
        oldWidget.configuration.actionWidth != widget.configuration.actionWidth) {
      _recomputePanelWidths();
    }

    if (oldWidget.configuration.enableHaptics != widget.configuration.enableHaptics) {
      _hapticService = HapticService(enabled: widget.configuration.enableHaptics);
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
    if (state.openState == SwipeOpenState.closing && !_snapController.isAnimating) {
      _snapClosed(initialVelocity: 0.0);
    }
  }

  // ── Gesture callbacks ──────────────────────────────────────────────────────

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
      if (dir == SwipeDirection.right) {
        _rawDragOffset = _rawDragOffset.clamp(0.0, double.infinity);
      } else {
        _rawDragOffset = _rawDragOffset.clamp(double.negativeInfinity, 0.0);
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

    final panelMaxWidth =
        dir == SwipeDirection.right ? _rightPanelMaxWidth : _leftPanelMaxWidth;

    final effectiveOffset = dir == SwipeDirection.none
        ? 0.0
        : SwipePhysics.applyRubberBand(
            rawOffset: _rawDragOffset,
            resistanceStart: panelMaxWidth,
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

    final panelMaxWidth =
        dir == SwipeDirection.right ? _rightPanelMaxWidth : _leftPanelMaxWidth;

    final itemWidth = context.size?.width ?? MediaQuery.of(context).size.width;
    final signedVelocity = dir == SwipeDirection.right ? velocity : -velocity;

    final snapTarget = SwipePhysics.resolveSnapTarget(
      currentOffset: state.absOffset,
      velocity: signedVelocity,
      openOffset: panelMaxWidth,
      revealThreshold: config.actionRevealThreshold,
      fullSwipeThreshold: config.fullSwipeThreshold,
      screenWidth: itemWidth,
      fullSwipeVelocityThreshold: config.fullSwipeVelocityThreshold,
    );

    if (snapTarget == double.infinity) {
      _runFullSwipeAnimation(direction: dir);
    } else if (snapTarget == panelMaxWidth) {
      widget.controller?.notifyOpened(widget.itemId, allowSimultaneous: false);
      _runSnapAnimation(
        fromOffset: state.dragOffset,
        toOffset: dir == SwipeDirection.right ? panelMaxWidth : -panelMaxWidth,
        velocity: velocity,
        targetOpenState: SwipeOpenState.open,
      );
    } else {
      _snapClosed(initialVelocity: velocity);
    }
  }

  // ── Haptics ────────────────────────────────────────────────────────────────

  void _checkAndFireHaptics(
    double absOffset,
    double panelMaxWidth,
    SwipeItemState prevState,
  ) {
    if (panelMaxWidth == 0) return;
    final config = widget.configuration;

    final thresholdPx = panelMaxWidth * config.actionRevealThreshold;
    if (!prevState.hapticFiredAtThreshold && absOffset >= thresholdPx) {
      _stateNotifier.value =
          _stateNotifier.value.copyWith(hapticFiredAtThreshold: true);
      _hapticService.onThresholdReached();
    }

    if (!_hapticFiredAtPanelEdge && absOffset >= panelMaxWidth) {
      _hapticFiredAtPanelEdge = true;
      _hapticService.onFullSwipeReached();
    }

    final fullSwipePx =
        config.fullSwipeThreshold * (context.size?.width ?? 400);
    if (!prevState.hapticFiredAtFullSwipe && absOffset >= fullSwipePx) {
      _stateNotifier.value =
          _stateNotifier.value.copyWith(hapticFiredAtFullSwipe: true);
      _hapticService.onFullSwipeReached();
    }
  }

  // ── Snap animations ────────────────────────────────────────────────────────

  void _runSnapAnimation({
    required double fromOffset,
    required double toOffset,
    required double velocity,
    required SwipeOpenState targetOpenState,
  }) {
    _snapController.stop();

    final config = widget.configuration;
    final spring = SwipePhysics.buildSpring(
      from: fromOffset,
      to: toOffset,
      initialVelocity: velocity,
      dampingRatio: config.springDamping,
      response: config.springResponse,
    );

    _stateNotifier.value = _stateNotifier.value.copyWith(
      openState: targetOpenState == SwipeOpenState.open
          ? SwipeOpenState.opening
          : SwipeOpenState.closing,
    );

    _snapController.animateWith(spring).then((_) {
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

  void _runFullSwipeAnimation({required SwipeDirection direction}) {
    final itemWidth = context.size?.width ?? MediaQuery.of(context).size.width;
    final targetOffset =
        direction == SwipeDirection.right ? itemWidth : -itemWidth;
    final config = widget.configuration;

    _stateNotifier.value = _stateNotifier.value.copyWith(
      isFullSwiping: true,
      openState: SwipeOpenState.fullSwiping,
    );

    _snapController.stop();
    _snapController.duration = SwipeConstants.fullSwipeAnimationDuration;
    _snapController.value = 0.0;

    final fromOffset = _stateNotifier.value.dragOffset;
    final animation = CurvedAnimation(
      parent: _snapController,
      curve: config.snapCurve,
    );

    void listener() {
      if (!mounted) return;
      final interpolated =
          fromOffset + (targetOffset - fromOffset) * animation.value;
      _stateNotifier.value =
          _stateNotifier.value.copyWith(dragOffset: interpolated);
    }

    animation.addListener(listener);
    _snapController.forward(from: 0.0).then((_) {
      animation.removeListener(listener);
      if (!mounted) return;
      _firePrimaryAction(direction);
    });
  }

  void _firePrimaryAction(SwipeDirection direction) {
    final actions =
        direction == SwipeDirection.right ? widget.rightActions : widget.leftActions;
    final overrideCallback =
        direction == SwipeDirection.right ? widget.onFullSwipeRight : widget.onFullSwipeLeft;

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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: widget.enabled ? _onDragStart : null,
      onHorizontalDragUpdate: widget.enabled ? _onDragUpdate : null,
      onHorizontalDragEnd: widget.enabled ? _onDragEnd : null,
      child: ValueListenableBuilder<SwipeItemState>(
        valueListenable: _stateNotifier,
        builder: (context, state, _) => _buildContent(state),
      ),
    );
  }

  Widget _buildContent(SwipeItemState state) {
    final offset = state.dragOffset;
    final itemH = widget.itemHeight ?? SwipeConstants.defaultItemHeight;

    return SizedBox(
      height: widget.itemHeight,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
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
          Transform.translate(
            offset: Offset(offset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
