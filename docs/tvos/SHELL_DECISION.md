# tvOS Root Shell Decision Record (v1)

Date: 2026-03-24
Target: tvOS 18+ (simulator-first validation)

## Context

The tvOS information architecture is fixed to four top-level destinations:

1. `Roll`
2. `Presets`
3. `History`
4. `Settings`

The remaining question is how those destinations should be surfaced in a 10-foot, focus-driven interface.

Two obvious options exist:

- `UITabBarController` with a top tab bar
- a custom focus-first shell built around the board, persistent action rail, and destination transitions

## Decision

Use a custom focus-first shell for tvOS.

Do not use `UITabBarController` as the primary root shell.

## Why

### 1. The board is the product surface

Dice is not a content-library app where each destination deserves equal constant visual weight. On tvOS, the playable board needs to remain the center of gravity.

A tab bar makes the shell the primary visual object. A custom focus-first shell keeps the board primary and lets navigation stay secondary.

### 2. `Roll` needs persistent board-adjacent actions

The `Roll` destination needs a notation summary, global actions, focused-die behavior, and help affordances on the same screen as the board.

That is not a natural fit for a tab-bar-led shell. A custom shell can keep those controls visible without making them compete with a top-level tab strip.

### 3. The other destinations are utility destinations

`Presets`, `History`, and `Settings` are important, but they are subordinate to rolling dice. They should be easy to reach, but they do not need the same constant chrome priority as the board.

A custom shell can present them as explicit global destinations without permanently dedicating screen real estate to a tab scaffold.

### 4. Focus behavior needs to be tightly controlled

The app still needs explicit focus maps between:

- global actions
- destination entry points
- the board
- subordinate overlays

A custom shell gives direct control over focus entry, exit, and return behavior. That is the right tradeoff for a board-centric app where focus behavior is part of the UX, not just a framework default.

### 5. It matches the current reusable render path better

The current tvOS work already reuses the shared board renderer and layers tvOS controls on top. A custom shell continues that architecture cleanly:

- shared renderer and domain logic stay canonical
- tvOS shell owns only focus, chrome, and destination transitions

## What This Means

### Roll

`Roll` remains the default root destination and continues using the board-first shell.

### Presets, History, and Settings

These become shell-level destinations entered from the custom chrome rather than tabs.

Each destination still has a clear current-location state and a reliable return path back to `Roll`.

### Destination visibility

The shell must still expose all four destinations clearly enough for sofa-distance use. Choosing a custom shell does not permit hidden or gesture-only navigation.

## Why Not `UITabBarController`

A tab bar is rejected because:

- it gives equal permanent weight to secondary destinations
- it competes visually with the board and board controls
- it provides less control over board-specific focus choreography
- it encourages app-shell patterns that fit browsing apps better than a live board surface

## Consequences

### Positive

- The board stays primary.
- Focus behavior can be designed intentionally.
- The shell aligns with the existing shared-renderer architecture.
- Later board, presets, and history work can share one consistent shell model.

### Negative

- More shell behavior must be implemented manually.
- Focus restoration and destination highlighting must be designed explicitly instead of inherited from a tab controller.

## Acceptance Implications

This decision is complete when future tvOS work assumes all of the following:

1. The root shell is custom and focus-first.
2. `UITabBarController` is not introduced as the primary navigation shell.
3. The shell keeps the board primary while still exposing all four destinations visibly.
4. Focus maps and destination transitions are defined against this custom shell model.
