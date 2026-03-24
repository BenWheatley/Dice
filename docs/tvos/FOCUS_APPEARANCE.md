# tvOS Focus Appearance and Contrast Spec (v1)

Date: 2026-03-24
Target: tvOS 18+ (simulator-first validation)

## Purpose

This record defines how focus should look and sound on tvOS for:

1. dice on the board
2. destination/action buttons
3. list rows and cards
4. overlays

It also fixes minimum contrast and readability thresholds so future implementation can be judged against explicit acceptance criteria instead of taste.

## Global Focus Principles

1. Focus must be visible from sofa distance without requiring motion to notice it.
2. Focus must not rely on color alone.
3. Focus must not make neighboring targets unreadable.
4. Focus treatment must be stable across `neutral`, `felt`, `wood`, and `black` backgrounds.
5. Sound should confirm focus movement, not compete with roll audio.

## Contrast Thresholds

### Text

1. Primary actionable text: target `7:1`, minimum `4.5:1` against its immediate surface.
2. Secondary supporting text: target `4.5:1`, minimum `3:1` only when the text qualifies as large text.
3. Focused text must never lose contrast relative to the unfocused state.

### Non-text focus indicators

1. Focus outlines, glows, and rings must achieve at least `3:1` contrast against the pixels directly behind them.
2. If a glow cannot maintain `3:1` on a bright or patterned background, add or switch to an outline ring.
3. Selected state and focused state must remain distinguishable when both are present.

### Readability

1. Minimum primary action height: `80pt`.
2. Minimum list row height: `88pt`.
3. Minimum interactive horizontal gap between large controls: `24pt`.
4. Avoid more than five peer actions in one row without grouping or paging.

## Focus Treatment by Element Type

## Dice on the Board

### Base behavior

Focused dice are the most visually sensitive case because the board is dense and patterned.

Use this stack, in order:

1. moderate scale
2. lift shadow
3. adaptive outline ring
4. restrained parallax

### Dice focus spec

1. Scale: `1.08x`
2. Z-lift visual impression: subtle only; do not physically move the die enough to break board composition.
3. Shadow opacity increase: from board default to approximately `0.45`
4. Shadow blur radius: approximately `28pt`
5. Shadow vertical offset: approximately `16pt`
6. Parallax: low-to-medium
7. Outline ring width: `4pt`

### Adaptive outline ring

The outline ring is required for dice because patterned materials and patterned backgrounds make glow-only focus unreliable.

Rules:

1. On dark or saturated dice, use a light outer ring.
2. On light dice, use a dark outer ring.
3. On mixed or marble surfaces, choose the ring color from sampled luminance at the die edge, not the die's nominal theme alone.
4. The ring must sit outside the die silhouette and must not cover numerals or pips.

### What not to do

1. Do not use a large bloom that obscures adjacent dice.
2. Do not scale above `1.10x`; it creates collisions on dense boards.
3. Do not rely on parallax alone.
4. Do not dim the rest of the board so aggressively that non-focused dice become illegible.

## Destination Rail Actions

These are the primary global controls and need the strongest chrome consistency.

### Action focus spec

1. Scale: `1.06x`
2. Corner radius remains stable; do not animate shape changes.
3. Background brightening or darkening delta: about `12%` from unfocused state.
4. Shadow blur radius: `20pt`
5. Shadow opacity: about `0.35`
6. Parallax: medium
7. Label weight shift: regular to semibold if needed, but never enough to reflow layout.

### Focus indicator

Use both:

1. surface change
2. outer focus halo or outline

The rail must remain readable on every table background. If the control surface already sits on a dark glass plate, the focus halo can be restrained, but the surface contrast change must still be clear.

## List Rows and Cards

This includes presets, history rows, settings rows, and future token-composer cards.

### Row/card focus spec

1. Scale: `1.03x` to `1.05x`
2. Shadow blur radius: `18pt`
3. Shadow opacity: about `0.30`
4. Parallax: medium
5. Background delta: about `10%` lighter or darker than the unfocused card, depending on theme
6. Trailing checkmark or accessory must remain visible in both focused and unfocused states

### Selection within rows

If a row is both selected and focused:

1. keep the persistent selection mark visible
2. add focus halo around the full row
3. do not replace the selection mark with focus styling

## Overlays and Dialogs

Overlays must separate strongly from the active board.

### Overlay surface spec

1. Use a darker scrim behind the overlay, but keep the board faintly visible for spatial continuity.
2. Overlay chrome must meet the same text thresholds as destination rail actions.
3. Initial focus must be visually obvious without requiring the user to nudge the remote first.

### Overlay focus spec

1. First focused control appears with the same action/card focus styling used elsewhere.
2. The overlay container itself does not pulse or animate repeatedly.
3. Error states add a second, independent accent treatment and must not replace focus styling.

## Focus Sound

1. Use standard tvOS focus sound behavior as the baseline.
2. Do not add a custom sound to every focus move.
3. Add custom audio only to committed actions such as roll, apply preset, or save, not navigation.
4. Focus movement should remain quiet enough that repeated lateral browsing does not become fatiguing.

## Background Interaction Rules

Focus treatment must remain legible on every background mode.

### Neutral

Because `neutral` is bright and striped, glow-only focus is insufficient. Prefer adaptive outline plus shadow.

### Felt

Because felt has visible fine noise, focus rings should be solid and not texture-matched.

### Wood

Because wood includes grain and possible knots, avoid relying on brown/gold-only halos. Use luminance-adaptive outlines.

### Black

On true black, reduce halo radius slightly so focus does not look blurry. The outline still needs to exist, but the shadow can be reduced because separation already exists.

## Acceptance Thresholds

This item is complete when future tvOS implementation satisfies all of the following:

1. A focused die is identifiable within `250ms` without moving it.
2. Focus remains visible on light dice over `neutral` and `wood` backgrounds.
3. Focus remains visible on dark dice over `black` and `felt` backgrounds.
4. Focus never relies on color alone.
5. Simultaneous selected-plus-focused rows remain visually distinct from focused-only rows.
6. Rail buttons, settings rows, and preset rows remain readable at sofa distance without truncating to ambiguity.
7. Navigation audio uses native focus feedback rather than custom repeated sounds.

## Implementation Implications

When this is implemented, the code should centralize tvOS focus styling so the same appearance rules apply across:

1. destination rail buttons
2. settings rows
3. presets/history rows
4. future die-option overlays

The dice renderer remains shared. Only the tvOS shell should own focus chrome and focus-aided board highlighting.
