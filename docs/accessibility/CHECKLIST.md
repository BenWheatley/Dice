# Accessibility Checklist (v1)

## Labels and Traits

- Notation input, roll/preset/history/animation/reset controls have explicit accessibility labels.
- Dice cell buttons expose per-die labels and reroll hints.
- Totals and validation messaging expose readable labels and dynamic text sizing.

## Focus and Interaction

- Keyboard return rolls notation input.
- Hardware keyboard shortcuts support roll/reset/focus/history.
- Interactive controls are focusable and pointer-enabled for Catalyst.

## Visual and Dynamic Type

- Dynamic type enabled on core labels/buttons.
- Validation errors are presented inline and announced via VoiceOver notifications.
- Background/text contrast keeps controls readable against patterned background.

## Residual Risk

- SceneKit face textures are visual-only and not individually announced; value parity is provided via cell labels and totals text.
