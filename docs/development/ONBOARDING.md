# Onboarding Guide

## Prerequisites
- macOS with Xcode 17+ installed.
- Simulator runtimes for iOS 18.6+ and watchOS 10.2+.
- Command line tools available (`xcodebuild`, `xcrun`).

## Clone and Open
1. Clone repository.
2. Open `Dice.xcodeproj` in Xcode.
3. Select `Dice` scheme.

## First Build
- Build once to warm caches:
  - `xcodebuild build -project Dice.xcodeproj -scheme Dice -destination 'platform=iOS Simulator,id=75445CDF-7A60-4E0C-B7CF-F80C7BE9A14E' -derivedDataPath /tmp/DiceDerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`

## Core Local Commands
- Unit tests:
  - `xcodebuild test -project Dice.xcodeproj -scheme Dice -destination 'platform=iOS Simulator,id=75445CDF-7A60-4E0C-B7CF-F80C7BE9A14E' -only-testing:DiceTests -derivedDataPath /tmp/DiceDerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
- iPhone UI tests:
  - `xcodebuild test -project Dice.xcodeproj -scheme Dice -destination 'platform=iOS Simulator,id=75445CDF-7A60-4E0C-B7CF-F80C7BE9A14E' -only-testing:DiceUITests -derivedDataPath /tmp/DiceDerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
- iPad UI tests:
  - `xcodebuild test -project Dice.xcodeproj -scheme Dice -destination 'platform=iOS Simulator,id=19FCE827-4EF4-4186-BE7F-712D5BD3D929' -only-testing:DiceUITests -derivedDataPath /tmp/DiceDerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`

## Workflow Expectations
1. Pick one unchecked item in `DEVELOPMENT_PLAN.md`.
2. Implement with TDD where behavior changes.
3. Run required checks.
4. Check off the completed item.
5. Commit one checklist item per commit.

## Troubleshooting
- Simulator first-launch is slow:
  - Initial runtime prep can take several minutes; rerun after setup completes.
- UITest flaky exit codes:
  - Rerun once; record both runs in commit notes if instability occurs.
- Stale simulator state:
  - `xcrun simctl shutdown all` then relaunch target simulator.
- Build artifacts seem stale:
  - Remove `/tmp/DiceDerivedData` and rerun build/test command.
- Code signing prompts appear unexpectedly:
  - Ensure commands include `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO` for simulator flows.
