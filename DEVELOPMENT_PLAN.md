# Dice App Development Plan

This plan targets completion for iOS/iPadOS 18+, watchOS 10.2+, and macOS 15.7+, with both true-random and intuitive roll modes.
Confirmed decisions: macOS delivery via Mac Catalyst, multi-window enabled with independent dice state per window, intuitive mode behavior uses existing implementation, notation cap is 30d100, and v1 must be testable via simulators only (no Apple Developer Team-required features).
Each checklist item is scoped to about 1-2 hours of focused developer work.

## 1. Project Foundation

- [x] Audit current codebase and produce a gap report against platform/version targets and feature requirements.
- [x] Confirm product definition (MVP vs v1) and acceptance criteria for iOS/iPadOS, watchOS, and macOS.
- [x] Define architecture decision record (ADR): shared dice engine package/module + per-platform UI layers.
- [x] Document v1 testing constraint: simulator-only test matrix, no provisioning-dependent features.
- [x] Create and document branch/commit workflow: one completed checklist unit per commit, with test evidence in commit message.
- [x] Set up CI pipeline skeleton for build + unit tests for all targets.
- [x] Add lint/format/static analysis baseline and document local developer commands.

## 2. Shared Domain Engine

- [x] Extract roll configuration parsing and validation into a shared domain module.
- [x] Write unit tests first for notation parser (valid/invalid inputs, bounds, intuitive suffix behavior).
- [x] Extract true-random rolling algorithm into pure testable services with deterministic test seams.
- [x] Write unit tests first for true-random behavior (range safety, count accuracy, statistical smoke checks).
- [x] Extract intuitive rolling algorithm into pure testable services.
- [x] Write unit tests first for intuitive behavior (bias constraints, reset behavior, edge cases, mode switching).
- [x] Implement roll session/statistics domain model (local/session totals, reset logic, sums).
- [x] Write unit tests first for roll session life cycle and persistence semantics.

## 3. App State and Persistence

- [x] Introduce shared app-state model for active notation, mode, dice values, and stats.
- [x] Add persistence service for user preferences and recent presets (AppStorage/UserDefaults wrapper).
- [x] Write tests first for persistence round-trip and migration defaults.
- [x] Design roll history domain model and retention policy (per-window active history + persisted recent history).
- [x] Write tests first for roll history append, ordering, truncation, and clear behavior.
- [x] Implement roll history persistence and export formatting service (share/export text or CSV).
- [x] Define and implement error/reporting strategy for invalid input and unsupported dice configurations.
- [x] Add lightweight analytics/logging hooks for roll events and failure diagnostics.

## 4. iOS/iPadOS Experience

- [x] Refactor iOS/iPadOS UI to consume shared state + engine with clear view-model boundaries.
- [x] Add tests first for view-model behavior (roll, reroll single die, shake-to-roll, reset stats).
- [x] Add roll history UI (session view, clear action, export action) with accessibility coverage.
- [x] Implement/update adaptive layout for iPhone and iPad (size class, split view, dynamic type).
- [x] Harden input UX: notation editing, presets, validation feedback, keyboard/accessibility flow.
- [x] Improve dice board rendering integration (supported polyhedra, animation toggles, fallback behavior).
- [x] Add UI tests for primary flows (launch, roll, reroll die, preset select, intuitive toggle, reset).

## 5. watchOS Experience

- [x] Confirm watch target architecture (extension/app model) compatibility for watchOS 10.2+.
- [x] Refactor watch roll logic to shared engine APIs.
- [x] Add watch-focused unit tests for state transitions and mode handling.
- [x] Implement watch interaction polish: tap-to-roll, haptics, accessibility labels, glanceable stats.
- [x] Add watch UI test coverage for core roll and mode-switch scenarios.

## 6. macOS Experience

- [x] Define macOS app strategy (Mac Catalyst) and document decision.
- [x] Create macOS target scaffolding and integrate shared domain module.
- [x] Enable multiple Catalyst windows/scenes with isolated dice state per window.
- [x] Implement macOS primary UI flows (roll, reroll, notation input, presets, stats, mode toggle).
- [x] Add macOS roll history panel and export flow parity with iOS.
- [x] Add keyboard shortcuts and pointer interactions for macOS ergonomics.
- [x] Add macOS unit/UI tests for core behavior parity with iOS.

## 7. Cross-Platform Quality and Accessibility

