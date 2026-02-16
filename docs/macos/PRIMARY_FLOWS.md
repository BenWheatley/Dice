# Mac Catalyst Primary Flows (v1)

The Mac build uses the same UIKit controller stack under Mac Catalyst, so core flows are shared with iOS/iPadOS and validated in simulator runs.

## Flow Mapping

- Roll from notation input: `notationField` + `rollButton`.
- Reroll single die: per-cell `dieButton_*`.
- Preset selection and intuitive toggle: `presetsButton` menu (`Nd6` and `Nd6i` actions).
- Session stats: `totalsLabel`.
- Stats reset: `resetStatsButton`.

## Catalyst Notes

- Multi-window is enabled via scene manifest (`UIApplicationSupportsMultipleScenes = true`).
- Each window constructs its own `DiceCollectionViewController` and `DiceViewModel`, which keeps active dice state isolated per window.
- Roll logic, mode handling, and history behavior are shared through the domain/view-model layer.
