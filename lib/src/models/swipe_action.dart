import 'package:flutter/widgets.dart';

/// Defines a single action revealed when a [SwipeableListItem] is swiped.
///
/// Actions are rendered as tappable buttons behind the list item.
/// Supply either [icon]/[label] for a standard button, or [customWidget] for
/// full control over the button's appearance.
class SwipeAction {
  /// Unique identifier within the action list. Used for keying widgets.
  final String id;

  /// Icon shown inside the button. Optional if [customWidget] is provided.
  final Widget? icon;

  /// Text label shown below the icon. Optional.
  final String? label;

  /// Localized action name for screen readers and the keyboard action menu.
  ///
  /// Provide this for icon-only and custom actions without a descriptive label.
  final String? semanticLabel;

  /// The name announced by assistive technology and shown in the keyboard menu.
  String get accessibleLabel {
    final iconWidget = icon;
    return semanticLabel ??
        label ??
        (iconWidget is Icon ? iconWidget.semanticLabel : null) ??
        id;
  }

  /// Background fill color of the button.
  final Color backgroundColor;

  /// Color applied to [icon] and [label] text.
  final Color foregroundColor;

  /// Proportional width weight relative to sibling actions. Defaults to 1.0.
  ///
  /// For example, actions with flex [2.0, 1.0] will occupy 2/3 and 1/3 of
  /// the total panel width respectively.
  final double flex;

  /// Whether this is the primary action triggered by a full swipe.
  ///
  /// Only one action per side should be marked primary. If none is marked,
  /// the first action in the list is used as the full-swipe target.
  final bool isPrimary;

  /// Whether the item auto-closes after this action is tapped. Defaults to true.
  final bool closeOnTap;

  /// Whether tapping this action produces haptic feedback. Defaults to true.
  /// The configuration's master haptic switch also applies.
  final bool enableHaptic;

  /// Callback invoked when the user taps this action or triggers it via full swipe.
  final VoidCallback onTap;

  /// Optional corner radius override for this button.
  ///
  /// If null, the panel applies default radii based on position in the list.
  final BorderRadius? borderRadius;

  /// Replaces the default [icon] + [label] layout with a fully custom widget.
  ///
  /// The widget is constrained to the button's computed width × item height.
  final Widget? customWidget;

  /// Label text style override. Defaults to a compact, medium-weight label.
  final TextStyle? labelStyle;

  const SwipeAction({
    required this.id,
    required this.backgroundColor,
    required this.onTap,
    this.icon,
    this.label,
    this.semanticLabel,
    this.foregroundColor = const Color(0xFFFFFFFF),
    this.flex = 1.0,
    this.isPrimary = false,
    this.closeOnTap = true,
    this.enableHaptic = true,
    this.borderRadius,
    this.customWidget,
    this.labelStyle,
  }) : assert(flex >= 0 && flex < double.infinity),
       assert(
         icon != null || label != null || customWidget != null,
         'SwipeAction must have at least one of: icon, label, or customWidget.',
       );
}
