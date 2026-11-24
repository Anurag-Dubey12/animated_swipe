import 'package:flutter/material.dart';

import '../models/swipe_action.dart';
import '../models/swipe_item_state.dart';
import 'swipe_action_button.dart';

/// Lays out a single set of action buttons across the reveal and takeover.
class SwipeActionPanel extends StatelessWidget {
  final List<SwipeAction> actions;
  final double width;
  final double openWidth;
  final double takeoverProgress;
  final SwipeDirection direction;
  final EdgeInsets insets;
  final double cornerRadius;
  final void Function(SwipeAction action) onActionTap;

  const SwipeActionPanel({
    super.key,
    required this.actions,
    required this.width,
    required this.openWidth,
    required this.takeoverProgress,
    required this.direction,
    required this.insets,
    required this.cornerRadius,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final contentWidth = width - insets.horizontal;
    if (contentWidth <= 0) return const SizedBox.shrink();

    final rightward = direction == SwipeDirection.right;
    final inset = insets != EdgeInsets.zero;
    final visibleActions = actions.where((action) => action.flex > 0).toList();
    final totalFlex = visibleActions.fold<double>(
      0,
      (total, action) => total + action.flex,
    );
    final primary = visibleActions.firstWhere(
      (action) => action.isPrimary,
      orElse: () => visibleActions.first,
    );
    final regularWidth = openWidth - insets.horizontal;
    final reveal = contentWidth / regularWidth;
    final shares = List<double>.filled(visibleActions.length, 0);
    shares[0] = 1;
    // The first action fills the available space until the other actions enter.
    for (var index = 1; index < visibleActions.length; index++) {
      final start = 0.2 + 0.6 * (index - 1) / (visibleActions.length - 1);
      final progress = ((reveal - start) / (1 - start)).clamp(0.0, 1.0);
      final share =
          visibleActions[index].flex /
          totalFlex *
          Curves.easeInOut.transform(progress);
      shares[index] = share;
      shares[0] -= share;
    }

    return Padding(
      padding: insets,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final heightProgress = inset
              ? Curves.easeOut.transform((contentWidth / 56).clamp(0.0, 1.0))
              : 1.0;
          return Align(
            alignment: Alignment.center,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(cornerRadius),
              child: SizedBox(
                width: contentWidth,
                height: constraints.maxHeight * heightProgress,
                child: Row(
                  textDirection: rightward
                      ? TextDirection.ltr
                      : TextDirection.rtl,
                  children: [
                    for (final (index, action) in visibleActions.indexed)
                      SwipeActionButton(
                        key: ValueKey(action.id),
                        action: action,
                        width:
                            contentWidth *
                            (shares[index] * (1 - takeoverProgress) +
                                (identical(action, primary)
                                    ? takeoverProgress
                                    : 0)),
                        naturalWidth: regularWidth * action.flex / totalFlex,
                        takeoverProgress: identical(action, primary)
                            ? takeoverProgress
                            : 0,
                        direction: direction,
                        onTap: () => onActionTap(action),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
