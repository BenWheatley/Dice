# Startup Performance Budget

## Budget
- Cold launch to notation input visible (`notationField` exists): **<= 6.0 seconds** on CI iPhone simulator.

## Automated Check
- Enforced by UI test: `DiceUITests.testStartupLaunchWithinBudget`.
- The test records launch start time, launches the app, waits for `notationField`, and fails when elapsed time is above budget.

## CI Alerting
- `xcodebuild test` in `.github/workflows/ci.yml` already runs `DiceUITests`.
- Any budget regression causes a failing CI run, which is the release-gating alert.

## Triage Steps on Failure
1. Confirm reproducibility by re-running the single test locally.
2. Check recent changes that affect app startup path (`AppDelegate`, scene setup, initial roll/render path).
3. Capture Instruments Time Profiler sample for launch and record top offenders.
4. Add/adjust focused tests to prevent the same regression pattern.
