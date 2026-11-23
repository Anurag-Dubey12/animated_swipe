# animated_swipe

Add horizontal swipe actions to any Flutter row. The foreground tracks the drag, action buttons open behind it, and continued movement expands the primary action while compressing the others. A short drag settles back or leaves the buttons open for tapping.

## Install from this repository

Use Flutter 3.35.5 or later. Add this checkout as a path dependency in your app's `pubspec.yaml`.

```yaml
dependencies:
  animated_swipe:
    path: ../animated_swipe
```

## Wrap a row

```dart
import 'package:animated_swipe/animated_swipe.dart';
import 'package:flutter/material.dart';

Widget swipeableTask({
  required String id,
  required String title,
  required VoidCallback onComplete,
  required VoidCallback onArchive,
  required VoidCallback onDelete,
  SwipeController? controller,
}) {
  return SwipeableListItem(
    key: ValueKey(id),
    itemId: id,
    controller: controller,
    cornerRadius: 0,
    configuration: const SwipeConfiguration(actionWidth: 88),
    leftActions: [
      SwipeAction(
        id: 'delete',
        icon: const Icon(Icons.delete_outline),
        backgroundColor: Colors.red,
        isPrimary: true,
        onTap: onDelete,
      ),
      SwipeAction(
        id: 'archive',
        icon: const Icon(Icons.archive_outlined),
        backgroundColor: Colors.indigo,
        onTap: onArchive,
      ),
    ],
    rightActions: [
      SwipeAction(
        id: 'complete',
        icon: const Icon(Icons.check),
        backgroundColor: Colors.blue,
        onTap: onComplete,
      ),
    ],
    child: ListTile(title: Text(title)),
  );
}
```

`leftActions` reveal on the right during a leftward drag. `rightActions` reveal on the left during a rightward drag. Within a side, list actions from the outside edge toward the row.

Share a `SwipeController` across your rows, give each row a stable ID, and dispose of the controller with its owner. Call `close(id)` or `closeAll()` to close rows programmatically. An open row closes when its enclosing vertical list scrolls by default.

## Customize the swipe

| Setting | Behavior |
| --- | --- |
| `actionWidth` and `SwipeAction.flex` | Control each button's natural width. Buttons scale to fit narrow rows. |
| `actionInsets` and `cornerRadius` | Use zero insets for full-height actions. Use `EdgeInsets.symmetric(horizontal: 8, vertical: 9)` with a radius of 16 for a rounded inset button. |
| `enableFullSwipeLeft` / `enableFullSwipeRight` | Turn off automatic action invocation on either side while keeping its buttons tappable. |
| `fullSwipeThreshold` | Set the release threshold as a fraction of the row width. The trigger stays beyond the open panel. The default is 0.70. |
| `onFullSwipeLeft` / `onFullSwipeRight` | Override the corresponding primary action for a full swipe. The first visible action is the fallback when no action is marked primary. |
| `snapDuration` / `snapCurve` | Tune eased settling. Set `useSpringPhysics: true` to use `springResponse` and `springDamping` for settling. |
| `enableHaptics` / `SwipeAction.enableHaptic` | Control row-wide haptics and individual tap feedback. |

A full swipe invokes its callback after the exit animation. Update your list in the callback to remove the row, or keep the row and let it close. Set `closeOnTap: false` on an action if its panel should stay open after a tap.

Run the [example](example/lib/main.dart) with `flutter run` from `example/`. Use the **Action layout** menu to switch between full-height actions and the inset button.

The Android example uses a locally installed JDK 17 for Gradle.
