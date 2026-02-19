# Release Process

## Scope
This process covers iOS/iPadOS, watchOS companion, and Mac Catalyst release packaging.
For v1 development, simulator-only testing is required; code-signing and TestFlight are documented for release readiness.

## Versioning
1. Select semantic app version (`MARKETING_VERSION`), e.g. `1.0.0`.
2. Increment build number (`CURRENT_PROJECT_VERSION`) for every distributable build.
3. Update release notes/changelog with user-visible changes and fixed defects.

## Pre-Release Gates
1. Unit tests green (`DiceTests`).
2. UI smoke matrix green on iPhone and iPad simulators (`DiceUITests`).
3. QA matrix document updated (`docs/qa/`).
4. Accessibility, performance, and resource check docs updated when relevant.
5. `DEVELOPMENT_PLAN.md` release items complete.

## Signing and Capabilities
1. Configure team, bundle IDs, and signing identities in Xcode project settings.
2. Verify provisioning profiles for iOS app, watch app, watch extension, and Catalyst app.
3. Re-check entitlements for each target before archive.

## Build and Archive
1. Select `Dice` scheme in Release configuration.
2. Create archive for iOS App Store distribution.
3. Create archive for Mac Catalyst distribution if shipping on macOS.
4. Validate archive in Organizer and resolve warnings/errors.

## Internal Distribution / TestFlight
1. Upload archive to App Store Connect from Organizer.
2. Wait for processing and confirm build appears in App Store Connect.
3. Assign build to internal testers first.
4. Expand to external TestFlight groups after smoke validation.
5. Track tester feedback and create defects with severity and owner.

## Release Candidate Checklist
1. Tag release candidate commit (`git tag`).
2. Run full CI and final simulator regression matrix.
3. Confirm metadata/screenshots/compliance fields in App Store Connect.
4. Approve and submit for review.

## Post-Release
1. Monitor crash/telemetry signals and support channels.
2. Triage hotfixes with regression tests first.
3. Start next patch version branch after stabilization.

## Triage Dashboard
Use `docs/release/CRASH_TELEMETRY_DASHBOARD.md` as the canonical crash/telemetry aggregation and incident triage workflow for release candidates.
