# Animated swipe architecture

`lib/echo_animated_swipe.dart` exports `SwipeableListItem`, `SwipeController`, and the action, configuration, and state models. The example exercises both layouts with a single package dependency.

## Gesture and animation

- `SwipeGestureRecognizer` listens on the foreground, so dragging an exposed action keeps the panel in place. The foreground follows the pointer up to the row edge and responds immediately when the drag reverses. When full swipe is disabled, the row stretches progressively beyond the open panel.
- `SwipeActionPanel` starts with the first action. The second enters after 20% of the reveal, and the settled panel shows all actions at their flex widths. Past halfway across the row, the primary grows as the other actions taper to zero. Reversing the drag restores those widths along the same curve.
- `SwipeActionButton` slides the icon and label from the outer edge toward the center during reveal. The primary content then moves toward the foreground row during takeover. Both layouts use this motion. An inset panel also grows in height as it enters.
- `SwipePhysics` uses the release velocity to carry the row toward its destination and slow it to rest. The default slide duration scales with the remaining distance. A successful full swipe completes the exit before invoking the callback. Cancellation and interrupted animations clear pending completions.
- `SwipeController` tracks open rows with stable IDs. The row listens for a close request and for scrolling by its enclosing vertical scrollable. A `ValueListenableBuilder` updates the foreground transform and actions while reusing the same foreground child.

## Reference motion

Around 0.96–1.20 s in the first clip, the inset action appears small and gains height while its background stretches. Around 3.81–4.33 s the label moves toward the exposed edge of the row and returns toward the center as the drag reverses. The final swipe around 8.17–8.38 s expands the action before the row disappears.

In the second clip, the 0.84–1.54 s leftward drag first exposes two full-height actions. The secondary narrows from roughly 100 pixels in the recording to zero as the primary fills the reveal. Around 2.14–2.54 s, the secondary comes back as the drag reverses. The opposite-direction action around 3.48–4.78 s shows the icon moving from near the outside edge toward the foreground and back. These are visual observations from the clips. Gesture thresholds and haptics are package defaults and can be configured.
