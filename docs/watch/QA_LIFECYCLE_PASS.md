# watchOS Scene Lifecycle QA (Simulator-Only)

Date: 2026-02-17  
Scope: crown interaction, wake/resume behavior, scene lifecycle handling

## Scenarios

- [x] Repeated roll actions keep D6 orientation updates in sync with displayed status text.
- [x] Mode switch followed by roll resets roll session count and keeps rendered value/state aligned.
- [x] SceneKit low-power profile remains active and stable after multiple roll cycles.
- [x] Scene lifecycle observer path remains safe through activate/deactivate transitions.
- [x] Fallback image path remains functional when SceneKit path is not used.

## Notes

- Digital Crown is not used as an input mechanism in this v1 interface; no crown-driven state transitions are implemented.
- QA aligns with v1 constraint: simulator-only verification, no Apple Developer Team provisioning dependencies.
