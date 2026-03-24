# tvOS Focus Map (v1)

Date: 2026-03-24
Target: tvOS 18+ (simulator-first validation)

## Purpose

This record defines the focus contract for each top-level tvOS destination:

1. initial focus target
2. directional neighbors
3. overlay entry/exit behavior
4. focus restoration rules

This is the navigation spec that future tvOS implementation work must follow.

## Global Rules

### Focus zones

The tvOS shell uses three focus-zone types:

1. destination rail
2. content surface
3. transient overlay

The shell must always know which zone currently owns focus.

### Destination rail

The global destination rail contains five focusable actions in this fixed order:

1. `Roll`
2. `Presets`
3. `History`
4. `Settings`
5. `Help`

`Help` is utility chrome, not a top-level destination. It is still part of the rail because it must remain discoverable.

### Root-shell fallback

When a destination cannot restore its previous focus target, fall back in this order:

1. current destination button in the destination rail
2. primary focus target for that destination
3. `Roll`

### Overlay rule

When any transient overlay dismisses, restore focus to the control that opened it if that control still exists and is visible. Otherwise restore using the root-shell fallback rule.

### Board rule

Dice are focusable only inside `Roll`.

The board never traps focus. `Down` from the board must always return to the destination rail.

## Roll

### Screen zones

`Roll` has two focusable zones:

1. destination rail
2. dice board

The notation summary is informational only and is not focusable.

### Initial focus

Use the following order:

1. last-focused die, if it still exists and is fully visible
2. `Roll` button in the destination rail
3. board die nearest the visual center

On first launch, focus starts on `Roll`.

After dismissing first-launch help, focus returns to `Roll`.

### Destination rail neighbors

| Focused item | Left | Right | Up | Down |
| --- | --- | --- | --- | --- |
| `Roll` | none | `Presets` | board die nearest horizontal center | none |
| `Presets` | `Roll` | `History` | board die nearest the presets column | none |
| `History` | `Presets` | `Settings` | board die nearest the history column | none |
| `Settings` | `History` | `Help` | board die nearest the settings column | none |
| `Help` | `Settings` | none | board die nearest the help column | none |

If no die exists in the matching column, `Up` lands on the nearest visible die to screen center.

### Board neighbors

The board uses visual-grid adjacency, not collection-order adjacency.

Rules:

1. `Left` moves to the nearest die whose center is left of the current die and overlaps most strongly in vertical position.
2. `Right` mirrors the `Left` rule.
3. `Up` moves to the nearest die above using the same overlap-first heuristic.
4. `Down` moves to the nearest die below using the same heuristic.
5. If no die exists in the requested direction, focus returns to the destination rail action whose column is closest to the current die.
6. If the board has exactly one die, all lateral movement leaves focus unchanged and `Down` returns to `Roll`.

### Primary actions

1. `Select` on a die rerolls that die.
2. `Play/Pause` on a die opens the die-options overlay.
3. `Select` on `Roll` rerolls all unlocked dice.
4. `Select` on `Presets`, `History`, or `Settings` enters that destination.
5. `Select` on `Help` opens the help overlay.

### Roll overlays and return focus

#### Help overlay

- initial focus: close action
- dismiss return: control that opened help
- `Menu/Back`: dismiss

#### Die options overlay

The die-options overlay is a vertical action list.

Order:

1. `Roll This Die`
2. `Lock` or `Unlock`
3. `Color`
4. `Remove`
5. `Close`

Rules:

- initial focus: first action
- `Menu/Back`: dismiss
- dismiss return: originating die
- if the die was removed, dismiss return: nearest surviving die
- if no dice remain, dismiss return: `Roll`

## Presets

### Screen zones

`Presets` has two zones:

1. destination rail
2. presets list

The add/create action lives in the navigation/header area of the presets content zone, not in the global destination rail.

### Initial focus

Use the following order:

1. last-focused preset row, if it still exists
2. currently applied preset row, if visible
3. first visible preset row
4. `Presets` in the destination rail

### Presets list neighbors

