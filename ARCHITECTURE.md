# Animated swipe architecture

`lib/animated_swipe.dart` exports `SwipeableListItem`, `SwipeController`, and the action, configuration, and state models. The example exercises both layouts with a single package dependency.

## Gesture and animation

- `SwipeGestureRecognizer` distinguishes horizontal movement from a vertical scroll. `SwipeableListItem` tracks the signed drag offset. The foreground follows the pointer while resistance applies once the drag passes the row edge, or the open panel when full swipe is disabled.
- `SwipeActionPanel` allocates widths by action flex. After the panel opens, the primary grows as secondary widths taper to zero. Reversing the drag restores those widths along the same curve. The same action widget stays mounted as it grows.
- `SwipeActionButton` anchors icon and label content within the expanding surface. With insets, the panel also grows in height and stays centered vertically as it enters.
- `SwipePhysics` resolves release using direction-relative velocity and distance. The widget animates with one ticker. A successful full swipe completes the exit before invoking the callback. Cancellation and interrupted animations clear pending completions.
- `SwipeController` tracks open rows with stable IDs. The row listens for a close request and for scrolling by its enclosing vertical scrollable. A `ValueListenableBuilder` updates the foreground transform and actions while reusing the same foreground child.

## Reference motion

Around 0.96–1.20 s in the first clip, the inset action appears small and gains height while its background stretches. Around 3.81–4.33 s the label moves toward the exposed edge of the row and returns toward the center as the drag reverses. The final swipe around 8.17–8.38 s expands the action before the row disappears.

In the second clip, the 0.84–1.54 s leftward drag first exposes two full-height actions. The secondary narrows from roughly 100 pixels in the recording to zero as the primary fills the reveal. Around 2.14–2.54 s, the secondary comes back as the drag reverses. The opposite-direction action around 3.48–4.78 s shows the icon moving from near the outside edge toward the foreground and back. These are visual observations from the clips. Gesture thresholds and haptics are package defaults and can be configured.
