# Development Workflow

Date: 2026-02-16

## Branch Strategy

- Use short-lived feature branches prefixed with `codex/` when branching is needed.
- Keep changes scoped to one checklist item at a time.

## Work Unit Rule

For every completed checklist item in `DEVELOPMENT_PLAN.md`:

1. Mark the item checked (`[x]`) in `DEVELOPMENT_PLAN.md`.
2. Commit immediately as a single focused commit.
3. Include evidence of tests run for that unit (or explicit reason if no tests apply).

## Commit Message Pattern

Use an imperative summary:

- `Implement parser bounds for 30d100`
- `Add unit tests for intuitive roll reset behavior`
- `Enable Catalyst multi-window scene support`

## Test Evidence Standard

- Run the narrowest relevant automated tests for touched code before commit.
- If docs-only change: note that no runtime tests were required.
- If tests are blocked by environment constraints: note what was attempted and what remains.

## Pull Request Expectations (when used)

1. List completed checklist item(s).
2. Summarize behavior change.
3. Include test evidence and known gaps.
4. Highlight any deviations from TDD flow.

