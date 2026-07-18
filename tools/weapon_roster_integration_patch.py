from pathlib import Path
from textwrap import dedent


def replace(path, old, new, label):
    p = Path(path)
    source = p.read_text(encoding="utf-8")
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: {count} matches in {path}")
    p.write_text(source.replace(old, new, 1), encoding="utf-8")


def write(path, text):
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(dedent(text).lstrip(), encoding="utf-8")


combat = "games/living-kingdoms/src/shared/Combat/CombatContracts.luau"
replace(
    combat,
    'CombatContracts.WeaponIds = table.freeze({\n\tBasicFirearm = "weapon.basic_firearm",\n})',
    '''CombatContracts.WeaponIds = table.freeze({
\tBasicFirearm = "weapon.basic_firearm",
\tLightMachineGun = "weapon.light-machine-gun",
\tBreachShotgun = "weapon.breach-shotgun",
\tSniperRifle = "weapon.sniper-rifle",
\tServicePistol = "weapon.service-pistol",
\tSubmachineGun = "weapon.submachine-gun",
})''',
    "weapon ids",
)

write(
    "games/living-kingdoms/src/server/Systems/TargetCandidateValidator.luau",
    '''
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatContracts = require(ReplicatedStorage.Shared.Combat.CombatContracts)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)
type OperativeCombatStateId = CombatContracts.OperativeCombatStateId
type TargetCandidate = CombatContracts.TargetCandidate
type TargetValidationResult = CombatContracts.TargetValidationResult
type WeaponReadinessState = CombatContracts.WeaponReadinessState
export type OperativeTargetingState = { worldPosition: Vector3, combatStateId: OperativeCombatStateId, weaponReadiness: WeaponReadinessState }
local Validator = {}
local reasons = CombatContracts.TargetValidationRejectionReasonIds
local function reject(reasonId) return { isValid=false, rejectionReasonId=reasonId } end
local function distanceSquared(a: Vector3,b: Vector3): number local x=b.X-a.X local z=b.Z-a.Z return x*x+z*z end
function Validator.validate(operative: OperativeTargetingState, candidate: TargetCandidate): TargetValidationResult
\tif operative.combatStateId ~= CombatContracts.OperativeCombatStateIds.Ready then return reject(reasons.OperativeStateInvalid) end
\tif candidate.relationshipId ~= CombatContracts.TeamRelationshipIds.Hostile then return reject(reasons.RelationshipNotHostile) end
\tif not candidate.isAlive then return reject(reasons.HostileDead) end
\tif not candidate.isTargetable then return reject(reasons.HostileUntargetable) end
\tif not candidate.isVisible then return reject(reasons.NotVisible) end
\tif not candidate.hasLineOfSight then return reject(reasons.NoLineOfSight) end
\tlocal weapon=FirearmConfig.get(operative.weaponReadiness.weaponId)
\tif weapon==nil or operative.weaponReadiness.ammunition.weaponId~=weapon.WeaponId or operative.weaponReadiness.cadence.weaponId~=weapon.WeaponId or operative.weaponReadiness.readinessStateId~=CombatContracts.WeaponReadinessStateIds.Ready then return reject(reasons.WeaponNotReady) end
\tif distanceSquared(operative.worldPosition,candidate.worldPosition)>weapon.RangeStuds*weapon.RangeStuds then return reject(reasons.OutOfRange) end
\tif operative.weaponReadiness.ammunition.loadedRounds<=0 then return reject(reasons.NoAmmunition) end
\treturn { isValid=true, rejectionReasonId=nil }
end
return table.freeze(Validator)
''',
)

