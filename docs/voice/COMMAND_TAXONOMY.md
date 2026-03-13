# Voice Command Taxonomy and App Intent Mapping

Date: 2026-03-13  
Scope: iOS/iPadOS/macOS/watchOS shared command semantics

## Purpose

Define the canonical user voice command set and map each command to a single App Intent action so Siri/Shortcuts behavior is deterministic and consistent with in-app interactions.

## Canonical Commands

| User command intent | App Intent action (type name) | Required parameters | Optional parameters | State effect | Watch behavior notes |
| --- | --- | --- | --- | --- | --- |
| Roll now | `RollDiceIntent` | none | `notation`, `mode` override | Executes a roll using current config or provided override; updates last result, stats, history, telemetry | Uses same single-die/watch config defaults when notation is not provided |
| Repeat last roll | `RepeatLastRollIntent` | none | none | Re-executes last roll configuration; updates last result, stats, history, telemetry | If no previous roll exists, intent returns a recoverable "no prior roll" result |
| Set notation | `SetDiceNotationIntent` | `notation` | none | Validates and stores active notation; does not auto-roll unless explicitly requested by caller | On watch, applies to single-die-compatible state when representable; otherwise keeps phone state authoritative |
| Set mode | `SetRollModeIntent` | `mode` (`trueRandom` or `intuitive`) | none | Updates roll mode for subsequent rolls and persists preference | Mode token on watch (`TR`/`INT`) must update immediately |
| Lock die | `SetDieLockIntent` | `dieIndex`, `locked=true` | none | Marks one die as held for subsequent rerolls | Unsupported in watch single-die context; returns unsupported-operation dialog |
| Unlock die | `SetDieLockIntent` | `dieIndex`, `locked=false` | none | Clears held state for a die | Unsupported in watch single-die context; returns unsupported-operation dialog |
| Show stats | `ShowRollStatsIntent` | none | `scope` (`session`/`recent`) | Opens or foregrounds the roll-distribution sheet/view in app context | On watch, opens stats-focused summary presentation instead of phone sheet detents |
| Apply preset | `ApplyPresetIntent` | `preset` entity | none | Loads preset notation/config and persists as active configuration | Uses same preset resolver as phone; unavailable preset returns disambiguation/failure result |

## Command Disambiguation Rules

1. `RollDiceIntent` with `notation` present must validate notation with `DiceNotationParser` before mutation.
2. If user phrase implies both set + execute ("roll 3d20+1d6"), resolve to `RollDiceIntent` with notation override, not separate set + roll.
3. `SetDiceNotationIntent` is mutation-only; no implicit roll side effects.
4. `SetDieLockIntent` requires `dieIndex` bounds validation against current dice count.
5. Any command needing unavailable UI context (for example stats presentation from background) must request foreground continuation.

## Shared Execution Contract

- Intent handlers must call the same service stack used by UI interactions:
  - parser: `DiceNotationParser`
  - roll/session: `DiceRollSession`
  - orchestration: `DiceViewModel`/shared app-state services
  - persistence: `DicePreferencesStore`, `DiceRollHistoryStore`
- Intent results must return both:
  - concise spoken/dialog text
  - machine-usable structured values (sum, notation, mode, values) for Shortcuts chaining

## Stability Notes

- Intent type names above are the canonical contract for upcoming implementation tasks in section 17.
- If naming must change during implementation, update this file and all shortcut phrase registrations in the same commit.
