# Widget Simulator UI Validation Checklist

Date: 2026-02-27

## Devices and Families

- iPhone simulator (iOS 18.6+)
  - Home Screen `.systemSmall`
  - Home Screen `.systemMedium`
  - Lock Screen `.accessoryInline`
  - Lock Screen `.accessoryCircular`
- iPad simulator (iPadOS 18.6+)
  - Home Screen `.systemSmall`
  - Home Screen `.systemMedium`

## Appearance Coverage

Run each family in both:

- Light appearance
- Dark appearance

## Data States

Validate each family against these states:

- First launch/empty history (shows ready/empty copy)
- Active history with recent totals (shows last total and strip)
- Mixed mode states (true-random vs intuitive label/token)

## Deep-Link Behavior

For each widget family tap target:

- `dice://roll` routes to roll screen and triggers roll flow readiness
- `dice://history` routes to history presentation
- `dice://presets` routes to presets presentation

Validate for:

- Cold launch from SpringBoard
- Warm launch with existing scene

## Truncation and Legibility

- Inline widget string remains readable without clipping.
- Circular widget value and mode token remain legible.
- Small widget notation/total/mode stack does not overlap.
- Medium widget recent strip shows three compact slots with no clipping.

## Pass Criteria

- No clipped text in checked families.
- No unreadable contrast in light/dark.
- Tap routes always land on intended destination.
- Empty-state and active-state content both render correctly.
