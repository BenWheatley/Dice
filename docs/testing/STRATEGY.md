# Testing Strategy

## Objectives
- Keep core dice behavior deterministic under tests.
- Enforce TDD for domain and state transitions.
- Catch regressions across iOS/iPadOS/watchOS/Catalyst shared logic.

## TDD Rules
1. Write or update a failing test before changing production behavior.
2. Implement the minimal code to pass.
3. Refactor only after green tests.
4. Keep tests deterministic by injecting random sources and test seams.
5. For bug fixes, add a regression test that fails on the previous behavior.

## Test Pyramid
- Unit tests (`DiceTests`): primary confidence layer for parser, rollers, session, persistence, view models, and Catalyst parity checks.
- UI tests (`DiceUITests`): smoke coverage for launch, roll, presets, reroll, animation toggle, and reset flows.
- Simulator profiling/QA artifacts: performance/resource sanity and cross-device matrix validation.

## Required Checks Before Commit
1. Run unit tests:
   - `xcodebuild test -project Dice.xcodeproj -scheme Dice -destination 'platform=iOS Simulator,id=75445CDF-7A60-4E0C-B7CF-F80C7BE9A14E' -only-testing:DiceTests -derivedDataPath /tmp/DiceDerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
2. Run UI tests when UI-affecting changes are present:
   - `xcodebuild test -project Dice.xcodeproj -scheme Dice -destination 'platform=iOS Simulator,id=75445CDF-7A60-4E0C-B7CF-F80C7BE9A14E' -only-testing:DiceUITests -derivedDataPath /tmp/DiceDerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
3. For layout-sensitive changes, run iPad simulator UI tests:
   - `xcodebuild test -project Dice.xcodeproj -scheme Dice -destination 'platform=iOS Simulator,id=19FCE827-4EF4-4186-BE7F-712D5BD3D929' -only-testing:DiceUITests -derivedDataPath /tmp/DiceDerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
4. Update `DEVELOPMENT_PLAN.md` checkbox status for completed unit.
5. Commit exactly one completed checklist unit.

## Flake Handling
- If a UI run exits due simulator instability, rerun once and capture both outcomes in commit notes.
- Prefer unit-test pass as the non-negotiable gate.

## Simulator-Only Constraint
- v1 validation intentionally avoids checks requiring Apple Developer Team provisioning.
- All required checks above are executable on local simulators.
