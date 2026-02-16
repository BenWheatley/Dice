# Agent Workflow Requirements (Project-Wide)

These rules apply to all agents working in this repository.

## Execution Rules

1. Work from `DEVELOPMENT_PLAN.md` in checklist order unless the user reprioritizes.
2. Each completed checklist item must be immediately:
   - checked off in `DEVELOPMENT_PLAN.md`
   - committed as a separate git commit
3. Use TDD for implementation tasks:
   - write or update failing test(s) first
   - implement code to pass tests
   - refactor while keeping tests green
4. Keep code clean and maintainable:
   - small focused functions and types
   - clear naming
   - minimal duplication
5. Document architecture and non-obvious logic:
   - maintain architecture documentation
   - add concise comments only where behavior is not obvious
6. When requirements are unclear or blocked, ask the user targeted questions before proceeding.
7. Ignore user-specific Xcode scheme metadata churn and do not interrupt progress for it:
   - treat `Dice.xcodeproj/xcuserdata/**` as local environment noise unless the user explicitly asks to modify it
   - never include `xcschememanagement.plist` updates in feature commits unless requested
8. Avoid triggering simulator runtime downloads during routine testing:
   - prefer explicit installed runtimes in `xcodebuild -destination` (for example `platform=iOS Simulator,OS=18.6,name=iPhone 16`)
   - avoid `OS=latest` unless intentionally validating against the newest installed runtime

## Platform/Feature Scope

1. Target platforms: iOS/iPadOS 18+, watchOS 10.2+, macOS 15.7+.
2. Preserve and support both rolling modes:
   - true-random mode
   - intuitive mode
3. v1 delivery constraint: simulator-only testing and validation; avoid features requiring Apple Developer Team provisioning.
4. Do not remove existing working functionality unless explicitly requested.

## Quality Gate Per Commit

Before each commit, agents should run the narrowest relevant automated tests and confirm they pass.
If full test runs are not possible, document what was run and what remains.
