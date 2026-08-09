from pathlib import Path

PLAYABLE = Path("docs/roadmap/PLAYABLE-MVP-PATCH-EXECUTION.md")
QUEUE = Path("docs/roadmap/AGENT-BUILD-AHEAD-QUEUE.md")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


playable = PLAYABLE.read_text()
playable = replace_once(
    playable,
    "# Atlas — Playable MVP + Patch Execution v2.9\n\n**Status:** CURRENT EXECUTION-SEQUENCING AUTHORITY  \n**Adopted:** 2026-08-08  ",
    "# Atlas — Playable MVP + Patch Execution v2.10\n\n**Status:** CURRENT EXECUTION-SEQUENCING AUTHORITY  \n**Adopted:** 2026-08-08  \n**Refreshed:** 2026-08-09  ",
    "playable version",
)
playable = replace_once(
    playable,
    "Static validation remains required, but static validation does not replace Studio/runtime evidence for playable claims.\n",
    "Static validation remains required, but static validation does not replace Studio/runtime evidence for playable claims.\n\n**Build-through clarification:** an unrun consolidated Studio/device pass is not, by itself, a source-development stop. When the current milestone is source-complete and marked **BUILT — VERIFICATION PENDING**, agents may continue dependency-safe work into the next patch under `MVP-BUILD-THROUGH-TESTING-POLICY.md`. A known runtime failure, broken authority boundary, or evidence result that invalidates current assumptions *does* preempt later-patch work and returns priority to FIX.\n",
    "build-through clarification",
)
playable = replace_once(
    playable,
    "**Status: [~] ACTIVE — the complete run is not yet accepted.**",
    "**Status: [~] BUILT — CONSOLIDATED VERIFICATION PENDING.** The planned MVP 0.1 source loop is now end-to-end implemented; the milestone is not promoted to VERIFIED/accepted until the consolidated exact-build Studio/device pass succeeds.",
    "mvp status",
)
old_opening = "- [x] The humble melee → earned-firearm opening is implemented without masquerading as firearm state: Field Hatchet combat has its own server-authoritative contract/target/damage path, fresh players start in melee mode, forged firearm fire/reload is rejected while melee, the first personal survival chest recovers the Service Pistol through the existing found-weapon owner, stronger firearm discoveries remain available, and deliberate replay restores the melee opening. This is **BUILT — VERIFICATION PENDING** pending the consolidated Studio/device pass.\n"
new_opening = old_opening + "- [x] Failed and abandoned expeditions now forfeit claimed-but-unbanked equipment; only server-derived `Completed` outcomes distribute/persist expedition equipment, and the debrief labels forfeited versus banked gear truthfully.\n- [x] Deliberate replay clears temporary run power — Run Relics, upgrade stacks, Field XP/level, pending choices, run-only stats, combat modifiers, opening loot and firearm runtime — while preserving durable inventory/discoveries and monotonic client transport counters.\n- [x] Durable inventory now has a live session lifecycle for full-length runs: load/acquire on join, renewal inside the lease window, release on leave and final release on shutdown.\n- [x] Banked equipment is no longer inert: the owner can equip an owned durable item under the existing inventory authority, and the next deliberate launch resolves its authored equipment definition to the trusted combat `WeaponId` after fresh-run reset and before pressure arms.\n- [x] The existing RPG menu now consumes the sanitized durable inventory snapshot, shows equipped Primary/Secondary/Armor/Relic gear plus rarity/power, and uses device-neutral `Activated` input to submit only the owned `InstanceId`; server-pushed inventory state remains the truth after equip.\n"
playable = replace_once(playable, old_opening, new_opening, "mvp durable checklist")
old_next = "**Next highest-ROI MVP 0.1 task:** re-audit current `main` after the melee-opening merge and choose the highest-ROI remaining **source-verifiable** gap in the representative spawn → preparation → launch → explore → fight → loot/reward → elite → boss → result → return → upgrade → replay loop. Do not redo BA-062 or the melee/firearm-opening migration merely because their manual evidence remains pending. Under `MVP-BUILD-THROUGH-TESTING-POLICY.md`, continue dependency-safe implementation while keeping those slices marked **BUILT — VERIFICATION PENDING**. The consolidated exact-build Studio/device STOP / PLAY / FIX pass remains required before MVP 0.1 or its device/melee behavior can be promoted to **VERIFIED**; fix any choice-input, first-contact, gunfeel, silhouette, biome-readability or frame-budget failure found there before calling the milestone accepted."
new_next = "**Next highest-ROI MVP 0.1 task:** there is no known missing source feature required to complete the planned MVP 0.1 loop. The next milestone task is the **consolidated exact-build Studio/device STOP / PLAY / FIX pass** across spawn → preparation → launch → explore → fight → loot/reward → elite → boss → result → return → bank/equip → replay, including keyboard/controller/touch and representative performance. Until that pass can run, `MVP-BUILD-THROUGH-TESTING-POLICY.md` authorizes dependency-safe **Patch 0.2 Combat Feel + Readability** source work; do not invent new MVP 0.1 scope merely because verification is pending. As of this refresh, PR #316 is the existing overlapping Patch 0.2 melee-presentation branch and must be inspected/rebased/validated before starting duplicate work. Any actual Studio/device failure found in the consolidated pass immediately preempts Patch 0.2 and becomes the highest-priority MVP 0.1 FIX."
playable = replace_once(playable, old_next, new_next, "mvp next task")
playable = replace_once(
    playable,
    "# Patch 0.2 — Combat Feel + Readability\n\n**Goal:** make the already-playable loop satisfying to control and understand.\n",
    "# Patch 0.2 — Combat Feel + Readability\n\n**Current source-safe upgrade lane while MVP 0.1 awaits consolidated verification.** Do not interpret this as MVP 0.1 being VERIFIED; build-through work remains subordinate to any real failure discovered by the pending exact-build pass.\n\n**Goal:** make the already-playable loop satisfying to control and understand.\n",
    "patch 0.2 current lane",
)
PLAYABLE.write_text(playable)

