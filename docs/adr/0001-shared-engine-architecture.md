# ADR 0001: Shared Dice Engine + Platform UI Layers

- Status: Accepted
- Date: 2026-02-16

## Context

The current codebase mixes domain logic (notation parsing, roll algorithms, session totals) into iOS UI code, with watch logic duplicated and minimal tests. v1 requires behavior parity across iOS/iPadOS, watchOS, and Mac Catalyst, plus multi-window state isolation on macOS.

## Decision

Adopt a layered architecture:

1. Shared domain engine module:
   - notation parser/validation
   - true-random roller
   - existing intuitive roller behavior
   - roll session/statistics model
   - roll history model and export formatter
2. Platform presentation layer per target:
   - iOS/iPadOS UIKit controllers/view-models
   - watchOS interface controller/view-model
   - Catalyst windows/scenes using iOS UI shell
3. Persistence adapters in app layer:
   - user defaults-backed preferences/presets/history metadata where needed
4. Scene/window state boundary:
   - each active window owns an independent app state instance

## Rationale

- Maximizes code reuse for core behavior across targets.
- Enables reliable TDD with deterministic domain tests.
- Reduces regression risk when implementing Catalyst multi-window.
- Keeps platform-specific interaction details isolated.

## Consequences

### Positive

- Faster parity delivery across platforms.
- Cleaner test boundaries.
- Easier long-term maintenance and feature expansion.

### Negative

- Requires up-front refactor of existing view-controller-centric logic.
- Introduces additional module boundaries and mapping code.

## Implementation Notes

- Keep intuitive algorithm behavior equivalent to current iOS implementation.
- Enforce notation bounds in shared parser: `1...30` dice and `2...100` sides.
- Avoid cloud/provisioning dependencies for v1 to preserve simulator-only validation.

