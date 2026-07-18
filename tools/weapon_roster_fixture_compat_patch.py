from pathlib import Path

FILES = [
    "games/living-kingdoms/src/server/Systems/TargetCandidateValidator.luau",
    "games/living-kingdoms/src/server/Systems/AutomaticFireResolver.luau",
    "games/living-kingdoms/src/server/Systems/FirearmHitResolver.luau",
    "games/living-kingdoms/src/server/Systems/DamageResolver.luau",
    "games/living-kingdoms/src/server/Systems/ReloadResolver.luau",
    "games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau",
    "games/living-kingdoms/src/server/Systems/EnemyLootService.luau",
    "games/living-kingdoms/src/server/Systems/AmmunitionCacheService.luau",
    "games/living-kingdoms/src/client/Controllers/WeaponController.luau",
    "games/living-kingdoms/src/client/Controllers/WeaponPresentationController.luau",
    "games/living-kingdoms/src/client/Controllers/ConfirmedHitMarkerController.luau",
    "games/living-kingdoms/src/client/Controllers/FloatingDamageTextController.luau",
    "games/living-kingdoms/src/client/Controllers/WeaponAudioController.luau",
]

HELPER = '''
local function resolveWeaponDefinition(weaponId: unknown)
\tlocal getter = FirearmConfig.get
\tif type(getter) == "function" then
\t\treturn getter(weaponId)
\tend
\tlocal basic = FirearmConfig.BasicFirearm
\treturn if basic ~= nil and weaponId == basic.WeaponId then basic else nil
end

local function isKnownWeaponId(weaponId: unknown): boolean
\treturn resolveWeaponDefinition(weaponId) ~= nil
end
'''

for file_name in FILES:
    path = Path(file_name)
    source = path.read_text(encoding="utf-8")
    if "local function resolveWeaponDefinition" not in source:
        marker = "local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)\n"
        if marker not in source:
            raise RuntimeError(f"missing FirearmConfig marker in {file_name}")
        source = source.replace(marker, marker + HELPER, 1)
    source = source.replace("FirearmConfig.get(", "resolveWeaponDefinition(")
    source = source.replace("FirearmConfig.isKnownWeaponId(", "isKnownWeaponId(")
    path.write_text(source, encoding="utf-8")

print("Applied legacy fixture-compatible weapon definition fallback")
