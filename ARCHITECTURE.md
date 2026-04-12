# animated_swipe — Architecture Guide

## Package Overview

iOS Mail-style swipe actions for Flutter list items. Supports partial reveal with tappable buttons, full-swipe takeover with primary action flooding, spring physics, rubber-band resistance, and haptic feedback.

---

## File Map

```
lib/
├── animated_swipe.dart                        # Public barrel export
└── src/
    ├── controller/
    │   └── swipe_controller.dart              # Multi-item coordination
    ├── gestures/
    │   └── swipe_gesture_recognizer.dart       # Custom gesture (currently unused)
    ├── haptics/
    │   └── haptic_service.dart                # Haptic feedback wrapper
    ├── models/
    │   ├── swipe_action.dart                  # Action button model
    │   ├── swipe_configuration.dart           # All tunable parameters
    │   └── swipe_item_state.dart              # Immutable drag state + enums
    ├── physics/
    │   └── swipe_physics.dart                 # Rubber-band, spring, snap math
    ├── utils/
    │   └── swipe_constants.dart               # Default numeric values
    └── widgets/
        ├── swipe_action_button.dart           # Single action button renderer
        ├── swipe_action_panel.dart            # Action row + full-swipe takeover
        └── swipeable_list_item.dart           # Main widget (entry point)

example/lib/main.dart                          # Demo app (iOS Mail inbox)
test/                                          # Unit tests
```

---

## What Each File Does

### `animated_swipe.dart`
Public barrel export. Users import only this file. Exports: `SwipeController`, `SwipeAction`, `SwipeConfiguration`, `SwipeItemState`, `SwipeableListItem`. Internal files (panel, button, physics, haptics, constants) are not exported.

---

### Models

#### `swipe_item_state.dart`
- **`SwipeDirection`** enum — `none`, `left`, `right`
- **`SwipeOpenState`** enum — `closed`, `opening`, `open`, `closing`, `fullSwiping`
- **`SwipeItemState`** — immutable value object holding the drag offset, direction, open state, and haptic-fired guards. Every frame during a drag, a new instance is emitted via `ValueNotifier`. Has `copyWith`, equality, and derived getters (`isClosed`, `isOpen`, `absOffset`).

#### `swipe_action.dart`
- **`SwipeAction`** — describes one action button. Fields: `id`, `icon`, `label`, `backgroundColor`, `foregroundColor`, `flex` (proportional width weight), `isPrimary` (used in full-swipe takeover), `closeOnTap`, `enableHaptic`, `onTap` callback, `borderRadius`, `customWidget` (replaces icon+label), `labelStyle`.

#### `swipe_configuration.dart`
- **`SwipeConfiguration`** — all tunable parameters in one place. Thresholds (reveal, full-swipe, velocity), gesture discrimination (horizontal bias, start threshold), rubber-band factor, spring damping/response, snap curve, haptic toggle, close-on-scroll, simultaneous swipe, enable left/right, action width.

---

### Controller

#### `swipe_controller.dart`
- **`SwipeController`** extends `ChangeNotifier`
- Holds a `Map<String, ValueNotifier<SwipeItemState>>` registry
- Each `SwipeableListItem` registers in `initState`, unregisters in `dispose`
- **`notifyOpened(id)`** — when one item opens, closes all others (mutual exclusion)
- **`closeAll()`** / **`close(id)`** — programmatic close from outside
- **`openItemId`** / **`hasOpenItem`** — query state

**How mutual exclusion works:** When item A opens, it calls `controller.notifyOpened('A')`. The controller iterates the registry and sets all other items' state to `SwipeOpenState.closing`. Each item's `ValueListenableBuilder` picks that up and runs its snap-close spring animation.

---

### Physics

#### `swipe_physics.dart`
Pure static math, no widgets. Three core methods:

- **`applyRubberBand(rawOffset, resistanceStart, rubberBandFactor)`** — below `resistanceStart` returns unchanged, above applies `threshold + (overshoot / factor)`. Gives the elastic pull feel.
- **`resolveSnapTarget(currentOffset, velocity, ...)`** — after drag ends, returns: `0.0` (snap closed), `panelMaxWidth` (snap open), or `infinity` (full swipe). Priority: velocity > offset > threshold.
- **`buildSpring(from, to, velocity, dampingRatio, response)`** — creates a `SpringSimulation` matching iOS `UISpringTimingParameters`. Converts damping ratio + response to stiffness + damping coefficient.

#### `swipe_constants.dart`
All default numeric values used across the package. `defaultSpringDamping = 0.7`, `defaultRubberBandFactor = 3.5`, `defaultFullSwipeVelocityThreshold = 1200.0`, etc.

---

### Haptics

#### `haptic_service.dart`
Thin wrapper around `HapticFeedback`. Four methods:
- **`onThresholdReached()`** — `mediumImpact` when drag crosses halfway through the action panel
- **`onFullSwipeReached()`** — `heavyImpact` when drag crosses the panel edge (primary takes over) and again at full-swipe distance
- **`onSnapClose()`** — `lightImpact` when item springs closed
- **`onActionTap()`** — `selectionClick` when a button is tapped

