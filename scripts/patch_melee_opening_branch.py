from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    target = Path(path)
    source = target.read_text()
    if new in source:
        return
    count = source.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one patch anchor, found {count}: {old[:80]!r}")
    target.write_text(source.replace(old, new, 1))


runtime = "games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau"
replace_once(
    runtime,
    'local HordeExperienceConfig = require(ReplicatedStorage.Shared.Config.HordeExperienceConfig)\n',
    'local HordeExperienceConfig = require(ReplicatedStorage.Shared.Config.HordeExperienceConfig)\n'
    'local PrimaryCombatModeContracts = require(ReplicatedStorage.Shared.Combat.PrimaryCombatModeContracts)\n',
)
replace_once(
    runtime,
    'local OperativeLifeService = require(script.Parent.OperativeLifeService)\n',
    'local OperativeLifeService = require(script.Parent.OperativeLifeService)\n'
    'local PrimaryCombatModeService = require(script.Parent.PrimaryCombatModeService)\n',
)
replace_once(
    runtime,
    '\tgrantFoundAmmunition: (player: Player, requestedRounds: number) -> number,\n'
    '\tevaluateAt: (serverTimestamp: number) -> (),\n',
    '\tgrantFoundAmmunition: (player: Player, requestedRounds: number) -> number,\n'
    '\tresetForReplay: () -> (),\n'
    '\tevaluateAt: (serverTimestamp: number) -> (),\n',
)
replace_once(
    runtime,
    'local AIM_CONE_MINIMUM_DOT = math.cos(math.rad(13))\n',
    'local AIM_CONE_MINIMUM_DOT = math.cos(math.rad(13))\n'
    'local PrimaryCombatModeIds = PrimaryCombatModeContracts.ModeIds\n\n'
    'local function firearmModeActive(player: Player): boolean\n'
    '\treturn PrimaryCombatModeService.readMode(player) == PrimaryCombatModeIds.Firearm\n'
    'end\n',
)
replace_once(
    runtime,
    '\tlocal retained = retainedCombatByOperativeEntityId[operativeEntityId]\n'
    '\tretainedCombatByOperativeEntityId[operativeEntityId] = nil\n'
    '\tlocal weaponId = if retained ~= nil then retained.weaponId else FirearmConfig.DefaultSelectableWeaponId\n',
    '\tlocal retained = retainedCombatByOperativeEntityId[operativeEntityId]\n'
    '\tretainedCombatByOperativeEntityId[operativeEntityId] = nil\n'
    '\tif retained ~= nil then\n'
    '\t\tPrimaryCombatModeService.setMode(player, PrimaryCombatModeIds.Firearm)\n'
    '\tend\n'
    '\tlocal weaponId = if retained ~= nil then retained.weaponId else FirearmConfig.DefaultSelectableWeaponId\n',
)
replace_once(
    runtime,
    '\tlocal discoverable = false\n'
    '\tfor _, candidateId in FirearmConfig.DiscoverableWeaponIds do\n',
    '\tlocal discoverable = weaponId == FirearmConfig.DefaultSelectableWeaponId\n'
    '\tfor _, candidateId in FirearmConfig.DiscoverableWeaponIds do\n',
)
replace_once(
    runtime,
    '\tsetPlayerAttribute(player, "LK_EquippedWeaponId", weaponId)\n'
    '\tRelicModifierService.resetSustainedShots(player)\n'
    '\tOperativeCombatRuntimeService.publishAmmunitionState(player)\n'
    '\treturn true\nend\n\nfunction OperativeCombatRuntimeService.grantFoundAmmunition',
    '\tsetPlayerAttribute(player, "LK_EquippedWeaponId", weaponId)\n'
    '\tPrimaryCombatModeService.setMode(player, PrimaryCombatModeIds.Firearm)\n'
    '\tRelicModifierService.resetSustainedShots(player)\n'
    '\tOperativeCombatRuntimeService.publishAmmunitionState(player)\n'
    '\treturn true\nend\n\nfunction OperativeCombatRuntimeService.grantFoundAmmunition',
)
replace_once(
    runtime,
    '\tif not OperativeLifeService.isCombatAllowed(player) then\n'
    '\t\tdiscloseTarget(player, playerState, nil, nowTimestamp)\n'
    '\t\tRelicModifierService.resetSustainedShots(player)\n'
    '\t\tlocal restricted = OperativeLifeService.applyCombatRestrictions(player, playerState)\n'
    '\t\tif restricted ~= nil then\n'
    '\t\t\tplayerStates[player] = restricted\n'
    '\t\tend\n'
    '\t\treturn\n'
    '\tend\n'
    '\tlocal operativePosition = getOperativePosition(player)\n',
    '\tif not OperativeLifeService.isCombatAllowed(player) then\n'
    '\t\tdiscloseTarget(player, playerState, nil, nowTimestamp)\n'
    '\t\tRelicModifierService.resetSustainedShots(player)\n'
    '\t\tlocal restricted = OperativeLifeService.applyCombatRestrictions(player, playerState)\n'
    '\t\tif restricted ~= nil then\n'
    '\t\t\tplayerStates[player] = restricted\n'
    '\t\tend\n'
    '\t\treturn\n'
    '\tend\n'
    '\tif not firearmModeActive(player) then\n'
    '\t\tplayerState.isFiring = false\n'
    '\t\tplayerState.aimDirection = nil\n'
    '\t\tdiscloseTarget(player, playerState, nil, nowTimestamp)\n'
    '\t\tRelicModifierService.resetSustainedShots(player)\n'
    '\t\treturn\n'
    '\tend\n'
    '\tlocal operativePosition = getOperativePosition(player)\n',
)
replace_once(
    runtime,
    '\tlocal playerState = playerStates[player]\n'
    '\tif playerState == nil then\n'
    '\t\treturn\n'
    '\tend\n'
    '\tlocal direction = aimDirection :: Vector3\n',
    '\tlocal playerState = playerStates[player]\n'
    '\tif playerState == nil then\n'
    '\t\treturn\n'
    '\tend\n'
    '\tif not firearmModeActive(player) then\n'
    '\t\tif isFiring == false then\n'
    '\t\t\tplayerState.isFiring = false\n'
    '\t\t\tplayerState.aimDirection = nil\n'
    '\t\tend\n'
    '\t\treturn\n'
    '\tend\n'
    '\tlocal direction = aimDirection :: Vector3\n',
)
replace_once(
    runtime,
    '\tif\n'
    '\t\tplayerState == nil\n'
    '\t\tor not OperativeLifeService.isCombatAllowed(player)\n'
    '\t\tor weaponId ~= playerState.operativeState.equippedWeaponId\n',
    '\tif\n'
    '\t\tplayerState == nil\n'
    '\t\tor not firearmModeActive(player)\n'
    '\t\tor not OperativeLifeService.isCombatAllowed(player)\n'
    '\t\tor weaponId ~= playerState.operativeState.equippedWeaponId\n',
)
replace_once(
    runtime,
    'local function addPlayer(player: Player)\n',
    'function OperativeCombatRuntimeService.resetForReplay()\n'
    '\ttable.clear(retainedCombatByOperativeEntityId)\n'
    '\tfor player in playerStates do\n'
    '\t\tplayerStates[player] = createPlayerState(player)\n'
    '\t\tlocal state = playerStates[player]\n'
    '\t\tsetPlayerAttribute(player, "LK_EquippedWeaponId", state.weaponState.weaponId)\n'
    '\t\tRelicModifierService.resetSustainedShots(player)\n'
    '\t\tOperativeCombatRuntimeService.publishAmmunitionState(player)\n'
    '\tend\n'
    'end\n\n'
    'local function addPlayer(player: Player)\n',
)

