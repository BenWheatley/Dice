# watchOS Architecture Compatibility (v1)

Target baseline: watchOS 10.2+.

## Current Delivery Model

- Existing project uses a WatchKit App (`watchapp2`) + WatchKit Extension (`watchkit2-extension`).
- This model remains supported on watchOS 10.2+ and can be tested fully in Simulator.
- The extension uses storyboard-based interface flow, which is acceptable for v1 scope.

## v1 Decision

- Keep the existing WatchKit App + Extension target structure for v1.
- Refactor watch roll behavior to the shared dice engine (`RollConfiguration`, `DiceRollSession`) to maintain behavior parity with iOS.
- Avoid provisioning-dependent features (push, connectivity-dependent entitlement work) in v1 validation.

## Test Approach

- Simulator-only validation on a watchOS 10.2+ simulator runtime.
- Unit tests cover watch state transitions and mode switching in shared test target.