- [x] Build accessibility checklist and remediate labels, traits, focus order, contrast, and dynamic type.
- [x] Add localization-ready string extraction and baseline English string catalog structure.
- [x] Run performance pass for animation/render loops and optimize hot paths.
- [x] Execute battery/resource usage checks on watchOS and iOS (profiling + quick fixes).
- [x] Perform cross-device manual QA matrix run and log defects with severity/owner.

## 8. Documentation and Developer Experience

- [x] Write architecture overview with module boundaries, data flow, and mode algorithm notes.
- [x] Add inline code comments for non-obvious logic in dice algorithms and SceneKit geometry generation.
- [x] Document testing strategy (TDD rules, test pyramid, required checks before commit).
- [x] Document release process (versioning, signing, TestFlight/internal distribution steps).
- [x] Create onboarding guide with local setup, build commands, and troubleshooting.

## 9. Release Hardening

- [x] Complete bug bash round 1 and resolve high-priority defects.
- [x] Complete bug bash round 2 focused on edge-case notation and long roll sessions.
- [x] Verify deterministic reproducibility for failing tests and stabilize flaky test cases.
- [x] Validate App Store metadata/assets checklist for iOS/iPadOS/watchOS/macOS listings.
- [x] Cut release candidate tag and run full CI + manual regression sign-off.

## 10. Product Questions (Resolve Before/While Implementing)

- [x] Confirm exact definition of "intuitive" mode behavior and acceptable bias boundaries (use existing implementation).
- [x] Confirm maximum supported dice notation ranges (max 30 dice, max 100 sides).
- [x] Confirm whether roll history/export is required for v1 (include in v1).
- [x] Confirm whether cloud sync/shared settings across iPhone, iPad, Mac, and Watch is required (deferred from v1 to avoid Apple Developer Team dependency).
- [x] Confirm visual/design direction and whether to preserve current art assets in v1 (preserve current assets for now).

## 11. Post-v1 Feature Additions (Useful Next Steps)

### Visual Themes and Texture Options

- [x] Add user-selectable color themes (Classic, Dark Slate, High Contrast) backed by app-wide style tokens.
- [x] Add selectable table/background textures (felt, wood, neutral) with performance-safe asset loading.
- [x] Add configurable die body finish presets (matte, gloss, stone) via SceneKit material parameters.
- [x] Add optional edge-outline rendering toggle to improve readability of lighter dice.
- [x] Add per-face contrast calibration so numerals/pips remain legible across theme and texture combinations.

### Dice Visual Customization

- [x] Add per-die-type color customization (d4/d6/d8/d10/d12/d20) with persisted preferences.
- [x] Add optional pip style variants for d6 (classic round, square, inset) with A/B visual tests.
- [x] Add numeral font selection for non-d6 dice faces with readability validation at small sizes.
- [x] Add a "preview current style" panel to test selected theme/material before applying globally.
- [x] Add reset-to-default controls for all visual customizations with confirmation UX.

### UX and Interaction Improvements

- [x] Add notation helper chips (d4, d6, d8, d10, d12, d20, +, i) above keyboard for faster input.
- [x] Add inline notation parser hints that explain invalid segments instead of generic invalid-format errors.
- [x] Add advanced preset manager (create, rename, reorder, delete, pin favorites).
- [x] Add "repeat last roll" action and shortcut across iOS/iPadOS/macOS/watchOS.
- [x] Add optional per-die lock feature so selected dice are held while rerolling the rest.

### Board and Animation Enhancements

- [x] Add board camera presets (top, slight tilt, dramatic angle) with animated transitions.
- [x] Add animation intensity settings (off, subtle, full) mapped to duration and bounce parameters.
- [x] Add optional motion blur/trail effect for rolling dice while maintaining 60fps target.
- [x] Add deterministic seed mode for board animation replay/debug of specific roll sequences.
  Removed in current UX scope: hidden from users and deleted from app settings/state by product decision.
- [x] Add mixed-dice spacing/layout presets to improve readability for large heterogeneous rolls.

### Audio and Haptics

- [x] Add optional dice roll sound pack v1 (soft wood, hard table) with volume slider.
- [x] Add face-up settle "tick" sound for final die stop, synchronized to animation completion.
- [x] Add separate mute toggles for SFX and haptics, persisted per platform.
- [x] Add accessibility-safe audio defaults (sound off by default when VoiceOver is active).
- [x] Add watchOS haptic variants for roll begin/end and invalid input feedback.

### Statistics and History UX

