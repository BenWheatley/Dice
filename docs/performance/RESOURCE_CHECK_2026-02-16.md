# Battery and Resource Check (2026-02-16)

## Scope
- iOS simulator: iPhone 16 (iOS 18.6)
- watchOS simulator: Apple Watch Series 5 40mm (watchOS 10.2)
- Requirement constraint: simulator-only validation (no Apple Developer Team provisioning)

## Trace Runs
- iOS trace: `/tmp/Dice-iOS-time.trace` with `Time Profiler`, 12s window
- watchOS trace: `/tmp/Dice-watch-time.trace` with `Time Profiler`, 12s window
- Attempted `Activity Monitor` template on iOS simulator, but simulator does not expose this service (`Activity monitoring service not available on this device`)

## Observations
- iOS `time-profile` sample rows exported: 429
- watchOS `time-profile` sample rows exported: 247
- `potential-hangs` rows for iOS: 0
- `potential-hangs` rows for watchOS: 0
- iOS call stacks include app symbols in the rendering path (`DiceCubeView`) and controller setup, with no hang markers during sampled interaction.

## Quick Fixes Applied
- SceneKit rendering now pauses when app resigns active and resumes on foreground via lifecycle observers in `DiceCubeView`.
- This reduces unnecessary render activity while backgrounded/inactive.

## Notes
- Because v1 is simulator-only, this pass focuses on relative hot-path and hang-risk checks rather than absolute battery draw.
- Device-level energy profiling is deferred to post-v1 when on-device validation is possible.