auto = "games/living-kingdoms/src/server/Systems/AutomaticFireResolver.luau"
replace(
    auto,
    "local function resolveCadenceSeconds(override: number?): number?\n\tlocal configured = FirearmConfig.BasicFirearm.CadenceSeconds",
    '''local function resolveCadenceSeconds(weaponId: string, override: number?): number?
\tlocal definition = FirearmConfig.get(weaponId)
\tif definition == nil then return nil end
\tlocal configured = definition.CadenceSeconds''',
    "auto cadence",
)
replace(
    auto,
    '''\tlocal cadenceSeconds = resolveCadenceSeconds(cadenceSecondsOverride)
\tlocal ammoConservationChance = resolveAmmoConservationChance()
\tlocal configuredWeaponId = FirearmConfig.BasicFirearm.WeaponId
\tif
\t\tcadenceSeconds == nil
\t\tor ammoConservationChance == nil
\t\tor weaponState.weaponId ~= configuredWeaponId
\t\tor weaponState.ammunition.weaponId ~= configuredWeaponId
\t\tor weaponState.cadence.weaponId ~= configuredWeaponId''',
    '''\tlocal cadenceSeconds = resolveCadenceSeconds(weaponState.weaponId, cadenceSecondsOverride)
\tlocal ammoConservationChance = resolveAmmoConservationChance()
\tlocal configuredWeapon = FirearmConfig.get(weaponState.weaponId)
\tif
\t\tcadenceSeconds == nil
\t\tor ammoConservationChance == nil
\t\tor configuredWeapon == nil
\t\tor weaponState.ammunition.weaponId ~= weaponState.weaponId
\t\tor weaponState.cadence.weaponId ~= weaponState.weaponId''',
    "auto validate",
)

hit = "games/living-kingdoms/src/server/Systems/FirearmHitResolver.luau"
replace(
    hit,
    '''\tif
\t\tacceptedFireResult.weaponId ~= FirearmConfig.BasicFirearm.WeaponId
\t\tor shotContext.weaponId ~= acceptedFireResult.weaponId
\tthen''',
    '''\tlocal weapon = FirearmConfig.get(acceptedFireResult.weaponId)
\tif weapon == nil or shotContext.weaponId ~= acceptedFireResult.weaponId then''',
    "hit weapon",
)
replace(hit, "\tlocal maximumRange = FirearmConfig.BasicFirearm.RangeStuds", "\tlocal maximumRange = weapon.RangeStuds", "hit range")

damage = "games/living-kingdoms/src/server/Systems/DamageResolver.luau"
replace(
    damage,
    "local function resolveDamageAmount(override: number?, currentHealth: number): number?\n\tlocal configured = FirearmConfig.BasicFirearm.DamagePerHit",
    '''local function resolveDamageAmount(weaponId: string, override: number?, currentHealth: number): number?
\tlocal weapon = FirearmConfig.get(weaponId)
\tif weapon == nil then return nil end
\tlocal configured = weapon.DamagePerHit''',
    "damage lookup",
)
replace(
    damage,
    '''\tlocal healthBefore = math.max(0, targetHealthState.currentHealth)
\tlocal damageAmount = resolveDamageAmount(damageAmountOverride, healthBefore)
\tif
\t\tdamageAmount == nil
\t\tor hitResolution.weaponId ~= FirearmConfig.BasicFirearm.WeaponId
\t\tor hitResolution.sourceEntityId == nil''',
    '''\tlocal healthBefore = math.max(0, targetHealthState.currentHealth)
\tlocal weapon = FirearmConfig.get(hitResolution.weaponId)
\tlocal damageAmount = resolveDamageAmount(hitResolution.weaponId, damageAmountOverride, healthBefore)
\tif damageAmount == nil or weapon == nil or hitResolution.sourceEntityId == nil''',
    "damage validate",
)
replace(
    damage,
    "\t\tweaponId = FirearmConfig.BasicFirearm.WeaponId,\n\t\tdamageTypeId = FirearmConfig.BasicFirearm.DamageTypeId,",
    "\t\tweaponId = weapon.WeaponId,\n\t\tdamageTypeId = weapon.DamageTypeId,",
    "damage event",
)

