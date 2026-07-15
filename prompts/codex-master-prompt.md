# Codex Master Execution Prompt

Use this prompt as the default starting instruction for implementation work.

---

You are working in `Razzleberrytt/atlas-game-development`, an AI-assisted game-development repository whose first game is the Roblox RTS **Living Kingdoms**.

## Mission

Complete the next appropriate roadmap task without expanding scope or leaving `main` less stable than you found it.

## Required reading

Before changing code, read:

1. `README.md`
2. `docs/bible/00-project-charter.md`
3. `docs/bible/01-mvp.md`
4. `docs/architecture/technical-blueprint.md`
5. `docs/roadmap/MASTER-ROADMAP.md`
6. Any specification, decision record, or production document directly related to the selected task

## Execution protocol

1. Inspect the repository and identify the earliest uncompleted, unblocked task in the active milestone.
2. Confirm that its prerequisites are present.
3. If the task is too broad for one focused pull request, split it into ordered subtasks in the roadmap before implementation.
4. Implement only that task and required supporting changes.
5. Do not add speculative systems, monetization, persistent progression, extra factions, or unrelated polish.
6. Keep client/server authority consistent with the technical blueprint.
7. Keep balance data centralized in configuration rather than hidden in logic.
8. Add or update tests and manual verification instructions appropriate to the change.
9. Update documentation and roadmap status in the same change.
10. Run all available validation and report exact results.

## Non-negotiable constraints

- Do not rewrite working systems without demonstrated need.
- Do not modify unrelated systems merely to make the implementation more elegant.
- Do not claim Roblox Studio validation occurred unless it actually occurred.
- Do not hide failures, skipped tests, or unresolved limitations.
- Do not mark a task complete unless its acceptance criteria are met.
- Preserve a playable or at least launchable project at every merge.

## Final report format

Provide:

- Task completed
- What changed
- Files changed
- Validation run and exact results
- Manual Roblox Studio checks still required
- Known limitations
- Recommended next roadmap task

---

For a specific assignment, append:

`Execute task LK-XXXX: <task title>.`
