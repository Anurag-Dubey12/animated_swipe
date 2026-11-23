import 'package:flutter/foundation.dart';
import '../models/swipe_item_state.dart';

/// Coordinates open/close state across multiple [SwipeableListItem] widgets.
///
/// Attach a single [SwipeController] to a group of [SwipeableListItem]s (e.g.,
/// all items in a [ListView]) to enable automatic mutual exclusion: when one
/// item opens, all others close.
///
/// Dispose the controller when its owning widget is removed from the tree.
///
/// ```dart
/// final _controller = SwipeController();
///
/// @override
/// void dispose() {
///   _controller.dispose();
///   super.dispose();
/// }
/// ```
class SwipeController extends ChangeNotifier {
  /// Registry of all live item notifiers, keyed by [itemId].
  final Map<String, ValueNotifier<SwipeItemState>> _registry = {};

  // Insertion order preserves the most recently opened item if several are open.
  final Set<String> _openItems = {};

  /// Called by [SwipeableListItem] in [State.initState] to register its notifier.
  void register(String itemId, ValueNotifier<SwipeItemState> notifier) {
    _registry[itemId] = notifier;
  }

  /// Called by [SwipeableListItem] in [State.dispose] to clean up its notifier.
  void unregister(String itemId) {
    _registry.remove(itemId);
    if (_openItems.remove(itemId)) {
      notifyListeners();
    }
  }

  /// Called when an item begins opening.
  ///
  /// Unless [allowSimultaneous] is true, all other registered items will be
  /// commanded to close via their [ValueNotifier].
  void notifyOpened(String itemId, {bool allowSimultaneous = false}) {
    if (!allowSimultaneous) {
      _openItems.clear();
      _closeAllExcept(itemId);
    }
    _openItems
      ..remove(itemId)
      ..add(itemId);
    notifyListeners();
  }

  /// Called when an item has finished closing itself.
  void notifyClosedSelf(String itemId) {
    if (_openItems.remove(itemId)) {
      notifyListeners();
    }
  }

  /// Programmatically closes all registered items.
  void closeAll() {
    _openItems.clear();
    _closeAllExcept(null);
    notifyListeners();
  }

  /// Programmatically closes the item with [itemId].
  ///
  /// No-op if the item is not registered or already closed.
  void close(String itemId) {
    final notifier = _registry[itemId];
    if (notifier == null) return;
    final state = notifier.value;
    final wasOpen = _openItems.remove(itemId);
    if (!state.isClosed) {
      notifier.value = state.copyWith(openState: SwipeOpenState.closing);
    }
    if (wasOpen) notifyListeners();
  }

  /// Whether any registered item is currently open.
  bool get hasOpenItem => _openItems.isNotEmpty;

  /// The most recently opened item's ID, or null if all items are closed.
  String? get openItemId => _openItems.isEmpty ? null : _openItems.last;

  void _closeAllExcept(String? exceptId) {
    for (final entry in _registry.entries) {
      if (entry.key == exceptId) continue;
      final state = entry.value.value;
      if (!state.isClosed) {
        entry.value.value = state.copyWith(openState: SwipeOpenState.closing);
      }
    }
  }
}
