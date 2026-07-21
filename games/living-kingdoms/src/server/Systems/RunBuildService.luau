--!strict

-- RPG-0102 server-only lifecycle adapter for the pure RunBuildStateStore,
-- extended by RPG-0107 with the relic reward / slot / replacement entry points,
-- by RPG-0110 with the live production reward fan-out, and by RPG-0111 with the
-- narrow client network surface.
--
-- Clients receive only safe copied snapshots of their own build and may request
-- exactly two things: choosing an offered relic, or replacing one occupied slot
-- with an offered relic. Both requests are identity-free -- the server derives
-- the operative from the calling player -- and both pass the same store
-- validation as the server-only entry points. Nothing a client sends can create
-- a reward, reroll an offer, choose for another operative, or exceed a slot.

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
local choiceConnection: RBXScriptConnection? = nil
local replacementConnection: RBXScriptConnection? = nil
local lastRequestTimestamps: { [Player]: number } = {}

local runBuildNetwork = ReplicatedStorage:WaitForChild("RunBuildNetwork")
local stateRemote = runBuildNetwork:WaitForChild("State") :: RemoteEvent
local readStateRemote = runBuildNetwork:WaitForChild("ReadState") :: RemoteFunction
local submitChoiceRemote = runBuildNetwork:WaitForChild("SubmitRelicChoice") :: RemoteEvent
local submitReplacementRemote = runBuildNetwork:WaitForChild("SubmitRelicReplacement") :: RemoteEvent

local RunRpgConfig = require(ReplicatedStorage.Shared.Config.RunRpgConfig)

local CompatibilityIds = RunRpgContracts.RelicCompatibilityIds
local Rejections = RunRpgContracts.RunRpgRejectionReasonIds
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

-- Publishing is explicit: every mutating entry point republishes, so no polling
-- loop or extra connection is required to keep a client's view current.
local function publishTo(player: Player)
	local snapshot = store:readSafeSnapshot(operativeId(player))
	if snapshot ~= nil then
		stateRemote:FireClient(player, snapshot)
	end
end

local function publishAll()
	for _, player in Players:GetPlayers() do
		publishTo(player)
	end
end

-- One shared client-request cooldown, mirroring the upgrade-choice surface.
local REQUEST_COOLDOWN_SECONDS = RunRpgConfig.Limits.minimumChoiceRequestIntervalSeconds

local function acceptsRequest(player: Player): boolean
	local now = os.clock()
	local last = lastRequestTimestamps[player]
	if last ~= nil and now - last < REQUEST_COOLDOWN_SECONDS then
		return false
	end
	lastRequestTimestamps[player] = now
	return true
end

local function rejectionFor(player: Player, requestId: unknown, reasonId: string)
	stateRemote:FireClient(
		player,
		table.freeze({
			operationId = RunRpgContracts.RunBuildNetworkOperationIds.Rejected,
			operationGeneration = store:readOperationGeneration(),
			revision = 0,
			rejectionReasonId = reasonId,
			requestId = if type(requestId) == "string" then requestId else nil,
		})
	)
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
	playerAddedConnection = Players.PlayerAdded:Connect(function(player)
		register(player)
		publishTo(player)
	end)
	playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		store:disconnectOperative(operativeId(player))
		lastRequestTimestamps[player] = nil
	end)
	choiceConnection = submitChoiceRemote.OnServerEvent:Connect(function(player, intent, ...)
		if select("#", ...) ~= 0 then
			return
		end
		if not acceptsRequest(player) then
			rejectionFor(player, if type(intent) == "table" then intent.requestId else nil, Rejections.InvalidIntent)
			return
		end
		local accepted, reason = RunBuildService.submitRelicChoice(player, intent :: any)
		if accepted then
			publishTo(player)
		else
			rejectionFor(
				player,
				if type(intent) == "table" then intent.requestId else nil,
				reason or Rejections.InvalidIntent
			)
		end
	end)
	replacementConnection = submitReplacementRemote.OnServerEvent:Connect(function(player, intent, ...)
		if select("#", ...) ~= 0 then
			return
		end
		if not acceptsRequest(player) then
			rejectionFor(player, if type(intent) == "table" then intent.requestId else nil, Rejections.InvalidIntent)
			return
		end
		local accepted, reason = RunBuildService.submitRelicReplacement(player, intent :: any)
		if accepted then
			publishTo(player)
		else
			rejectionFor(
				player,
				if type(intent) == "table" then intent.requestId else nil,
				reason or Rejections.InvalidIntent
			)
		end
	end)
	readStateRemote.OnServerInvoke = function(player: Player)
		return store:readSafeSnapshot(operativeId(player))
	end
	publishAll()
