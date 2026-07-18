from pathlib import Path

SERVER_FILES = [
    "games/living-kingdoms/src/server/Systems/TargetCandidateValidator.luau",
    "games/living-kingdoms/src/server/Systems/AutomaticFireResolver.luau",
    "games/living-kingdoms/src/server/Systems/FirearmHitResolver.luau",
    "games/living-kingdoms/src/server/Systems/DamageResolver.luau",
    "games/living-kingdoms/src/server/Systems/ReloadResolver.luau",
    "games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau",
    "games/living-kingdoms/src/server/Systems/EnemyLootService.luau",
    "games/living-kingdoms/src/server/Systems/AmmunitionCacheService.luau",
]
CLIENT_FILES = [
    "games/living-kingdoms/src/client/Controllers/WeaponController.luau",
    "games/living-kingdoms/src/client/Controllers/WeaponPresentationController.luau",
    "games/living-kingdoms/src/client/Controllers/ConfirmedHitMarkerController.luau",
    "games/living-kingdoms/src/client/Controllers/FloatingDamageTextController.luau",
    "games/living-kingdoms/src/client/Controllers/WeaponAudioController.luau",
]

RESOLVE_HELPER = '''
local function resolveWeaponDefinition(weaponId: unknown)
\tlocal getter = FirearmConfig.get
\tif type(getter) == "function" then
\t\treturn getter(weaponId)
\tend
\tlocal basic = FirearmConfig.BasicFirearm
\treturn if basic ~= nil and weaponId == basic.WeaponId then basic else nil
end
'''
KNOWN_HELPER = '''
local function isKnownWeaponId(weaponId: unknown): boolean
\treturn resolveWeaponDefinition(weaponId) ~= nil
end
'''

for file_name in SERVER_FILES + CLIENT_FILES:
    path = Path(file_name)
    source = path.read_text(encoding="utf-8")
    if "local function resolveWeaponDefinition" not in source:
        marker = "local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)\n"
        if marker not in source:
            raise RuntimeError(f"missing FirearmConfig marker in {file_name}")
        helper = RESOLVE_HELPER + (KNOWN_HELPER if file_name in CLIENT_FILES else "")
        source = source.replace(marker, marker + helper, 1)
    source = source.replace("FirearmConfig.get(", "resolveWeaponDefinition(")
    source = source.replace("FirearmConfig.isKnownWeaponId(", "isKnownWeaponId(")
    path.write_text(source, encoding="utf-8")

runtime_path = Path("games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau")
runtime_source = runtime_path.read_text(encoding="utf-8")
runtime_source = runtime_source.replace(
    'player:SetAttribute("LK_EquippedWeaponId", assignment.weaponId)',
    'setPlayerAttribute(player, "LK_EquippedWeaponId", assignment.weaponId)',
)
runtime_source = runtime_source.replace(
    'player:SetAttribute("LK_EquippedWeaponId", state.weaponState.weaponId)',
    'setPlayerAttribute(player, "LK_EquippedWeaponId", state.weaponState.weaponId)',
)
runtime_source = runtime_source.replace(
    'player:SetAttribute("LK_EquippedWeaponId", nil)',
    'setPlayerAttribute(player, "LK_EquippedWeaponId", nil)',
)
attribute_helper = '''
local function setPlayerAttribute(player: Player, attributeName: string, value: unknown)
\tlocal candidate = player :: any
\tif type(candidate.SetAttribute) == "function" then
\t\tcandidate:SetAttribute(attributeName, value)
\tend
end
'''
marker = "local SERVER_REQUEST_COOLDOWN_SECONDS = 0.25\n"
if marker not in runtime_source:
    raise RuntimeError("runtime attribute helper anchor drifted")
runtime_path.write_text(runtime_source.replace(marker, marker + attribute_helper, 1), encoding="utf-8")

security_path = Path("games/living-kingdoms/tests/CombatSecurityIntegration.test.luau")
security_source = security_path.read_text(encoding="utf-8")
old_assertion = '''assert(
\tstring.find(clientSource, "reloadIntentRemote:FireServer(FirearmConfig.BasicFirearm.WeaponId)", 1, true),
\t"reload request payload widened"
)'''
new_assertion = '''assert(
\tstring.find(clientSource, "reloadIntentRemote:FireServer(state.currentWeaponId)", 1, true),
\t"reload request must contain only the server-disclosed equipped weapon ID"
)
assert(
\tnot string.find(clientSource, "reloadIntentRemote:FireServer(state.currentWeaponId,", 1, true),
\t"reload request must not include ammunition, timing, or weapon statistics"
)'''
if security_source.count(old_assertion) != 1:
    raise RuntimeError("combat security reload assertion anchor drifted")
security_path.write_text(security_source.replace(old_assertion, new_assertion, 1), encoding="utf-8")

audio_path = Path("games/living-kingdoms/tests/FirearmAudioSourceAudit.test.luau")
audio_source = audio_path.read_text(encoding="utf-8")
old_audio = 'assertThat(contains(controller, "FirearmConfig.BasicFirearm.WeaponId"), "audio must gate on the basic firearm")'
new_audio = '''assertThat(contains(controller, "isKnownWeaponId(payload.weaponId)"), "audio must gate on a configured firearm")
assertThat(contains(controller, "resolveWeaponDefinition"), "audio must retain legacy fixture compatibility")'''
if audio_source.count(old_audio) != 1:
    raise RuntimeError("firearm audio audit anchor drifted")
audio_path.write_text(audio_source.replace(old_audio, new_audio, 1), encoding="utf-8")

print("Applied fixture compatibility, safe attribute disclosure, and roster-aware authority audits")
