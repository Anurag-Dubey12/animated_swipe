import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../controller/swipe_controller.dart';
import '../gestures/swipe_gesture_recognizer.dart';
import '../haptics/haptic_service.dart';
import '../models/swipe_action.dart';
import '../models/swipe_configuration.dart';
import '../models/swipe_item_state.dart';
import '../physics/swipe_physics.dart';
import '../utils/swipe_constants.dart';
import 'swipe_action_panel.dart';

/// Reveals action buttons as the foreground child is dragged horizontally.
///
/// Give items in a group the same [SwipeController] to coordinate open rows.
class SwipeableListItem extends StatefulWidget {
  /// Unique identifier for this item in its controller.
  final String itemId;

  /// The row or other widget displayed in the foreground.
  final Widget child;

  /// Actions revealed by a right-to-left drag, on the right edge.
  final List<SwipeAction> leftActions;

  /// Actions revealed by a left-to-right drag, on the left edge.
  final List<SwipeAction> rightActions;

  final SwipeController? controller;
  final SwipeConfiguration configuration;

  /// Fixed row height. When omitted, the child's layout determines the height.
  final double? itemHeight;

  /// Overrides the primary action callback for a right-to-left full swipe.
  final VoidCallback? onFullSwipeLeft;

  /// Overrides the primary action callback for a left-to-right full swipe.
  final VoidCallback? onFullSwipeRight;

  final bool enabled;

  /// Radius of the panel's outer corners. Defaults to 12 logical pixels.
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
  }) : assert(cornerRadius >= 0);

  @override
  State<SwipeableListItem> createState() => _SwipeableListItemState();
}