queue = QUEUE.read_text()
queue = replace_once(queue, "# Atlas — Agent Build-Ahead Queue v2.8", "# Atlas — Agent Build-Ahead Queue v2.9", "queue version")
queue = replace_once(
    queue,
    "- Checkpoint used for this refresh: `b91941d7e4db3047759f37d887d7f86bf32d6fb1`",
    "- Checkpoint used for this refresh: `51bad3f948985bb0530d83a7ed10e02b4a55b5d7` (PR #318 merged)",
    "queue checkpoint",
)
queue = replace_once(
    queue,
    "- BA-062's M1-M5 and C1-C4 source findings are remediated through the canonical action map, gamepad/touch coverage, prompt-key separation, UI close/label cleanup, and fail-closed numbered-choice coordination. Direct keyboard/gamepad claims are collision-free in source. PRs #286 and #287 add truthful Squad Ping and class-action presentation copy. **No real-device acceptance is claimed; consolidated Studio/device verification remains open.**\n",
    "- BA-062's M1-M5 and C1-C4 source findings are remediated through the canonical action map, gamepad/touch coverage, prompt-key separation, UI close/label cleanup, and fail-closed numbered-choice coordination. Direct keyboard/gamepad claims are collision-free in source. PRs #286 and #287 add truthful Squad Ping and class-action presentation copy; the later primary-combat-mode path also routes Field Hatchet primary attack across mouse/R2/generated touch. **No real-device acceptance is claimed; consolidated Studio/device verification remains open.**\n- MVP 0.1 source implementation is now end-to-end built through PRs #293–#318: deliberate safe replay, canonical First Descent seed/composition and boss reward, authored Approach combat and Lookout Cache discovery, server-authoritative melee → earned-firearm opening, failure forfeiture, temporary-run reset, live durable-inventory leases, durable equip/start-loadout handoff, and existing-menu durable equipment interaction. The milestone remains **BUILT — VERIFICATION PENDING**, not VERIFIED.\n",
    "queue mvp snapshot",
)
queue = replace_once(
    queue,
    "9. Source CI does not prove Studio behavior.\n10. Every source change needs focused tests and full applicable validation.\n11. Future phases in Master Roadmap v2.8 remain locked unless this queue explicitly marks a task READY.\n12. READY work is unassigned. Do not reserve tasks to Codex, Claude, or another named agent; while quota-limited sequential mode is active, finish and merge the current task before starting the next.",
    "9. Source CI does not prove Studio behavior.\n10. An unrun consolidated Studio/device pass is not a source-work lock by itself: when Playable MVP authority marks the current milestone **BUILT — VERIFICATION PENDING** and no known runtime failure invalidates assumptions, dependency-safe next-patch source work may continue. Any actual runtime/device failure preempts that work and returns priority to FIX.\n11. Every source change needs focused tests and full applicable validation.\n12. Future phases in Master Roadmap v2.8 remain locked unless this queue or the higher-precedence Playable MVP authority explicitly makes them current/eligible.\n13. READY work is unassigned. Do not reserve tasks to Codex, Claude, or another named agent; while quota-limited sequential mode is active, finish and merge the current task before starting the next.",
    "queue build laws",
)
queue = replace_once(
    queue,
    "| BA-032 | DONE | First repeatable dungeon content data. | [`docs/specifications/first-repeatable-dungeon-content.md`](../specifications/first-repeatable-dungeon-content.md) — pins canonical seed `202` for a seven-room First Descent and authors concrete basic/Runner/Crawler/Spitter/Brute/Screamer/Progenitor compositions against the existing room/enemy/horde contracts. Data-only; no runtime spawner wiring. |",
    "| BA-032 | DONE | First repeatable dungeon content data. | [`docs/specifications/first-repeatable-dungeon-content.md`](../specifications/first-repeatable-dungeon-content.md) pins canonical seed `202` and the seven-room First Descent compositions. Later MVP 0.1 integration (PRs #294 and #296) now consumes that seed, room-local placement and authored enemy composition through the existing expedition/enemy authorities; the original data contract remains the content source. |",
    "BA-032 truth",
)
queue = replace_once(
    queue,
    "| BA-033 | DONE | Elite/boss reward-decision data. | [`docs/specifications/first-dungeon-reward-decisions.md`](../specifications/first-dungeon-reward-decisions.md) — maps the authored elite/boss room reward refs to canonical two-choice Run Relic decisions (`reward-source.elite-kill` / `reward-source.boss-milestone`) while keeping runtime consumption disabled and persistent equipment excluded pending BA-043. |",
    "| BA-033 | DONE | Elite/boss reward-decision data. | [`docs/specifications/first-dungeon-reward-decisions.md`](../specifications/first-dungeon-reward-decisions.md) remains the authored Run Relic decision source. Boss Run Relic consumption is now live through the existing run-build authority (PR #295). Persistent equipment was subsequently retained under its existing inventory owner and integrated into MVP replay through PRs #315/#317/#318; this row does not authorize Patch 0.3 affix breadth. |",
    "BA-033 truth",
)
queue = replace_once(
    queue,
    "| BA-042 | DONE | Loot/build-decision coverage audit. | [`docs/specifications/loot-build-decision-coverage-audit.md`](../specifications/loot-build-decision-coverage-audit.md) — finds a complete operation-bound run-build choice path beside an older mapped persistent equipment grant/persistence path whose rarity/Power model lacks a client equip/application loop and conflicts with the first RPG integration's exclusions. Records 12/17 Field Upgrades, 12/12 Run Relics, three configured relic sources, no independent temporary-resource choice layer, no player-item affixes/sets, and outstanding Studio evidence. No runtime activation. |",
    "| BA-042 | DONE | Loot/build-decision coverage audit. | [`docs/specifications/loot-build-decision-coverage-audit.md`](../specifications/loot-build-decision-coverage-audit.md) recorded the then-existing split between run-build choices and persistent equipment. That client equip/application gap is now closed by MVP 0.1: live inventory lease lifecycle (#315), server-owned durable equip/start-loadout handoff (#317), and sanitized existing-menu equip flow (#318). The audit remains useful provenance; player-item affixes/sets remain later Patch 0.3 breadth. |",
    "BA-042 truth",
)
queue = replace_once(
    queue,
    "| BA-043 | BLOCKED on explicit equipment/run-build authority decision | Deterministic item/affix generation rules. | Existing `EquipmentReward*` and inventory owners already define persistent rarity/Power rewards, while the first run-RPG integration excludes that shape and no player item-affix/set contract exists. Decide whether persistent equipment is retained, held, or migrated before adding a seedable affix resolver; never create a parallel loot/inventory/persistence owner. |",
    "| BA-043 | BLOCKED until Patch 0.3 becomes current | Deterministic item/affix generation rules. | The authority decision is resolved: persistent equipment is retained under the existing `EquipmentReward*` / inventory owners and now has a real equip/application loop. Do **not** add affix/set breadth during MVP 0.1/Patch 0.2; when Patch 0.3 becomes current, extend the retained owner rather than creating a parallel loot/inventory/persistence path. |",
    "BA-043 truth",
)
queue = replace_once(
    queue,
    "| BA-050 | DONE | First authored outdoor route as data. | [`docs/specifications/first-authored-outdoor-route.md`](../specifications/first-authored-outdoor-route.md) — orders the eight active Ranger Station → Extraction Clearing landmarks, exposes three route-local BA-051 encounter slots plus one optional BA-052 discovery slot, and hands off to First Descent at `descent-entry`. `RuntimeConsumptionActive = false`; recovered 189-Part WorldPath geometry remains held and the expedition launch terminal is not reused as dungeon-transition authority. |",
    "| BA-050 | DONE | First authored outdoor route as data. | [`docs/specifications/first-authored-outdoor-route.md`](../specifications/first-authored-outdoor-route.md) remains the authored route/slot source. Recovered 189-Part WorldPath geometry is still held, but later MVP 0.1 work consumes the related BA-051 Approach combat beats and BA-052 Lookout Cache without inventing unverified route geometry or reusing the launch terminal as dungeon-transition authority. |",
    "BA-050 truth",
)
queue = replace_once(
    queue,
    "| BA-051 | DONE | Encounter-beat definitions. | [`docs/specifications/first-outdoor-encounter-beats.md`](../specifications/first-outdoor-encounter-beats.md) — binds the three BA-050 slots to a Basic orientation contact, a Basic/Runner/Crawler mixed group, and a two-wave Basic/Runner → Basic/Blight-Spitter roadblock. Duration/recovery values remain authoring targets, only the final roadblock carries late-route elite-resolver-candidate intent, and runtime consumption stays disabled. |",
    "| BA-051 | DONE | Encounter-beat definitions. | [`docs/specifications/first-outdoor-encounter-beats.md`](../specifications/first-outdoor-encounter-beats.md) remains the authored Approach sequence source. PR #299 now consumes its logging-road, campground and two-stage roadblock combat through the existing expedition encounter/enemy authorities with authored recovery pacing; BA-050 imported route geometry remains held. |",
    "BA-051 truth",
)
queue = replace_once(
    queue,
    "| BA-052 | DONE | Landmark/discovery definitions. | [`docs/specifications/first-outdoor-discovery.md`](../specifications/first-outdoor-discovery.md) — defines the optional Lookout Cache with stable discovery/slot/landmark/streaming IDs, `OptionalVantageCache` gameplay meaning, `ReadableOptionalDetour` presentation intent, and canonical planned `reward-source.authored-container` reward reference. Data-only; no streaming, persistence, networking, presentation, or reward runtime ownership. |",
    "| BA-052 | DONE | Landmark/discovery definitions. | [`docs/specifications/first-outdoor-discovery.md`](../specifications/first-outdoor-discovery.md) remains the stable Lookout Cache definition. PR #300 activates the bounded Approach Lookout Cache claim through server-owned distance/run/phase/one-time validation and the existing RunBuild authored-container reward path; no client reward authority or account-persistence path was added. |",
    "BA-052 truth",
)
queue = replace_once(
    queue,
    "| BA-060 | DONE | First-session onboarding sequence. | [`docs/specifications/first-session-onboarding-sequence.md`](../specifications/first-session-onboarding-sequence.md) — pins the 12-step safe arrival → preparation → deliberate launch → route/discovery → First Descent → Run Relic decision → result → safe return → build understanding → deliberate replay journey. Runtime-existing, prepared-data, prepared-integration, and blocked-lifecycle states remain explicit; final replay is blocked on the current `OperationLifecycleService` auto-replay behavior rather than being changed sideways. |",
    "| BA-060 | DONE | First-session onboarding sequence. | [`docs/specifications/first-session-onboarding-sequence.md`](../specifications/first-session-onboarding-sequence.md) remains the 12-step first-session journey. The old auto-replay blocker is closed by PR #293: terminal result returns to safe preparation and a fresh run begins only after a new lobby-ready launch. PR #312 resets temporary run power, and PRs #315/#317/#318 make bank → equip → deliberate replay meaningful while preserving durable state. |",
    "BA-060 truth",
)
queue = replace_once(
    queue,
    "| BA-073 | BLOCKED on relevant prepared domains + v2.7 gate | Vertical-slice integration plan. | Exact promotion order and Studio evidence requirements after runtime gates open. |",
    "| BA-073 | HISTORICAL | Vertical-slice integration plan. | Superseded for practical sequencing by `PLAYABLE-MVP-PATCH-EXECUTION.md` and the merged MVP 0.1 integration series. Remaining evidence promotion is governed by the playable roadmap, build-through policy and Blueprint v2.7 evidence authority rather than a new speculative integration plan. |",
    "BA-073 truth",
)
old_recommended = "### Highest-ROI build-ahead task after current-patch work\n\nPlayable MVP + Patch Execution v2.9 controls global implementation order. Gate 0 runtime stabilization and the smallest MVP 0.1 enablers outrank this queue.\n\nBA-062 no longer has an unimplemented source finding. Its next meaningful step is consolidated Studio/device acceptance, which belongs to the human/runtime lane and must not be replaced by more source-only polish.\n\nWhen that runtime lane cannot proceed and build-ahead work is explicitly desired, the highest-value safe repository task is:\n\n**BA-005 — continue one coherent source-managed authored-overworld reconstruction group behind hold.**\n\nRequirements for the next BA-005 increment:\n\n- refresh current property/presentation evidence before selecting the group;\n- choose one coherent HubTown/resource/world-structure group rather than broad geometry;\n- preserve the authored-overworld coordinate/lifecycle boundary from the modern operation forest;\n- keep all reconstructed content held/dormant;\n- do not boot recovered gameplay services or create a second authority;\n- add focused source/static evidence and merge before choosing another group.\n\nMain World Track 1 remains complete as a preparation sequence (BA-010 → BA-014). Its next step is measurement in the human/Studio lane, not additional speculative environment composition."
new_recommended = "### Highest-ROI work after current-patch refresh\n\nPlayable MVP + Patch Execution v2.10 controls global implementation order. MVP 0.1's planned source loop is now **BUILT — VERIFICATION PENDING** through PR #318. The consolidated exact-build Studio/device pass remains the milestone acceptance task, but its being unrun does not freeze dependency-safe source work.\n\nWhile consolidated verification is pending and no known runtime failure invalidates the baseline, the highest-ROI repository lane is:\n\n**Patch 0.2 — Combat Feel + Readability.**\n\nBefore starting overlapping combat-presentation work, inspect open PR #316 (`[MVP 0.2] Show server-confirmed teammate melee swings`), refresh it against current `main`, remove any temporary branch scaffolding, and require normal CI before merge. Do not duplicate that slice in a new branch.\n\nIf the user explicitly asks for non-runtime build-ahead preparation instead of current-patch work, BA-005 remains allowed behind hold as a lower-priority lane. Keep reconstructed authored-overworld content dormant, evidence-bounded and separate from the operation forest. Main World Track 1 remains complete as preparation (BA-010 → BA-014); its next meaningful step is Studio measurement, not speculative composition."
queue = replace_once(queue, old_recommended, new_recommended, "queue recommended work")
old_backlog = "```text\nBA-005 authored-overworld reconstruction continuation — IN PROGRESS / allowed behind hold\nBA-026 economy model/audit — BLOCKED on Master ECON gate\nBA-035 party/session ownership policy — BLOCKED on social/session ownership decision\nBA-041 Crawler behavior primitive — BLOCKED on scoped identity decision\nBA-043 item/affix generation — BLOCKED on equipment/run-build authority decision\nBA-073 vertical-slice integration plan — BLOCKED on prepared-domain + v2.7 runtime gates\n```"
new_backlog = "```text\nPatch 0.2 Combat Feel + Readability — CURRENT SOURCE-SAFE LANE; inspect open PR #316 before overlapping work\nBA-005 authored-overworld reconstruction continuation — IN PROGRESS / allowed behind hold when build-ahead is explicitly desired\nBA-026 economy model/audit — BLOCKED on Master ECON gate\nBA-035 party/session ownership policy — BLOCKED on social/session ownership decision\nBA-041 Crawler behavior primitive — BLOCKED on scoped identity decision\nBA-043 item/affix generation — BLOCKED until Patch 0.3 becomes current\nBA-073 vertical-slice integration plan — HISTORICAL / superseded by playable-patch sequencing\n```"
queue = replace_once(queue, old_backlog, new_backlog, "queue backlog")
queue = replace_once(
    queue,
    "The highest-value human/runtime task remains:\n\n**produce a recorded CI artifact containing the client-bootstrap fix, re-pin a fresh v2.7 R1 evidence packet to that exact build/place identity, and rerun R1.**\n\nBA-062 also needs a consolidated keyboard/controller/touch acceptance pass before any source-only input work is promoted beyond E1.",
    "The highest-value playable human/runtime task is now the **consolidated exact-build MVP 0.1 Studio/device pass**: complete the representative first run, return/bank/equip/replay loop, keyboard/controller/touch checks, and representative performance on one pinned build. Any failure becomes an immediate MVP 0.1 FIX.\n\nBlueprint v2.7 R1/runtime-matrix evidence remains a separate controlling evidence obligation where that authority still requires refresh; do not treat Patch 0.2 source progress as evidence promotion. BA-062 likewise remains **BUILT/PREPARED — DEVICE VERIFICATION PENDING** until the consolidated pass records real device behavior.",
    "queue human lane",
)
QUEUE.write_text(queue)

print("Roadmap truth sync applied")
