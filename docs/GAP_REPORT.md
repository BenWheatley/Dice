# Dice v1 Gap Report

Date: 2026-02-16
Scope baseline: iOS/iPadOS 18+, watchOS 10.2+, macOS 15.7+ (Catalyst), true-random + existing intuitive mode, notation cap 30d100, roll history/export included, simulator-only testability.

## Evidence Snapshot

- Targets/schemes currently in project:
  - `Dice`
  - `DiceTests`
  - `DiceUITests`
  - `Dice WatchKit App`
  - `Dice WatchKit Extension`
- Deployment settings observed:
  - iOS app/tests: `IPHONEOS_DEPLOYMENT_TARGET = 18.6`
  - watch app/extension: `WATCHOS_DEPLOYMENT_TARGET = 10.2`
- No explicit Catalyst configuration or multi-scene configuration found.
- Current tests are template placeholders only (unit and UI).

## Requirement Coverage

### Platform Targets

- iOS/iPadOS 18+: `partial`
  - Meets minimum deployment target.
  - Still storyboard/legacy app lifecycle and lacks acceptance criteria verification.
- watchOS 10.2+: `partial`
  - Meets deployment target.
  - Feature parity is far below v1 target scope.
- macOS 15.7+ via Catalyst: `missing`
  - No Catalyst setup found.
  - No multi-window scene model.

### Core Functional Features

- True-random mode: `present`
  - Implemented in iOS and watch paths (basic random draw).
- Existing intuitive mode: `present (iOS only)`
  - Present in iOS path; not exposed in watch.
- Notation cap 30d100: `missing`
  - Current parser accepts `1...500` dice and `2...1000` sides.
- Roll history: `missing`
  - No history model/UI found.
- Export roll history: `missing`
  - No export path found.
- Multi-window independent dice sets (Catalyst): `missing`
  - No `UIScene`/window session state separation found.

### Engineering Quality

- TDD/unit test coverage: `missing`
  - Test targets still default template tests.
- UI test coverage for primary flows: `missing`
  - No real assertions/flows implemented.
- Shared domain module: `missing`
  - Roll logic and parsing are embedded in view controller.
- CI/lint/static analysis baseline: `missing`
  - No CI or lint config found in repo.
- Architecture documentation: `missing`
  - No ADR/architecture overview yet.

## Highest-Risk Gaps (Order to Address)

1. Extract and test shared roll engine + parser with v1 bounds (`30d100`).
2. Add real unit tests/UI tests to establish a regression safety net.
3. Introduce scene-based app lifecycle to enable Catalyst multi-window isolation.
4. Add roll history model + persistence + export surfaces.
5. Build watch/mac parity on top of shared engine.

## Immediate Next Work Units

1. Confirm written v1 acceptance criteria across platforms.
2. Produce architecture ADR for shared engine and platform UI shells.
3. Document simulator-only validation matrix and constraints.

