# Simulator-Only Test Matrix (v1)

Date: 2026-02-16

## Constraint

v1 must be verifiable without joining an Apple Developer Team or enabling provisioning-dependent capabilities.

## Allowed Validation Environment

- Local Xcode simulator and local test execution only.
- No required signing/capability setup beyond defaults needed for simulator builds.

## Platform Matrix

- iOS/iPadOS:
  - iPhone simulator on iOS 18+
  - iPad simulator on iPadOS 18+
- watchOS:
  - Apple Watch simulator on watchOS 10.2+
- macOS:
  - Mac Catalyst app run/tests on macOS 15.7+

## Capability Rules for v1

Do not introduce capabilities that require team provisioning to test:

- iCloud/CloudKit
- Push Notifications/APNs
- Associated Domains
- App Groups required for core behavior validation
- Any entitlement requiring paid-team setup to run simulator tests

## Required Local Checks Per Work Unit

1. Run the narrowest relevant tests locally for changed code.
2. If simulator execution is blocked by environment limits, record that explicitly in commit notes or follow-up docs.
3. Keep tests deterministic where possible (inject RNG/test seams for domain tests).

