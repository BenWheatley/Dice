# Release Candidate Sign-Off

Date: 2026-02-16
Candidate tag: `v1.0.0-rc1`

## Regression Commands
1. `xcodebuild test -project Dice.xcodeproj -scheme Dice -destination 'platform=iOS Simulator,id=75445CDF-7A60-4E0C-B7CF-F80C7BE9A14E' -only-testing:DiceTests -derivedDataPath /tmp/DiceDerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
2. `xcodebuild test -project Dice.xcodeproj -scheme Dice -destination 'platform=iOS Simulator,id=75445CDF-7A60-4E0C-B7CF-F80C7BE9A14E' -only-testing:DiceUITests -derivedDataPath /tmp/DiceDerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
3. `xcodebuild test -project Dice.xcodeproj -scheme Dice -destination 'platform=iOS Simulator,id=19FCE827-4EF4-4186-BE7F-712D5BD3D929' -only-testing:DiceUITests -derivedDataPath /tmp/DiceDerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`

## Results
- Unit tests: pass (44/44)
- iPhone UI tests: pass (3/3)
- iPad UI tests: pass (3/3)

## Manual Regression Sign-Off
- Primary roll flows verified on iPhone and iPad simulators.
- Preset + reroll, history/reset, and animation toggle flows verified.
- watchOS and Catalyst parity covered by unit and QA matrix artifacts.
- No open P0/P1 defects in bug-bash logs.

## Outcome
- RC accepted for v1 simulator-scope release readiness.
