from pathlib import Path

path = Path("docs/roadmap/PLAYABLE-MVP-PATCH-EXECUTION.md")
source = path.read_text()


def replace_once(old: str, new: str) -> None:
    global source
    if new in source:
        return
    count = source.count(old)
    if count != 1:
        raise SystemExit(f"expected one roadmap anchor, found {count}: {old[:120]!r}")
    source = source.replace(old, new, 1)


replace_once(
    "The opening power curve should begin with a humble melee-capable path and make firearms feel discovered or earned. Because the current canonical combat owner is firearm-specific, this requires a focused server-authoritative migration with tests and Studio evidence; do not fake it by assigning firearm ammunition/state contracts to a melee item.\n",
    "The opening power curve should begin with a humble melee-capable path and make firearms feel discovered or earned. Do not fake it by assigning firearm ammunition/state contracts to a melee item.\n\n"
    "**Opening implementation status (2026-08-09): BUILT — VERIFICATION PENDING.** Fresh operatives now begin in a server-owned `Melee` primary-combat mode with a distinct Field Hatchet contract, damage path, mouse/R2/touch primary-attack routing, truthful HUD state and first/third-person presentation. Firearm evaluation, fire and reload are rejected server-side while melee. Each operative's first personally opened survival chest stages the humble Service Pistol recovery through the existing found-weapon authority; successful recovery switches the server-owned mode to `Firearm`, while the stronger shotgun/SMG/LMG/sniper discovery pool remains available afterward. Deliberate replay resets combat mode, hidden firearm runtime state and survival loot so the opening can repeat cleanly. Automated repository validation is green; consolidated Studio/device evidence is still required before this opening is `VERIFIED`.\n",
)

replace_once(
    """- [ ] **Device parity is broken for combat.** BA-061's action-map audit
  ([`../specifications/input-action-map-audit.md`](../specifications/input-action-map-audit.md))
  found firing bound to `MouseButton1` alone: gamepad and touch players can
  move, reload, sprint, ping, use the flashlight and collect loot, but cannot
  attack. Reload, sprint and revive also lack gamepad bindings, and `E`
  (revive) and `ButtonX` (class action) both collide with the engine's
  `ProximityPrompt` defaults. This is a source-level finding at E1; no device
  was tested. It blocks an affirmative answer to the keyboard/controller/touch
  acceptance question below and should be fixed before the Studio pass, so that
  pass can evaluate all three input paths rather than one.
""",
    """- [x] BA-061/BA-062 source remediation is implemented for the audited combat/input gaps: primary attack is device-neutral across mouse, gamepad R2 and generated touch; reload, sprint and revive have controller paths; and the audited `E` / `ButtonX` prompt collisions were removed. This is **BUILT — VERIFICATION PENDING** at the device-evidence layer: no keyboard/controller/touch hardware pass is claimed yet.
- [x] The humble melee → earned-firearm opening is implemented without masquerading as firearm state: Field Hatchet combat has its own server-authoritative contract/target/damage path, fresh players start in melee mode, forged firearm fire/reload is rejected while melee, the first personal survival chest recovers the Service Pistol through the existing found-weapon owner, stronger firearm discoveries remain available, and deliberate replay restores the melee opening. This is **BUILT — VERIFICATION PENDING** pending the consolidated Studio/device pass.
""",
)

replace_once(
    """**Next highest-ROI MVP 0.1 task:** give firing a device-neutral binding so
controller and touch players can fight at all (BA-062, first remediation item
only; client-side intent origin, server keeps combat authority), then run the
exact-build STOP / PLAY / FIX pass. Fix any choice-input, first-contact, gunfeel, silhouette, biome-readability or frame-budget failure before expanding day/night, skill-tree breadth or additional RPG systems.
""",
    """**Next highest-ROI MVP 0.1 task:** re-audit current `main` after the melee-opening merge and choose the highest-ROI remaining **source-verifiable** gap in the representative spawn → preparation → launch → explore → fight → loot/reward → elite → boss → result → return → upgrade → replay loop. Do not redo BA-062 or the melee/firearm-opening migration merely because their manual evidence remains pending. Under `MVP-BUILD-THROUGH-TESTING-POLICY.md`, continue dependency-safe implementation while keeping those slices marked **BUILT — VERIFICATION PENDING**. The consolidated exact-build Studio/device STOP / PLAY / FIX pass remains required before MVP 0.1 or its device/melee behavior can be promoted to **VERIFIED**; fix any choice-input, first-contact, gunfeel, silhouette, biome-readability or frame-budget failure found there before calling the milestone accepted.
""",
)

path.write_text(source)
print("patched Playable MVP roadmap for current BA-062 and melee-opening status")
