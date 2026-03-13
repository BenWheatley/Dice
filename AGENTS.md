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
9. Keep deterministic animation seed/replay controls out of end-user UI:
   - do not add seed/replay options to production menus or settings
   - if seed-based behavior is needed for debugging, keep it test-only or internal developer tooling
10. Honor explicitly requested implementation technologies:
   - when the user specifies a concrete technology (for example, "switch to shaders"), implement using that technology
   - do not substitute an alternative approach that seems similar without first getting explicit user approval
11. Enforce clear separation of concerns:
   - each file should have a single, focused responsibility
   - avoid mixing unrelated UI, domain logic, rendering, persistence, and utility concerns in the same file
   - when new work crosses concerns, split types/helpers into appropriately scoped files
12. Do not require non-standard local tooling:
   - do not assume user machines have optional CLI tools installed
   - when suggesting or requiring commands, prefer broadly available defaults or provide a fallback
13. Avoid quick workarounds when first-class platform paths exist:
   - do not ship temporary or shortcut implementations when a standard platform-native approach is available
   - if a temporary approach is ever proposed for unblock reasons, get explicit user approval first and record follow-up work
14. Prioritize strong engineering quality and low technical debt:
   - choose maintainable, testable designs over expedient hacks
   - keep abstractions clear and cohesive, and reduce future rework during current implementation
15. Only code that compiles and passes tests is ready to commit:
   - do not commit code with known compile errors
   - do not mark work complete unless relevant tests pass (or environment blockers are explicitly documented and resolved with the user)
16. Acceptance completion standard:
   - acceptance tests must be evaluated against realistic UX expectations and Apple Human Interface Guidelines
   - do not update task checklists to complete until UX/HIG acceptance is satisfied
17. Treat sandbox limitations as environment artifacts, not product failures:
   - if simulator/device discovery fails in sandbox (for example CoreSimulatorService invalid, missing destinations, or DerivedData/log permission errors), rerun the same `xcodebuild` command outside sandbox before concluding there is an app issue
   - if Metal toolchain/component commands disagree between sandbox and host, trust outside-sandbox `xcodebuild -showComponent` results
   - when reporting failures, explicitly label whether they are sandbox-only or reproducible outside sandbox
18. Never do per-pixel rendering work on CPU:
   - if behavior requires per-pixel work, implement it with GPU shaders
   - do not add or keep CPU loops that generate textures/pixels at runtime for production rendering paths
19. Enforce first-class shader source paths:
   - shader logic must live in dedicated `.metal` source files, not embedded Swift multiline strings
   - if `SCNMaterial.shaderModifiers` is used, the shader source must be loaded from a `.metal` file or generated from file-backed assets
20. Enforce first-class-path commit attestation:
   - every commit message must include a line `First-class path used: YES` or `First-class path used: NO`
   - `First-class path used: NO` is not allowed for production changes; block commit until implementation uses a first-class path
21. Canonical render path enforcement across platforms:
   - treat iOS rendering/material code paths as canonical unless the user explicitly approves a platform-specific divergence
   - watchOS/macOS/tvOS/visionOS rendering should reuse shared render/material utilities instead of duplicating per-platform implementations
   - if fixing a watchOS rendering issue, validate with watchOS build/tests first (do not rely on iPhone simulator runs as primary validation)
22. In this repository, run simulator `xcodebuild` commands outside sandbox first:
   - do not spend tokens on in-sandbox simulator build/test attempts as a first step
   - prefer direct outside-sandbox execution for simulator destinations (watchOS/iOS/tvOS/visionOS) and only report sandbox behavior when explicitly requested

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
