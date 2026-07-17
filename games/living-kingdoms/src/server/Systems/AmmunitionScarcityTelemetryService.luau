--!strict

--[[
	P6-0107 read-only scarcity telemetry. Sampling is explicit and Studio-driven;
	this module creates no scheduler, instances, remotes, or gameplay mutation.
	Accepted shots are derived from conserved ammunition truth:
	starting rounds + committed cache grants - current rounds.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CacheConfig = require(ReplicatedStorage.Shared.Config.AmmunitionCacheConfig)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)
local AmmunitionCacheService = require(script.Parent.AmmunitionCacheService)
local OperativeCombatRuntimeService = require(script.Parent.OperativeCombatRuntimeService)

export type OperativeSnapshot = {
	userId: number,
	operativeEntityId: string,
	isActive: boolean,
	acceptedShotCount: number,
	cacheCollectionCount: number,
	cacheRoundsGranted: number,
	dryAmmunitionTransitionCount: number,
	currentLoadedRounds: number,
	currentReserveRounds: number,
	minimumTotalRoundsObserved: number,
	consumedCacheIds: { string },
}

export type Snapshot = {
	sampleCount: number,
	firstSampleServerTimestamp: number?,
	lastSampleServerTimestamp: number?,
	observedOperativeCount: number,
	activeOperativeCount: number,
	acceptedShotCount: number,
	cacheCollectionCount: number,
	cacheRoundsGranted: number,
	dryOperativeCount: number,
	dryAmmunitionTransitionCount: number,
	currentLoadedRounds: number,
	currentReserveRounds: number,
	minimumTotalRoundsObserved: number?,
	totalCacheOpportunityCount: number,
	consumedCacheOpportunityCount: number,
	remainingCacheOpportunityCount: number,
	operatives: { OperativeSnapshot },
}

type TrackedOperative = {
	userId: number,
	operativeEntityId: string,
	isActive: boolean,
	acceptedShotCount: number,
	cacheCollectionCount: number,
	cacheRoundsGranted: number,
	dryAmmunitionTransitionCount: number,
	currentLoadedRounds: number,
	currentReserveRounds: number,
	minimumTotalRoundsObserved: number,
	consumedCacheIds: { [string]: boolean },
	wasDry: boolean,
}

local Service = {}
local trackedByUserId: { [number]: TrackedOperative } = {}
local sampleCount = 0
local firstSampleServerTimestamp: number? = nil
local lastSampleServerTimestamp: number? = nil

local function isWholeNonnegative(value: unknown): boolean
	return type(value) == "number" and value == value and value < math.huge and value >= 0 and value % 1 == 0
end

local function countSet(values: { [string]: boolean }): number
	local count = 0
	for _, present in values do
		if present then
			count += 1
		end
	end
	return count
end

local function sumGrantedRounds(values: { [string]: number }): number
	local total = 0
	for _, grantedRounds in values do
		if isWholeNonnegative(grantedRounds) then
			total += grantedRounds
		end
	end
	return total
end

local function sortedCacheIds(values: { [string]: boolean }): { string }
	local ids = {}
	for cacheId, present in values do
		if present then
			table.insert(ids, cacheId)
		end
	end
	table.sort(ids)
	return ids
end

local function createTrackedOperative(
	player: Player,
	loadedRounds: number,
	reserveRounds: number,
	consumedCacheIds: { [string]: boolean },
	cacheRoundsGranted: number
): TrackedOperative
	local totalRounds = loadedRounds + reserveRounds
	local initialTotalRounds = FirearmConfig.BasicFirearm.PrototypeInitialLoadedRounds
		+ FirearmConfig.BasicFirearm.PrototypeInitialReserveRounds
	return {
		userId = player.UserId,
		operativeEntityId = "operative.player:" .. tostring(player.UserId),
		isActive = true,
		acceptedShotCount = math.max(0, initialTotalRounds + cacheRoundsGranted - totalRounds),
		cacheCollectionCount = countSet(consumedCacheIds),
		cacheRoundsGranted = cacheRoundsGranted,
		dryAmmunitionTransitionCount = 0,
		currentLoadedRounds = loadedRounds,
		currentReserveRounds = reserveRounds,
		minimumTotalRoundsObserved = totalRounds,
		consumedCacheIds = table.clone(consumedCacheIds),
		wasDry = totalRounds == 0,
	}
end

function Service.resetSampling()
	table.clear(trackedByUserId)
	sampleCount = 0
	firstSampleServerTimestamp = nil
	lastSampleServerTimestamp = nil
end

function Service.sample(serverTimestamp: number): Snapshot
	assert(
		type(serverTimestamp) == "number"
			and serverTimestamp == serverTimestamp
			and serverTimestamp >= 0
			and serverTimestamp < math.huge,
		"invalid scarcity telemetry sample time"
	)
	for _, tracked in trackedByUserId do
		tracked.isActive = false
	end
	local initialTotalRounds = FirearmConfig.BasicFirearm.PrototypeInitialLoadedRounds
		+ FirearmConfig.BasicFirearm.PrototypeInitialReserveRounds
	for _, player in Players:GetPlayers() do
		local combatRead = OperativeCombatRuntimeService.readReviveCombatState(player)
		if combatRead == nil then
			continue
		end
		local ammunition = combatRead.combatState.weaponState.ammunition
		if
			type(ammunition) ~= "table"
			or not isWholeNonnegative(ammunition.loadedRounds)
			or not isWholeNonnegative(ammunition.reserveRounds)
		then
			continue
		end
		local loadedRounds = ammunition.loadedRounds
		local reserveRounds = ammunition.reserveRounds
		local totalRounds = loadedRounds + reserveRounds
		local collection = AmmunitionCacheService.readCollectionState(player)
		local cacheRoundsGranted = sumGrantedRounds(collection.grantedRoundsByCacheId)
		local derivedAcceptedShots = math.max(0, initialTotalRounds + cacheRoundsGranted - totalRounds)
		local tracked = trackedByUserId[player.UserId]
		if tracked == nil then
			tracked = createTrackedOperative(
				player,
				loadedRounds,
				reserveRounds,
				collection.processedCacheIds,
				cacheRoundsGranted
			)
			trackedByUserId[player.UserId] = tracked
		else
			local isDry = totalRounds == 0
			if not tracked.wasDry and isDry then
				tracked.dryAmmunitionTransitionCount += 1
			end
			tracked.isActive = true
			tracked.acceptedShotCount = math.max(tracked.acceptedShotCount, derivedAcceptedShots)
			tracked.cacheCollectionCount = countSet(collection.processedCacheIds)
			tracked.cacheRoundsGranted = cacheRoundsGranted
			tracked.currentLoadedRounds = loadedRounds
			tracked.currentReserveRounds = reserveRounds
			tracked.minimumTotalRoundsObserved = math.min(tracked.minimumTotalRoundsObserved, totalRounds)
			tracked.consumedCacheIds = table.clone(collection.processedCacheIds)
			tracked.wasDry = isDry
		end
	end
	sampleCount += 1
	firstSampleServerTimestamp = firstSampleServerTimestamp or serverTimestamp
	lastSampleServerTimestamp = serverTimestamp
	return Service.read()
end

function Service.read(): Snapshot
	local operatives: { OperativeSnapshot } = {}
	local activeOperativeCount = 0
	local acceptedShotCount = 0
	local cacheCollectionCount = 0
	local cacheRoundsGranted = 0
	local dryOperativeCount = 0
	local dryAmmunitionTransitionCount = 0
	local currentLoadedRounds = 0
	local currentReserveRounds = 0
	local minimumTotalRoundsObserved: number? = nil
	for _, tracked in trackedByUserId do
		local consumedCacheIds = sortedCacheIds(tracked.consumedCacheIds)
		table.freeze(consumedCacheIds)
		table.insert(
			operatives,
			table.freeze({
				userId = tracked.userId,
				operativeEntityId = tracked.operativeEntityId,
				isActive = tracked.isActive,
				acceptedShotCount = tracked.acceptedShotCount,
				cacheCollectionCount = tracked.cacheCollectionCount,
				cacheRoundsGranted = tracked.cacheRoundsGranted,
				dryAmmunitionTransitionCount = tracked.dryAmmunitionTransitionCount,
				currentLoadedRounds = tracked.currentLoadedRounds,
				currentReserveRounds = tracked.currentReserveRounds,
				minimumTotalRoundsObserved = tracked.minimumTotalRoundsObserved,
				consumedCacheIds = consumedCacheIds,
			})
		)
		acceptedShotCount += tracked.acceptedShotCount
		cacheCollectionCount += tracked.cacheCollectionCount
		cacheRoundsGranted += tracked.cacheRoundsGranted
		dryAmmunitionTransitionCount += tracked.dryAmmunitionTransitionCount
		minimumTotalRoundsObserved = if minimumTotalRoundsObserved == nil
			then tracked.minimumTotalRoundsObserved
			else math.min(minimumTotalRoundsObserved, tracked.minimumTotalRoundsObserved)
		if tracked.isActive then
			activeOperativeCount += 1
			currentLoadedRounds += tracked.currentLoadedRounds
			currentReserveRounds += tracked.currentReserveRounds
			if tracked.wasDry then
				dryOperativeCount += 1
			end
		end
	end
	table.sort(operatives, function(a, b)
		return a.userId < b.userId
	end)
	table.freeze(operatives)
	local observedOperativeCount = #operatives
	local totalCacheOpportunityCount = observedOperativeCount * #CacheConfig.Caches
	local remainingCacheOpportunityCount = math.max(0, totalCacheOpportunityCount - cacheCollectionCount)
	return table.freeze({
		sampleCount = sampleCount,
		firstSampleServerTimestamp = firstSampleServerTimestamp,
		lastSampleServerTimestamp = lastSampleServerTimestamp,
		observedOperativeCount = observedOperativeCount,
		activeOperativeCount = activeOperativeCount,
		acceptedShotCount = acceptedShotCount,
		cacheCollectionCount = cacheCollectionCount,
		cacheRoundsGranted = cacheRoundsGranted,
		dryOperativeCount = dryOperativeCount,
		dryAmmunitionTransitionCount = dryAmmunitionTransitionCount,
		currentLoadedRounds = currentLoadedRounds,
		currentReserveRounds = currentReserveRounds,
		minimumTotalRoundsObserved = minimumTotalRoundsObserved,
		totalCacheOpportunityCount = totalCacheOpportunityCount,
		consumedCacheOpportunityCount = cacheCollectionCount,
		remainingCacheOpportunityCount = remainingCacheOpportunityCount,
		operatives = operatives,
	})
end

return table.freeze(Service)
