# Mac Catalyst History and Export Parity

Mac Catalyst uses the same history feature set as iOS/iPadOS through `DiceViewModel`:

- Session history presentation via `History` button.
- Clear history action (`clearHistory()`).
- Export as plain text (`dice-history.txt`) and CSV (`dice-history.csv`) through system share sheet.

On Catalyst, the action sheet and activity controller are presented using popover anchors (`historyButton`) for desktop-safe behavior.
