# tvOS Control Model Decision Record (v1)

Date: 2026-03-23  
Target: tvOS 18+ (simulator-first validation)

## Context

The current `Dice tvOS` shell proves that the shared renderer and roll domain can compile and launch on Apple TV, but it is not yet a usable product. The board is visible, while the control model is effectively hidden. That is the wrong default for tvOS.

tvOS is a focus-driven, 10-foot interface. Users operate it with a Siri Remote or game controller, not touch. Dice therefore needs a control model that is discoverable from the screen itself, consistent with Apple TV focus behavior, and layered on top of the existing shared rendering path rather than replacing it.

## Decision

Adopt a focus-first control model for tvOS.

### Remote semantics

1. Directional input moves focus.
2. `Select` activates the currently focused element.
3. `Menu/Back` dismisses the current overlay or moves up one navigation level.
4. `Play/Pause` is reserved for secondary or contextual actions only and must never be the only path to a primary task.

### Board semantics

1. Dice on the board must become individually focusable targets.
2. A focused die remains fully readable and gains clear focus treatment without covering neighboring dice.
3. `Select` on a focused die rerolls that die.
4. `Play/Pause` on a focused die opens die-specific options.
5. Global reroll remains a dedicated focusable action and is not hidden behind a remote-only gesture.

### Discoverability rules

1. The app must not depend on invisible input knowledge for primary tasks.
2. A first-launch help surface must teach the remote model in one screen:
   - move focus
   - `Select`
   - `Play/Pause`
   - `Menu/Back`
3. That help must be short, visual, and reopenable later from a standard settings/help entry.

### Platform-boundary rules

1. tvOS reuses the canonical shared dice render/material/domain path.
2. tvOS-specific work lives in the platform shell:
   - focus behavior
   - overlays
   - navigation structure
   - remote/controller input mapping
3. tvOS must not create a separate dice rendering implementation when the shared iOS path can be reused.

## Rationale

- This matches the native Apple TV interaction model instead of forcing touch-derived behavior onto a focus interface.
- It makes primary actions discoverable without documentation or trial-and-error.
- It keeps the renderer shared while allowing tvOS to adapt its shell to sofa-distance interaction.
- It gives later composer, presets, and settings work a stable foundation instead of layering new UI on top of hidden controls.

## Consequences

### Positive

- Users can understand how to control the app from the screen itself.
- Future tvOS tasks can build on a single consistent interaction contract.
- Shared rendering remains canonical across iOS and tvOS.

### Negative

- The current minimal tvOS shell is intentionally insufficient and must gain focusable UI and overlays before it is acceptable.
- Some touch-era assumptions from iOS cannot transfer directly and must be expressed as focusable elements instead.

## Explicit Non-Decisions

This record does not decide:

- the final root shell (`UITabBarController` vs custom shell)
- detailed focus maps for each destination
- token composer layout
- per-die overlay layout specifics

Those are covered by subsequent checklist items and should follow this control model rather than redefining it.

## Acceptance Implications

The tvOS app is not acceptable until all of the following are true:

1. A user can discover how to roll without guessing hidden controls.
2. Every primary action is reachable through visible focusable UI.
3. No primary task depends on `Play/Pause`.
4. The board supports focused-die targeting instead of board-only global actions.
