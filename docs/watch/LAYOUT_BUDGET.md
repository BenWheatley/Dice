# watchOS Layout Budget (v1, Simulator-Only)

Date: 2026-02-17  
Targets: 44mm, 45mm, 49mm

## Content Budget

- Primary action count: 1 (`Roll` button).
- Secondary action count: 1 (mode toggle via menu).
- Maximum hierarchy depth: 2 visible levels (`status` + `primary action`).
- Maximum status line length:
  - Line 1 (`mode·notation`): 10 characters.
  - Line 2 (`value/count`): 5 characters.
- Maximum tappable controls on a single screen: 2.

## Touch Budget

- Minimum tap target: 44x44 pt equivalent.
- Primary action occupies at least 65% of interactive vertical area.
- No adjacent tap zones with spacing under 8 pt.

## Typography Budget

- Status text uses compact two-line tokens to avoid clipping at accessibility sizes.
- No sentence-length labels in the main watch flow.
- Numeric result token remains standalone (`v#`) for quick glance parsing.

## Rendering Budget

- Single D6 SceneKit preview only (no board grid on watch).
- Target frame rate:
  - Normal mode: 30 fps.
  - Low power mode: 15 fps.
- Scene fallback must remain available if SceneKit is unavailable.
