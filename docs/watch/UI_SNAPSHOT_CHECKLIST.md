# watchOS Snapshot Checklist (Simulator-Only)

Date: 2026-02-17  
Targets: 44mm, 45mm, 49mm watch simulator profiles  
Locale set: `en_US`, `de_DE`, `fr_FR`, `ja_JP`

- [x] Main roll button title fits with default content size.
- [x] Main roll button title fits with accessibility text sizes enabled in simulator.
- [x] Status text remains readable in two-line compact form (`mode·notation` + value/count line).
- [x] Mode token transitions correctly: `TR` <-> `INT`.
- [x] Last-value token renders without clipping for values `1...6`.
- [x] Invalid state fallback does not crash UI when scene is unavailable.
- [x] SceneKit preview and fallback image mode both expose accessibility labels/values.
- [x] Long localization strings do not overlap roll button frame.

Notes:
- Storyboard-based watch UI is deprecated by Apple for newer watchOS, but current implementation remains simulator-testable and stable for v1.
