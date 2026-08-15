--!strict

-- Central live stat registry. Progression, equipment, and temporary systems own
-- their source modifiers; this service owns validation, replacement, ordering,
-- and final stat resolution.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.CharacterStatConfig)
local Resolver = require(ReplicatedStorage.Shared.Progression.CharacterStatResolver)

local Service = {}

local MAX_MODIFIERS_PER_SOURCE = 64
local sourcesByUserId: { [number]: { [string]: { any } } } = {}
local sourceCategoriesByUserId: { [number]: { [string]: string } } = {}
local nextListenerId = 0
local changedListeners: { [number]: (any) -> () } = {}
local playerRemovingConnection: RBXScriptConnection? = nil
local started = false

local function isPlayer(player: any): boolean
	return typeof(player) == "Instance" and player:IsA("Player")
end

local function validSourceCategory(sourceCategory: any): boolean
	if type(sourceCategory) ~= "string" then
		return false
	end
	for _, configured in Config.SourceCategories do
		if sourceCategory == configured then
			return true
		end
	end
	return false
end

local function notify(player: Player, sourceId: string)
	local snapshot = Service.getResolvedStats(player)
	if snapshot == nil then
		return
	end
	local payload = table.freeze({ Player = player, UserId = player.UserId, SourceId = sourceId, Stats = snapshot })
	for _, callback in changedListeners do
		local ok, message = pcall(callback, payload)
		if not ok then
			warn("[CharacterStatService] listener failed: " .. tostring(message))
		end
	end
end

local function collectModifiers(userId: number): { any }
	local collected = {}
	local sources = sourcesByUserId[userId]
	if sources == nil then
		return collected
	end
	local sourceIds = {}
	for sourceId in sources do
		table.insert(sourceIds, sourceId)
	end
	table.sort(sourceIds)
	for _, sourceId in sourceIds do
		for _, modifier in sources[sourceId] do
			table.insert(collected, modifier)
		end
	end
	return collected
end

function Service.start()
	if started then
		return
	end
	started = true
	playerRemovingConnection = Players.PlayerRemoving:Connect(function(player: Player)
		Service.clearPlayer(player)
	end)
end

function Service.setSourceModifiers(player: Player, sourceId: any, sourceCategory: any, modifiers: any): any
	if not isPlayer(player) then
		return table.freeze({ Accepted = false, ReasonId = "InvalidPlayer" })
	end
	if type(sourceId) ~= "string" or sourceId == "" or #sourceId > 128 then
		return table.freeze({ Accepted = false, ReasonId = "InvalidSourceId" })
	end
	if not validSourceCategory(sourceCategory) then
		return table.freeze({ Accepted = false, ReasonId = "InvalidSourceCategory" })
	end
	if type(modifiers) ~= "table" or #modifiers > MAX_MODIFIERS_PER_SOURCE then
		return table.freeze({ Accepted = false, ReasonId = "InvalidModifiers" })
	end

	local canonical = {}
	for _, rawModifier in modifiers do
		if type(rawModifier) ~= "table" then
			return table.freeze({ Accepted = false, ReasonId = "InvalidModifier" })
		end
		local modifier = {
			SourceId = sourceId,
			SourceCategory = sourceCategory,
			StatId = rawModifier.StatId,
			Operation = rawModifier.Operation,
			Value = rawModifier.Value,
			Priority = rawModifier.Priority,
		}
		local valid, reasonId = Resolver.validateModifier(modifier, Config)
		if not valid then
			return table.freeze({ Accepted = false, ReasonId = reasonId or "InvalidModifier" })
		end
		table.insert(canonical, table.freeze(modifier))
	end

	local userSources = sourcesByUserId[player.UserId]
	if userSources == nil then
		userSources = {}
		sourcesByUserId[player.UserId] = userSources
	end
	local categories = sourceCategoriesByUserId[player.UserId]
	if categories == nil then
		categories = {}
		sourceCategoriesByUserId[player.UserId] = categories
	end
	userSources[sourceId] = canonical
	categories[sourceId] = sourceCategory
	notify(player, sourceId)
	return table.freeze({ Accepted = true, ReasonId = "SourceModifiersSet", SourceId = sourceId, ModifierCount = #canonical })
end

function Service.clearSourceModifiers(player: Player, sourceId: any): any
	if not isPlayer(player) then
		return table.freeze({ Accepted = false, ReasonId = "InvalidPlayer" })
	end
	if type(sourceId) ~= "string" or sourceId == "" then
		return table.freeze({ Accepted = false, ReasonId = "InvalidSourceId" })
	end
	local sources = sourcesByUserId[player.UserId]
	if sources ~= nil then
		sources[sourceId] = nil
	end
	local categories = sourceCategoriesByUserId[player.UserId]
	if categories ~= nil then
		categories[sourceId] = nil
	end
	notify(player, sourceId)
	return table.freeze({ Accepted = true, ReasonId = "SourceModifiersCleared", SourceId = sourceId })
end

function Service.getResolvedStat(player: Player, statId: any): number?
	if not isPlayer(player) or not Resolver.isKnownStat(statId, Config) then
		return nil
	end
	return Resolver.resolveStat(statId, collectModifiers(player.UserId), Config)
end

function Service.getResolvedStats(player: Player): { [string]: number }?
	if not isPlayer(player) then
		return nil
	end
	return Resolver.resolveAll(collectModifiers(player.UserId), Config)
end

-- PascalCase aliases are intentional: they make the public seam cheap for
-- existing services that use that convention without creating duplicate math.
Service.GetResolvedStat = Service.getResolvedStat
Service.GetResolvedStats = Service.getResolvedStats
Service.SetSourceModifiers = Service.setSourceModifiers
Service.ClearSourceModifiers = Service.clearSourceModifiers

function Service.clearPlayer(player: Player)
	if not isPlayer(player) then
		return
	end
	sourcesByUserId[player.UserId] = nil
	sourceCategoriesByUserId[player.UserId] = nil
end

function Service.connectResolvedStatsChanged(callback: any): (() -> ())?
	if type(callback) ~= "function" then
		return nil
	end
	nextListenerId += 1
	local listenerId = nextListenerId
	changedListeners[listenerId] = callback
	local connected = true
	return function()
		if not connected then
			return
		end
		connected = false
		changedListeners[listenerId] = nil
	end
end

return table.freeze(Service)
