# Crash and Telemetry Triage Dashboard

## Purpose
Use this dashboard to aggregate simulator-visible crash and telemetry signals during release candidate validation, then drive an explicit triage workflow.

## Sources
- App telemetry (`DiceTelemetry` OSLog category `telemetry`):
  - `roll mode=... notation=... sum=... dice=...`
  - `invalid_input input=... reason=...`
  - `stats_reset`
- Crash and termination signals from Xcode test results and simulator diagnostics:
  - `xcodebuild test` output + `.xcresult`
  - Simulator crash reports in `~/Library/Logs/DiagnosticReports`

## Collection Commands
1. Capture latest telemetry lines for the app bundle:
```sh
xcrun simctl spawn booted log show --style compact --last 30m --predicate 'subsystem == "com.kitsunesoftware.Dice"'
```
2. Capture only invalid-input telemetry:
```sh
xcrun simctl spawn booted log show --style compact --last 30m --predicate 'subsystem == "com.kitsunesoftware.Dice" AND eventMessage CONTAINS "invalid_input"'
```
3. Export most recent test run summary:
```sh
xcrun xcresulttool get --format json --path <path-to.xcresult>
```

## Dashboard Table
Update this table for each RC cycle.

| Signal | Last 24h Count | Last 7d Count | Threshold | Status | Owner | Notes |
|---|---:|---:|---|---|---|---|
| Crash (uncaught/abort) | 0 | 0 | 0 in RC | Green | iOS owner | |
| UI test launch crash | 0 | 0 | 0 in RC | Green | QA owner | |
| `invalid_input` rate | 0 | 0 | Investigate >2% of interactions | Green | UX + parser owner | |
| Roll telemetry gaps | 0 | 0 | 0 missing roll events in scripted smoke run | Green | App architecture owner | |
| Stats reset anomalies | 0 | 0 | 0 unexpected resets | Green | State-management owner | |

## Triage Severity
- `P0`: crash on launch, data loss, blocked core roll flow.
- `P1`: repeated crash in secondary flow, invalid output in totals/history, major accessibility regression.
- `P2`: non-blocking telemetry inconsistency, copy mismatch, minor UI regression.

## Triage Workflow
1. Collect telemetry/crash evidence and add one row per issue in the incident log below.
2. Assign severity and owner.
3. Reproduce on simulator with deterministic steps.
4. Add/extend test coverage before fix merge.
5. Land fix, re-run full test suite, and mark incident as `Verified`.

## Incident Log Template
| ID | Date | Signal | Severity | Repro Steps | Root Cause | Fix Commit | Test Added | Status |
|---|---|---|---|---|---|---|---|---|
| RC-YYYYMMDD-01 |  |  |  |  |  |  |  | Open |

## Exit Criteria for RC Approval
- No open `P0` or `P1` incidents.
- Dashboard thresholds all `Green`.
- Full simulator test suite passed after final fixes.
