--!strict

-- Server-authoritative owner for durable attribute allocation and respec. XP
-- remains owned by CharacterProgressionService; this service derives earned
-- points from the canonical level and persists only player build decisions.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.CharacterStatConfig)
local Resolver = require(ReplicatedStorage.Shared.Progression.CharacterBuildResolver)
local CharacterProgressionService = require(script.Parent.CharacterProgressionService)
local CharacterStatService = require(script.Parent.CharacterStatService)

local Service = {}

local PROGRESSION_SOURCE_ID = "progression:character-build"
local MAX_REQUEST_IDS_PER_PLAYER = 64
local statesByUserId: { [number]: any } = {}
local requestResultsByUserId: { [number]: { [string]: any } } = {}
local requestOrderByUserId: { [number]: { string } } = {}
local persistenceWriter: ((number, any, string, number) -> any)? = nil
local playerRemovingConnection: RBXScriptConnection? = nil
local progressionDisconnect: (() -> ())? = nil
local started = false

local function isPlayer(player: any): boolean
	return typeof(player) == "Instance" and player:IsA("Player")
end

local function validRequestId(requestId: any): boolean
	return type(requestId) == "string" and #requestId >= 8 and #requestId <= 128
end

local function currentLevel(player: Player): number
	local progression = CharacterProgressionService.getState(player)
	if type(progression) == "table" and type(progression.Level) == "number" then
		return progression.Level
	end
	return 1
end

local function exportState(state: any): any
	local allocations = {}
	for attributeId, points in state.AllocatedAttributes do
		allocations[attributeId] = points
	end
	return {
		Version = Config.Version,
		AllocatedAttributes = allocations,
	}
end

local function ensureState(player: Player): any
	local existing = statesByUserId[player.UserId]
	if existing ~= nil then
		return existing
	end
	local state = Resolver.defaultState(Config)
	statesByUserId[player.UserId] = state
	return state
end

local function refreshStatSource(player: Player, state: any): boolean
	local generated = Resolver.progressionModifiers(state, currentLevel(player), Config)
	if generated == nil then
		return false
	end
	local modifiers = {}
	for _, modifier in generated do
		table.insert(modifiers, {
			StatId = modifier.StatId,
			Operation = modifier.Operation,
			Value = modifier.Value,
			Priority = modifier.Priority,
		})
	end
	local applied = CharacterStatService.setSourceModifiers(
		player,
		PROGRESSION_SOURCE_ID,
		Config.SourceCategories.Progression,
		modifiers
	)
	return type(applied) == "table" and applied.Accepted == true
end

local function publishAttributes(player: Player, state: any)
	local level = currentLevel(player)
	local available = Resolver.availableAttributePoints(state, level, Config) or 0
	local totalPerks = Resolver.totalEarnedPerkPoints(level, Config) or 0
	player:SetAttribute("CharacterAvailableAttributePoints", available)
	player:SetAttribute("CharacterEarnedPerkPoints", totalPerks)
	for attributeId, points in state.AllocatedAttributes do
		player:SetAttribute("CharacterAttribute" .. attributeId, points)
	end
end

local function setState(player: Player, state: any): boolean
	statesByUserId[player.UserId] = state
	publishAttributes(player, state)
	return refreshStatSource(player, state)
end

local function getDuplicateResult(userId: number, requestId: string): any?
	local results = requestResultsByUserId[userId]
	if results == nil then
		return nil
	end
	return results[requestId]
end

local function rememberResult(userId: number, requestId: string, result: any)
	local results = requestResultsByUserId[userId]
	if results == nil then
		results = {}
		requestResultsByUserId[userId] = results
	end
	local order = requestOrderByUserId[userId]
	if order == nil then
		order = {}
		requestOrderByUserId[userId] = order
	end
	if results[requestId] == nil then
		table.insert(order, requestId)
	end
	results[requestId] = result
	while #order > MAX_REQUEST_IDS_PER_PLAYER do
		local expired = table.remove(order, 1)
		results[expired] = nil
	end
end

local function duplicateResponse(result: any): any
	return table.freeze({
		Accepted = result.Accepted,
		ReasonId = result.ReasonId,
		AlreadyApplied = true,
		State = result.State,
		AvailableAttributePoints = result.AvailableAttributePoints,
		RefundedAttributePoints = result.RefundedAttributePoints,
	})
end

function Service.start()
	if started then
		return
	end
	started = true
	CharacterStatService.start()
	progressionDisconnect = CharacterProgressionService.connectProgressionChanged(function(payload: any)
		local player = payload.Player
		if isPlayer(player) then
			local state = ensureState(player)
			publishAttributes(player, state)
			refreshStatSource(player, state)
		end
	end)
	playerRemovingConnection = Players.PlayerRemoving:Connect(function(player: Player)
		Service.releasePlayer(player)
	end)
end

function Service.configurePersistence(writer: any): boolean
	if type(writer) ~= "function" then
		return false
	end
	persistenceWriter = writer
	return true
end

