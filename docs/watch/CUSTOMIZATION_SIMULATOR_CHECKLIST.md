# watchOS Customization Simulator Checklist

Date: 2026-03-12  
Scope: watch single-die customization regressions (simulator only)

## Side Count Switching

- [ ] Start from `d6`, switch to `d20`, roll, and verify visible die value range is `1...20`.
- [ ] Switch from `d20` to token geometry (`d21`) and verify reroll updates value without stale `d20` face mapping.
- [ ] Switch from token geometry (`d21`) to coin geometry (`d2`) and verify roll still updates status/value correctly.

## Reroll Speed

- [ ] Trigger 20 consecutive rerolls using the same side count and confirm each update feels immediate (no visible UI freeze).
- [ ] Record a simulator trace sample and verify reroll interaction path has no long main-thread stalls attributable to watch model updates.

## Accessibility Labels

- [ ] After switching side count, verify the accessible die value string includes the correct side notation (`Value N on dX`).
- [ ] Verify roll control accessibility label/hint remain stable after customization changes.
- [ ] Verify SceneKit preview mode and static fallback mode both expose updated value labels after side-count changes.
