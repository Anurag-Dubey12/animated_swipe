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
    final radius = Radius.circular(cornerRadius);
    final totalFlex = actions.fold<double>(
      0,
      (total, action) => total + action.flex,
    );
    final multiple = actions
        .where((action) => action.flex > 0)
        .skip(1)
        .isNotEmpty;
    final primary = actions.firstWhere(
      (action) => action.isPrimary && action.flex > 0,
      orElse: () => actions.firstWhere((action) => action.flex > 0),
    );
    final regularWidth = openWidth - insets.horizontal;
    final baseWidth = contentWidth.clamp(0.0, regularWidth);
    final primaryShare = primary.flex / totalFlex;
    final secondaryWidth = baseWidth * (1 - takeoverProgress);
    final primaryWidth = contentWidth - secondaryWidth * (1 - primaryShare);

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
              borderRadius: BorderRadius.horizontal(
                left: rightward || inset ? radius : Radius.zero,
                right: !rightward || inset ? radius : Radius.zero,
              ),
              child: SizedBox(
                width: contentWidth,
                height: constraints.maxHeight * heightProgress,
                child: Row(
                  textDirection: rightward
                      ? TextDirection.ltr
                      : TextDirection.rtl,
                  children: [
                    for (final action in actions)
                      if (action.flex > 0 &&
                          (takeoverProgress < 1 || identical(action, primary)))
                        SwipeActionButton(
                          key: ValueKey(action.id),
                          action: action,
                          width: identical(action, primary)
                              ? primaryWidth
                              : secondaryWidth * action.flex / totalFlex,
                          naturalWidth: regularWidth * action.flex / totalFlex,
                          takeoverProgress: identical(action, primary)
                              ? takeoverProgress
                              : 0,
                          inset: inset,
                          nearestRow: multiple && !inset,
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
