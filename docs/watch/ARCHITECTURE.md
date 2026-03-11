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

## Shared Code vs Platform Deltas (Current)

- Shared with iOS/macOS targets:
  - roll domain types: `RollConfiguration`, `RollOutcome`, `IntuitiveRollContext`, `DiceInputError`, `DicePool`
  - roll engines/parsing: `DiceRollSession`, `IntuitiveRoller`, `TrueRandomRoller`, `DiceNotationParser`
  - D6 orientation math: `D6FaceOrientation`
  - D6 beveled geometry shape: `D6BeveledCubeGeometry`
- Watch-specific (intentional):
  - face texture generation path uses SpriteKit label scenes per face in `InterfaceController`.
  - iOS `D6SceneKitRenderConfig` remains UIKit-renderer based (`UIGraphicsImageRenderer`), which is unavailable on watchOS.
- Rationale:
  - keeps domain/geometry logic shared while using a watch-compatible material path.
  - avoids parallel domain implementations and reduces drift between watch and iOS behavior.
