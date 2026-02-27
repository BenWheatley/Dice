# Architecture Overview

## Goals
- Share dice/domain behavior across iOS, iPadOS, watchOS, and Mac Catalyst.
- Keep UI state orchestration separate from pure roll logic.
- Support two roll modes: true-random and intuitive (existing implementation behavior).

## Module Boundaries

### Domain / Engine (platform-agnostic Swift)
- `DiceNotationParser`: parses and validates notation (`NdM`, optional `i`) with v1 bounds (`1...30` dice, `2...100` sides).
- `TrueRandomRoller`: standard random distribution roll engine.
- `IntuitiveRoller`: bias-constrained mode that adapts based on roll totals using existing project behavior.
- `DiceRollSession`: owns session-local counters and reset semantics.
- `DiceRollHistory` + `RollHistoryExporter`: history retention and export formatting.
- `DiceAppState`: current configuration, values, stats, and UI-facing state snapshot.

### Application Services
- `DicePreferencesStore`: user defaults wrapper for notation, recent presets, and animation preference.
- `DiceRollHistoryStore`: persistence wrapper for recent history.
- `DiceTelemetry`: lightweight logging hooks for roll events and invalid input diagnostics.

### Presentation Layer
- `DiceViewModel` (iOS/iPadOS/Catalyst): orchestrates parser, rollers, session, persistence, telemetry, and history for UIKit controllers.
- `WatchRollViewModel` (watchOS): watch-focused state transitions and mode toggling over shared domain services.
- `DiceCollectionViewController`: UIKit binding and interaction flow for notation, rolling, rerolling, history, and controls.
- `DiceCubeView`: SceneKit-backed rendering surface for 3D dice preview.


### Widgets and Entry Points
- `WidgetKit` extension will own Home Screen and Lock Screen widgets.
- Widget data providers consume persisted roll summary snapshots from shared app data services.
- `UIApplicationShortcutItem` routes app icon long-press actions into scene-aware deep-link destinations.

## Data Flow
1. User input arrives as notation text or preset action.
2. `DiceViewModel` parses/validates via `DiceNotationParser`.
3. `DiceRollSession` executes roll via true-random or intuitive path from `RollConfiguration.intuitive`.
4. `DiceAppState` is updated with values and aggregate stats.
5. History entry is appended and persisted.
6. UI reads state from view model and renders list + 3D board.
7. Telemetry records roll or validation failure events.

## Mode Algorithm Notes

### True-random
- Uses unbiased integer generation over side range.
- Test seams provide deterministic sources in unit tests.

### Intuitive (existing behavior)
- Uses local/session totals to avoid reinforcing overrepresented outcomes.
- Falls back to true-random behavior when prior totals are insufficient.
- Resets local distribution context when mode/configuration changes.

## Platform Notes
- iOS/iPadOS and Mac Catalyst share UIKit controller + `DiceViewModel` flow.
- Catalyst uses scene-based multiwindow configuration; each scene has isolated active dice state.
- watchOS uses dedicated watch UI with shared parser/session/roller domain logic.
- v1 validation remains simulator-first to avoid Apple Developer Team provisioning dependencies.