end

function RunBuildService.resetOperation()
	if not started then
		return
	end
	store:startOperation()
	for _, player in Players:GetPlayers() do
		register(player)
	end
	publishAll()
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
	if choiceConnection ~= nil then
		choiceConnection:Disconnect()
		choiceConnection = nil
	end
	if replacementConnection ~= nil then
		replacementConnection:Disconnect()
		replacementConnection = nil
	end
	readStateRemote.OnServerInvoke = nil :: any
	table.clear(lastRequestTimestamps)
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

-- Server-only relic read for the authoritative RPG-0108 effect owners. No client
-- ever receives this; the replicated build view remains readSafeSnapshot.
function RunBuildService.readEquippedRelicIds(player: Player): RunBuildStateStore.EquippedRelicRead?
	return store:readEquippedRelicIds(operativeId(player))
end

function RunBuildService.readRelicCounter(player: Player, relicId: string): number?
	return store:readRelicCounter(operativeId(player), relicId)
end

function RunBuildService.setRelicCounter(player: Player, relicId: string, value: number): boolean
	return store:setRelicCounter(operativeId(player), relicId, value)
end

function RunBuildService.consumeRelicCharge(player: Player, relicId: string): boolean
	return store:consumeRelicCharge(operativeId(player), relicId)
end

-- Server-only counted-relic advance for the authoritative effect owners.
function RunBuildService.advanceRelicCounter(
	player: Player,
	relicId: string,
	increment: number,
	threshold: number
): RunBuildStateStore.RelicCounterAdvance?
	return store:advanceRelicCounter(operativeId(player), relicId, increment, threshold)
end

function RunBuildService.commitSquadUpgradeStacks(
	operationGeneration: number,
	requestId: string,
	upgradeStacks: RunBuildStateStore.UpgradeStacks
): (boolean, string?)
	local accepted, reason = store:commitUpgradeStacks(operationGeneration, requestId, upgradeStacks)
	if accepted then
		publishAll()
	end
	return accepted, reason
end

-- Server-only reward source. Offers a bounded two-relic choice to one operative
-- from a confirmed server-owned reward event.
function RunBuildService.offerRelicReward(
	player: Player,
	requestId: string,
	sourceId: string
): (boolean, string?, number?)
	local accepted, reason, rewardSequence = store:enqueueRelicReward(
		store:readOperationGeneration(),
		requestId,
		operativeId(player),
		sourceId,
		loadoutCompatibilityIds(player)
	)
	if accepted then
		publishTo(player)
	end
	return accepted, reason, rewardSequence
end

--[[
	RPG-0110 production reward fan-out. One server-confirmed event opens the same
	bounded choice for every currently registered operative, deriving a distinct
	deterministic request ID per operative from the event's own ID. Operatives with
	a full reward queue, a replayed event, or no remaining compatible relic are
	rejected individually and silently, exactly as a single offer would be.
	Returns how many operatives actually received an offer.
]]
function RunBuildService.offerRelicRewardToParticipants(eventId: string, sourceId: string): number
	if not started or type(eventId) ~= "string" or eventId == "" then
		return 0
	end
	local offeredCount = 0
	for _, player in Players:GetPlayers() do
		local accepted = RunBuildService.offerRelicReward(player, eventId .. ":" .. operativeId(player), sourceId)
		if accepted then
			offeredCount += 1
		end
	end
	return offeredCount
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