survival = "games/living-kingdoms/src/server/Systems/SurvivalLootService.luau"
replace_once(
    survival,
    'local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)\n',
    'local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)\n'
    'local PrimaryCombatModeContracts = require(ReplicatedStorage.Shared.Combat.PrimaryCombatModeContracts)\n',
)
replace_once(
    survival,
    'local Service = {}\n',
    'local Service = {}\n'
    'local PrimaryCombatModeAttributeName = PrimaryCombatModeContracts.AttributeName\n'
    'local PrimaryCombatModeIds = PrimaryCombatModeContracts.ModeIds\n',
)
replace_once(
    survival,
    '\telseif item.kindId == "weapon" and item.weaponId ~= nil then\n'
    '\t\tif not OperativeCombatRuntimeService.equipFoundWeapon(player, item.weaponId) then\n'
    '\t\t\treturn false, "WEAPON CANNOT BE EQUIPPED RIGHT NOW"\n'
    '\t\tend\n'
    '\t\tstate.foundWeapon = true\n',
    '\telseif item.kindId == "weapon" and item.weaponId ~= nil then\n'
    '\t\tif not OperativeCombatRuntimeService.equipFoundWeapon(player, item.weaponId) then\n'
    '\t\t\treturn false, "WEAPON CANNOT BE EQUIPPED RIGHT NOW"\n'
    '\t\tend\n'
    '\t\tif item.weaponId ~= Config.OpeningRecoveryWeaponId then\n'
    '\t\t\tstate.foundWeapon = true\n'
    '\t\tend\n',
)
replace_once(
    survival,
    '\t\t\tlocal roll = (index * 37 + player.UserId) % 100\n'
    '\t\t\tlocal shouldFindWeapon = not state.foundWeapon\n'
    '\t\t\t\tand not hasPendingWeapon(state)\n',
    '\t\t\tlocal roll = (index * 37 + player.UserId) % 100\n'
    '\t\t\tlocal shouldRecoverOpeningWeapon = state.openedChests == Config.OpeningRecoveryByOpenedChest\n'
    '\t\t\t\tand player:GetAttribute(PrimaryCombatModeAttributeName) == PrimaryCombatModeIds.Melee\n'
    '\t\t\t\tand not hasPendingWeapon(state)\n'
    '\t\t\tlocal shouldFindWeapon = not shouldRecoverOpeningWeapon\n'
    '\t\t\t\tand not state.foundWeapon\n'
    '\t\t\t\tand not hasPendingWeapon(state)\n',
)
replace_once(
    survival,
    '\t\t\tif shouldFindWeapon then\n'
    '\t\t\t\tlocal weapons = Config.DiscoverableWeaponIds\n'
    '\t\t\t\tlocal weaponId = weapons[(index % #weapons) + 1]\n'
    '\t\t\t\tstageLoot(state, {\n'
    '\t\t\t\t\titemId = chestId .. ".weapon",\n'
    '\t\t\t\t\tkindId = "weapon",\n'
    '\t\t\t\t\tdisplayName = (FirearmConfig.get(weaponId) :: any).DisplayName,\n'
    '\t\t\t\t\tquantity = 1,\n'
    '\t\t\t\t\trarityId = "Rare",\n'
    '\t\t\t\t\tchestId = chestId,\n'
    '\t\t\t\t\tworldPosition = position,\n'
    '\t\t\t\t\tweaponId = weaponId,\n'
    '\t\t\t\t})\n'
    '\t\t\tend\n',
    '\t\t\tif shouldRecoverOpeningWeapon or shouldFindWeapon then\n'
    '\t\t\t\tlocal weaponId: string\n'
    '\t\t\t\tlocal rarityId: string\n'
    '\t\t\t\tif shouldRecoverOpeningWeapon then\n'
    '\t\t\t\t\tweaponId = Config.OpeningRecoveryWeaponId\n'
    '\t\t\t\t\trarityId = "Uncommon"\n'
    '\t\t\t\telse\n'
    '\t\t\t\t\tlocal weapons = Config.DiscoverableWeaponIds\n'
    '\t\t\t\t\tweaponId = weapons[(index % #weapons) + 1]\n'
    '\t\t\t\t\trarityId = "Rare"\n'
    '\t\t\t\tend\n'
    '\t\t\t\tstageLoot(state, {\n'
    '\t\t\t\t\titemId = chestId .. ".weapon",\n'
    '\t\t\t\t\tkindId = "weapon",\n'
    '\t\t\t\t\tdisplayName = (FirearmConfig.get(weaponId) :: any).DisplayName,\n'
    '\t\t\t\t\tquantity = 1,\n'
    '\t\t\t\t\trarityId = rarityId,\n'
    '\t\t\t\t\tchestId = chestId,\n'
    '\t\t\t\t\tworldPosition = position,\n'
    '\t\t\t\t\tweaponId = weaponId,\n'
    '\t\t\t\t})\n'
    '\t\t\tend\n',
)
replace_once(
    survival,
    'function Service.stop()\n',
    'function Service.resetForReplay()\n'
    '\tif not started then\n'
    '\t\treturn\n'
    '\tend\n'
    '\tService.stop()\n'
    '\tService.start()\n'
    'end\n\n'
    'function Service.stop()\n',
)

