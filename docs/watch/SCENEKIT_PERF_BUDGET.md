# watchOS SceneKit Perf Budget

Scope: single D6 SceneKit preview on watchOS 10.2+.

## Targets

- Frame pacing target: 30 fps during roll animation.
- Idle target: no continuous scene updates once die settles.
- Roll animation target duration: <= 0.4s.
- Geometry budget: one `SCNBox` node (beveled), no dynamic mesh rebuilds per roll.
- Material budget: six static face materials, generated once per controller lifetime.

## Operational Guardrails

- Use `preferredFramesPerSecond = 30` on `WKInterfaceSCNScene`.
- Keep antialiasing at `multisampling2X`.
- Use one camera, one key light, one ambient light.
- Avoid per-frame physics simulation; rotate directly to target orientation.
- Keep fallback image path available if SceneKit rendering is unavailable.

## Validation Checklist

- Verify repeated rolls do not degrade responsiveness over 100 interactions.
- Verify mode toggles do not recreate scene resources unnecessarily.
- Verify app resume from background retains scene and continues rolling correctly.
