from __future__ import annotations

from pathlib import Path


def replace_once(source: str, old: str, new: str, label: str) -> str:
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one match, found {count}")
    return source.replace(old, new, 1)


bootstrap_path = Path("games/living-kingdoms/src/server/init.server.luau")
bootstrap = bootstrap_path.read_text(encoding="utf-8")
bootstrap = replace_once(
    bootstrap,
    '''\telse
\t\tassert(existingState:IsA("RemoteEvent"), "ProgressionNetwork.State must be a RemoteEvent")
\tend
\tlocal existingReadState = network:FindFirstChild("ReadState")
\tif existingReadState == nil then
\t\tlocal readState = Instance.new("RemoteFunction")''',
    '''\telse
\t\tassert(existingState:IsA("RemoteEvent"), "ProgressionNetwork.State must be a RemoteEvent")
\tend
\tlocal existingSelectionIntent = network:FindFirstChild("SelectionIntent")
\tif existingSelectionIntent == nil then
\t\tlocal selectionIntent = Instance.new("RemoteEvent")
\t\tselectionIntent.Name = "SelectionIntent"
\t\tselectionIntent.Parent = network
\telse
\t\tassert(
\t\t\texistingSelectionIntent:IsA("RemoteEvent"),
\t\t\t"ProgressionNetwork.SelectionIntent must be a RemoteEvent"
\t\t)
\tend
\tlocal existingReadState = network:FindFirstChild("ReadState")
\tif existingReadState == nil then
\t\tlocal readState = Instance.new("RemoteFunction")''',
    "progression selection remote",
)
bootstrap_path.write_text(bootstrap, encoding="utf-8")


runtime_path = Path("games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau")
runtime = runtime_path.read_text(encoding="utf-8")
runtime = replace_once(
    runtime,
    "local ReloadResolver = require(script.Parent.ReloadResolver)\nlocal TargetCandidateSelector = require(script.Parent.TargetCandidateSelector)",
    "local ReloadResolver = require(script.Parent.ReloadResolver)\nlocal RunProgressionService = require(script.Parent.RunProgressionService)\nlocal TargetCandidateSelector = require(script.Parent.TargetCandidateSelector)",
    "runtime progression require",
)
runtime = replace_once(
    runtime,
    '''local function resolveAcceptedShot(
\tplayerState: PlayerCombatState,
\toperativePosition: Vector3,
\tfireResult: CombatContracts.AuthoritativeFireResult,
\tnowTimestamp: number
)''',
    '''local function resolveAcceptedShot(
\tplayerState: PlayerCombatState,
\toperativePosition: Vector3,
\tfireResult: CombatContracts.AuthoritativeFireResult,
\tnowTimestamp: number,
\tmodifiers: any
)''',
    "accepted shot modifier signature",
)
runtime = replace_once(
    runtime,
    '''\tlocal damageResolution = DamageResolver.resolve(hitResolution, healthRead.healthState, nowTimestamp)
\tEnemyDirectorService.commitHealthState(
\t\ttargetEntityId,
\t\thealthRead.revision,
\t\tdamageResolution.targetHealthStateAfter,
\t\tnowTimestamp
\t)
\tpresentationRemote:FireAllClients({''',
    '''\tlocal damageResolution = DamageResolver.resolve(
\t\thitResolution,
\t\thealthRead.healthState,
\t\tnowTimestamp,
\t\tFirearmConfig.BasicFirearm.DamagePerHit + modifiers.damageBonus
\t)
\tlocal didCommit = EnemyDirectorService.commitHealthState(
\t\ttargetEntityId,
\t\thealthRead.revision,
\t\tdamageResolution.targetHealthStateAfter,
\t\tnowTimestamp
\t)
\tlocal didApplyDamage = didCommit and damageResolution.didApplyDamage
\tpresentationRemote:FireAllClients({''',
    "damage modifier and commit truth",
)
runtime = replace_once(
    runtime,
    '''\t\tdidApplyDamage = damageResolution.didApplyDamage,
\t\timpactWorldPosition = if damageResolution.didApplyDamage then fact.worldPosition else nil,''',
    '''\t\tdidApplyDamage = didApplyDamage,
\t\timpactWorldPosition = if didApplyDamage then fact.worldPosition else nil,''',
    "committed damage presentation",
)
runtime = replace_once(
    runtime,
    '''\tlocal fireResolution = AutomaticFireResolver.resolve({
\t\tentityId = playerState.operativeState.entityId,
\t\tcombatStateId = playerState.operativeState.combatStateId,
\t}, selectedTarget, playerState.weaponState, nowTimestamp)''',
    '''\tlocal modifiers = RunProgressionService.readCombatModifiers()
\tlocal fireResolution = AutomaticFireResolver.resolve({
\t\tentityId = playerState.operativeState.entityId,
\t\tcombatStateId = playerState.operativeState.combatStateId,
\t}, selectedTarget, playerState.weaponState, nowTimestamp, FirearmConfig.BasicFirearm.CadenceSeconds * modifiers.cadenceMultiplier)''',
    "cadence modifier read",
)
runtime = replace_once(
    runtime,
    "\t\tresolveAcceptedShot(playerState, operativePosition, fireResolution.fireResult, nowTimestamp)",
    "\t\tresolveAcceptedShot(playerState, operativePosition, fireResolution.fireResult, nowTimestamp, modifiers)",
    "accepted shot modifier call",
)
runtime = replace_once(
    runtime,
    "\tlocal resolution = ReloadResolver.begin(playerState.operativeState, playerState.weaponState, nowTimestamp)",
    '''\tlocal modifiers = RunProgressionService.readCombatModifiers()
\tlocal resolution = ReloadResolver.begin(
\t\tplayerState.operativeState,
\t\tplayerState.weaponState,
\t\tnowTimestamp,
\t\tFirearmConfig.BasicFirearm.ReloadDurationSeconds * modifiers.reloadMultiplier
\t)''',
    "reload modifier read",
)
runtime = replace_once(
    runtime,
    '''\ttask.delay(FirearmConfig.BasicFirearm.ReloadDurationSeconds, function()
\t\tcompleteReload(player, reloadState.completionServerTimestamp, generation)
\tend)''',
    '''\ttask.delay(
\t\tmath.max(0, reloadState.completionServerTimestamp - Workspace:GetServerTimeNow()),
\t\tfunction()
\t\t\tcompleteReload(player, reloadState.completionServerTimestamp, generation)
\t\tend
\t)''',
    "authoritative upgraded reload scheduling",
)
runtime_path.write_text(runtime, encoding="utf-8")