presentation = "games/living-kingdoms/src/client/Controllers/WeaponPresentationController.luau"
replace_once(
    presentation,
    'local CombatContracts = require(ReplicatedStorage.Shared.Combat.CombatContracts)\n',
    'local CombatContracts = require(ReplicatedStorage.Shared.Combat.CombatContracts)\n'
    'local PrimaryCombatModeContracts = require(ReplicatedStorage.Shared.Combat.PrimaryCombatModeContracts)\n',
)
replace_once(
    presentation,
    '\tweaponAttributeConnection: RBXScriptConnection,\n',
    '\tweaponAttributeConnection: RBXScriptConnection,\n'
    '\tcombatModeAttributeConnection: RBXScriptConnection,\n',
)
replace_once(
    presentation,
    'local MAX_PRESENTED_SHOT_IDS = 128\n',
    'local MAX_PRESENTED_SHOT_IDS = 128\n'
    'local PRIMARY_COMBAT_MODE_ATTRIBUTE = PrimaryCombatModeContracts.AttributeName\n'
    'local PrimaryCombatModeIds = PrimaryCombatModeContracts.ModeIds\n',
)
replace_once(
    presentation,
    '\tdestroyRig(player)\n'
    '\tif not state.started or character.Parent == nil then\n'
    '\t\treturn\n'
    '\tend\n'
    '\tlocal weaponId = player:GetAttribute("LK_EquippedWeaponId")\n',
    '\tdestroyRig(player)\n'
    '\tif not state.started or character.Parent == nil then\n'
    '\t\treturn\n'
    '\tend\n'
    '\tif player:GetAttribute(PRIMARY_COMBAT_MODE_ATTRIBUTE) == PrimaryCombatModeIds.Melee then\n'
    '\t\treturn\n'
    '\tend\n'
    '\tlocal weaponId = player:GetAttribute("LK_EquippedWeaponId")\n',
)
replace_once(
    presentation,
    '\t\tbinding.weaponAttributeConnection:Disconnect()\n'
    '\t\tstate.bindings[player] = nil\n',
    '\t\tbinding.weaponAttributeConnection:Disconnect()\n'
    '\t\tbinding.combatModeAttributeConnection:Disconnect()\n'
    '\t\tstate.bindings[player] = nil\n',
)
replace_once(
    presentation,
    '\tlocal weaponAttributeConnection = player:GetAttributeChangedSignal("LK_EquippedWeaponId"):Connect(function()\n'
    '\t\tlocal currentCharacter = player.Character\n'
    '\t\tif currentCharacter ~= nil then\n'
    '\t\t\tattachRig(player, currentCharacter)\n'
    '\t\tend\n'
    '\tend)\n'
    '\tstate.bindings[player] = {\n'
    '\t\tcharacterAddedConnection = characterAddedConnection,\n'
    '\t\tcharacterRemovingConnection = characterRemovingConnection,\n'
    '\t\tweaponAttributeConnection = weaponAttributeConnection,\n'
    '\t}\n',
    '\tlocal weaponAttributeConnection = player:GetAttributeChangedSignal("LK_EquippedWeaponId"):Connect(function()\n'
    '\t\tlocal currentCharacter = player.Character\n'
    '\t\tif currentCharacter ~= nil then\n'
    '\t\t\tattachRig(player, currentCharacter)\n'
    '\t\tend\n'
    '\tend)\n'
    '\tlocal combatModeAttributeConnection = player:GetAttributeChangedSignal(PRIMARY_COMBAT_MODE_ATTRIBUTE):Connect(function()\n'
    '\t\tlocal currentCharacter = player.Character\n'
    '\t\tif currentCharacter ~= nil then\n'
    '\t\t\tattachRig(player, currentCharacter)\n'
    '\t\telse\n'
    '\t\t\tdestroyRig(player)\n'
    '\t\tend\n'
    '\tend)\n'
    '\tstate.bindings[player] = {\n'
    '\t\tcharacterAddedConnection = characterAddedConnection,\n'
    '\t\tcharacterRemovingConnection = characterRemovingConnection,\n'
    '\t\tweaponAttributeConnection = weaponAttributeConnection,\n'
    '\t\tcombatModeAttributeConnection = combatModeAttributeConnection,\n'
    '\t}\n',
)

