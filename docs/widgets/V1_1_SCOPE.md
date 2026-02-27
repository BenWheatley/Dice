# Widgets and Quick Actions Scope (v1.1)

Date: 2026-02-27

## Objective

Adopt first-class Apple platform surfaces for glanceable roll state and fast entry points without introducing non-standard custom UI frameworks.

## In Scope

- Home Screen widgets (WidgetKit):
  - `.systemSmall`: last notation, last total, and mode token.
  - `.systemMedium`: last roll summary and latest 3 outcomes strip.
- Lock Screen widgets (WidgetKit accessory families):
  - `.accessoryInline`
  - `.accessoryCircular`
- SpringBoard app icon quick actions:
  - Roll Now
  - Repeat Last Roll
  - Presets
  - Roll History
- URL/deep-link routing from widgets and quick actions into app scenes.

## Out of Scope

- Live Activities / Dynamic Island.
- Cloud-synced widget data dependencies.
- Provisioning-dependent capabilities requiring Apple Developer Team setup.

## API and Framework Decisions

- Use `WidgetKit` for all widgets.
- Use `AppIntents` (`WidgetConfigurationIntent`) where parameterization is needed.
- Use app-local persisted state and deterministic snapshots for timelines.
- Use `UIApplicationShortcutItem` (static + dynamic) for SpringBoard quick actions.

## Simulator-Only Validation Constraints

- Validate on installed simulator runtimes only:
  - iOS/iPadOS 18+
  - macOS 15.7+ (Catalyst host behavior for deep-link route handling)
- No entitlement/capability that requires paid-team provisioning to test.

## Acceptance Criteria

1. Widget families render usable content and placeholder/snapshot states.
2. Tapping widget targets routes to the intended app destination.
3. Long-press quick actions invoke correct route on cold and warm starts.
4. Empty-state copy appears when there is no roll history.
5. Light and dark appearance both remain legible.
