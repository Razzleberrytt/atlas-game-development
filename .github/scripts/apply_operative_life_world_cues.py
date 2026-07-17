from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"expected one match in {path}, found {count}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


bootstrap = "games/living-kingdoms/src/client/init.client.luau"
replace_once(
    bootstrap,
    "local OperativeLifeController = require(script.Controllers.OperativeLifeController)\n",
    "local OperativeLifeController = require(script.Controllers.OperativeLifeController)\nlocal OperativeLifeWorldPresentationController = require(script.Controllers.OperativeLifeWorldPresentationController)\n",
)
replace_once(
    bootstrap,
    "ClassSilhouetteController.start()\n\nprint",
    "ClassSilhouetteController.start()\nOperativeLifeWorldPresentationController.start()\n\nprint",
)

registry = "games/living-kingdoms/src/shared/Config/VisualAssetConfig.luau"
replace_once(
    registry,
    '''\trecord(\n\t\tKeys.InterfaceLifeState,\n\t\tFamilyIds.Interface,\n\t\tStatusIds.TemporaryPresentation,\n\t\t"src/client/Controllers/OperativeLifeController.luau",\n\t\t"Life, incapacitation, revive, and death display is functional temporary UI.",\n\t\t"LifeStateInterface",\n\t\t{},\n\t\t"operative.life",\n\t\tfalse\n\t),''',
    '''\trecord(\n\t\tKeys.InterfaceLifeState,\n\t\tFamilyIds.Interface,\n\t\tStatusIds.TemporaryPresentation,\n\t\t"src/client/Controllers/OperativeLifeWorldPresentationController.luau",\n\t\t"The temporary local life UI remains, and authoritative incapacitated, revive-progress, solo-recovery, and death states now receive client-local world-space geometry and text cues from server-disclosed Player attributes.",\n\t\t"OperativeLifeWorldCue",\n\t\t{},\n\t\t"operative.life",\n\t\tfalse\n\t),''',
)

roadmap = "docs/roadmap/VISUAL-PRODUCTION-TRACK.md"
replace_once(
    roadmap,
    '''  - The presentation adds zero remotes, server runtime, timers, or frame loops and never changes class assignment, movement, collision, health, weapons, ammunition, objectives, or mission state.\n  - Still required: canonical shared operative rig, firearm carry integration, locomotion and life-state poses, class-action cues after their gameplay contracts exist, Studio gameplay-camera approval, avatar-scale coverage, and representative squad performance evidence.''',
    '''  - The presentation adds zero remotes, server runtime, timers, or frame loops and never changes class assignment, movement, collision, health, weapons, ammunition, objectives, or mission state.\n  - Existing server-disclosed life attributes now drive occlusion-respecting world cues: rescue-cross plus `DOWNED`, authoritative revive percentage, upward-chevron plus `SELF RECOVERY`, and X plus `KIA`. Each visible cue uses two non-colliding parts, geometry plus text rather than color alone, two global connections, two connections per player, and no frame loop or timer.\n  - Still required: canonical shared operative rig, firearm carry integration, locomotion/body life-state poses, class-action cues after their gameplay contracts exist, Studio gameplay-camera approval, avatar-scale coverage, and representative squad performance evidence.''',
)

inventory = "docs/specifications/visual-placeholder-inventory.md"
replace_once(
    inventory,
    "| Interface | Life-state display | Temporary presentation | Functional alive/incapacitated/revive/death UI | VIS-0104 / VIS-0108 |",
    "| Interface | Life-state display | Temporary presentation | `OperativeLifeController` retains functional local UI; `OperativeLifeWorldPresentationController` adds server-attribute-driven downed, revive-progress, solo-recovery, and KIA geometry/text cues | VIS-0104 / VIS-0108 |",
)
replace_once(
    inventory,
    "Continue VIS-0104 with authoritative operative life-state presentation while keeping canonical rig import, gameplay-camera approval, class-action cues, avatar-scale coverage, and representative squad performance evidence pending.",
    "Continue VIS-0104 with firearm carry and body-pose integration while keeping canonical rig import, gameplay-camera approval, class-action cues, avatar-scale coverage, and representative squad performance evidence pending.",
)

test = "games/living-kingdoms/tests/VisualAssetContractsConfig.test.luau"
replace_once(
    test,
    '''assertThat(\n\tconfig.ByKey[contracts.AssetKeys.InterfaceMission].statusId == contracts.StatusIds.TemporaryPresentation,\n\t"mission interface must remain honestly marked as temporary"\n)''',
    '''local lifeInterface = config.ByKey[contracts.AssetKeys.InterfaceLifeState]\nassertThat(lifeInterface.statusId == contracts.StatusIds.TemporaryPresentation, "life interface must remain temporary")\nassertThat(\n\tlifeInterface.runtimeOwnerPath == "src/client/Controllers/OperativeLifeWorldPresentationController.luau",\n\t"life interface registry must name the world cue owner"\n)\nassertThat(lifeInterface.expectedRootName == "OperativeLifeWorldCue", "life cue root contract drifted")\nassertThat(\n\tconfig.ByKey[contracts.AssetKeys.InterfaceMission].statusId == contracts.StatusIds.TemporaryPresentation,\n\t"mission interface must remain honestly marked as temporary"\n)''',
)

print("operative life world cue integration staged")
