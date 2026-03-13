# Voice and Siri Architecture (Current OS Stack)

## Decision

The app uses **App Intents + App Shortcuts** as the first-class Siri and voice integration path across current OS versions.

Legacy SiriKit custom intent extensions are not used for new dice features. They are only considered if a domain-specific SiriKit capability is still required and has no App Intents equivalent.

## Why This Path

- App Intents is the current Apple-first integration model for Siri, Shortcuts, and Spotlight discoverability.
- It keeps command handling in Swift-native intent types that can call shared app-domain services.
- It avoids splitting command logic across legacy and modern APIs.

## Target Architecture

### Shared Intent Execution Layer

- Intent handlers call existing shared app-domain services for:
  - notation parsing
  - roll execution (true-random and intuitive)
  - preset lookup and application
  - state persistence updates

This keeps Siri/voice behavior aligned with UI-triggered behavior.

### Platform Packaging

- iOS/iPadOS/Mac Catalyst: primary App Intents/App Shortcuts surface.
- watchOS: uses the same intent semantics and shared domain execution contracts; watch-specific invocation and handoff behavior must preserve identical command results.

## Conflict and Consistency Rules

- Voice-triggered state writes follow the existing timestamped last-write-wins policy for cross-device settings sync.
- If two writes have equal timestamps, the current remote-preferred tie-break rule remains in effect.
- This is acceptable for a single-user multi-device setup because user intent is latest-command-wins, not collaborative merge.

## Non-Goals for This Decision

- This file does not define final phrase catalogs or localized utterance strings.
- This file does not add backward-compatibility shims unless explicitly required by a remaining SiriKit-only capability.

## Related Docs

- Command-to-intent mapping: `docs/voice/COMMAND_TAXONOMY.md`
