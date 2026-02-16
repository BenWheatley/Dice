# CI Skeleton

Date: 2026-02-16

The workflow in `.github/workflows/ci.yml` provides an initial CI baseline with:

- iOS simulator tests for `Dice` scheme
- watchOS simulator build for `Dice WatchKit App` scheme
- Mac Catalyst build check for `Dice` scheme

Notes:

- This is a skeleton and may fail until downstream checklist items are complete (notably Catalyst setup and test coverage expansion).
- Simulator-only validation is preserved (no provisioning-dependent steps).