reload = "games/living-kingdoms/src/server/Systems/ReloadResolver.luau"
replace(
    reload,
    '''local function isConfiguredWeaponState(weaponState: WeaponReadinessState): boolean
\tlocal configuredWeaponId = FirearmConfig.BasicFirearm.WeaponId
\treturn weaponState.weaponId == configuredWeaponId
\t\tand weaponState.ammunition.weaponId == configuredWeaponId
\t\tand weaponState.cadence.weaponId == configuredWeaponId
\t\tand weaponState.ammunition.magazineCapacity == FirearmConfig.BasicFirearm.MagazineCapacity
end''',
    '''local function configuredWeapon(weaponState: WeaponReadinessState): FirearmConfig.FirearmDefinition?
\tlocal definition = FirearmConfig.get(weaponState.weaponId)
\tif definition == nil or weaponState.ammunition.weaponId ~= weaponState.weaponId or weaponState.cadence.weaponId ~= weaponState.weaponId or weaponState.ammunition.magazineCapacity ~= definition.MagazineCapacity then return nil end
\treturn definition
end''',
    "reload lookup",
)
replace(
    reload,
    '''\tif
\t\tnot isConfiguredWeaponState(weaponState)
\t\tor operativeState.equippedWeaponId ~= FirearmConfig.BasicFirearm.WeaponId
\tthen''',
    '''\tlocal weapon = configuredWeapon(weaponState)
\tif weapon == nil or operativeState.equippedWeaponId ~= weapon.WeaponId then''',
    "reload begin",
)
replace(
    reload,
    "\t\tweaponId = FirearmConfig.BasicFirearm.WeaponId,\n\t\tstartedAtServerTimestamp = serverTimestamp,\n\t\tcompletionServerTimestamp = serverTimestamp + FirearmConfig.BasicFirearm.ReloadDurationSeconds,",
    "\t\tweaponId = weapon.WeaponId,\n\t\tstartedAtServerTimestamp = serverTimestamp,\n\t\tcompletionServerTimestamp = serverTimestamp + weapon.ReloadDurationSeconds,",
    "reload timing",
)
replace(
    reload,
    "\tif not isConfiguredWeaponState(weaponState) then\n\t\treturn rejectCompletion(operativeState, weaponState, reasons.WeaponInvalid)\n\tend",
    "\tlocal weapon = configuredWeapon(weaponState)\n\tif weapon == nil then\n\t\treturn rejectCompletion(operativeState, weaponState, reasons.WeaponInvalid)\n\tend",
    "reload complete",
)
replace(reload, "\tif reloadState.weaponId ~= FirearmConfig.BasicFirearm.WeaponId then", "\tif reloadState.weaponId ~= weapon.WeaponId then", "reload state")

