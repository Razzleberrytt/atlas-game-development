--!strict

-- Minimal standalone fixture runner. It loads the production module with
-- server-owned contract/config fixtures; it does not emulate Roblox runtime.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local CONTRACTS_TOKEN = {}
local CONFIG_TOKEN = {}

local rejectionReasons = table.freeze({
	OperativeStateInvalid = "OperativeStateInvalid",
	RelationshipNotHostile = "RelationshipNotHostile",
	HostileDead = "HostileDead",
	HostileUntargetable = "HostileUntargetable",
	NotVisible = "NotVisible",
	NoLineOfSight = "NoLineOfSight",
	OutOfRange = "OutOfRange",
	NoAmmunition = "NoAmmunition",
	WeaponNotReady = "WeaponNotReady",
})

local contracts = {
	OperativeCombatStateIds = table.freeze({ Ready = "Ready" }),
	TeamRelationshipIds = table.freeze({ Hostile = "Hostile" }),
	WeaponReadinessStateIds = table.freeze({ Ready = "Ready" }),
	TargetValidationRejectionReasonIds = rejectionReasons,
}

local config = {
	BasicFirearm = table.freeze({
		WeaponId = "weapon.basic_firearm",
		RangeStuds = 80,
	}),
}

local replicatedStorage = {
	Shared = {
		Combat = { CombatContracts = CONTRACTS_TOKEN },
		Config = { FirearmConfig = CONFIG_TOKEN },
	},
}

local environment = {
	game = {
		GetService = function(_self: unknown, serviceName: string)
			assert(serviceName == "ReplicatedStorage", "unexpected service request")
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
		error("unexpected module request")
	end,
}

local source = fs.readFile("games/living-kingdoms/src/server/Systems/TargetCandidateValidator.luau")
local loadValidator = luau.load(source, {
	debugName = "TargetCandidateValidator",
	environment = environment,
	injectGlobals = true,
})
local validator = loadValidator()

type Fixture = {
	name: string,
	mutate: ((operative: any, candidate: any) -> ())?,
	expectedReason: string?,
}

local function position(x: number, y: number, z: number)
	return { X = x, Y = y, Z = z }
end

local function validOperative()
	return {
		worldPosition = position(0, 0, 0),
		combatStateId = "Ready",
		weaponReadiness = {
			weaponId = "weapon.basic_firearm",
			readinessStateId = "Ready",
			ammunition = {
				weaponId = "weapon.basic_firearm",
				loadedRounds = 12,
				reserveRounds = 24,
				magazineCapacity = 12,
			},
			cadence = {
				weaponId = "weapon.basic_firearm",
				nextAllowedFireServerTimestamp = 0,
			},
		},
	}
end

local function validCandidate()
	return {
		entityId = "hostile.fixture",
		entityKindId = "Hostile",
		teamId = "hostiles",
		relationshipId = "Hostile",
		worldPosition = position(10, 500, 0),
		distanceStuds = 10,
		isAlive = true,
		isTargetable = true,
		isVisible = true,
		hasLineOfSight = true,
		isActivelyThreatening = false,
	}
end

local fixtures: { Fixture } = {
	{ name = "fully valid candidate" },
	{
		name = "operative state blocked",
		mutate = function(operative)
			operative.combatStateId = "Incapacitated"
		end,
		expectedReason = rejectionReasons.OperativeStateInvalid,
	},
	{
		name = "hostile relationship required",
		mutate = function(_, candidate)
			candidate.relationshipId = "Neutral"
		end,
		expectedReason = rejectionReasons.RelationshipNotHostile,
	},
	{
		name = "dead hostile",
		mutate = function(_, candidate)
			candidate.isAlive = false
		end,
		expectedReason = rejectionReasons.HostileDead,
	},
	{
		name = "untargetable hostile",
		mutate = function(_, candidate)
			candidate.isTargetable = false
		end,
		expectedReason = rejectionReasons.HostileUntargetable,
	},
	{
		name = "line of sight true but visibility false",
		mutate = function(_, candidate)
			candidate.isVisible = false
		end,
		expectedReason = rejectionReasons.NotVisible,
	},
	{
		name = "visibility true but line of sight false",
		mutate = function(_, candidate)
			candidate.hasLineOfSight = false
		end,
		expectedReason = rejectionReasons.NoLineOfSight,
	},
	{
		name = "out of range",
		mutate = function(_, candidate)
			candidate.worldPosition = position(80.001, 0, 0)
		end,
		expectedReason = rejectionReasons.OutOfRange,
	},
	{
		name = "zero loaded ammunition",
		mutate = function(operative)
			operative.weaponReadiness.ammunition.loadedRounds = 0
		end,
		expectedReason = rejectionReasons.NoAmmunition,
	},
	{
		name = "cadence-blocked weapon",
		mutate = function(operative)
			operative.weaponReadiness.readinessStateId = "CadenceBlocked"
		end,
		expectedReason = rejectionReasons.WeaponNotReady,
	},
	{
		name = "reloading weapon",
		mutate = function(operative)
			operative.weaponReadiness.readinessStateId = "Reloading"
		end,
		expectedReason = rejectionReasons.WeaponNotReady,
	},
	{
		name = "empty readiness state with a loaded fixture",
		mutate = function(operative)
			operative.weaponReadiness.readinessStateId = "Empty"
		end,
		expectedReason = rejectionReasons.WeaponNotReady,
	},
	{
		name = "disabled weapon",
		mutate = function(operative)
			operative.weaponReadiness.readinessStateId = "Disabled"
		end,
		expectedReason = rejectionReasons.WeaponNotReady,
	},
	{
		name = "unknown weapon",
		mutate = function(operative)
			operative.weaponReadiness.weaponId = "weapon.unknown"
		end,
		expectedReason = rejectionReasons.WeaponNotReady,
	},
}

for _, fixture in fixtures do
	local operative = validOperative()
	local candidate = validCandidate()
	if fixture.mutate ~= nil then
		fixture.mutate(operative, candidate)
	end

	local result = validator.validate(operative, candidate)
	assert(result.isValid == (fixture.expectedReason == nil), fixture.name .. ": unexpected validity")
	assert(result.rejectionReasonId == fixture.expectedReason, fixture.name .. ": unexpected rejection reason")
end

for _, range in { 79.999, 80, 80.001 } do
	local candidate = validCandidate()
	candidate.worldPosition = position(range, 1000, 0)
	local result = validator.validate(validOperative(), candidate)
	assert(result.isValid == (range <= 80), string.format("range boundary %.3f failed", range))
end

local precedenceOperative = validOperative()
local precedenceCandidate = validCandidate()
precedenceOperative.combatStateId = "Dead"
precedenceOperative.weaponReadiness.ammunition.loadedRounds = 0
precedenceCandidate.relationshipId = "Friendly"
precedenceCandidate.isAlive = false
precedenceCandidate.isVisible = false
local precedenceResult = validator.validate(precedenceOperative, precedenceCandidate)
assert(precedenceResult.rejectionReasonId == rejectionReasons.OperativeStateInvalid, "first-failure precedence failed")

local repeatOperative = validOperative()
local repeatCandidate = validCandidate()
local firstResult = validator.validate(repeatOperative, repeatCandidate)
for _ = 1, 10 do
	local repeatedResult = validator.validate(repeatOperative, repeatCandidate)
	assert(repeatedResult.isValid == firstResult.isValid, "repeat validity changed")
	assert(repeatedResult.rejectionReasonId == firstResult.rejectionReasonId, "repeat reason changed")
end

print(string.format("TargetCandidateValidator: %d fixtures and range/precedence/repeat checks passed", #fixtures))
