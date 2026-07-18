--!strict

--[[
	HROI-0106 pure authoritative healing transition. Callers must supply a current
	server-owned operative snapshot, one server-authored healing event, and the
	exact server timestamp, then atomically commit the returned snapshot through
	the revisioned life service. No Humanoid access, networking, or hidden state.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OperativeLifeContracts = require(ReplicatedStorage.Shared.Health.OperativeLifeContracts)

type OperativeLifeStateSnapshot = OperativeLifeContracts.OperativeLifeStateSnapshot

export type AuthoritativeHealing = {
	healingEventId: string,
	sourceEntityId: string?,
	targetEntityId: string,
	healingAmount: number,
	serverTimestamp: number,
}

export type HealingResolution = {
	didTransition: boolean,
	rejectionReasonId: string?,
	lifeStateIdBefore: string?,
	lifeStateIdAfter: string?,
	transitionServerTimestamp: number?,
	healingEventId: string?,
	healedAmount: number,
	snapshotAfter: OperativeLifeStateSnapshot,
}

local Resolver = {}
local AliveStateId = OperativeLifeContracts.OperativeLifeStateIds.Alive

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in value do
		result[deepCopy(key)] = deepCopy(child)
	end
	return result
end

local function reject(snapshot: OperativeLifeStateSnapshot, reasonId: string): HealingResolution
	return {
		didTransition = false,
		rejectionReasonId = reasonId,
		lifeStateIdBefore = nil,
		lifeStateIdAfter = nil,
		transitionServerTimestamp = nil,
		healingEventId = nil,
		healedAmount = 0,
		snapshotAfter = deepCopy(snapshot),
	}
end

function Resolver.resolve(
	operativeSnapshot: OperativeLifeStateSnapshot,
	healing: AuthoritativeHealing,
	serverTimestamp: number
): HealingResolution
	if
		type(operativeSnapshot) ~= "table"
		or type(operativeSnapshot.operativeEntityId) ~= "string"
		or operativeSnapshot.operativeEntityId == ""
		or type(operativeSnapshot.healthState) ~= "table"
		or not isFiniteNumber(operativeSnapshot.healthState.currentHealth)
		or not isFiniteNumber(operativeSnapshot.healthState.maximumHealth)
		or operativeSnapshot.healthState.maximumHealth <= 0
		or operativeSnapshot.healthState.currentHealth < 0
		or operativeSnapshot.healthState.currentHealth > operativeSnapshot.healthState.maximumHealth
	then
		return reject(operativeSnapshot, "InvalidSnapshot")
	end
	if
		type(healing) ~= "table"
		or type(healing.healingEventId) ~= "string"
		or healing.healingEventId == ""
		or #healing.healingEventId > 240
		or (healing.sourceEntityId ~= nil and type(healing.sourceEntityId) ~= "string")
		or healing.targetEntityId ~= operativeSnapshot.operativeEntityId
		or not isFiniteNumber(healing.healingAmount)
		or healing.healingAmount <= 0
		or healing.healingAmount > operativeSnapshot.healthState.maximumHealth
	then
		return reject(operativeSnapshot, "InvalidHealing")
	end
	if
		not isFiniteNumber(serverTimestamp)
		or serverTimestamp < 0
		or healing.serverTimestamp ~= serverTimestamp
	then
		return reject(operativeSnapshot, "InvalidServerTimestamp")
	end
	if operativeSnapshot.lifeStateId ~= AliveStateId then
		return reject(operativeSnapshot, "TargetNotAlive")
	end
	if operativeSnapshot.healthState.currentHealth >= operativeSnapshot.healthState.maximumHealth then
		return reject(operativeSnapshot, "AlreadyAtMaximumHealth")
	end

	local snapshotAfter = deepCopy(operativeSnapshot) :: OperativeLifeStateSnapshot
	local healthBefore = snapshotAfter.healthState.currentHealth
	snapshotAfter.healthState.currentHealth = math.min(
		snapshotAfter.healthState.maximumHealth,
		healthBefore + healing.healingAmount
	)
	local healedAmount = snapshotAfter.healthState.currentHealth - healthBefore
	return {
		didTransition = true,
		rejectionReasonId = nil,
		lifeStateIdBefore = AliveStateId,
		lifeStateIdAfter = AliveStateId,
		transitionServerTimestamp = serverTimestamp,
		healingEventId = healing.healingEventId,
		healedAmount = healedAmount,
		snapshotAfter = snapshotAfter,
	}
end

return table.freeze(Resolver)
