# SpringBoard Quick Actions Scope

Date: 2026-02-27

## Action Set

- `Roll Now` -> `dice://roll`
- `Repeat Last Roll` -> `dice://repeat`
- `Presets` -> `dice://presets`
- `Roll History` -> `dice://history`

## Route Contracts

- Routes are URL-based and scene-safe for multi-window.
- Each action is idempotent when launched repeatedly.
- Unsupported or stale actions become no-op and keep app stable.

## UX Notes

- Keep labels short for iOS quick action menu width.
- Use SF Symbols aligned with action meaning.
- Keep the top action as `Roll Now` for fastest access.
