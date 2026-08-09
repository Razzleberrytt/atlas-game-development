--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local CONTRACTS_TOKEN = {}
local CONFIG_TOKEN = {}
local contracts = {
	RejectionReasonIds = table.freeze({
		InvalidIntent = "InvalidIntent",
		NoTarget = "NoTarget",
	}),
}
local config = {
	OpeningWeapon = {
		RangeStuds = 8,
		AimHalfAngleDegrees = 52,
	},
}
local replicatedStorage = {
	Shared = {
		Combat = { MeleeContracts = CONTRACTS_TOKEN },
		Config = { MeleeCombatConfig = CONFIG_TOKEN },
	},
}
local source = fs.readFile("games/living-kingdoms/src/server/Systems/MeleeStrikeResolver.luau")
local resolver = luau.load(source, {
	debugName = "MeleeStrikeResolver",
	environment = {
		game = {
			GetService = function(_self: unknown, serviceName: string)
				assert(serviceName == "ReplicatedStorage")
				return replicatedStorage
			end,
		},
		require = function(token: unknown)
			if token == CONTRACTS_TOKEN then
				return contracts
			end
			if token == CONFIG_TOKEN then
				return config
			end
			error("unexpected melee resolver dependency")
		end,
	},
	injectGlobals = true,
})()

local origin = Vector3.new(0, 0, 0)
local forward = Vector3.new(0, 0, -1)
local candidates = {
	{ entityId = "hostile.near", worldPosition = Vector3.new(0, 0, -5), isAlive = true },
	{ entityId = "hostile.far", worldPosition = Vector3.new(0, 0, -7), isAlive = true },
}
local selected = resolver.selectTarget(origin, forward, candidates)
assert(selected.targetEntityId == "hostile.near", "closest valid melee target should win")
assert(selected.rejectionReasonId == nil)

local outsideRange = resolver.selectTarget(origin, forward, {
	{ entityId = "hostile.too-far", worldPosition = Vector3.new(0, 0, -8.1), isAlive = true },
})
assert(outsideRange.targetEntityId == nil)
assert(outsideRange.rejectionReasonId == "NoTarget")

local behind = resolver.selectTarget(origin, forward, {
	{ entityId = "hostile.behind", worldPosition = Vector3.new(0, 0, 4), isAlive = true },
})
assert(behind.targetEntityId == nil)
assert(behind.rejectionReasonId == "NoTarget")

local dead = resolver.selectTarget(origin, forward, {
	{ entityId = "hostile.dead", worldPosition = Vector3.new(0, 0, -3), isAlive = false },
})
assert(dead.targetEntityId == nil)
assert(dead.rejectionReasonId == "NoTarget")

local invalidDirection = resolver.selectTarget(origin, Vector3.new(0, 0, 0), candidates)
assert(invalidDirection.targetEntityId == nil)
assert(invalidDirection.rejectionReasonId == "InvalidIntent")

local tieBreak = resolver.selectTarget(origin, forward, {
	{ entityId = "hostile.z", worldPosition = Vector3.new(1, 0, -5), isAlive = true },
	{ entityId = "hostile.a", worldPosition = Vector3.new(-1, 0, -5), isAlive = true },
})
assert(tieBreak.targetEntityId == "hostile.a", "equal melee candidates must resolve deterministically by id")

print("MeleeStrikeResolver: close-range deterministic aim selection passed")