| Focused item | Left | Right | Up | Down |
| --- | --- | --- | --- | --- |
| preset row | destination rail `Presets` | none | previous preset row | next preset row |
| add/create row | destination rail `Presets` | none | none or header control above | first preset row |

If the list is empty, focus starts on the add/create row.

### Primary actions

1. `Select` on a preset applies it and returns to `Roll`.
2. `Select` on add/create opens preset creation.
3. `Menu/Back` returns to the previous top-level destination, normally `Roll`.

### Overlay return behavior

#### Apply preset

After applying a preset:

1. dismiss `Presets`
2. switch to `Roll`
3. focus `Roll`

The first activation after applying a preset should make it obvious that the next press will roll the new board.

#### Create/edit preset overlay

- initial focus: title field if text entry is shown, otherwise first actionable row
- dismiss return: add/create row or edited preset row
- successful save return: saved preset row
- `Menu/Back`: dismiss without leaving `Presets`

## History

### Screen zones

`History` has three zones:

1. destination rail
2. filter strip
3. history content list/chart

The filter strip is horizontal and contains only a small number of coarse controls, for example:

1. `All`
2. `Current Dice`
3. `Intuitive`
4. `Random`

### Initial focus

Use the following order:

1. last-focused history row or chart element, if it still exists
2. first filter chip
3. first history row
4. `History` in the destination rail

### History neighbors

#### Filter strip

| Focused item | Left | Right | Up | Down |
| --- | --- | --- | --- | --- |
| filter chip | previous chip | next chip | destination rail `History` | first history row or chart |

#### History content

| Focused item | Left | Right | Up | Down |
| --- | --- | --- | --- | --- |
| history row | none | none | previous history row or filter chip | next history row |
| chart bar/bin | previous bin | next bin | filter chip nearest x-position | none or next row below |

### Primary actions

1. `Select` on a history row opens the detail overlay.
2. `Select` on a chart bin filters/highlights matching entries in place.
3. `Menu/Back` returns to the previous top-level destination, normally `Roll`.

### Overlay return behavior

#### History detail overlay

- initial focus: close action
- dismiss return: originating row or chart bin
- `Menu/Back`: dismiss

## Settings

### Screen zones

`Settings` has two zones:

1. destination rail
2. grouped settings list

The settings list uses grouped sections with persistent selection state. Selecting an option updates the setting and keeps the screen open.

### Initial focus

Use the following order:

1. last-focused settings row, if it still exists
2. first selected row in the first visible section
3. first row in the first section
4. `Settings` in the destination rail

### Settings neighbors

| Focused item | Left | Right | Up | Down |
| --- | --- | --- | --- | --- |
| settings row | destination rail `Settings` | none | previous row or previous section's last row | next row or next section's first row |
| close button | destination rail `Settings` | none | none | first row in first section |

### Primary actions

1. `Select` on a mode/background/theme row updates the setting and remains on that row.
2. `Select` on `Close` dismisses the settings overlay.
3. `Menu/Back` dismisses the settings overlay.

### Overlay return behavior

Settings is itself a top-level destination, not a transient sheet.

When leaving `Settings` for another destination and later returning:

1. restore the last-focused settings row if possible
2. otherwise focus the first selected row in the first visible section

## Destination-to-Destination Transitions

### From destination rail

1. `Select` on a destination changes the current destination immediately.
2. Focus lands on that destination's initial focus target, not merely on the destination button again.
3. `Menu/Back` from a top-level destination never exits the app directly if a transient overlay is open; it dismisses the overlay first.

### From content surfaces

1. `Left` from list-based destinations returns to the owning destination button.
2. `Down` from the `Roll` board returns to the closest destination button.
3. `Up` from a destination content surface returns to local header/filter controls first, then to the destination button only when no local control exists.

## Acceptance Implications

This focus map is complete when future tvOS implementation follows all of the following:

1. Every top-level destination has an explicit initial focus target.
2. Directional movement is defined by screen geometry, not incidental view order.
3. Overlay dismissal restores focus to the invoking control whenever possible.
4. `Roll` remains board-first without allowing the board to trap focus.
5. `Settings` selection updates do not dismiss the screen.
6. Applying a preset returns to `Roll` with a predictable focused control.
