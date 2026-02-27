# SpringBoard Quick Actions Simulator Checklist

Date: 2026-02-27

## Preconditions

- iOS Simulator runtime installed: iOS 18.6+
- App installed and launched at least once (to allow dynamic quick-action refresh)
- Test both iPhone and iPad simulator profiles

## Static Action Presence

- Long-press app icon on SpringBoard.
- Verify these actions are present with SF Symbols and localized labels:
  - Roll Now
  - Repeat Last Roll
  - Presets
  - Roll History

## Dynamic Availability Rules

- Clear persisted history from app.
- Return to SpringBoard and long-press app icon.
- Verify `Repeat Last Roll` is removed after app refresh cycle.
- Perform one roll in app, return to SpringBoard, and verify `Repeat Last Roll` reappears.
- Verify repeat subtitle includes latest notation (`Last: <notation>`).

## Launch Routing (Cold Start)

- Terminate app from app switcher.
- Trigger each quick action from SpringBoard.
- Verify destination behavior:
  - Roll Now: roll action executes on launch.
  - Repeat Last Roll: repeats previous configuration only when history exists.
  - Presets: presets UI opens.
  - Roll History: history UI opens.

## Launch Routing (Warm Start)

- Keep app running in background.
- Trigger each quick action from SpringBoard.
- Verify same destination behavior as cold start.

## Multiwindow Isolation (iPad/Catalyst)

- Open two app windows with different visible contexts.
- Invoke quick action while one window is foreground.
- Verify only the active/target scene handles the route.
- Verify non-target window does not unexpectedly navigate.

## Pass Criteria

- Actions present and labeled correctly.
- Dynamic repeat action availability matches history state.
- Cold and warm start routing is correct.
- No incorrect cross-window navigation during quick-action handling.
