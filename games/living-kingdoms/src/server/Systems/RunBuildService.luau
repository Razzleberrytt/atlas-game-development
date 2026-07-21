--!strict

-- RPG-0102 server-only lifecycle adapter for the pure RunBuildStateStore,
-- extended by RPG-0107 with the relic reward / slot / replacement entry points.
--
-- Reward events are a server-only validation source until RPG-0110 connects the
-- production elite, special, objective, horde, and boss reward owners. No client
-- remote is added here; the polished HUD and its network surface remain owned by
-- RPG-0111. The choice/replacement entry points validate the identity-free
-- contract intent shapes so a later remote can route through them unchanged.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunBuildStateStore = require(script.Parent.RunBuildStateStore)
local RunRpgContracts = require(ReplicatedStorage.Shared.RPG.RunRpgContracts)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)
local CombatContracts = require(ReplicatedStorage.Shared.Combat.CombatContracts)

local RunBuildService = {}

local store = RunBuildStateStore.new()
local started = false
local playerAddedConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil

local CompatibilityIds = RunRpgContracts.RelicCompatibilityIds
local WeaponIds = CombatContracts.WeaponIds

-- Maps a firearm to the relic compatibility category its loadout unlocks. Any
-- and Cooperative relics are never weapon-gated, so they are omitted here.
local weaponCompatibilityById: { [string]: string } = {
	[WeaponIds.LightMachineGun] = CompatibilityIds.Automatic,
	[WeaponIds.SubmachineGun] = CompatibilityIds.Automatic,
	[WeaponIds.BreachShotgun] = CompatibilityIds.Shotgun,
	[WeaponIds.SniperRifle] = CompatibilityIds.Sniper,
}

local function operativeId(player: Player): string
	return tostring(player.UserId)
end

local function register(player: Player)
	store:registerOperative(operativeId(player))
end

local function loadoutCompatibilityIds(player: Player): { [string]: boolean }
	local weaponId = player:GetAttribute("LK_EquippedWeaponId")
	if type(weaponId) ~= "string" or not FirearmConfig.isKnownWeaponId(weaponId) then
		weaponId = FirearmConfig.BasicFirearm.WeaponId
	end
	local tags = {}
	local compatibilityId = weaponCompatibilityById[weaponId]
	if compatibilityId ~= nil then
		tags[compatibilityId] = true
	end
	return tags
end

function RunBuildService.start()
	if started then
		return
	end
	started = true
	store:startOperation()
	for _, player in Players:GetPlayers() do
		register(player)
	end
	playerAddedConnection = Players.PlayerAdded:Connect(register)
	playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		store:disconnectOperative(operativeId(player))
	end)
end

function RunBuildService.resetOperation()
	if not started then
		return
	end
	store:startOperation()
	for _, player in Players:GetPlayers() do
		register(player)
	end
end

function RunBuildService.stop()
	if not started then
		return
	end
	started = false
	if playerAddedConnection ~= nil then
		playerAddedConnection:Disconnect()
		playerAddedConnection = nil
	end
	if playerRemovingConnection ~= nil then
		playerRemovingConnection:Disconnect()
		playerRemovingConnection = nil
	end
	store:stopOperation()
end

function RunBuildService.readOperationGeneration(): number
	return store:readOperationGeneration()
end

function RunBuildService.readSquadUpgradeStacks(): RunBuildStateStore.UpgradeStacks
	return store:readUpgradeStacks()
end

function RunBuildService.readSafeSnapshot(player: Player): any?
	return store:readSafeSnapshot(operativeId(player))
end

function RunBuildService.commitSquadUpgradeStacks(
	operationGeneration: number,
	requestId: string,
	upgradeStacks: RunBuildStateStore.UpgradeStacks
): (boolean, string?)
	return store:commitUpgradeStacks(operationGeneration, requestId, upgradeStacks)
end

-- Server-only reward source. Offers a bounded two-relic choice to one operative
-- from a confirmed server-owned reward event.
function RunBuildService.offerRelicReward(
	player: Player,
	requestId: string,
	sourceId: string
): (boolean, string?, number?)
	return store:enqueueRelicReward(
		store:readOperationGeneration(),
		requestId,
		operativeId(player),
		sourceId,
		loadoutCompatibilityIds(player)
	)
end

function RunBuildService.submitRelicChoice(
	player: Player,
	intent: RunRpgContracts.RelicChoiceIntent
): (boolean, string?)
	if not RunRpgContracts.validateRelicChoiceIntent(intent) then
		return false, RunRpgContracts.RunRpgRejectionReasonIds.InvalidIntent
	end
	return store:chooseRelic(
		intent.operationGeneration,
		intent.requestId,
		operativeId(player),
		intent.rewardSequence,
		intent.relicId
	)
end

function RunBuildService.submitRelicReplacement(
	player: Player,
	intent: RunRpgContracts.RelicReplacementIntent
): (boolean, string?)
	if not RunRpgContracts.validateRelicReplacementIntent(intent) then
		return false, RunRpgContracts.RunRpgRejectionReasonIds.InvalidIntent
	end
	return store:replaceRelic(
		intent.operationGeneration,
		intent.requestId,
		operativeId(player),
		intent.rewardSequence,
		intent.relicId,
		intent.replaceSlotIndex
	)
end

return table.freeze(RunBuildService)