lifecycle = "games/living-kingdoms/src/server/Systems/OperationLifecycleService.luau"
replace_once(
    lifecycle,
    'local OperativeLifeService = require(script.Parent.OperativeLifeService)\n',
    'local OperativeCombatRuntimeService = require(script.Parent.OperativeCombatRuntimeService)\n'
    'local OperativeLifeService = require(script.Parent.OperativeLifeService)\n'
    'local PrimaryCombatModeService = require(script.Parent.PrimaryCombatModeService)\n',
)
replace_once(
    lifecycle,
    'local SquadFailureService = require(script.Parent.SquadFailureService)\n',
    'local SquadFailureService = require(script.Parent.SquadFailureService)\n'
    'local SurvivalLootService = require(script.Parent.SurvivalLootService)\n',
)
replace_once(
    lifecycle,
    '\tfor _, ownerId in MatchResultConfig.ReplayStartOrder do\n',
    '\t-- These application-scoped owners carry run-sensitive state but predate the\n'
    '\t-- cleanup-owner vocabulary. Reset them explicitly at the replay seam so a\n'
    '\t-- deliberate new run always returns to the same melee opening contract.\n'
    '\tPrimaryCombatModeService.resetAllToMelee()\n'
    '\tOperativeCombatRuntimeService.resetForReplay()\n'
    '\tSurvivalLootService.resetForReplay()\n'
    '\tfor _, ownerId in MatchResultConfig.ReplayStartOrder do\n',
)

print("Applied melee opening/firearm recovery exact-text patch set")