runtime = "games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau"
replace(
    runtime,
    "local TargetCandidateSelector = require(script.Parent.TargetCandidateSelector)",
    '''local TargetCandidateSelector = require(script.Parent.TargetCandidateSelector)
local weaponLoadoutModule = script.Parent.WeaponLoadoutService
local WeaponLoadoutService = if weaponLoadoutModule == nil
\tthen table.freeze({ read = function(_player: Player) return nil end })
\telse require(weaponLoadoutModule)''',
    "runtime dep",
)
replace(
    runtime,
    '''local function createWeaponState(): WeaponReadinessState
\tlocal weaponId = FirearmConfig.BasicFirearm.WeaponId
\treturn {
\t\tweaponId = weaponId,
\t\treadinessStateId = CombatContracts.WeaponReadinessStateIds.Ready,
\t\tammunition = {
\t\t\tweaponId = weaponId,
\t\t\tloadedRounds = FirearmConfig.BasicFirearm.PrototypeInitialLoadedRounds,
\t\t\treserveRounds = FirearmConfig.BasicFirearm.PrototypeInitialReserveRounds,
\t\t\tmagazineCapacity = FirearmConfig.BasicFirearm.MagazineCapacity,''',
    '''local function createWeaponState(weaponId: string?): WeaponReadinessState
\tlocal definition = FirearmConfig.get(weaponId) or FirearmConfig.BasicFirearm
\tweaponId = definition.WeaponId
\treturn {
\t\tweaponId = weaponId,
\t\treadinessStateId = CombatContracts.WeaponReadinessStateIds.Ready,
\t\tammunition = {
\t\t\tweaponId = weaponId,
\t\t\tloadedRounds = definition.PrototypeInitialLoadedRounds,
\t\t\treserveRounds = definition.PrototypeInitialReserveRounds,
\t\t\tmagazineCapacity = definition.MagazineCapacity,''',
    "runtime state",
)
replace(runtime, "\t\tweaponState = createWeaponState(),", "\t\tweaponState = createWeaponState(weaponId),", "runtime state arg")
replace(
    runtime,
    "\tlocal ammunition = playerState.weaponState.ammunition\n\tlocal kindId = if grantedRounds == nil",
    '''\tlocal ammunition = playerState.weaponState.ammunition
\tlocal definition = FirearmConfig.get(ammunition.weaponId)
\tif definition == nil then return false end
\tlocal kindId = if grantedRounds == nil''',
    "runtime publish def",
)
replace(runtime, "\t\tmaximumReserveRounds = FirearmConfig.BasicFirearm.MaximumReserveRounds,", "\t\tmaximumReserveRounds = definition.MaximumReserveRounds,", "runtime reserve")
replace(
    runtime,
    '''\tlocal payload: any = {
\t\tkindId = kindId,
\t\toperativeEntityId = playerState.operativeState.entityId,
\t\tweaponId = FirearmConfig.BasicFirearm.WeaponId,
\t}''',
    '''\tlocal payload: any = {
\t\tkindId = kindId,
\t\toperativeEntityId = playerState.operativeState.entityId,
\t\tweaponId = playerState.weaponState.weaponId,
\t}''',
    "runtime reload presentation",
)
replace(runtime, "\t\tweaponId = FirearmConfig.BasicFirearm.WeaponId,\n\t\tselectedTargetEntityId = targetEntityId,", "\t\tweaponId = playerState.weaponState.weaponId,\n\t\tselectedTargetEntityId = targetEntityId,", "runtime hit context")
replace(runtime, "\t\tweaponId = FirearmConfig.BasicFirearm.WeaponId,\n\t\ttargetEntityId = targetEntityId,", "\t\tweaponId = playerState.weaponState.weaponId,\n\t\ttargetEntityId = targetEntityId,", "runtime shot presentation")
replace(
    runtime,
    "local function evaluatePlayer(player: Player, playerState: PlayerCombatState, nowTimestamp: number)\n\tif not OperativeLifeService.isCombatAllowed(player) then",
    '''local function applyLockedLoadout(player: Player, playerState: PlayerCombatState)
\tlocal assignment = WeaponLoadoutService.read(player)
\tif assignment == nil or assignment.selectionStateId ~= "Locked" or assignment.weaponId == playerState.weaponState.weaponId or FirearmConfig.get(assignment.weaponId) == nil then return end
\tplayerState.generation += 1
\tplayerState.operativeState.combatStateId = CombatContracts.OperativeCombatStateIds.Ready
\tplayerState.operativeState.equippedWeaponId = assignment.weaponId
\tplayerState.weaponState = createWeaponState(assignment.weaponId)
\tplayerState.selectedTargetEntityId = nil
\ttable.clear(playerState.processedShotIds)
\ttable.clear(playerState.sightedByEntityId)
\tplayer:SetAttribute("LK_EquippedWeaponId", assignment.weaponId)
\tOperativeCombatRuntimeService.publishAmmunitionState(player)
end

local function evaluatePlayer(player: Player, playerState: PlayerCombatState, nowTimestamp: number)
\tapplyLockedLoadout(player, playerState)
\tif not OperativeLifeService.isCombatAllowed(player) then''',
    "runtime apply loadout",
)
replace(
    runtime,
    "\ttask.delay(FirearmConfig.BasicFirearm.ReloadDurationSeconds, function()",
    '''\tlocal definition = FirearmConfig.get(playerState.weaponState.weaponId)
\tif definition == nil then return end
\ttask.delay(definition.ReloadDurationSeconds, function()''',
    "runtime reload delay",
)
replace(
    runtime,
    "local function addPlayer(player: Player)\n\tresetPlayer(player)\n\tOperativeCombatRuntimeService.publishAmmunitionState(player)",
    '''local function addPlayer(player: Player)
\tresetPlayer(player)
\tlocal state = playerStates[player]
\tif state ~= nil then player:SetAttribute("LK_EquippedWeaponId", state.weaponState.weaponId) end
\tOperativeCombatRuntimeService.publishAmmunitionState(player)''',
    "runtime attribute",
)
replace(runtime, "\tplayerStates[player] = nil\nend", "\tplayerStates[player] = nil\n\tplayer:SetAttribute(\"LK_EquippedWeaponId\", nil)\nend", "runtime clear")

