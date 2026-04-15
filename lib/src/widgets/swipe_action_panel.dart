import 'package:flutter/widgets.dart';
import '../models/swipe_action.dart';
import '../models/swipe_item_state.dart';
import 'swipe_action_button.dart';

/// Renders the row of action buttons revealed during a swipe.
///
/// **Two modes:**
///
/// 1. **Normal reveal** (`totalWidth <= maxWidth`): all buttons expand
///    proportionally by their [SwipeAction.flex] values.
///
/// 2. **Full-swipe takeover** (`totalWidth > maxWidth`): the primary action
///    floods the entire panel — its color fills the background, its icon
///    scales up, and secondary buttons collapse to zero width. This matches
///    iOS Mail's behaviour where the delete button takes over as you over-drag.
class SwipeActionPanel extends StatelessWidget {
  final List<SwipeAction> actions;
  final double totalWidth;
  final double maxWidth;
  final double itemHeight;
  final SwipeDirection direction;
  final double cornerRadius;
  final void Function(SwipeAction action) onActionTap;

  const SwipeActionPanel({
    super.key,
    required this.actions,
    required this.totalWidth,
    required this.maxWidth,
    required this.itemHeight,
    required this.direction,
    required this.cornerRadius,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty || totalWidth <= 0) return const SizedBox.shrink();

    final isOverDrag = maxWidth > 0 && totalWidth > maxWidth;

    if (isOverDrag) {
      return _buildFullSwipeTakeover();
    }
    return _buildNormalReveal();
  }

  /// Normal mode: all buttons side by side, proportional widths.
  Widget _buildNormalReveal() {
    final widths = _computeProportionalWidths();

    final orderedActions = direction == SwipeDirection.right
        ? actions
        : actions.reversed.toList();
    final orderedWidths = direction == SwipeDirection.right
        ? widths
        : widths.reversed.toList();

    return SizedBox(
      width: totalWidth,
      height: itemHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(orderedActions.length, (i) {
          final action = orderedActions[i];
          final isFirst = i == 0;
          final isLast = i == orderedActions.length - 1;

          return SwipeActionButton(
            key: ValueKey(action.id),
            action: _withRadius(action, isFirst),
            width: orderedWidths[i],
            height: itemHeight,
            isFirst: isFirst,
            isLast: isLast,
            onTap: () => onActionTap(action),
          );
        }),
      ),
    );
  }

  /// Full-swipe takeover: primary action fills the entire panel.
  /// Secondary buttons are gone. Icon scales up and the content travels
  /// alongside the foreground item so it never gets stuck.
  Widget _buildFullSwipeTakeover() {
    final primary = _findPrimary();
    final overflow = totalWidth - maxWidth;
    final progress = maxWidth > 0
        ? (overflow / maxWidth).clamp(0.0, 1.0)
        : 1.0;

    // Icon scales from 1.0 to 1.5 during the initial takeover phase.
    final iconScale = 1.0 + (0.5 * progress);

    final hasIcon = primary.icon != null;
    final hasLabel = primary.label != null;

    final content = primary.customWidget ??
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasIcon)
              IconTheme(
                data: IconThemeData(
                  color: primary.foregroundColor,
                  size: 24,
                ),
                child: primary.icon!,
              ),
            if (hasIcon && hasLabel)
              const SizedBox(height: 4),
            if (hasLabel)
              Text(
                primary.label!,
                style: (primary.labelStyle ??
                        const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ))
                    .copyWith(color: primary.foregroundColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        );

    // Position the content at a fixed inset from the trailing edge of the
    // panel (the edge adjacent to the foreground child). This way the content
    // moves together with the child as it slides off screen, instead of
    // getting stuck in the middle.
    const double inset = 24.0;

    return GestureDetector(
      onTap: () => onActionTap(primary),
      child: Container(
        width: totalWidth,
        height: itemHeight,
        decoration: BoxDecoration(
          color: primary.backgroundColor,
          borderRadius: BorderRadius.only(
            topLeft: direction == SwipeDirection.right
                ? Radius.circular(cornerRadius)
                : Radius.zero,
            bottomLeft: direction == SwipeDirection.right
                ? Radius.circular(cornerRadius)
                : Radius.zero,
            topRight: direction == SwipeDirection.left
                ? Radius.circular(cornerRadius)
                : Radius.zero,
            bottomRight: direction == SwipeDirection.left
                ? Radius.circular(cornerRadius)
                : Radius.zero,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              // Anchor to the trailing edge (near the foreground child).
              right: direction == SwipeDirection.right ? inset : null,
              left: direction == SwipeDirection.left ? inset : null,
              top: 0,
              bottom: 0,
              child: Center(
                child: Transform.scale(
                  scale: iconScale,
                  child: content,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Finds the primary action (or falls back to first).
  SwipeAction _findPrimary() {
    return actions.firstWhere(
      (a) => a.isPrimary,
      orElse: () => actions.first,
    );
  }

  /// Proportional flex distribution for normal reveal mode.
  List<double> _computeProportionalWidths() {
    final totalFlex = actions.fold<double>(0.0, (sum, a) => sum + a.flex);
    if (totalFlex == 0) return List.filled(actions.length, 0.0);
    return actions.map((a) => totalWidth * (a.flex / totalFlex)).toList();
  }

  /// Applies corner radius based on position in the panel.
  SwipeAction _withRadius(SwipeAction action, bool isOutermost) {
    final resolved = action.borderRadius ??
        BorderRadius.only(
          topLeft: (direction == SwipeDirection.right && isOutermost)
              ? Radius.circular(cornerRadius)
              : Radius.zero,
          bottomLeft: (direction == SwipeDirection.right && isOutermost)
              ? Radius.circular(cornerRadius)
              : Radius.zero,
          topRight: (direction == SwipeDirection.left && isOutermost)
              ? Radius.circular(cornerRadius)
              : Radius.zero,
          bottomRight: (direction == SwipeDirection.left && isOutermost)
              ? Radius.circular(cornerRadius)
              : Radius.zero,
        );

    return SwipeAction(
      id: action.id,
      backgroundColor: action.backgroundColor,
      onTap: action.onTap,
      icon: action.icon,
      label: action.label,
      foregroundColor: action.foregroundColor,
      flex: action.flex,
      isPrimary: action.isPrimary,
      closeOnTap: action.closeOnTap,
      enableHaptic: action.enableHaptic,
      borderRadius: resolved,
      customWidget: action.customWidget,
      labelStyle: action.labelStyle,
    );
  }
}
