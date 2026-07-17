from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"expected one match in {path}, found {count}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


weapon = "games/living-kingdoms/src/client/Controllers/WeaponPresentationController.luau"
replace_once(
    weapon,
    "\trigs: { [Player]: BasicFirearmPresentationRig },\n\tactiveTweens: { [string]: Tween },",
    "\trigs: { [Player]: BasicFirearmPresentationRig },\n\tgripMotors: { [Player]: Motor6D },\n\tactiveTweens: { [string]: Tween },",
)
replace_once(
    weapon,
    "\trigs = {},\n\tactiveTweens = {},",
    "\trigs = {},\n\tgripMotors = {},\n\tactiveTweens = {},",
)
replace_once(
    weapon,
    "local function destroyRig(player: Player)\n\tRemoteWeaponMotionPresenter.cleanupPlayer(player)",
    "local function destroyRig(player: Player)\n\tRemoteWeaponMotionPresenter.cleanupPlayer(player)\n\tlocal gripMotor = state.gripMotors[player]\n\tif gripMotor ~= nil then\n\t\tif gripMotor.Parent ~= nil then\n\t\t\tgripMotor:Destroy()\n\t\tend\n\t\tstate.gripMotors[player] = nil\n\tend",
)
replace_once(
    weapon,
    "\tif hand == nil or not state.started or character.Parent == nil then\n\t\treturn\n\tend\n\tlocal existing = character:FindFirstChild(MODEL_NAME)",
    "\tif hand == nil or not state.started or character.Parent == nil then\n\t\treturn\n\tend\n\tlocal staleGrip = hand:FindFirstChild(\"WeaponGrip\")\n\tif staleGrip ~= nil then\n\t\tstaleGrip:Destroy()\n\tend\n\tlocal existing = character:FindFirstChild(MODEL_NAME)",
)
replace_once(
    weapon,
    "\tgripMotor.C1 = CFrame.identity\n\tgripMotor.Parent = hand\n\n\tstate.rigs[player] = rig",
    "\tgripMotor.C1 = CFrame.identity\n\tgripMotor.Parent = hand\n\n\tstate.rigs[player] = rig\n\tstate.gripMotors[player] = gripMotor",
)

bootstrap = "games/living-kingdoms/src/client/init.client.luau"
replace_once(
    bootstrap,
    "local WeaponPresentationController = require(script.Controllers.WeaponPresentationController)\n",
    "local WeaponPresentationController = require(script.Controllers.WeaponPresentationController)\nlocal OperativeCarryPresentationController = require(script.Controllers.OperativeCarryPresentationController)\n",
)
replace_once(
    bootstrap,
    "WeaponPresentationController.start()\nEnemyPresentationController.start()",
    "WeaponPresentationController.start()\nOperativeCarryPresentationController.start()\nEnemyPresentationController.start()",
)

roadmap = "docs/roadmap/VISUAL-PRODUCTION-TRACK.md"
replace_once(
    roadmap,
    "  - Still required: canonical shared operative rig, firearm carry integration, locomotion/body life-state poses, class-action cues after their gameplay contracts exist, Studio gameplay-camera approval, avatar-scale coverage, and representative squad performance evidence.",
    "  - Existing `WeaponGrip` and R6/R15 shoulder motors now receive event-driven upper-body carry poses for ready, authoritative reviver, incapacitated, and dead states. The controller writes at most three captured Motor6D baselines per event, restores every baseline on cleanup, and adds no frame loop, timer, remote, or server runtime.\n  - `WeaponPresentationController` now destroys its stored grip motor and any stale hand-level `WeaponGrip` before replacement, preventing rebind accumulation.\n  - Still required: canonical shared operative rig, authored locomotion and body-pose animation, class-action cues after their gameplay contracts exist, Studio gameplay-camera and animation-interaction approval, avatar-scale coverage, and representative squad performance evidence.",
)

inventory = "docs/specifications/visual-placeholder-inventory.md"
replace_once(
    inventory,
    "| Weapon | Basic firearm model | Missing production presentation | `BasicFirearmPresentationFactory`; project-original Blackwater Support LMG procedural fallback and deterministic source candidate | VIS-0102 |",
    "| Weapon | Basic firearm model | Missing production presentation | `BasicFirearmPresentationFactory` plus `WeaponPresentationController`; project-original Blackwater Support LMG procedural fallback with deterministic source candidate, stale-grip cleanup, and event-driven carry integration | VIS-0102 / VIS-0104 |",
)
replace_once(
    inventory,
    "| Operative | Base operative rig | Default-avatar placeholder | `OperativeLifeService`; Roblox character shell remains authoritative, with a client-local four-part procedural armor overlay from `ClassSilhouetteController` | VIS-0104 |",
    "| Operative | Base operative rig | Default-avatar placeholder | `OperativeLifeService`; Roblox character shell remains authoritative, with `ClassSilhouetteController` armor and `OperativeCarryPresentationController` R6/R15 ready, reviver, incapacitated, and dead upper-body fallbacks | VIS-0104 |",
)
replace_once(
    inventory,
    "Continue VIS-0104 with firearm carry and body-pose integration while keeping canonical rig import, gameplay-camera approval, class-action cues, avatar-scale coverage, and representative squad performance evidence pending.",
    "Continue VIS-0104 with canonical rig and authored animation planning while keeping class-action cues, gameplay-camera and animation-interaction approval, avatar-scale coverage, and representative squad performance evidence pending.",
)

print("operative firearm carry integration staged")
