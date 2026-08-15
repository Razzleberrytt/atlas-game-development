--!strict

-- Canonical server owner for live character XP. Other server systems award XP
-- through this module; there is deliberately no client mutation endpoint.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.CharacterProgressionConfig)
local Resolver = require(ReplicatedStorage.Shared.Progression.CharacterProgressionResolver)

local Service = {}

local started = false
local statesByUserId: { [number]: any } = {}
local nextListenerId = 0
local levelUpListeners: { [number]: (any) -> () } = {}
local progressionChangedListeners: { [number]: (any) -> () } = {}
local persistenceWriter: ((number, any, string, string?, number) -> any)? = nil

local function isPlayer(player: any): boolean
	return typeof(player) == "Instance" and player:IsA("Player")
end

local function validSourceId(sourceId: any): boolean
	if type(sourceId) ~= "string" then
		return false
	end
	for _, configured in Config.SourceIds do
		if sourceId == configured then
			return true
		end
	end
	return false
end

local function publishAttributes(player: Player, state: any)
	player:SetAttribute("CharacterLevel", state.Level)
	player:SetAttribute("CharacterTotalXP", state.TotalXP)
	player:SetAttribute("CharacterXPIntoLevel", state.XPIntoLevel)
	player:SetAttribute("CharacterXPToNextLevel", state.XPRemainingToNextLevel)
	player:SetAttribute("CharacterIsLevelCap", state.IsLevelCap)
end

local function notify(listeners: { [number]: (any) -> () }, payload: any)
	for _, callback in listeners do
		local ok, message = pcall(callback, payload)
		if not ok then
			warn("[CharacterProgressionService] listener failed: " .. tostring(message))
		end
	end
end

local function setState(player: Player, state: any)
	statesByUserId[player.UserId] = state
	publishAttributes(player, state)
end

local function ensureState(player: Player): any
	local existing = statesByUserId[player.UserId]
	if existing ~= nil then
		return existing
	end
	local state = Resolver.normalizeState(nil, Config)
	setState(player, state)
	return state
end

local function initializePlayer(player: Player)
	ensureState(player)
end

function Service.start()
	if started then
		return
	end
	started = true
	for _, player in Players:GetPlayers() do
		initializePlayer(player)
	end
	Players.PlayerAdded:Connect(initializePlayer)
	Players.PlayerRemoving:Connect(function(player: Player)
		statesByUserId[player.UserId] = nil
	end)
end

-- InventoryLiveService supplies this once its lease lifecycle is mounted. The
-- writer must durably accept the candidate state before this service publishes
-- it. This keeps live attributes and saved progression in lockstep.
function Service.configurePersistence(writer: any): boolean
	if type(writer) ~= "function" then
		return false
	end
	persistenceWriter = writer
	return true
end

-- Server-side persistence adapters may hydrate malformed or historical state.
-- The pure resolver canonicalizes it; derived Level/XPIntoLevel fields are never
-- trusted from storage.
function Service.hydratePlayer(player: Player, rawState: any): any
	if not isPlayer(player) then
		return table.freeze({ Accepted = false, ReasonId = "InvalidPlayer", State = nil })
	end
	local state = Resolver.normalizeState(rawState, Config)
	setState(player, state)
	return table.freeze({ Accepted = true, ReasonId = "ProgressionHydrated", State = state })
end

function Service.exportPlayerState(player: Player): any
	if not isPlayer(player) then
		return nil
	end
	return Resolver.serializeState(ensureState(player), Config)
end

function Service.getState(player: Player): any
	if not isPlayer(player) then
		return nil
	end
	return ensureState(player)
end

-- This is the only XP mutation API. Damage, targets, completion state, source,
-- amount and attribution are all resolved by server systems before this call.
function Service.awardXP(player: Player, amount: any, sourceId: any, attributionId: any?): any
	if not isPlayer(player) then
		return table.freeze({ Accepted = false, ReasonId = "InvalidPlayer" })
	end
	if not validSourceId(sourceId) then
		return table.freeze({ Accepted = false, ReasonId = "InvalidXPSource" })
	end
	if attributionId ~= nil and (type(attributionId) ~= "string" or attributionId == "") then
		return table.freeze({ Accepted = false, ReasonId = "InvalidAttributionId" })
	end

	local previousState = ensureState(player)
	local resolution = Resolver.awardXP(previousState, amount, Config)
	if resolution.Accepted ~= true then
		return resolution
	end

	local writer = persistenceWriter
	if writer == nil then
		return table.freeze({ Accepted = false, ReasonId = "ProgressionPersistenceUnavailable", State = previousState })
	end
	local persisted = writer(player.UserId, resolution.State, sourceId, attributionId, os.time())
	if type(persisted) ~= "table" or persisted.Accepted ~= true then
		return table.freeze({
			Accepted = false,
			ReasonId = if type(persisted) == "table" then persisted.ReasonId else "ProgressionSaveFailed",
			State = previousState,
		})
	end
	if persisted.AlreadyApplied == true then
		local storedState = Resolver.normalizeState(persisted.State, Config)
		setState(player, storedState)
		return table.freeze({
			Accepted = true,
			ReasonId = "XPAlreadyAwarded",
			SourceId = sourceId,
			AttributionId = attributionId,
			RequestedXP = resolution.RequestedXP,
			AwardedXP = 0,
			LevelsGained = 0,
			LevelUps = table.freeze({}),
			PreviousState = previousState,
			State = storedState,
		})
	end

	local committedState = Resolver.normalizeState(persisted.State or resolution.State, Config)
	setState(player, committedState)
	local payload = table.freeze({
		Player = player,
		UserId = player.UserId,
		SourceId = sourceId,
		AttributionId = attributionId,
		AwardedXP = resolution.AwardedXP,
		LevelsGained = resolution.LevelsGained,
		LevelUps = resolution.LevelUps,
		PreviousState = previousState,
		State = committedState,
	})
	notify(progressionChangedListeners, payload)
	if resolution.LevelsGained > 0 then
		notify(levelUpListeners, payload)
	end

	return table.freeze({
		Accepted = true,
		ReasonId = resolution.ReasonId,
		SourceId = sourceId,
		AttributionId = attributionId,
		RequestedXP = resolution.RequestedXP,
		AwardedXP = resolution.AwardedXP,
		LevelsGained = resolution.LevelsGained,
		LevelUps = resolution.LevelUps,
		PreviousState = previousState,
		State = committedState,
	})
end

local function connectListener(listeners: { [number]: (any) -> () }, callback: any): (() -> ())?
	if type(callback) ~= "function" then
		return nil
	end
	nextListenerId += 1
	local listenerId = nextListenerId
	listeners[listenerId] = callback
	local connected = true
	return function()
		if not connected then
			return
		end
		connected = false
		listeners[listenerId] = nil
	end
end

-- Extension seam for future skill points, stat points, unlocks, analytics, and
-- presentation. Consumers observe authoritative transitions without owning XP.
function Service.connectLevelUp(callback: any): (() -> ())?
	return connectListener(levelUpListeners, callback)
end

function Service.connectProgressionChanged(callback: any): (() -> ())?
	return connectListener(progressionChangedListeners, callback)
end

return table.freeze(Service)
