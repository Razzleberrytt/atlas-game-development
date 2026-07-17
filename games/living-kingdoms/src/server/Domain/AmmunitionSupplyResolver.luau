--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Contracts = require(ReplicatedStorage.Shared.Combat.AmmunitionScarcityContracts)

type ScarcityAmmunitionState = Contracts.ScarcityAmmunitionState
type AmmunitionSupply = Contracts.AmmunitionSupply
type CollectionResult = Contracts.CollectionResult

local RejectionIds = Contracts.CollectionRejectionReasonIds
local SourceIds = Contracts.SupplySourceIds

local Resolver = {}

local function copySet(source: { [string]: boolean }): { [string]: boolean }
	return table.clone(source)
end

local function copyState(state: ScarcityAmmunitionState): ScarcityAmmunitionState
	return table.freeze({
		weaponId = state.weaponId,
		loadedRounds = state.loadedRounds,
		reserveRounds = state.reserveRounds,
		magazineCapacity = state.magazineCapacity,
		maximumReserveRounds = state.maximumReserveRounds,
		processedSupplyIds = copySet(state.processedSupplyIds),
	})
end

local function invalidStateSnapshot(): ScarcityAmmunitionState
	return table.freeze({
		weaponId = "",
		loadedRounds = 0,
		reserveRounds = 0,
		magazineCapacity = 0,
		maximumReserveRounds = 0,
		processedSupplyIds = {},
	})
end

local function rejected(stateAfter: ScarcityAmmunitionState, reasonId: string): CollectionResult
	return table.freeze({
		didCollect = false,
		grantedRounds = 0,
		rejectionReasonId = reasonId,
		stateAfter = stateAfter,
	})
end

local function isWholeNonnegative(value: unknown): boolean
	return type(value) == "number" and value == value and value >= 0 and value < math.huge and value % 1 == 0
end

local function validState(state: unknown): boolean
	if type(state) ~= "table" then
		return false
	end
	local candidate = state :: any
	return type(candidate.weaponId) == "string"
		and candidate.weaponId ~= ""
		and isWholeNonnegative(candidate.loadedRounds)
		and isWholeNonnegative(candidate.reserveRounds)
		and isWholeNonnegative(candidate.magazineCapacity)
		and candidate.magazineCapacity > 0
		and candidate.loadedRounds <= candidate.magazineCapacity
		and isWholeNonnegative(candidate.maximumReserveRounds)
		and candidate.reserveRounds <= candidate.maximumReserveRounds
		and type(candidate.processedSupplyIds) == "table"
end

local function validSupply(supply: unknown, weaponId: string): boolean
	if type(supply) ~= "table" then
		return false
	end
	local candidate = supply :: any
	return type(candidate.supplyId) == "string"
		and candidate.supplyId ~= ""
		and (candidate.sourceId == SourceIds.AuthoredCache or candidate.sourceId == SourceIds.EngineerResupply)
		and candidate.weaponId == weaponId
		and isWholeNonnegative(candidate.availableRounds)
		and candidate.availableRounds > 0
end

function Resolver.collect(state: ScarcityAmmunitionState, supply: AmmunitionSupply): CollectionResult
	if not validState(state) then
		return rejected(invalidStateSnapshot(), RejectionIds.InvalidState)
	end
	local currentState = copyState(state)
	if not validSupply(supply, state.weaponId) then
		return rejected(currentState, RejectionIds.InvalidSupply)
	end
	if state.processedSupplyIds[supply.supplyId] then
		return rejected(currentState, RejectionIds.DuplicateCollection)
	end
	local capacity = state.maximumReserveRounds - state.reserveRounds
	if capacity <= 0 then
		return rejected(currentState, RejectionIds.NoCapacity)
	end
	local grantedRounds = math.min(capacity, supply.availableRounds)
	local processedSupplyIds = copySet(state.processedSupplyIds)
	processedSupplyIds[supply.supplyId] = true
	return table.freeze({
		didCollect = true,
		grantedRounds = grantedRounds,
		rejectionReasonId = nil,
		stateAfter = table.freeze({
			weaponId = state.weaponId,
			loadedRounds = state.loadedRounds,
			reserveRounds = state.reserveRounds + grantedRounds,
			magazineCapacity = state.magazineCapacity,
			maximumReserveRounds = state.maximumReserveRounds,
			processedSupplyIds = processedSupplyIds,
		}),
	})
end

return table.freeze(Resolver)
