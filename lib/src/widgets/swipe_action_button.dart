import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/swipe_action.dart';
import '../models/swipe_item_state.dart';

/// Keeps the content anchored as its action's background stretches.
class SwipeActionButton extends StatelessWidget {
  final SwipeAction action;
  final double width;
  final double naturalWidth;
  final double takeoverProgress;
  final bool inset;
  final bool nearestRow;
  final SwipeDirection direction;
  final VoidCallback onTap;

  const SwipeActionButton({
    super.key,
    required this.action,
    required this.width,
    required this.naturalWidth,
    required this.takeoverProgress,
    required this.inset,
    required this.nearestRow,
    required this.direction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rightward = direction == SwipeDirection.right;
    final center = width / 2;
    final anchorInset = math.min(36.0, naturalWidth / 2);
    // Follow the outside edge during the reveal, then move toward the row.
    final edgeDistance = math.min(center, anchorInset);
    final towardRow = width - edgeDistance;
    final resting = nearestRow ? towardRow : (inset ? center : edgeDistance);
    final fromLeft = resting + (towardRow - resting) * takeoverProgress;
    final contentX = rightward ? fromLeft : width - fromLeft;

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: action.backgroundColor,
            borderRadius: action.borderRadius,
          ),
          clipBehavior: Clip.antiAlias,
          child:
              action.customWidget ??
              ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      left: contentX,
                      top: 0,
                      bottom: 0,
                      width: 0,
                      child: OverflowBox(
                        minWidth: 0,
                        maxWidth: math.max(48, naturalWidth),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: math.max(48, naturalWidth) - 8,
                            ),
                            child: _buildDefaultContent(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildDefaultContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (action.icon != null)
          IconTheme(
            data: IconThemeData(color: action.foregroundColor, size: 22),
            child: action.icon!,
          ),
        if (action.icon != null && action.label != null)
          const SizedBox(height: 4),
        if (action.label != null)
          Text(
            action.label!,
            style:
                (action.labelStyle ??
                        const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ))
                    .copyWith(
                      color: action.labelStyle?.color ?? action.foregroundColor,
                    ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}
