# Definition of Done

A roadmap task is complete only when every applicable requirement below is satisfied.

## Scope

- The task has one clear objective.
- Changes remain within the task’s stated boundaries.
- Any necessary scope adjustment is documented before implementation.

## Implementation

- The intended behavior is implemented.
- Names and module boundaries follow the technical blueprint.
- Consequential game state remains server-authoritative.
- Balance values are configuration-driven where appropriate.
- No unrelated cleanup or speculative framework work is included.

## Validation

- Available automated checks pass.
- New deterministic logic has appropriate tests where feasible.
- Manual verification steps are written clearly.
- Roblox Studio results are reported honestly; unperformed checks are explicitly listed.
- No new unexplained console errors or warnings are introduced.

## Documentation

- Related specifications or architecture notes are updated.
- The roadmap reflects the accurate task status.
- New limitations or technical debt are recorded.

## Integration

- The project still builds, synchronizes, or launches according to the current milestone’s capabilities.
- The change is reviewable as one coherent pull request.
- Rollback is possible through normal Git history.

## Evidence required in the pull request

- Summary of behavior changed
- Exact validation commands and results
- Manual test checklist
- Screenshots or video when visual behavior is central and available
- Known limitations

A task must not be marked complete merely because code was written.