function Service.hydratePlayer(player: Player, rawState: any): any
	if not isPlayer(player) then
		return table.freeze({ Accepted = false, ReasonId = "InvalidPlayer" })
	end
	local state = Resolver.normalizeState(rawState, Config)
	if state == nil then
		return table.freeze({ Accepted = false, ReasonId = "InvalidBuildConfig" })
	end
	setState(player, state)
	return table.freeze({ Accepted = true, ReasonId = "BuildHydrated", State = exportState(state) })
end

function Service.getState(player: Player): any
	if not isPlayer(player) then
		return nil
	end
	return exportState(ensureState(player))
end

function Service.getSnapshot(player: Player): any
	if not isPlayer(player) then
		return nil
	end
	local state = ensureState(player)
	local level = currentLevel(player)
	return table.freeze({
		State = exportState(state),
		Level = level,
		AvailableAttributePoints = Resolver.availableAttributePoints(state, level, Config) or 0,
		EarnedPerkPoints = Resolver.totalEarnedPerkPoints(level, Config) or 0,
	})
end

function Service.allocateAttributePoints(player: Player, attributeId: any, amount: any, requestId: any): any
	if not isPlayer(player) then
		return table.freeze({ Accepted = false, ReasonId = "InvalidPlayer" })
	end
	if not validRequestId(requestId) then
		return table.freeze({ Accepted = false, ReasonId = "InvalidRequestId" })
	end
	local duplicate = getDuplicateResult(player.UserId, requestId)
	if duplicate ~= nil then
		return duplicateResponse(duplicate)
	end

	local previousState = ensureState(player)
	local resolution = Resolver.allocate(previousState, currentLevel(player), attributeId, amount, Config)
	if resolution.Accepted ~= true then
		return table.freeze(resolution)
	end
	local writer = persistenceWriter
	if writer == nil then
		return table.freeze({ Accepted = false, ReasonId = "BuildPersistenceUnavailable" })
	end
	local persisted = writer(player.UserId, exportState(resolution.State), requestId, os.time())
	if type(persisted) ~= "table" or persisted.Accepted ~= true then
		return table.freeze({
			Accepted = false,
			ReasonId = if type(persisted) == "table" then persisted.ReasonId else "BuildSaveFailed",
		})
	end

	local committed = Resolver.normalizeState(persisted.State or resolution.State, Config)
	if committed == nil then
		return table.freeze({ Accepted = false, ReasonId = "BuildSaveReturnedInvalidState" })
	end
	setState(player, committed)
	local result = table.freeze({
		Accepted = true,
		ReasonId = "Allocated",
		AlreadyApplied = persisted.AlreadyApplied == true,
		State = exportState(committed),
		AvailableAttributePoints = Resolver.availableAttributePoints(committed, currentLevel(player), Config) or 0,
	})
	rememberResult(player.UserId, requestId, result)
	return result
end

function Service.respec(player: Player, requestId: any): any
	if not isPlayer(player) then
		return table.freeze({ Accepted = false, ReasonId = "InvalidPlayer" })
	end
	if not validRequestId(requestId) then
		return table.freeze({ Accepted = false, ReasonId = "InvalidRequestId" })
	end
	local duplicate = getDuplicateResult(player.UserId, requestId)
	if duplicate ~= nil then
		return duplicateResponse(duplicate)
	end

	local previousState = ensureState(player)
	local resolution = Resolver.respec(previousState, currentLevel(player), Config)
	if resolution.Accepted ~= true then
		return table.freeze(resolution)
	end
	local writer = persistenceWriter
	if writer == nil then
		return table.freeze({ Accepted = false, ReasonId = "BuildPersistenceUnavailable" })
	end
	local persisted = writer(player.UserId, exportState(resolution.State), requestId, os.time())
	if type(persisted) ~= "table" or persisted.Accepted ~= true then
		return table.freeze({
			Accepted = false,
			ReasonId = if type(persisted) == "table" then persisted.ReasonId else "BuildSaveFailed",
		})
	end

	local committed = Resolver.normalizeState(persisted.State or resolution.State, Config)
	if committed == nil then
		return table.freeze({ Accepted = false, ReasonId = "BuildSaveReturnedInvalidState" })
	end
	setState(player, committed)
	local result = table.freeze({
		Accepted = true,
		ReasonId = "Respecced",
		AlreadyApplied = persisted.AlreadyApplied == true,
		State = exportState(committed),
		RefundedAttributePoints = resolution.RefundedAttributePoints,
		AvailableAttributePoints = Resolver.availableAttributePoints(committed, currentLevel(player), Config) or 0,
	})
	rememberResult(player.UserId, requestId, result)
	return result
end

function Service.releasePlayer(player: Player)
	if not isPlayer(player) then
		return
	end
	statesByUserId[player.UserId] = nil
	requestResultsByUserId[player.UserId] = nil
	requestOrderByUserId[player.UserId] = nil
	CharacterStatService.clearSourceModifiers(player, PROGRESSION_SOURCE_ID)
end

return table.freeze(Service)
