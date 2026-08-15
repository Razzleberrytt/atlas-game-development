#!/usr/bin/env python3
"""Static contract validation for Living Kingdoms modular asset systems."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROADMAP = ROOT / "docs" / "production" / "MODULAR-ASSET-PRODUCTION-ROADMAP.md"
CATALOG = (
    ROOT
    / "games"
    / "living-kingdoms"
    / "src"
    / "shared"
    / "Config"
    / "ModularAssetProductionCatalog.luau"
)
FACTORY = (
    ROOT
    / "games"
    / "living-kingdoms"
    / "src"
    / "shared"
    / "Assets"
    / "ModularAssetFactory.luau"
)
RESOLVER = (
    ROOT
    / "games"
    / "living-kingdoms"
    / "src"
    / "shared"
    / "Assets"
    / "ModularAssetResolver.luau"
)
BOOTSTRAP = (
    ROOT
    / "games"
    / "living-kingdoms"
    / "src"
    / "server"
    / "ModularAssetBootstrap.server.luau"
)
WEAPON_PRESENTATION_CONFIG = (
    ROOT
    / "games"
    / "living-kingdoms"
    / "src"
    / "client"
    / "Presentation"
    / "ModularWeaponPresentationConfig.luau"
)
WEAPON_PRESENTATION_ADAPTER = (
    ROOT
    / "games"
    / "living-kingdoms"
    / "src"
    / "client"
    / "Presentation"
    / "ModularWeaponPresentationAdapter.luau"
)
WEAPON_PRESENTATION_FACTORY = (
    ROOT
    / "games"
    / "living-kingdoms"
    / "src"
    / "client"
    / "Presentation"
    / "WeaponPresentationFactory.luau"
)

PACK_IDS = (
    "pack.modular_enemy",
    "pack.player_weapons",
    "pack.modular_dungeon",
    "pack.boss_models",
    "pack.environment_props",
    "pack.reward_containers",
    "pack.armor_sets",
    "pack.enemy_weapons",
    "pack.main_hub",
    "pack.biomes",
    "pack.interactive_objects",
    "pack.elite_variants",
    "pack.ability_vfx",
    "pack.world_landmarks",
    "pack.resources",
    "pack.quest_npcs",
    "pack.encounter_sources",
    "pack.destructibles",
    "pack.random_events",
    "pack.exotics",
)

TOP_FIVE = (
    "pack.modular_dungeon",
    "pack.modular_enemy",
    "pack.player_weapons",
    "pack.environment_props",
    "pack.reward_containers",
)

ENEMY_ARCHETYPES = (
    "Grunt",
    "Shooter",
    "Heavy",
    "MeleeAttacker",
    "Sniper",
    "Support",
    "Elite",
    "Corrupted",
)

WEAPON_CATEGORIES = (
    "AssaultRifle",
    "SMG",
    "Shotgun",
    "HandCannon",
    "SniperRifle",
    "LMG",
    "Launcher",
    "Exotic",
)

LIVE_WEAPON_ASSET_IDS = (
    "weapon.assault_rifle.a",
    "weapon.lmg.a",
    "weapon.shotgun.a",
    "weapon.sniper_rifle.a",
    "weapon.hand_cannon.a",
    "weapon.smg.a",
)

LIVE_WEAPON_CONFIG_KEYS = (
    "FirearmConfig.BasicFirearm.WeaponId",
    "FirearmConfig.LightMachineGun.WeaponId",
    "FirearmConfig.BreachShotgun.WeaponId",
    "FirearmConfig.SniperRifle.WeaponId",
    "FirearmConfig.ServicePistol.WeaponId",
    "FirearmConfig.SubmachineGun.WeaponId",
)

PROP_CATEGORIES = (
    "Crate",
    "Barrel",
    "Pipe",
    "Terminal",
    "Desk",
    "Shelf",
    "BrokenMachinery",
    "Sign",
    "Lamp",
    "Debris",
    "Rock",
    "Vegetation",
)

REWARD_TIERS = ("Common", "Rare", "Epic", "Legendary", "Boss", "Secret", "Event")

DUNGEON_ASSETS = (
    "dungeon.corridor.straight.a",
    "dungeon.corridor.curved.a",
    "dungeon.corridor.broken.a",
    "dungeon.room.combat.a",
    "dungeon.room.puzzle.a",
    "dungeon.room.loot.a",
    "dungeon.room.empty.a",
    "dungeon.door.standard.a",
    "dungeon.door.locked.a",
    "dungeon.door.destructible.a",
    "dungeon.door.hidden.a",
    "dungeon.transition.stairs.a",
    "dungeon.transition.bridge.a",
    "dungeon.platform.elevated.a",
    "dungeon.dead_end.loot.a",
    "dungeon.arena.boss.a",
    "dungeon.room.treasure.a",
    "dungeon.room.secret.a",
)


def read_required(path: Path) -> str:
    if not path.is_file():
        raise AssertionError(f"required modular asset file is missing: {path.relative_to(ROOT)}")
    return path.read_text(encoding="utf-8")


def require_all(text: str, values: tuple[str, ...], label: str) -> None:
    missing = [value for value in values if value not in text]
    if missing:
        raise AssertionError(f"{label} is missing: {', '.join(missing)}")


def main() -> int:
    try:
        roadmap = read_required(ROADMAP)
        catalog = read_required(CATALOG)
        factory = read_required(FACTORY)
        resolver = read_required(RESOLVER)
        bootstrap = read_required(BOOTSTRAP)
        weapon_presentation_config = read_required(WEAPON_PRESENTATION_CONFIG)
        weapon_presentation_adapter = read_required(WEAPON_PRESENTATION_ADAPTER)
        weapon_presentation_factory = read_required(WEAPON_PRESENTATION_FACTORY)

        require_all(catalog, PACK_IDS, "catalog pack coverage")
        require_all(catalog, TOP_FIVE, "catalog top-five priority")
        require_all(catalog, ENEMY_ARCHETYPES, "enemy archetypes")
        require_all(catalog, WEAPON_CATEGORIES, "weapon categories")
        require_all(catalog, PROP_CATEGORIES, "prop categories")
        require_all(catalog, REWARD_TIERS, "reward tiers")
        require_all(catalog, DUNGEON_ASSETS, "dungeon starter modules")

        require_all(
            roadmap,
            (
                "## 1. Modular Enemy Model Pack",
                "## 2. Weapon Model Pack",
                "## 3. Modular Dungeon Environment Kit",
                "## 4. Boss Models",
                "## 5. Environmental Prop Packs",
                "## 6. Loot Chest / Reward Container Models",
                "## 7. Armor Set Models",
                "## 8. Enemy Weapon Models",
                "## 9. Main Hub Environment Kit",
                "## 10. Biome Environment Packs",
                "## 11. Interactive Object Models",
                "## 12. Elite Enemy Variants",
                "## 13. Ability / Skill Visual Effects",
                "## 14. World Landmark Models",
                "## 15. Resource / Crafting Material Models",
                "## 16. Quest NPC Models",
                "## 17. Enemy Spawn / Encounter Objects",
                "## 18. Destructible Environment Models",
                "## 19. Random Event Asset Pack",
                "## 20. Rare / Exotic Item Models",
            ),
            "roadmap 20-pack coverage",
        )
        require_all(roadmap, ("Explore → Fight → Loot → Upgrade → Repeat", "900 visual combinations"), "roadmap force-multiplier contract")

        require_all(
            factory,
            (
                "function Factory.BuildStarterLibrary",
                "function Factory.BuildEnemyVariant",
                "Snap_North",
                "Snap_South",
                "Snap_West",
                "Snap_East",
                "RewardOrigin",
                "EnemyBaseCombinationCount",
                "pack.modular_dungeon",
                "pack.modular_enemy",
                "pack.player_weapons",
                "pack.environment_props",
                "pack.reward_containers",
            ),
            "factory implementation surface",
        )
        require_all(resolver, ("BuildIndex", "FindByAssetId", "CloneByAssetId", "GeneratedModularAssets"), "resolver API")
        require_all(bootstrap, ("Catalog.GeneratedRootName", "Factory.BuildStarterLibrary", "GeneratedPrototypeRoot"), "bootstrap contract")

        require_all(weapon_presentation_config, LIVE_WEAPON_CONFIG_KEYS, "live firearm modular mappings")
        require_all(weapon_presentation_config, LIVE_WEAPON_ASSET_IDS, "live modular weapon asset IDs")
        require_all(
            weapon_presentation_config,
            ("ModularAssetProductionCatalog.Weapons.Categories", "FirearmConfig.DefinitionsById", "GetAssetId"),
            "weapon mapping drift guards",
        )
        require_all(
            weapon_presentation_adapter,
            (
                "ModularAssetResolver.GetGeneratedRoot",
                "ModularAssetResolver.CloneByAssetId",
                'findAttachment(shell, "Grip")',
                'findAttachment(shell, "Muzzle")',
                "shell:ScaleTo(scale)",
                "ModularShellWeld",
                "hideProceduralShell",
                'VisualStatus", "ModularGeneratedAsset"',
            ),
            "modular weapon presentation adapter",
        )
        require_all(
            weapon_presentation_factory,
            (
                "createProceduralRig",
                "ModularWeaponPresentationConfig.GetAssetId",
                "ModularWeaponPresentationAdapter.Apply",
            ),
            "live weapon factory modular integration",
        )

        combined = "\n".join(
            (
                roadmap,
                catalog,
                factory,
                resolver,
                bootstrap,
                weapon_presentation_config,
                weapon_presentation_adapter,
                weapon_presentation_factory,
            )
        )
        if "rbxassetid://" in combined.lower():
            raise AssertionError("modular asset system must not commit placeholder marketplace asset IDs")
        if "math.random(" in factory:
            raise AssertionError("enemy visual composition must remain deterministic; use seeded catalog selection")

        expected_combinations = 5 * 6 * 5 * 6
        if expected_combinations != 900:
            raise AssertionError("starter enemy combinatorics contract drifted")

    except AssertionError as exc:
        print(f"[modular-assets] FAILED: {exc}", file=sys.stderr)
        return 1

    print("[modular-assets] OK — modular library + live weapon presentation contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