for path in [
    "games/living-kingdoms/src/server/Systems/EnemyLootService.luau",
    "games/living-kingdoms/src/server/Systems/AmmunitionCacheService.luau",
]:
    replace(
        path,
        "maximumReserveRounds = FirearmConfig.BasicFirearm.MaximumReserveRounds,",
        "maximumReserveRounds = (FirearmConfig.get(ammunition.weaponId) or FirearmConfig.BasicFirearm).MaximumReserveRounds,",
        "generic reserve " + path,
    )
replace(
    "games/living-kingdoms/src/server/Systems/AmmunitionCacheService.luau",
    "\t\tweaponId = definition.weaponId,\n\t\tavailableRounds = definition.rounds,",
    "\t\tweaponId = ammunition.weaponId,\n\t\tavailableRounds = (FirearmConfig.get(ammunition.weaponId) or FirearmConfig.BasicFirearm).AuthoredCacheRounds,",
    "cache current weapon",
)

server = "games/living-kingdoms/src/server/init.server.luau"
replace(
    server,
    "local function ensureProgressionNetwork()",
    '''local function ensureWeaponLoadoutNetwork()
\tlocal existingNetwork = ReplicatedStorage:FindFirstChild("WeaponLoadoutNetwork")
\tlocal network: Folder
\tif existingNetwork == nil then network=Instance.new("Folder") network.Name="WeaponLoadoutNetwork" network.Parent=ReplicatedStorage else assert(existingNetwork:IsA("Folder"),"WeaponLoadoutNetwork must be a Folder") network=existingNetwork end
\tfor _, remoteName in { "SelectionIntent", "State" } do
\t\tlocal existing=network:FindFirstChild(remoteName)
\t\tif existing==nil then local remote=Instance.new("RemoteEvent") remote.Name=remoteName remote.Parent=network else assert(existing:IsA("RemoteEvent"),remoteName.." must be a RemoteEvent") end
\tend
\tlocal existingRead=network:FindFirstChild("ReadState")
\tif existingRead==nil then local read=Instance.new("RemoteFunction") read.Name="ReadState" read.Parent=network else assert(existingRead:IsA("RemoteFunction"),"WeaponLoadoutNetwork.ReadState must be a RemoteFunction") end
end

local function ensureProgressionNetwork()''',
    "network function",
)
replace(server, "ensureClassNetwork()\nensureProgressionNetwork()", "ensureClassNetwork()\nensureWeaponLoadoutNetwork()\nensureProgressionNetwork()", "network ensure")
replace(server, "local WorldFoundationService = require(script.Systems.WorldFoundationService)\nlocal MissionDirectorService = require(script.Systems.MissionDirectorService)", "local WorldFoundationService = require(script.Systems.WorldFoundationService)\nlocal MissionDirectorService = require(script.Systems.MissionDirectorService)\nlocal WeaponLoadoutService = require(script.Systems.WeaponLoadoutService)", "service require")
replace(server, "EnemyLootService.start()\nAmmunitionScarcityValidationProbeService.start()", "EnemyLootService.start()\nAmmunitionScarcityValidationProbeService.start()\nMissionDirectorService.start()\nClassService.start()\nWeaponLoadoutService.start()", "service start")

client = "games/living-kingdoms/src/client/init.client.luau"
replace(client, "local ClassSelectionController = require(script.Controllers.ClassSelectionController)", "local ClassSelectionController = require(script.Controllers.ClassSelectionController)\nlocal WeaponSelectionController = require(script.Controllers.WeaponSelectionController)", "client require")
replace(client, "ClassSelectionController.start()\nClassSilhouetteController.start()", "ClassSelectionController.start()\nWeaponSelectionController.start()\nClassSilhouetteController.start()", "client start")

