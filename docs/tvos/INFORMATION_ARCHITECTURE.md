# tvOS Information Architecture (v1)

Date: 2026-03-24
Target: tvOS 18+ (simulator-first validation)

## Scope

This record defines the top-level information architecture for the Apple TV experience only:

- the primary destinations
- what each destination owns
- which destination launches first
- how destination restoration works when the app is reopened

This record does not decide the concrete shell widget (`UITabBarController` vs a custom focus-first shell). That is the next checklist item.

## Top-Level Destinations

The tvOS app has four top-level destinations:

1. `Roll`
2. `Presets`
3. `History`
4. `Settings`

These are the only global destinations in v1. Anything else is subordinate to one of them.

## Destination Ownership

### 1. Roll

`Roll` is the home screen and the primary task destination.

It owns:

- the dice board
- the current notation or composer summary
- global roll actions
- focused-die interactions
- first-launch help entry point

It does not own:

- preset management
- history browsing
- global settings lists

### 2. Presets

`Presets` owns saved and built-in roll setups.

It owns:

- browsing built-in presets
- browsing custom presets
- applying a preset
- creating, editing, and deleting presets
- pinning or promoting favorite presets later if needed

It does not own:

- live board interaction after the preset is applied
- roll history
- visual/system settings

Applying a preset always returns the user to `Roll`, because the result of applying a preset is a playable board, not a lingering preset-management state.

### 3. History

`History` owns past outcomes and aggregate stats.

It owns:

- recent roll history
- roll summaries
- distribution/statistics views
- future export/share actions if those remain in scope for tvOS

It does not own:

- live board editing
- preset management
- visual/system settings

### 4. Settings

`Settings` owns persistent preferences and help.

It owns:

- roll mode defaults
- table/background preferences
- theme and contrast-safe presentation settings
- lighting preferences
- accessibility-affecting toggles appropriate to tvOS
- help / remote instructions

It does not own:

- preset management
- history browsing
- direct dice board manipulation

## Launch Default

`Roll` is always the launch default on first launch.

Rationale:

- tvOS needs an immediately understandable primary action.
- The board is the product, not a library browser.
- A living-room device should open into the playable surface by default.

## State Restoration Rule

After the first launch, restore to the last-open top-level destination.

Rules:

1. If the user last left the app in `Roll`, reopen in `Roll`.
2. If the user last left the app in `Presets`, reopen in `Presets`.
3. If the user last left the app in `History`, reopen in `History`.
4. If the user last left the app in `Settings`, reopen in `Settings`.
5. If the stored destination is missing, corrupted, or unknown, fall back to `Roll`.

This restoration is top-level only. It should not attempt deep restoration into transient sub-overlays that may no longer be valid, such as:

- a die-specific options panel
- a confirmation dialog
- an add/edit preset alert
- a help alert

Those reopen at the owning destination, not inside the transient overlay.

## Navigation Expectations

The user must always be able to answer two questions from focus alone:

1. Which top-level destination am I in?
2. How do I get back to the playable board?

The IA therefore requires:

- a persistent destination model with a clearly indicated current destination
- a predictable `Menu/Back` path out of subordinate overlays
- a single hop back to `Roll` from global destinations

## Why This IA

This split matches the real user tasks on a TV:

- roll dice now
- choose a known setup
- inspect previous outcomes
- adjust persistent preferences

It avoids hiding unrelated tasks inside the board and avoids turning `Settings` or `Presets` into overloaded grab-bags.

## Consequences

### Positive

- The app gets a stable global model before detailed shell work begins.
- Future tvOS focus maps can be defined against a fixed set of destinations.
- State restoration becomes predictable and testable.

### Negative

- The shell must expose four destinations clearly enough for 10-foot navigation.
- Some iOS overlay patterns will need to become full destinations on tvOS instead of compact panels.

## Acceptance Criteria

This item is complete when the codebase and docs assume all of the following:

1. `Roll`, `Presets`, `History`, and `Settings` are the only top-level tvOS destinations.
2. `Roll` is the first-launch destination.
3. Reopening the app restores the last-open top-level destination.
4. Transient overlays are not restored directly.
