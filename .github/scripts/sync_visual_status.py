from pathlib import Path
import re


def sub(path: str, pattern: str, replacement: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise RuntimeError(f"expected one match in {path}, found {count}")
    file.write_text(updated, encoding="utf-8")


registry = "games/living-kingdoms/src/shared/Config/VisualAssetConfig.luau"
for key, description, footprint in [
    ("ClassCombatSpecialistEquipment", "Combat Specialist uses a project-original ten-part procedural fallback with broad reinforced shoulders, paired ammunition cases, a back roll, and a diagonal chest band; canonical rig and Studio approval remain pending.", "class.combat-specialist"),
    ("ClassMedicEquipment", "Medic uses a project-original ten-part procedural fallback with a compact pack, twin tall canisters, paired satchels, and a round beacon; canonical rig and Studio approval remain pending.", "class.medic"),
    ("ClassEngineerEquipment", "Engineer uses a project-original ten-part procedural fallback with a wide utility pack, squared tool cases, a frame bar, and an asymmetric antenna; canonical rig and Studio approval remain pending.", "class.engineer"),
]:
    pattern = rf'''\trecord\(\n\t\tKeys\.{key},.*?\n\t\ttrue\n\t\),'''
    replacement = f'''\trecord(\n\t\tKeys.{key},\n\t\tFamilyIds.ClassEquipment,\n\t\tStatusIds.PrimitivePlaceholder,\n\t\t"src/client/Controllers/ClassSilhouetteController.luau",\n\t\t"{description}",\n\t\t"OperativeClassSilhouette",\n\t\t{{}},\n\t\t"{footprint}",\n\t\ttrue\n\t),'''
    sub(registry, pattern, replacement)

roadmap = "docs/roadmap/VISUAL-PRODUCTION-TRACK.md"
sub(
    roadmap,
    r'''- \[ \] \*\*VIS-0104 — Add operative and starting-class visual identity\.\*\*.*?Duplicate-class squads and color-vision differences remain readable\.''',
    '''- [~] **VIS-0104 — Add operative and starting-class visual identity.**\n  - A client-local procedural shared armor base plus geometry-distinct Combat Specialist, Medic, and Engineer equipment silhouettes now attach to R6 or R15 torsos from the existing validated server-safe class roster.\n  - Each fallback is capped at ten massless, non-collidable, non-touchable, non-queryable parts; duplicate classes intentionally share the same geometry and color remains supplemental.\n  - The presentation adds zero remotes, server runtime, timers, or frame loops and never changes class assignment, movement, collision, health, weapons, ammunition, objectives, or mission state.\n  - Still required: canonical shared operative rig, firearm carry integration, locomotion and life-state poses, class-action cues after their gameplay contracts exist, Studio gameplay-camera approval, avatar-scale coverage, and representative squad performance evidence.''',
)

inventory = "docs/specifications/visual-placeholder-inventory.md"
sub(
    inventory,
    r'''\| Operative \| Base operative rig.*?\| Class equipment \| Engineer equipment.*?\| VIS-0104 \|''',
    '''| Operative | Base operative rig | Default-avatar placeholder | `OperativeLifeService`; Roblox character shell remains authoritative, with a client-local four-part procedural armor overlay from `ClassSilhouetteController` | VIS-0104 |\n| Class equipment | Combat Specialist equipment | Primitive placeholder | `ClassSilhouetteController`; broad reinforced shoulders, paired ammunition cases, back roll, and diagonal chest band from the validated class roster | VIS-0104 |\n| Class equipment | Medic equipment | Primitive placeholder | `ClassSilhouetteController`; compact pack, twin tall canisters, paired satchels, and round beacon from the validated class roster | VIS-0104 |\n| Class equipment | Engineer equipment | Primitive placeholder | `ClassSilhouetteController`; wide utility pack, squared tool cases, frame bar, and asymmetric antenna from the validated class roster | VIS-0104 |''',
)
sub(
    inventory,
    r'''Complete VIS-0103.*?operative/class silhouette slice\.''',
    '''Continue VIS-0104 with authoritative operative life-state presentation while keeping canonical rig import, gameplay-camera approval, class-action cues, avatar-scale coverage, and representative squad performance evidence pending.''',
)

print("visual status synchronized")