controller = "games/living-kingdoms/src/client/Controllers/WeaponController.luau"
replace(controller, "\t\"LK_HUD_MagazineCapacity\",\n\t\"LK_HUD_CombatStatus\",", "\t\"LK_HUD_MagazineCapacity\",\n\t\"LK_HUD_WeaponId\",\n\t\"LK_HUD_WeaponName\",\n\t\"LK_HUD_CombatStatus\",", "HUD attrs")
replace(controller, "\tselectedTargetEntityId: string?,", "\tselectedTargetEntityId: string?,\n\tcurrentWeaponId: string,", "controller type")
replace(controller, "\tselectedTargetEntityId = nil,\n\tinputBeganConnection = nil,", "\tselectedTargetEntityId = nil,\n\tcurrentWeaponId = FirearmConfig.BasicFirearm.WeaponId,\n\tinputBeganConnection = nil,", "controller state")
replace(controller, "\tif\n\t\tpayload.weaponId ~= FirearmConfig.BasicFirearm.WeaponId\n\t\tor not isWholeNonnegative(payload.loadedRounds)", "\tlocal definition = FirearmConfig.get(payload.weaponId)\n\tif\n\t\tdefinition == nil\n\t\tor not isWholeNonnegative(payload.loadedRounds)", "controller validate")
replace(controller, "\tpresentAmmunition(payload.loadedRounds, payload.reserveRounds, payload.magazineCapacity)\n\treturn true", "\tstate.currentWeaponId = definition.WeaponId\n\tlocalPlayer:SetAttribute(\"LK_HUD_WeaponId\", definition.WeaponId)\n\tlocalPlayer:SetAttribute(\"LK_HUD_WeaponName\", definition.ShortName)\n\tpresentAmmunition(payload.loadedRounds, payload.reserveRounds, payload.magazineCapacity)\n\treturn true", "controller publish")
source = Path(controller).read_text(encoding="utf-8")
source = source.replace("payload.weaponId == FirearmConfig.BasicFirearm.WeaponId", "FirearmConfig.isKnownWeaponId(payload.weaponId)")
source = source.replace("reloadIntentRemote:FireServer(FirearmConfig.BasicFirearm.WeaponId)", "reloadIntentRemote:FireServer(state.currentWeaponId)")
Path(controller).write_text(source, encoding="utf-8")

hud = "games/living-kingdoms/src/client/Controllers/HordeHUDController.luau"
replace(hud, "\tif ammoLabel ~= nil then\n\t\tammoLabel.Text = string.format(\"%02d  /  %02d\\nRESERVE  %03d\", loaded, capacity, reserve)", "\tif ammoLabel ~= nil then\n\t\tlocal weaponName = readStringAttribute(\"LK_HUD_WeaponName\", \"WEAPON\")\n\t\tammoLabel.Text = string.format(\"%s\\n%02d / %02d   RESERVE %03d\", weaponName, loaded, capacity, reserve)", "HUD name")

for path in [
    "games/living-kingdoms/src/client/Controllers/ConfirmedHitMarkerController.luau",
    "games/living-kingdoms/src/client/Controllers/FloatingDamageTextController.luau",
    "games/living-kingdoms/src/client/Controllers/WeaponAudioController.luau",
]:
    source = Path(path).read_text(encoding="utf-8")
    source = source.replace("payload.weaponId ~= FirearmConfig.BasicFirearm.WeaponId", "not FirearmConfig.isKnownWeaponId(payload.weaponId)")
    Path(path).write_text(source, encoding="utf-8")

floating = "games/living-kingdoms/src/client/Controllers/FloatingDamageTextController.luau"
replace(floating, "local function damageColor(damageAmount: number): Color3\n\tlocal configuredDamage = FirearmConfig.BasicFirearm.DamagePerHit", "local function damageColor(damageAmount: number, weaponId: string): Color3\n\tlocal configuredDamage = (FirearmConfig.get(weaponId) or FirearmConfig.BasicFirearm).DamagePerHit", "float baseline")
replace(floating, "local function activateEntry(shotId: string, damageAmount: number, worldPosition: Vector3)", "local function activateEntry(shotId: string, weaponId: string, damageAmount: number, worldPosition: Vector3)", "float signature")
replace(floating, "\tentry.label.TextColor3 = damageColor(damageAmount)", "\tentry.label.TextColor3 = damageColor(damageAmount, weaponId)", "float color")
replace(floating, "\tactivateEntry(payload.shotId, payload.damageAmount, payload.impactWorldPosition)", "\tactivateEntry(payload.shotId, payload.weaponId, payload.damageAmount, payload.impactWorldPosition)", "float call")

