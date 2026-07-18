--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local CONTRACTS_TOKEN = {}
local contracts = luau.load(
	fs.readFile("games/living-kingdoms/src/shared/Health/OperativeLifeContracts.luau"),
	{ debugName = "OperativeLifeContracts", injectGlobals = true }
)()
local replicatedStorage = { Shared = { Health = { OperativeLifeContracts = CONTRACTS_TOKEN } } }
local resolver = luau.load(
	fs.readFile("games/living-kingdoms/src/server/Systems/OperativeHealingResolver.luau"),
	{
		debugName = "OperativeHealingResolver",
		environment = {
			game = {
				GetService = function(_, serviceName)
					assert(serviceName == "ReplicatedStorage")
					return replicatedStorage
				end,
			},
			require = function(token)
				assert(token == CONTRACTS_TOKEN)
				return contracts
			end,
		},
		injectGlobals = true,
	}
)()

local function snapshot(health: number, lifeStateId: string?)
	return {
		operativeEntityId = "operative.player:7",
		lifeStateId = lifeStateId or "Alive",
		healthState = { currentHealth = health, maximumHealth = 100 },
		incapacitationState = if lifeStateId == "Incapacitated"
			then { startedAtServerTimestamp = 1, bleedOutDeadlineServerTimestamp = 31 }
			else nil,
		soloRecoveryState = {
			isEligible = false,
			recoveriesUsed = 0,
			recoveryStartedAtServerTimestamp = nil,
			recoveryCompletionServerTimestamp = nil,
		},
		processedDamageEventIds = { ["damage:old"] = true },
	}
end

local before = snapshot(45)
local healed = resolver.resolve(before, {
	healingEventId = "healing:loot:1",
	sourceEntityId = "loot:1",
	targetEntityId = before.operativeEntityId,
	healingAmount = 30,
	serverTimestamp = 10,
}, 10)
assert(healed.didTransition and healed.rejectionReasonId == nil)
assert(healed.healedAmount == 30)
assert(healed.snapshotAfter.healthState.currentHealth == 75)
assert(healed.snapshotAfter.lifeStateId == "Alive")
assert(healed.snapshotAfter.processedDamageEventIds["damage:old"])
assert(before.healthState.currentHealth == 45, "resolver must not mutate the caller snapshot")

local clamped = resolver.resolve(snapshot(90), {
	healingEventId = "healing:loot:2",
	sourceEntityId = "loot:2",
	targetEntityId = "operative.player:7",
	healingAmount = 30,
	serverTimestamp = 11,
}, 11)
assert(clamped.didTransition and clamped.healedAmount == 10)
assert(clamped.snapshotAfter.healthState.currentHealth == 100)

local full = resolver.resolve(snapshot(100), {
	healingEventId = "healing:loot:3",
	targetEntityId = "operative.player:7",
	healingAmount = 30,
	serverTimestamp = 12,
}, 12)
assert(not full.didTransition and full.rejectionReasonId == "AlreadyAtMaximumHealth")

local downed = resolver.resolve(snapshot(0, "Incapacitated"), {
	healingEventId = "healing:loot:4",
	targetEntityId = "operative.player:7",
	healingAmount = 30,
	serverTimestamp = 13,
}, 13)
assert(not downed.didTransition and downed.rejectionReasonId == "TargetNotAlive")

local wrongTarget = resolver.resolve(snapshot(50), {
	healingEventId = "healing:loot:5",
	targetEntityId = "operative.player:999",
	healingAmount = 30,
	serverTimestamp = 14,
}, 14)
assert(not wrongTarget.didTransition and wrongTarget.rejectionReasonId == "InvalidHealing")

local wrongTime = resolver.resolve(snapshot(50), {
	healingEventId = "healing:loot:6",
	targetEntityId = "operative.player:7",
	healingAmount = 30,
	serverTimestamp = 15,
}, 16)
assert(not wrongTime.didTransition and wrongTime.rejectionReasonId == "InvalidServerTimestamp")

print("OperativeHealingResolver: bounded alive-only healing and immutable snapshots passed")
