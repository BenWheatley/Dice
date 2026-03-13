# watchOS Customization IA (v2)

Date: 2026-03-11  
Target: watchOS 10.2+ (simulator-first validation)

## Goal

Support a single visible 3D die of any side count with lightweight customization that remains usable on small watch screens.

## Information Architecture

Depth budget: one level from the main roll screen.

1. Main Roll Screen
   - 3D die preview (primary visual target).
   - Compact status token line (`mode·notation`) and value token line (`v#`).
   - Primary `Roll` action.
   - Secondary `Customize` entry point.
   - Compact quick actions row for `Mode` and `Repeat` so core operations remain visible without legacy action menus.
2. Customize Sheet (single sheet, no sub-navigation)
   - Side Count control group.
   - Color control group.
   - Mode control group (`TR`/`INT`).
   - Done/Close action.

No deeper drill-down views are allowed in this IA.

## Main Roll Screen Layout

- Keep one dominant CTA (`Roll`).
- Keep `Customize` as primary secondary action, with compact `Mode` and `Repeat` quick actions below.
- Reserve at least 55% of interaction area for die preview + primary roll path.
- Keep status text to compact token format only.

## Customize Sheet Layout

Single vertically scrollable sheet with fixed section order:

1. `Side Count`
   - Digital Crown-steppable numeric control.
   - Quick chips for common sides (`d2`, `d4`, `d6`, `d8`, `d10`, `d12`, `d20`).
2. `Color`
   - One-row swatch selector using existing die color presets.
3. `Mode`
   - Two-state selector: `True Random` / `Intuitive`.
4. Footer actions
   - `Done` button (dismiss and apply).

## Side Count Interaction Model (Digital Crown + Chips)

This section is the canonical interaction contract for side count selection on watch.

### Value Range and Stepping

- Allowed side count range: `2...100`.
- Step size: `1` side per Digital Crown detent.
- Crown acceleration is allowed by system behavior, but logical step application remains integer-by-integer.
- Value changes update the rendered die immediately (live preview).

### Quick Chips

- Always-visible common chips: `d2`, `d4`, `d6`, `d8`, `d10`, `d12`, `d20`.
- Chip tap sets side count directly and refreshes preview immediately.
- When side count equals a chip value, that chip is shown as selected.
- Non-chip values (for example `d37`) are represented by the numeric control state; no synthetic chip is created.

### Crown/Chip Synchronization

- Crown changes update chip highlight state in real time.
- Chip taps update the crown-bound value so subsequent crown turns continue from the tapped value.
- No apply button is required for side-count edits; `Done` only closes the sheet.

### Legibility and Truncation Rules

- Side-count labels must always render as compact tokens (`dN`), never long-form text.
- Quick chips must not truncate (`d12`, `d20` must remain fully visible).
- If horizontal space is constrained, chips wrap/scroll; token text is never ellipsized.
- Status line on main screen remains tokenized (`mode·notation`) and may truncate only notation tail, never the mode token.
- For large side counts (`d100`), numeric control uses full numeric value without abbreviation.

## Interaction Rules

- All controls must be operable with touch only; Digital Crown adds speed, not exclusivity.
- Changes apply live to preview where practical (side count and color should update visible die immediately).
- Closing the sheet preserves the updated configuration.
- Invalid combinations should be prevented by control ranges, not error alerts.

## Accessibility and Legibility

- Minimum tap target: 44x44 pt equivalent.
- Use concise labels; avoid sentence-length helper text.
- Preserve VoiceOver labels for all controls and current value announcements.
- Keep the same glanceable status token contract after customization (`mode·notation`, `v#`).

## Persistence Contract

- Persist per-watch last configuration:
  - side count
  - color preset
  - mode
  - background texture (watch default remains `black` per separate task)
- Restore on next launch before first roll.
- Cross-device sync transport: `WatchConnectivity` application context (phone <-> watch).
- Conflict policy: timestamped last-write-wins.
  - Rationale: this is a single-user, multi-device preference profile, so newest write should become canonical.
  - Tie-breaker: when timestamps are equal, prefer the remote payload to ensure both peers converge.

## Notes on Cross-Platform Consistency

- Domain behavior (roll, mode semantics, side count validity) must remain shared with iOS/macOS code.
- Watch-specific presentation stays compact, but customization semantics should mirror phone where meaningful.