class _SwipeableListItemState extends State<SwipeableListItem>
    with SingleTickerProviderStateMixin {
  final _state = ValueNotifier(const SwipeItemState.closed());
  final _actionPointers = <int>{};
  late final AnimationController _animation;

  ScrollPosition? _scrollPosition;
  SwipeOpenState? _animationTarget;
  int _animationRevision = 0;
  bool _dragActive = false;
  bool _showKeyboardFocus = false;
  double _dragOffset = 0;
  double _dragStartOffset = 0;
  double _rowWidth = 0;

  SwipeConfiguration get _config => widget.configuration;
  HapticService get _haptics => HapticService(enabled: _config.enableHaptics);

  @override
  void initState() {
    super.initState();
    _animation = AnimationController.unbounded(vsync: this)
      ..addListener(_onAnimationTick);
    _state.addListener(_onCloseRequested);
    widget.controller?.register(widget.itemId, _state);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context, axis: Axis.vertical)?.position;
    if (_scrollPosition == position) return;
    _scrollPosition?.isScrollingNotifier.removeListener(_onScrollChanged);
    _scrollPosition = position;
    _scrollPosition?.isScrollingNotifier.addListener(_onScrollChanged);
  }

  @override
  void didUpdateWidget(SwipeableListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changedItem = oldWidget.itemId != widget.itemId;
    if (changedItem || oldWidget.controller != widget.controller) {
      oldWidget.controller?.unregister(oldWidget.itemId);
      widget.controller?.register(widget.itemId, _state);
    }
    if (changedItem) {
      _dragActive = false;
      _stopAnimation();
      _state.value = const SwipeItemState.closed();
    } else if (!widget.enabled ||
        (_state.value.activeDirection != SwipeDirection.none &&
            !_canDrag(_state.value.activeDirection))) {
      _requestClose();
    }
  }

  @override
  void dispose() {
    _scrollPosition?.isScrollingNotifier.removeListener(_onScrollChanged);
    _state.removeListener(_onCloseRequested);
    widget.controller?.unregister(widget.itemId);
    _animation.dispose();
    _state.dispose();
    super.dispose();
  }

  List<SwipeAction> _actionsFor(SwipeDirection direction) =>
      direction == SwipeDirection.right
      ? widget.rightActions
      : widget.leftActions;

  bool _canDrag(SwipeDirection direction) {
    return switch (direction) {
      SwipeDirection.left =>
        _config.enableLeftActions &&
            widget.leftActions.any((action) => action.flex > 0),
      SwipeDirection.right =>
        _config.enableRightActions &&
            widget.rightActions.any((action) => action.flex > 0),
      SwipeDirection.none => false,
    };
  }

  bool _canCommit(SwipeDirection direction) => direction == SwipeDirection.right
      ? _config.enableFullSwipeRight
      : _config.enableFullSwipeLeft;

  double _openWidth(SwipeDirection direction, double rowWidth) {
    final insets = _config.actionInsets.horizontal;
    if (rowWidth <= insets) return 0;
    final flex = _actionsFor(
      direction,
    ).fold<double>(0, (total, action) => total + action.flex);
    if (flex <= 0) return 0;

    // Keep the resting panel before the takeover point when full swipe is on.
    final maxWidth = _canCommit(direction)
        ? math.max(
            rowWidth * SwipeConstants.takeoverThreshold,
            insets + (rowWidth - insets) * 0.1,
          )
        : insets + (rowWidth - insets) * 0.78;
    return math.min(flex * _config.actionWidth + insets, maxWidth);
  }

  double _commitDistance(double openWidth, double rowWidth) => math.min(
    rowWidth,
    math.max(
      _config.fullSwipeThreshold * rowWidth,
      openWidth + rowWidth * 0.07,
    ),
  );

  void _onScrollChanged() {
    if (_config.closeOnScroll &&
        _scrollPosition!.isScrollingNotifier.value &&
        !_dragActive &&
        _actionPointers.isEmpty &&
        _state.value.openState != SwipeOpenState.fullSwiping) {
      _requestClose();
    }
  }

  void _requestClose() {
    if (_state.value.isClosed) return;
    _dragActive = false;
    _settle(0);
  }

  void _onCloseRequested() {
    if (_state.value.openState == SwipeOpenState.closing &&
        _animationTarget != SwipeOpenState.closing) {
      _requestClose();
    }
  }

  void _onDragStart(DragStartDetails details) {
    if (!widget.enabled || _state.value.isFullSwiping) return;
    _rowWidth = context.size?.width ?? 0;
    if (_rowWidth <= 0) return;

    _stopAnimation();
    _dragActive = true;
    final state = _state.value;
    _dragOffset = state.dragOffset;
    _dragStartOffset = state.dragOffset;
    final direction = state.activeDirection;
    if (direction != SwipeDirection.none && !_canCommit(direction)) {
      final openWidth = _openWidth(direction, _rowWidth);
      _dragOffset = SwipePhysics.resumeRubberBand(
        offset: state.dragOffset,
        resistanceStart: openWidth,
        maxStretch: _maxStretch(openWidth),
      );
    }
    _state.value = state.copyWith(
      openState: SwipeOpenState.opening,
      hapticFiredAtThreshold: false,
      hapticFiredAtFullSwipe: false,
    );
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_dragActive) return;
    _dragOffset += details.delta.dx;
    final direction = _directionOf(_dragOffset);
    final openWidth = _openWidth(direction, _rowWidth);
    if (!_canDrag(direction) || openWidth <= 0) {
      _dragOffset = 0;
      _state.value = _state.value.copyWith(
        dragOffset: 0,
        activeDirection: SwipeDirection.none,
      );
      return;
    }

    final previous = _state.value;
    final other = widget.controller?.openItemId;
    if (previous.activeDirection == SwipeDirection.none &&
        !_config.allowSimultaneousSwipe &&
        other != null &&
        other != widget.itemId) {
      widget.controller?.close(other);
    }

    final canCommit = _canCommit(direction);
    if (canCommit) {
      // Once the row clears the edge, the next reverse movement can bring it
      // back immediately, even if the pointer continued past it.
      _dragOffset = _dragOffset.clamp(-_rowWidth, _rowWidth);
    }
    final offset = canCommit
        ? _dragOffset
        : SwipePhysics.applyRubberBand(
            rawOffset: _dragOffset,
            resistanceStart: openWidth,
            maxStretch: _maxStretch(openWidth),
          );
    final hasRevealed =
        offset.abs() >= openWidth * _config.actionRevealThreshold;
    final isCommitReady =
        canCommit && offset.abs() >= _commitDistance(openWidth, _rowWidth);
    final crossedReveal = hasRevealed && !previous.hapticFiredAtThreshold;
    final crossedCommit = isCommitReady && !previous.hapticFiredAtFullSwipe;
    _state.value = previous.copyWith(
      dragOffset: offset,
      activeDirection: direction,
      hapticFiredAtThreshold: previous.hapticFiredAtThreshold || hasRevealed,
      hapticFiredAtFullSwipe: previous.hapticFiredAtFullSwipe || isCommitReady,
    );
    if (crossedCommit) {
      _haptics.onFullSwipeReached();
    } else if (crossedReveal) {
      _haptics.onThresholdReached();
    }
  }

  double _maxStretch(double openWidth) =>
      math.min(openWidth, _rowWidth - openWidth) / _config.rubberBandFactor;

  void _onDragEnd(DragEndDetails details) {
    if (!_dragActive) return;
    _dragActive = false;
    final state = _state.value;
    final direction = state.activeDirection;
    if (direction == SwipeDirection.none) {
      _settle(0);
      return;
    }

    final openWidth = _openWidth(direction, _rowWidth);
    final velocity = details.primaryVelocity ?? 0;
    final target = SwipePhysics.resolveSnapTarget(
      currentOffset: state.dragOffset,
      dragStartOffset: _dragStartOffset,
      velocity: direction == SwipeDirection.right ? velocity : -velocity,
      openOffset: openWidth,
      revealThreshold: _config.actionRevealThreshold,
      fullSwipeThreshold: _commitDistance(openWidth, _rowWidth) / _rowWidth,
      screenWidth: _rowWidth,
      fullSwipeVelocityThreshold: _config.fullSwipeVelocityThreshold,
      allowFullSwipe: _canCommit(direction),
    );

    if (target.isInfinite) {
      _commit(direction, velocity);
      return;
    }

    if (target > 0) {
      widget.controller?.notifyOpened(
        widget.itemId,
        allowSimultaneous: _config.allowSimultaneousSwipe,
      );
    }
    _settle(state.dragOffset.sign * target, velocity: velocity);
  }

  void _onDragCancel() {
    if (_dragActive) _requestClose();
  }

  void _settle(double offset, {double velocity = 0}) {
    final closing = offset == 0;
    if (_animationTarget == SwipeOpenState.closing && closing) return;
    final from = _state.value.dragOffset;
    final revision = _beginAnimation(
      closing ? SwipeOpenState.closing : SwipeOpenState.opening,
    );
    if (offset == from || _reduceMotion) {
      _finishSettle(offset, from);
      return;
    }

    _animation.value = from;
    final animation = _config.useSpringPhysics && _config.springDamping > 0
        ? _animation.animateWith(
            SwipePhysics.buildSpring(
              from: from,
              to: offset,
              initialVelocity: velocity,
              dampingRatio: _config.springDamping,
              response: _config.springResponse,
            ),
          )
        : _slideTo(from: from, to: offset, velocity: velocity);
    animation.then((_) {
      if (mounted && revision == _animationRevision) {
        _finishSettle(offset, from);
      }
    });
  }

  void _finishSettle(double offset, double from) {
    _animationTarget = null;
    if (offset == 0) {
      _state.value = const SwipeItemState.closed();
      if (from != 0) _haptics.onSnapClose();
      widget.controller?.notifyClosedSelf(widget.itemId);
    } else {
      _state.value = SwipeItemState(
        dragOffset: offset,
        openState: SwipeOpenState.open,
        activeDirection: _directionOf(offset),
      );
    }
  }

  TickerFuture _slideTo({
    required double from,
    required double to,
    required double velocity,
  }) {
    if (_config.snapCurve != Curves.easeOutCubic) {
      return _animation.animateTo(
        to,
        duration: _config.snapDuration,
        curve: _config.snapCurve,
      );
    }
    final motion = SwipePhysics.releaseMotion(
      from: from,
      to: to,
      velocity: velocity,
      referenceDistance: _openWidth(_state.value.activeDirection, _rowWidth),
      maxDuration: _config.snapDuration,
    );
    return _animation.animateTo(
      to,
      duration: motion.duration,
      curve: motion.curve,
    );
  }

  void _commit(SwipeDirection direction, double velocity) {
    final target = direction == SwipeDirection.right ? _rowWidth : -_rowWidth;
    final from = _state.value.dragOffset;
    final revision = _beginAnimation(SwipeOpenState.fullSwiping);

    if (target == from || _reduceMotion) {
      _firePrimaryAction(direction, target);
      return;
    }

    final motion = SwipePhysics.releaseMotion(
      from: from,
      to: target,
      velocity: velocity,
      referenceDistance: _rowWidth,
      maxDuration: Duration(
        milliseconds: (_config.springResponse * 800).round(),
      ),
    );
    _animation.value = from;
    _animation
        .animateTo(target, duration: motion.duration, curve: motion.curve)
        .then((_) {
          if (mounted && revision == _animationRevision) {
            _firePrimaryAction(direction, target);
          }
        });
  }

  void _firePrimaryAction(SwipeDirection direction, double target) {
    _state.value = _state.value.copyWith(dragOffset: target);
    final callback = direction == SwipeDirection.right
        ? widget.onFullSwipeRight
        : widget.onFullSwipeLeft;
    final actions = _actionsFor(direction).where((action) => action.flex > 0);
    final revision = _animationRevision;
    if (callback != null) {
      callback();
    } else if (actions.isNotEmpty) {
      actions
          .firstWhere((action) => action.isPrimary, orElse: () => actions.first)
          .onTap();
    }
    if (mounted && revision == _animationRevision) _settle(0);
  }

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  int _beginAnimation(SwipeOpenState target) {
    _stopAnimation();
    _animationTarget = target;
    _state.value = _state.value.copyWith(
      openState: target,
      isFullSwiping: target == SwipeOpenState.fullSwiping,
    );
    return _animationRevision;
  }

  void _stopAnimation() {
    _animationRevision++;
    _animationTarget = null;
    _animation.stop();
  }

  void _onAnimationTick() {
    if (!_animation.isAnimating) return;
    final state = _state.value;
    final value = _animation.value;
    _state.value = state.copyWith(
      dragOffset: state.activeDirection == SwipeDirection.right
          ? math.max(0, value)
          : math.min(0, value),
    );
  }

  void _onActionTap(SwipeAction action) {
    if (!widget.enabled || _state.value.isFullSwiping) return;
    if (action.enableHaptic) _haptics.onActionTap();
    action.onTap();
    if (mounted && action.closeOnTap) _requestClose();
  }

  SwipeDirection _directionOf(double offset) {
    if (offset > 0) return SwipeDirection.right;
    if (offset < 0) return SwipeDirection.left;
    return SwipeDirection.none;
  }

  Widget _withAccessibleActions(Widget foreground, {required bool enabled}) {
    final actions = <String, SwipeAction>{};
    for (final direction in [SwipeDirection.left, SwipeDirection.right]) {
      if (!enabled || !_canDrag(direction)) continue;
      for (final action in _actionsFor(direction)) {
        if (action.flex <= 0) continue;
        final name = action.accessibleLabel;
        var label = name;
        for (var number = 2; actions.containsKey(label); number++) {
          label = '$name ($number)';
        }
        actions[label] = action;
      }
    }

    return Semantics(
      container: true,
      customSemanticsActions: {
        for (final entry in actions.entries)
          CustomSemanticsAction(label: entry.key): () =>
              _onActionTap(entry.value),
      },
      child: FocusableActionDetector(
        enabled: enabled,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.f10, shift: true):
              _ShowSwipeActionsIntent(),
          SingleActivator(LogicalKeyboardKey.contextMenu):
              _ShowSwipeActionsIntent(),
        },
        actions: {
          _ShowSwipeActionsIntent: CallbackAction<_ShowSwipeActionsIntent>(
            onInvoke: (_) => _showActionMenu(actions),
          ),
        },
        onShowFocusHighlight: (show) =>
            setState(() => _showKeyboardFocus = show),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: _showKeyboardFocus
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: foreground,
        ),
      ),
    );
  }

  Future<void> _showActionMenu(Map<String, SwipeAction> actions) async {
    final overlay = Navigator.maybeOf(
      context,
    )?.overlay?.context.findRenderObject();
    final row = context.findRenderObject();
    if (overlay is! RenderBox ||
        row is! RenderBox ||
        _state.value.isFullSwiping) {
      return;
    }

    final itemId = widget.itemId;
    final selected = await showMenu<SwipeAction>(
      context: context,
      position: RelativeRect.fromSize(
        row.localToGlobal(Offset.zero, ancestor: overlay) & row.size,
        overlay.size,
      ),
      requestFocus: true,
      items: [
        for (final entry in actions.entries)
          PopupMenuItem(value: entry.value, child: Text(entry.key)),
      ],
    );
    if (mounted && selected != null && widget.itemId == itemId) {
      _onActionTap(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSwipe =
        widget.enabled &&
        (_canDrag(SwipeDirection.left) || _canDrag(SwipeDirection.right));
    final foreground = RawGestureDetector(
      gestures: canSwipe
          ? <Type, GestureRecognizerFactory>{
              SwipeGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<SwipeGestureRecognizer>(
                    () => SwipeGestureRecognizer(
                      horizontalBias: _config.gestureHorizontalBias,
                      startThreshold: _config.gestureStartThreshold,
                    ),
                    (recognizer) => recognizer
                      ..horizontalBias = _config.gestureHorizontalBias
                      ..startThreshold = _config.gestureStartThreshold
                      ..dragStartBehavior = DragStartBehavior.down
                      ..onStart = _onDragStart
                      ..onUpdate = _onDragUpdate
                      ..onEnd = _onDragEnd
                      ..onCancel = _onDragCancel,
                  ),
            }
          : const {},
      behavior: HitTestBehavior.opaque,
      child: RepaintBoundary(child: widget.child),
    );
    return ValueListenableBuilder<SwipeItemState>(
      valueListenable: _state,
      child: _withAccessibleActions(foreground, enabled: canSwipe),
      builder: (context, state, child) => SizedBox(
        height: widget.itemHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final rowWidth = constraints.hasTightWidth
                ? constraints.maxWidth
                : _rowWidth;
            return ClipRect(
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  if (state.dragOffset != 0 && _canDrag(state.activeDirection))
                    _buildPanel(state, rowWidth),
                  Transform.translate(
                    offset: Offset(state.dragOffset, 0),
                    child: child,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPanel(SwipeItemState state, double rowWidth) {
    final direction = state.activeDirection;
    final actions = _actionsFor(direction);
    final openWidth = _openWidth(direction, rowWidth);
    final width = math.min(state.absOffset, rowWidth);
    if (openWidth <= 0 || width <= _config.actionInsets.horizontal) {
      return const SizedBox.shrink();
    }

    final start = math.max(
      openWidth,
      rowWidth * SwipeConstants.takeoverThreshold,
    );
    final end = math.min(rowWidth, start + rowWidth * 0.15);
    final progress = _canCommit(direction)
        ? SwipePhysics.fullSwipeProgress(
            currentOffset: width,
            fullSwipeStartOffset: start,
            screenWidth: end,
          )
        : 0.0;
    final rightward = direction == SwipeDirection.right;
    return Positioned(
      left: rightward ? 0 : null,
      right: rightward ? null : 0,
      top: 0,
      bottom: 0,
      width: width,
      child: IgnorePointer(
        ignoring: state.isFullSwiping,
        child: Listener(
          onPointerDown: (event) => _actionPointers.add(event.pointer),
          onPointerUp: (event) => _actionPointers.remove(event.pointer),
          onPointerCancel: (event) => _actionPointers.remove(event.pointer),
          child: RawGestureDetector(
            gestures: {
              SwipeGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<SwipeGestureRecognizer>(
                    () => SwipeGestureRecognizer(
                      horizontalBias: _config.gestureHorizontalBias,
                      startThreshold: _config.gestureStartThreshold,
                    ),
                    (recognizer) => recognizer
                      ..horizontalBias = _config.gestureHorizontalBias
                      ..startThreshold = _config.gestureStartThreshold
                      // Claim a swipe so it cannot become an action tap.
                      ..onUpdate = (_) {},
                  ),
            },
            child: SwipeActionPanel(
              actions: actions,
              width: width,
              openWidth: openWidth,
              takeoverProgress: Curves.easeInOutCubic.transform(progress),
              direction: direction,
              insets: _config.actionInsets,
              cornerRadius: widget.cornerRadius,
              onActionTap: _onActionTap,
            ),
          ),
        ),
      ),
    );
  }
}

class _ShowSwipeActionsIntent extends Intent {
  const _ShowSwipeActionsIntent();
}