test_path = Path("games/living-kingdoms/tests/OperativeCombatRuntimeService.test.luau")
test = test_path.read_text(encoding="utf-8")
test = replace_once(
    test,
    "local LIFE_TOKEN = {}\nlocal RELOAD_TOKEN = {}\nlocal SELECTOR_TOKEN = {}",
    "local LIFE_TOKEN = {}\nlocal RELOAD_TOKEN = {}\nlocal PROGRESSION_TOKEN = {}\nlocal SELECTOR_TOKEN = {}",
    "runtime fixture progression token",
)
test = replace_once(
    test,
    "local scheduled = {}\nlocal service = luau.load",
    '''local scheduled = {}
local progressionService = {
\treadCombatModifiers = function()
\t\treturn {
\t\t\tdamageBonus = 0,
\t\t\tcadenceMultiplier = 1,
\t\t\treloadMultiplier = 1,
\t\t}
\tend,
}
local service = luau.load''',
    "runtime fixture progression mock",
)
test = replace_once(
    test,
    '''\t\t\t\tOperativeLifeService = LIFE_TOKEN,
\t\t\t\tReloadResolver = RELOAD_TOKEN,
\t\t\t\tTargetCandidateSelector = SELECTOR_TOKEN,''',
    '''\t\t\t\tOperativeLifeService = LIFE_TOKEN,
\t\t\t\tReloadResolver = RELOAD_TOKEN,
\t\t\t\tRunProgressionService = PROGRESSION_TOKEN,
\t\t\t\tTargetCandidateSelector = SELECTOR_TOKEN,''',
    "runtime fixture progression dependency",
)
test = replace_once(
    test,
    '''\t\t\telseif token == RELOAD_TOKEN then
\t\t\t\treturn reloadResolver
\t\t\telseif token == SELECTOR_TOKEN then''',
    '''\t\t\telseif token == RELOAD_TOKEN then
\t\t\t\treturn reloadResolver
\t\t\telseif token == PROGRESSION_TOKEN then
\t\t\t\treturn progressionService
\t\t\telseif token == SELECTOR_TOKEN then''',
    "runtime fixture progression require",
)
test_path.write_text(test, encoding="utf-8")

print("Applied exact squad run-upgrade integration patch")
