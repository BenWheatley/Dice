# Dice v1 Product Definition and Acceptance Criteria

Date: 2026-02-16

## Product Definition

v1 is a simulator-testable, cross-platform dice app with:

- iOS/iPadOS 18+ support
- watchOS 10.2+ support
- macOS 15.7+ via Mac Catalyst
- Two roll modes:
  - True-random
  - Existing intuitive implementation (behavior unchanged from current app logic)
- Dice notation support capped at `30d100`
- Roll history and export included in v1
- No features requiring Apple Developer Team provisioning for testing

## Cross-Platform Functional Acceptance Criteria

1. User can enter notation in `NdM` format with optional `i` suffix for intuitive mode.
2. Input validation enforces:
   - `N` between 1 and 30
   - `M` between 2 and 100
3. App can roll all dice in current notation and display resulting values and sum.
4. User can reroll an individual die without changing other dice.
5. Current roll statistics are shown and can be reset.
6. Roll history records each roll event with enough detail to reconstruct:
   - notation
   - mode
   - per-die values
   - total/sum
   - timestamp
7. User can export roll history as shareable text or CSV.
8. No cloud-only/provisioning-only dependencies are required to verify v1 behavior in simulators.

## iOS/iPadOS Acceptance Criteria

1. Primary roll, reroll, mode toggle, and reset flows are fully usable on iPhone and iPad.
2. Layout adapts to size class/orientation with no clipped core controls.
3. Shake-to-roll all dice works on iOS.
4. Roll history view supports inspect, clear, and export actions.
5. Accessibility labels exist for dice controls, mode state, roll and export actions.

## watchOS Acceptance Criteria

1. Watch app launches and performs roll action on watchOS 10.2 simulator.
2. Watch UI supports true-random and intuitive mode selection.
3. Current roll result is visible and updates after each roll.
4. Core interactions are accessible (labels/hints on primary controls).

## macOS (Catalyst) Acceptance Criteria

1. App runs under Mac Catalyst on macOS 15.7+.
2. Multiple windows are supported.
3. Each window maintains independent dice state (notation, mode, values, session stats, in-memory history).
4. Roll history inspection and export are available in each window.
5. Keyboard shortcuts exist for at least roll and reset actions.

## Quality Acceptance Criteria

1. Shared domain logic is covered by unit tests for parser, true-random, intuitive, and session/history models.
2. Critical UI flows have UI tests on iOS/iPadOS and Catalyst where practical.
3. Each completed work item is reflected in `DEVELOPMENT_PLAN.md` and committed separately.
4. Architecture and non-obvious algorithm logic are documented.

