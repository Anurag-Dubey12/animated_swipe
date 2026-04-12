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
  /// Secondary buttons are gone. Icon scales up with an animated feel.
  Widget _buildFullSwipeTakeover() {
    final primary = _findPrimary();
    final overflow = totalWidth - maxWidth;
    // How far into the takeover we are (0.0 = just crossed, 1.0 = fully taken).
    // Use maxWidth as the range — by the time overflow == maxWidth, transition
    // is complete. Clamped so it never exceeds 1.0.
    final progress = (overflow / maxWidth).clamp(0.0, 1.0);

    // Icon scales from 1.0 to 1.5 during takeover.
    final iconScale = 1.0 + (0.5 * progress);

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
        alignment: direction == SwipeDirection.left
            ? Alignment.centerRight
            : Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Transform.scale(
          scale: iconScale,
          child: primary.customWidget ??
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (primary.icon != null)
                    IconTheme(
                      data: IconThemeData(
                        color: primary.foregroundColor,
                        size: 24,
                      ),
                      child: primary.icon!,
                    ),
                  if (primary.icon != null && primary.label != null)
                    const SizedBox(height: 4),
                  if (primary.label != null)
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
              ),
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