All guarded by `enabled` flag (mirrors `SwipeConfiguration.enableHaptics`).

---

### Gestures

#### `swipe_gesture_recognizer.dart`
Custom `HorizontalDragGestureRecognizer` that compares dx/dy ratio to resolve the gesture arena early. **Currently unused** — the main widget switched to plain `GestureDetector` for reliability. Kept in case you want to re-enable custom arena resolution for edge cases.

---

### Widgets

#### `swipeable_list_item.dart`
The main widget. This is the largest and most important file.

**Responsibilities:**
- Wraps the child in a `GestureDetector` with horizontal drag callbacks
- Manages a `ValueNotifier<SwipeItemState>` for minimal rebuilds
- Tracks `_rawDragOffset` (raw pixel accumulation) and `_lockedDirection` (prevents mid-gesture direction flip)
- Applies rubber-band resistance via `SwipePhysics.applyRubberBand`
- Fires haptics at three points: panel halfway, panel edge, full-swipe distance
- On drag end, resolves snap target (closed / open / full-swipe) via `SwipePhysics.resolveSnapTarget`
- Runs spring animations via `AnimationController.animateWith(SpringSimulation)`
- On full-swipe: animates item off-screen, fires primary action callback, then springs back
- Registers with `SwipeController` for multi-item coordination
- Listens for external close commands (from controller)

**Build tree:**
```
GestureDetector
  └── ValueListenableBuilder<SwipeItemState>
        └── SizedBox
              └── Stack (Clip.hardEdge)
                    ├── Positioned (action panel, left or right)
                    └── Transform.translate (foreground child)
```

#### `swipe_action_panel.dart`
Renders the action buttons behind the item. **Two modes:**

1. **Normal reveal** (`totalWidth <= maxWidth`) — all buttons in a `Row`, each width proportional to its `flex` value. Standard tappable buttons.

2. **Full-swipe takeover** (`totalWidth > maxWidth`) — secondary buttons disappear. Primary action's color fills the entire panel. Primary's icon + label render centered with a scale-up animation (1.0x → 1.5x based on overshoot progress). The whole panel is tappable.

#### `swipe_action_button.dart`
Renders a single tappable action button. Receives computed `width` and `height` from the panel. Shows `icon` + `label` in a column, or `customWidget` if provided. Applies `backgroundColor`, `borderRadius`, and `foregroundColor`.

---

## Data Flow

```
User drags finger
  → GestureDetector.onHorizontalDragUpdate
    → _rawDragOffset accumulates
    → SwipePhysics.applyRubberBand computes effectiveOffset
    → _stateNotifier.value = new SwipeItemState(dragOffset: effectiveOffset)
    → _checkAndFireHaptics (threshold / panel edge / full-swipe)
      → HapticService fires vibration
    → ValueListenableBuilder rebuilds
      → Stack repositions Transform.translate + SwipeActionPanel
        → SwipeActionPanel checks totalWidth vs maxWidth
          → Normal: Row of SwipeActionButtons
          → Takeover: Single primary floods panel

User lifts finger
  → GestureDetector.onHorizontalDragEnd
    → SwipePhysics.resolveSnapTarget decides target
    → AnimationController.animateWith(SpringSimulation)
    → _onSnapTick updates _stateNotifier every frame
    → On completion: final state set, controller notified
```

---

## Swipe Behaviour Summary

| Drag distance | Visual | Haptic |
|---|---|---|
| 0 → halfway through panel | Buttons expand proportionally | — |
| Halfway through panel | Buttons continue expanding | `mediumImpact` |
| Panel edge reached | **Takeover**: primary color floods, icon scales up, secondaries gone | `heavyImpact` |
| Past panel edge (rubber-band) | Primary continues stretching, icon scales 1.0→1.5x | — |
| Full-swipe threshold (75% screen) | Item ready to auto-trigger | `heavyImpact` |
| Release in takeover zone | Spring to full-screen, fire action, spring back | `lightImpact` on close |
| Release before halfway | Spring back to closed | `lightImpact` |
| Release past halfway but before takeover | Spring open (locked at panel width) | — |

---

## Key Configuration Points

| Parameter | Default | What it controls |
|---|---|---|
| `actionWidth` | 120px | Width per action at flex=1.0 |
| `actionRevealThreshold` | 0.5 | Fraction of panel to snap open |
| `fullSwipeThreshold` | 0.75 | Fraction of screen for full swipe |
| `fullSwipeVelocityThreshold` | 1200 px/s | Fast-flick speed trigger |
| `rubberBandFactor` | 3.5 | Resistance past panel edge |
| `springDamping` | 0.7 | Spring bounce (0=bouncy, 1=dead) |
| `springResponse` | 0.4s | Spring speed |
| `enableHaptics` | true | Master haptic switch |
| `enableLeftActions` / `enableRightActions` | true | Disable one side |
