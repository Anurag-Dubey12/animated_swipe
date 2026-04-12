import 'package:flutter/services.dart';

/// Thin wrapper around [HapticFeedback] for swipe interaction feedback.
///
/// Centralises all haptic calls so widgets stay clean. The [enabled] flag
/// acts as a single guard — no scattered conditionals in widget code.
class HapticService {
  /// Whether haptic feedback is active. Mirrors [SwipeConfiguration.enableHaptics].
  final bool enabled;

  const HapticService({this.enabled = true});

  /// Medium impact — fired once when the drag crosses the action reveal threshold.
  ///
  /// Matches iOS Mail's "peek" haptic as the action buttons become visible.
  Future<void> onThresholdReached() async {
    if (!enabled) return;
    await HapticFeedback.mediumImpact();
  }

  /// Heavy impact — fired once when the drag crosses the full-swipe threshold.
  ///
  /// Matches iOS Mail's confirmation haptic before the action fires.
  Future<void> onFullSwipeReached() async {
    if (!enabled) return;
    await HapticFeedback.heavyImpact();
  }

  /// Light impact — fired when the item snaps closed after being open.
  Future<void> onSnapClose() async {
    if (!enabled) return;
    await HapticFeedback.lightImpact();
  }

  /// Selection click — fired on action button tap.
  Future<void> onActionTap() async {
    if (!enabled) return;
    await HapticFeedback.selectionClick();
  }
}
