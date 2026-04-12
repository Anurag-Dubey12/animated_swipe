import 'package:flutter/material.dart';
import '../models/swipe_action.dart';

/// Renders a single swipe action as a tappable button.
///
/// Width and height are controlled by the parent [SwipeActionPanel] and passed
/// in directly — this widget does not compute its own sizing.
///
/// Supply [action.customWidget] for a fully custom appearance, or use
/// [action.icon] and [action.label] for the standard iOS-style layout.
class SwipeActionButton extends StatelessWidget {
  /// The action model this button represents.
  final SwipeAction action;

  /// Pixel width of this button (computed proportionally by the panel).
  final double width;

  /// Pixel height matching the parent list item.
  final double height;

  /// Whether this is the outermost button (gets the outer rounded corner).
  final bool isFirst;

  /// Whether this is the innermost button (adjacent to the list item edge).
  final bool isLast;

  /// Called when the user taps this button.
  final VoidCallback onTap;

  const SwipeActionButton({
    super.key,
    required this.action,
    required this.width,
    required this.height,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: action.backgroundColor,
          borderRadius: action.borderRadius,
        ),
        clipBehavior: Clip.antiAlias,
        child: action.customWidget ?? _buildDefaultContent(),
      ),
    );
  }

  Widget _buildDefaultContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
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
            style: (action.labelStyle ??
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))
                .copyWith(color: action.foregroundColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}
