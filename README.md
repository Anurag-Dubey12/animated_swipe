# echo_animated_swipe

Add horizontal swipe actions to any Flutter row. The foreground tracks the drag, action buttons open behind it, and continued movement expands the primary action while compressing the others. A short drag settles back or leaves the buttons open for tapping.

## Install from this repository

Use Flutter 3.35.5 or later. Add this checkout as a path dependency in your app's `pubspec.yaml`.

```yaml
dependencies:
  echo_animated_swipe:
    path: ../animated_swipe
```

## Wrap a row

```dart
import 'package:echo_animated_swipe/echo_animated_swipe.dart';
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

Each side takes its own list, so you can use different counts, such as two actions on one side and four on the other. Leave a side empty to disable it. To swipe an open row, start the drag on the foreground content. The exposed actions can be tapped, and a drag starting there keeps the panel open.

Share a `SwipeController` across your rows, give each row a stable ID, and dispose of the controller with its owner. Call `close(id)` or `closeAll()` to close rows programmatically. An open row closes when its enclosing vertical list scrolls by default.

Screen readers can invoke a row's actions through its accessibility actions while the panel is closed. Keyboard users can focus the row with Tab and open its action menu with Shift+F10 or the Menu key. Set `SwipeAction.semanticLabel` to a localized name for icon-only and custom actions.

## Customize the swipe

| Setting | Behavior |
| --- | --- |
| `actionWidth` and `SwipeAction.flex` | Control each button's natural width. Buttons scale to fit narrow rows. |
| `actionInsets` and `cornerRadius` | Use zero insets for full-height actions. Set `cornerRadius` to round either layout, or use 0 for square corners. |
| `enableFullSwipeLeft` / `enableFullSwipeRight` | Turn off automatic action invocation on either side while keeping its buttons tappable. |
| `fullSwipeThreshold` | Set the release threshold as a fraction of the row width. The trigger stays beyond the open panel. The default is 0.70. |
| `fullSwipeVelocityThreshold` | Allow a fast flick to commit once the row is halfway open and the current drag has moved it outward by at least 15% of its width. |
| `onFullSwipeLeft` / `onFullSwipeRight` | Override the corresponding primary action for a full swipe. The first visible action is the fallback when no action is marked primary. |
| `snapDuration` / `snapCurve` | Cap the duration of the default velocity-aware slide or set a fixed duration and custom curve. Set `useSpringPhysics: true` to settle with `springResponse` and `springDamping`. |
| `enableHaptics` / `SwipeAction.enableHaptic` | Control row-wide haptics and individual tap feedback. |

A full swipe invokes its callback after the exit animation. Update your list in the callback to remove the row, or keep the row and let it close. Set `closeOnTap: false` on an action if its panel should stay open after a tap.

Run the [example](example/lib/main.dart) with `flutter run` from `example/`. Use **Action layout** to switch between full-height and inset actions, **Action content** to try text, icons, or a custom widget, and **Corner radius** to change the rounding. The vibration button toggles haptics.

The Android example uses a locally installed JDK 17 for Gradle.