- [x] Add histogram visualization for recent roll distributions per side count.
- [x] Add streak/outlier indicators (e.g., repeated highs/lows) with explanatory tooltip text.
- [x] Add filter/search controls in history (by notation, mode, date range).
- [x] Add shareable summary card export for a roll session (image + text metadata).
- [x] Add "clear recent only" and "clear all persisted" split actions in history management.

### Accessibility and Internationalization Extensions

- [x] Add dyslexia-friendly numeral option and test face-label readability across all die types.
- [x] Add larger-face-label accessibility mode for board previews and static dice cells.
- [x] Add reduced-motion-specific board behavior profile beyond simple animation on/off.
- [x] Add VoiceOver custom rotor actions for rerolling selected die and reading per-die side count.
- [x] Add additional localization pass for validation errors and stats copy tone consistency.

### Quality, Reliability, and Tooling

- [x] Add snapshot tests for key visual themes and dice combinations on iPhone/iPad/macOS layouts.
- [x] Add SceneKit regression tests for d6 pip orientation and d4/d10 geometry correctness.
- [x] Add property-based parser tests for mixed separators and whitespace/edge formatting.
- [x] Add startup performance budget checks and automated alerting for regressions in CI.
- [x] Add crash/telemetry event aggregation dashboard document for release triage workflow.
- [x] Enforce single-responsibility split for UI support types by extracting controller-adjacent classes/helpers into dedicated Swift files and wiring target membership.
- [x] Enforce single-responsibility split for domain/support models by ensuring each remaining multi-type Swift file is decomposed into single-type files with explicit target membership.
- [x] Move Metal background shader source from inline Swift strings to dedicated `.metal` source files compiled through the default Metal library.
- [x] Tune Metal table shader scales so stripes/wood read zoomed-out correctly and felt uses lower-frequency, fabric-like noise.
- [x] Fix shader and D4 regressions: neutral background must never render black, and D4 face-vertex label winding/orientation must not mirror across faces.
- [x] Replace D4 digit derivation from raw mesh vertex indices with an explicit canonical vertex-value map, and use that map for top-face orientation.
- [x] Replace D4 2D label-placement heuristic with 3D tetrahedron-derived placement/orientation (vertex to opposite-face-center direction) so displayed digits follow physical D4 rules.
- [x] Fix D4 corner-label regressions by aligning material-refresh face ordering with tetrahedron UV corner ordering, backed by regression tests.
- [x] Fix startup dice color/render state by applying notation-based per-die color overrides and restored dice count immediately on app restore.
- [x] Keep die color changes scoped to the tapped die in per-die options (do not mutate side-count defaults for the full group).
- [x] Restrict per-die reroll animation to the selected die while keeping all non-target dice visually settled.
- [x] Implement shader-based stone die finish with procedural marble-style veining and retain finish behavior under automated material tests.
- [x] Increase wood table shader realism by warping grain boundaries with low-amplitude procedural noise instead of perfectly regular bands.

## 12. watchOS Small-Screen Interface Plan

### Constraints and Layout Model (Harsh Size Limits)

- [x] Define watch layout budget (44mm/45mm/49mm targets): max tap zones, max text length, and hierarchy depth.
- [x] Create single-screen information architecture for watch roll flow (one primary action, one secondary mode action).
- [x] Replace dense text with glanceable status tokens (notation, mode, last value) tuned for watch legibility.
- [x] Add dynamic type and accessibility size pass specific to watch small-screen clipping cases.
- [x] Add watch UI snapshot checklist for edge-case strings and long localized labels.

### SceneKit Feasibility and Reuse

- [x] Confirm watchOS SceneKit approach using `WKInterfaceSCNScene` and document API constraints vs `SCNView`.
- [x] Extract minimal shared D6 SceneKit render config (geometry/material/orientation) reusable by iOS + watchOS.
- [x] Implement watch single-die D6 SceneKit preview (one die only, no board grid) for performance safety.
- [x] Map roll result to D6 face orientation using shared orientation helper to keep iOS/watch parity.
- [x] Add fallback path to static image mode if SceneKit view is unavailable or disabled by settings.

### Performance and Interaction Safety

- [x] Add watch frame-rate/perf budget target for SceneKit D6 (steady interaction on simulator profile).
- [x] Add low-power mode behavior (reduced animation intensity and reduced SceneKit update frequency).
- [x] Add watch haptic/audio sync to final face settle event for clearer result confirmation.
- [x] Add tests for mode switching and repeated rolls with SceneKit enabled to catch state desync regressions.
- [x] Add watch-specific QA pass for crown interaction, wake/resume, and scene lifecycle handling.
