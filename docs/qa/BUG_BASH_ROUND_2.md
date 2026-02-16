# Bug Bash Round 2 (Edge Notation + Long Sessions)

Date: 2026-02-16

## Focus
- Edge notation bounds (`1d2`, `30d100`, intuitive suffix at upper bounds)
- Out-of-bounds rejection near limits (`31d100`, `30d101`)
- Long session stability (high roll counts without totals drift)

## Validation Performed
- Added unit tests:
  - `testParseAcceptsUpperBoundIntuitiveNotation`
  - `testParseRejectsEdgeOutOfBoundsNotation`
  - `testRollSessionTracksLongRunTotalsWithoutDrift`
- Executed `DiceTests` suite (44 tests total).

## Findings
- No new defects discovered.
- Parser correctly accepts/rejects edge inputs.
- Session totals remain consistent after 1,000 deterministic rolls.

## Defect Log (Round 2)
| ID | Description | Severity | Owner | Status |
| --- | --- | --- | --- | --- |
| R2-000 | No defects found in edge-case and long-session pass. | None | N/A | Closed |
