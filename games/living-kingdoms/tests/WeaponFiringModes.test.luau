--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local CONTRACTS_TOKEN = {}
local CONFIG_TOKEN = {}
local reasons = table.freeze({
	NoSelectedTarget = "NoSelectedTarget",
	SelectedTargetInvalid = "SelectedTargetInvalid",
	OperativeStateInvalid = "OperativeStateInvalid",
	NoAmmunition = "NoAmmunition",
	WeaponNotReady = "WeaponNotReady",
	CadenceBlocked = "CadenceBlocked",
})
local contracts = {
	OperativeCombatStateIds = table.freeze({ Ready = "Ready" }),
	WeaponReadinessStateIds = table.freeze({ Ready = "Ready" }),
	AutomaticFireRejectionReasonIds = reasons,
	AuthoritativeFireStatusIds = table.freeze({ Fired = "Fired", Rejected = "Rejected" }),
}
local definitions = {
	["weapon.auto"] = { WeaponId = "weapon.auto", CadenceSeconds = 0.1, FiringModeId = "Automatic", BurstCount = 1, BurstIntervalSeconds = 0.1 },
	["weapon.semi"] = { WeaponId = "weapon.semi", CadenceSeconds = 0.25, FiringModeId = "SemiAutomatic", BurstCount = 1, BurstIntervalSeconds = 0.25 },
	["weapon.burst"] = { WeaponId = "weapon.burst", CadenceSeconds = 0.6, FiringModeId = "Burst", BurstCount = 3, BurstIntervalSeconds = 0.1 },
}
local config = {
	get = function(weaponId: unknown)
		return if type(weaponId) == "string" then definitions[weaponId] else nil
	end,
}
local replicatedStorage = { Shared = { Combat = { CombatContracts = CONTRACTS_TOKEN }, Config = { FirearmConfig = CONFIG_TOKEN } } }
local resolver = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/AutomaticFireResolver.luau"), {
	debugName = "AutomaticFireResolver.firing-modes",
	environment = {
		game = {
			GetService = function(_self: unknown, serviceName: string)
				assert(serviceName == "ReplicatedStorage", "unexpected service")
				return replicatedStorage
			end,
		},
		require = function(token: unknown)
			if token == CONTRACTS_TOKEN then return contracts end
			if token == CONFIG_TOKEN then return config end
			error("unexpected module")
		end,
	},
	injectGlobals = true,
})()

local function operative()
	return { entityId = "operative.fixture", combatStateId = "Ready" }
end
local function target()
	return { operativeEntityId = "operative.fixture", targetEntityId = "enemy.fixture", isValid = true }
end
local function state(weaponId: string, rounds: number?)
	return {
		weaponId = weaponId,
		readinessStateId = "Ready",
		ammunition = { weaponId = weaponId, loadedRounds = rounds or 12, reserveRounds = 24, magazineCapacity = 12 },
		cadence = { weaponId = weaponId, lastFireServerTimestamp = nil, nextAllowedFireServerTimestamp = 0 },
		reloadState = nil,
	}
end

local auto = resolver.resolve(operative(), target(), state("weapon.auto"), 1)
assert(auto.decision.shouldFire, "automatic first shot rejected")
auto = resolver.resolve(operative(), target(), auto.weaponStateAfter, 1.1)
assert(auto.decision.shouldFire, "automatic held fire must continue at cadence")

local semi = resolver.resolve(operative(), target(), state("weapon.semi"), 1)
assert(semi.decision.shouldFire, "semi first press rejected")
local heldSemi = resolver.resolve(operative(), target(), semi.weaponStateAfter, 2)
assert(not heldSemi.decision.shouldFire and heldSemi.decision.rejectionReasonId == reasons.CadenceBlocked, "semi held trigger fired twice")
local releasedSemi = resolver.resolve(operative(), nil, heldSemi.weaponStateAfter, 2.1)
assert(not releasedSemi.decision.shouldFire, "release unexpectedly fired")
semi = resolver.resolve(operative(), target(), releasedSemi.weaponStateAfter, 2.2)
assert(semi.decision.shouldFire, "semi did not re-arm after release")

local burst = resolver.resolve(operative(), target(), state("weapon.burst"), 1)
assert(burst.decision.shouldFire, "burst shot one rejected")
assert(math.abs(burst.weaponStateAfter.cadence.nextAllowedFireServerTimestamp - 1.1) < 1e-12, "burst interval one wrong")
local tooSoon = resolver.resolve(operative(), target(), burst.weaponStateAfter, 1.05)
assert(not tooSoon.decision.shouldFire and tooSoon.decision.rejectionReasonId == reasons.CadenceBlocked, "burst ignored interval")
burst = resolver.resolve(operative(), target(), tooSoon.weaponStateAfter, 1.1)
assert(burst.decision.shouldFire, "burst shot two rejected")
burst = resolver.resolve(operative(), target(), burst.weaponStateAfter, 1.2)
assert(burst.decision.shouldFire, "burst shot three rejected")
assert(math.abs(burst.weaponStateAfter.cadence.nextAllowedFireServerTimestamp - 1.8) < 1e-12, "post-burst cadence wrong")
local heldBurst = resolver.resolve(operative(), target(), burst.weaponStateAfter, 2)
assert(not heldBurst.decision.shouldFire, "held burst started a second burst")
local releasedBurst = resolver.resolve(operative(), nil, heldBurst.weaponStateAfter, 2.1)
burst = resolver.resolve(operative(), target(), releasedBurst.weaponStateAfter, 2.2)
assert(burst.decision.shouldFire, "burst did not re-arm after release")

local empty = state("weapon.auto", 1)
empty.ammunition.loadedRounds = 0
local dry = resolver.resolve(operative(), target(), empty, 1)
assert(not dry.decision.shouldFire and dry.decision.rejectionReasonId == reasons.NoAmmunition, "zero ammo must fail closed")

print("WeaponFiringModes: automatic, semi, burst, cadence and zero-ammo behavior passed")