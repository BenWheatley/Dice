# Local Development Commands

Date: 2026-02-16

Use `make` targets for consistent local checks:

- `make list`
  - List targets/schemes in `Dice.xcodeproj`.
- `make test-ios`
  - Run `Dice` scheme tests on iOS simulator.
- `make build-watch`
  - Build watch scheme on watch simulator.
- `make build-catalyst`
  - Build Dice scheme for Mac Catalyst.
- `make analyze-ios`
  - Run Xcode static analyzer for iOS scheme.
- `make lint`
  - Run SwiftLint strict mode (`.swiftlint.yml` baseline).
- `make format-check`
  - Run `swift-format` lint checks.

Tooling notes:

- `swiftlint` and `swift-format` are optional external tools and must be installed locally.
- v1 validation is simulator-only by project policy.

