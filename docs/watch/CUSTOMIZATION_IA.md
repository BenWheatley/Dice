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
2. Customize Sheet (single sheet, no sub-navigation)
   - Side Count control group.
   - Color control group.
   - Mode control group (`TR`/`INT`).
   - Done/Close action.

No deeper drill-down views are allowed in this IA.

## Main Roll Screen Layout

- Keep one dominant CTA (`Roll`).
- Keep only one secondary action (`Customize`).
- Reserve at least 65% of interaction area for the primary roll path.
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

## Notes on Cross-Platform Consistency

- Domain behavior (roll, mode semantics, side count validity) must remain shared with iOS/macOS code.
- Watch-specific presentation stays compact, but customization semantics should mirror phone where meaningful.
