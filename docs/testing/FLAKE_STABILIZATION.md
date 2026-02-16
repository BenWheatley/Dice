# Flaky Test Stabilization (2026-02-16)

## Goal
Improve deterministic reproducibility of UI test runs and reduce startup/input timing flakes.

## Changes Applied
- Added UI test launch mode in app startup (`-ui-testing`) to disable UIKit animations.
- Added optional state reset flag (`-reset-state`) to clear persisted defaults at launch for reproducible UI baselines.
- Updated `DiceUITests` to always launch with `-ui-testing -reset-state`.
- Increased key element wait timeouts from 3s to 5s for simulator variance.
- Improved notation replacement helper to use the text field clear button when available before delete fallback.

## Verification
- Unit suite: `DiceTests` passed.
- UI suite initial run failed with process bootstrap crash (simulator instability):
  - `Early unexpected exit, operation never finished bootstrapping`
- UI suite rerun passed fully (3/3 tests).

## Outcome
- Reproducibility improved by eliminating persisted-state drift between UI tests.
- Remaining risk is simulator process bootstrap instability, mitigated by documented single rerun policy.