presentation = "games/living-kingdoms/src/client/Controllers/WeaponPresentationController.luau"
replace(presentation, "local BasicFirearmPresentationFactory = require(script.Parent.Parent.Presentation.BasicFirearmPresentationFactory)", "local WeaponPresentationFactory = require(script.Parent.Parent.Presentation.WeaponPresentationFactory)", "presentation require")
source = Path(presentation).read_text(encoding="utf-8")
source = source.replace("BasicFirearmPresentationFactory.BasicFirearmPresentationRig", "WeaponPresentationFactory.WeaponPresentationRig")
source = source.replace("BasicFirearmPresentationRig", "WeaponPresentationRig")
source = source.replace('local MODEL_NAME = "BasicFirearmPresentation"', 'local MODEL_NAME = "WeaponPresentation"')
source = source.replace('local GRIP_C0 = CFrame.new(0, -0.55, -0.15) * CFrame.Angles(math.rad(-8), math.rad(90), math.rad(-90))\n', "")
source = source.replace('local rig = BasicFirearmPresentationFactory.create()\n\trig.root.CFrame = hand.CFrame * GRIP_C0', 'local weaponId = player:GetAttribute("LK_EquippedWeaponId")\n\tlocal configuredId = if FirearmConfig.isKnownWeaponId(weaponId) then weaponId else FirearmConfig.BasicFirearm.WeaponId\n\tlocal rig = WeaponPresentationFactory.create(configuredId)\n\trig.root.CFrame = hand.CFrame * rig.gripC0')
source = source.replace("gripMotor.C0 = GRIP_C0", "gripMotor.C0 = rig.gripC0")
source = source.replace("payload.weaponId == FirearmConfig.BasicFirearm.WeaponId", "FirearmConfig.isKnownWeaponId(payload.weaponId)")
source = source.replace("payload.weaponId ~= FirearmConfig.BasicFirearm.WeaponId", "not FirearmConfig.isKnownWeaponId(payload.weaponId)")
source = source.replace("type PlayerBinding = {\n\tcharacterAddedConnection: RBXScriptConnection,\n\tcharacterRemovingConnection: RBXScriptConnection,\n}", "type PlayerBinding = {\n\tcharacterAddedConnection: RBXScriptConnection,\n\tcharacterRemovingConnection: RBXScriptConnection,\n\tweaponAttributeConnection: RBXScriptConnection,\n}")
source = source.replace("\t\tbinding.characterAddedConnection:Disconnect()\n\t\tbinding.characterRemovingConnection:Disconnect()", "\t\tbinding.characterAddedConnection:Disconnect()\n\t\tbinding.characterRemovingConnection:Disconnect()\n\t\tbinding.weaponAttributeConnection:Disconnect()")
source = source.replace('''\tlocal characterRemovingConnection = player.CharacterRemoving:Connect(function()
\t\tdestroyRig(player)
\tend)
\tstate.bindings[player] = {
\t\tcharacterAddedConnection = characterAddedConnection,
\t\tcharacterRemovingConnection = characterRemovingConnection,
\t}''', '''\tlocal characterRemovingConnection = player.CharacterRemoving:Connect(function()
\t\tdestroyRig(player)
\tend)
\tlocal weaponAttributeConnection = player:GetAttributeChangedSignal("LK_EquippedWeaponId"):Connect(function()
\t\tlocal currentCharacter = player.Character
\t\tif currentCharacter ~= nil then attachRig(player, currentCharacter) end
\tend)
\tstate.bindings[player] = {
\t\tcharacterAddedConnection = characterAddedConnection,
\t\tcharacterRemovingConnection = characterRemovingConnection,
\t\tweaponAttributeConnection = weaponAttributeConnection,
\t}''')
Path(presentation).write_text(source, encoding="utf-8")

for path in [
    "games/living-kingdoms/src/client/Presentation/RemoteWeaponMotionPresenter.luau",
    "games/living-kingdoms/src/client/Presentation/WeaponShotEffectPresenter.luau",
]:
    source = Path(path).read_text(encoding="utf-8")
    source = source.replace("local BasicFirearmPresentationFactory = require(script.Parent.BasicFirearmPresentationFactory)", "local WeaponPresentationFactory = require(script.Parent.WeaponPresentationFactory)")
    source = source.replace("BasicFirearmPresentationFactory.BasicFirearmPresentationRig", "WeaponPresentationFactory.WeaponPresentationRig")
    source = source.replace("BasicFirearmPresentationRig", "WeaponPresentationRig")
    Path(path).write_text(source, encoding="utf-8")

print("Applied weapon roster integration patch")
