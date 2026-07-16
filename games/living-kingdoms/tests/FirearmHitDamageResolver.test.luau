--!strict

-- Minimal standalone fixture runner for deterministic hit and damage resolution.
-- It loads the production modules with server-owned data and no Roblox runtime.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local CONTRACTS_TOKEN = {}
local CONFIG_TOKEN = {}

local reasons = table.freeze({
	FireNotAccepted = "FireNotAccepted",
	MissingShotIdentity = "MissingShotIdentity",
	WeaponInvalid = "WeaponInvalid",
	TargetMismatch = "TargetMismatch",
	TargetInvalid = "TargetInvalid",
	TargetDead = "TargetDead",
	TargetNotHostile = "TargetNotHostile",
	NotVisible = "NotVisible",
	OutOfRange = "OutOfRange",
	LineOfSightBlocked = "LineOfSightBlocked",
	Miss = "Miss",
	ShotAlreadyResolved = "ShotAlreadyResolved",
})

local contracts = {
	AuthoritativeFireStatusIds = table.freeze({ Fired = "Fired", Rejected = "Rejected" }),
	TeamRelationshipIds = table.freeze({ Hostile = "Hostile" }),
	ShotObstructionResultIds = table.freeze({
		TargetHit = "TargetHit",
		Blocked = "Blocked",
		Miss = "Miss",
	}),
	FirearmHitRejectionReasonIds = reasons,
}

local config = {
	BasicFirearm = table.freeze({
		WeaponId = "weapon.basic_firearm",
		DamageTypeId = "Ballistic",
		RangeStuds = 80,
		DamagePerHit = 20,
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

local function loadModule(path: string, debugName: string)
	local source = fs.readFile(path)
	local loader = luau.load(source, {
		debugName = debugName,
		environment = environment,
		injectGlobals = true,
	})
	return loader()
end

local hitResolver = loadModule("games/living-kingdoms/src/server/Systems/FirearmHitResolver.luau", "FirearmHitResolver")
local damageResolver = loadModule("games/living-kingdoms/src/server/Systems/DamageResolver.luau", "DamageResolver")

local function position(x: number, y: number, z: number)
	return { X = x, Y = y, Z = z }
end

local function acceptedFireResult()
	return {
		statusId = "Fired",
		shotId = "shot:operative.alpha:weapon.basic_firearm:5",
		operativeEntityId = "operative.alpha",
		weaponId = "weapon.basic_firearm",
		targetEntityId = "hostile.fixture",
		firedAtServerTimestamp = 5,
		ammunitionAfter = {
			weaponId = "weapon.basic_firearm",
			loadedRounds = 11,
			reserveRounds = 24,
			magazineCapacity = 12,
		},
		didHit = nil,
		hitEntityId = nil,
		rejectionReasonId = nil,
	}
end

local function shotContext()
	return {
		operativeEntityId = "operative.alpha",
		weaponId = "weapon.basic_firearm",
		selectedTargetEntityId = "hostile.fixture",
		operativeWorldPosition = position(0, 0, 0),
		obstructionResultId = "TargetHit",
	}
end

local function targetContext()
	return {
		entityId = "hostile.fixture",
		worldPosition = position(10, 500, 0),
		isAlive = true,
		isTargetable = true,
		relationshipId = "Hostile",
		isVisible = true,
	}
end

local function healthState(currentHealth: number)
	return {
		entityId = "hostile.fixture",
		currentHealth = currentHealth,
		processedShotIds = {},
	}
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[deepCopy(key)] = deepCopy(child)
	end
	return copy
end

local function deepEqual(first: any, second: any): boolean
	if type(first) ~= type(second) then
		return false
	end
	if type(first) ~= "table" then
		return first == second
	end
	for key, value in first do
		if not deepEqual(value, second[key]) then
			return false
		end
	end
	for key in second do
		if first[key] == nil then
			return false
		end
	end
	return true
end

local function assertRejectedHit(result: any, reasonId: string, context: string)
	assert(result.didHit == false, context .. ": unexpectedly hit")
	assert(result.rejectionReasonId == reasonId, context .. ": wrong rejection reason")
end

local accepted = acceptedFireResult()
local clearShot = shotContext()
local validTarget = targetContext()
local hit = hitResolver.resolve(accepted, clearShot, validTarget)
assert(hit.didHit == true, "accepted unobstructed shot missed")
assert(hit.rejectionReasonId == nil, "accepted hit has rejection reason")
assert(hit.shotId == accepted.shotId, "accepted hit changed ShotId")
assert(hit.sourceEntityId == accepted.operativeEntityId, "accepted hit changed source")
assert(hit.targetEntityId == accepted.targetEntityId, "accepted hit changed target")
assert(hit.weaponId == config.BasicFirearm.WeaponId, "accepted hit changed weapon")

local rejectedFire = acceptedFireResult()
rejectedFire.statusId = "Rejected"
assertRejectedHit(
	hitResolver.resolve(rejectedFire, shotContext(), targetContext()),
	reasons.FireNotAccepted,
	"rejected fire"
)

local preResolvedFire = acceptedFireResult()
preResolvedFire.didHit = true
preResolvedFire.hitEntityId = "client.claim"
assertRejectedHit(
	hitResolver.resolve(preResolvedFire, shotContext(), targetContext()),
	reasons.FireNotAccepted,
	"pre-resolved hit fields"
)

for name, shotId in { missing = nil, empty = "", malformed = "client-shot" } do
	local fireResult = acceptedFireResult()
	fireResult.shotId = shotId
	assertRejectedHit(
		hitResolver.resolve(fireResult, shotContext(), targetContext()),
		reasons.MissingShotIdentity,
		"ShotId " .. name
	)
end

local wrongOperativeContext = shotContext()
wrongOperativeContext.operativeEntityId = "operative.other"
assertRejectedHit(
	hitResolver.resolve(acceptedFireResult(), wrongOperativeContext, targetContext()),
	reasons.MissingShotIdentity,
	"operative identity mismatch"
)

local wrongWeaponFire = acceptedFireResult()
wrongWeaponFire.weaponId = "weapon.wrong"
wrongWeaponFire.shotId = "shot:operative.alpha:weapon.wrong:5"
local wrongWeaponContext = shotContext()
wrongWeaponContext.weaponId = "weapon.wrong"
assertRejectedHit(
	hitResolver.resolve(wrongWeaponFire, wrongWeaponContext, targetContext()),
	reasons.WeaponInvalid,
	"wrong weapon ID"
)

local mismatchTarget = targetContext()
mismatchTarget.entityId = "hostile.other"
assertRejectedHit(
	hitResolver.resolve(acceptedFireResult(), shotContext(), mismatchTarget),
	reasons.TargetMismatch,
	"target mismatch"
)

local mismatchShot = shotContext()
mismatchShot.selectedTargetEntityId = "hostile.other"
assertRejectedHit(
	hitResolver.resolve(acceptedFireResult(), mismatchShot, targetContext()),
	reasons.TargetMismatch,
	"shot selected-target mismatch"
)

local revalidationFixtures = {
	{
		name = "target became dead",
		mutate = function(target: any)
			target.isAlive = false
		end,
		reason = reasons.TargetDead,
	},
	{
		name = "target became untargetable",
		mutate = function(target: any)
			target.isTargetable = false
		end,
		reason = reasons.TargetInvalid,
	},
	{
		name = "relationship changed",
		mutate = function(target: any)
			target.relationshipId = "Neutral"
		end,
		reason = reasons.TargetNotHostile,
	},
	{
		name = "visibility lost",
		mutate = function(target: any)
			target.isVisible = false
		end,
		reason = reasons.NotVisible,
	},
}

for _, fixture in revalidationFixtures do
	local target = targetContext()
	fixture.mutate(target)
	assertRejectedHit(hitResolver.resolve(acceptedFireResult(), shotContext(), target), fixture.reason, fixture.name)
end

local blockedShot = shotContext()
blockedShot.obstructionResultId = "Blocked"
local blockedHit = hitResolver.resolve(acceptedFireResult(), blockedShot, targetContext())
assertRejectedHit(blockedHit, reasons.LineOfSightBlocked, "line of sight blocked")

local missShot = shotContext()
missShot.obstructionResultId = "Miss"
local missedHit = hitResolver.resolve(acceptedFireResult(), missShot, targetContext())
assertRejectedHit(missedHit, reasons.Miss, "explicit miss")

for range, shouldHit in { [79.999] = true, [80] = true, [80.001] = false } do
	local target = targetContext()
	target.worldPosition = position(range, 1000, 0)
	local result = hitResolver.resolve(acceptedFireResult(), shotContext(), target)
	assert(result.didHit == shouldHit, string.format("range boundary %.3f failed", range))
	assert(
		result.rejectionReasonId == (if shouldHit then nil else reasons.OutOfRange),
		string.format("range boundary %.3f returned wrong reason", range)
	)
end

local precedenceTarget = targetContext()
precedenceTarget.entityId = "hostile.other"
precedenceTarget.isAlive = false
precedenceTarget.isTargetable = false
precedenceTarget.relationshipId = "Friendly"
precedenceTarget.isVisible = false
precedenceTarget.worldPosition = position(100, 0, 0)
local precedenceShot = shotContext()
precedenceShot.obstructionResultId = "Blocked"
assertRejectedHit(
	hitResolver.resolve(acceptedFireResult(), precedenceShot, precedenceTarget),
	reasons.TargetMismatch,
	"hit first-failure precedence"
)

local immutableFire = acceptedFireResult()
local immutableShot = shotContext()
local immutableTarget = targetContext()
local fireBefore = deepCopy(immutableFire)
local shotBefore = deepCopy(immutableShot)
local targetBefore = deepCopy(immutableTarget)
hitResolver.resolve(immutableFire, immutableShot, immutableTarget)
assert(deepEqual(immutableFire, fireBefore), "hit resolver mutated fire input")
assert(deepEqual(immutableShot, shotBefore), "hit resolver mutated shot input")
assert(deepEqual(immutableTarget, targetBefore), "hit resolver mutated target input")

local nonlethalHealth = healthState(100)
local nonlethal = damageResolver.resolve(hit, nonlethalHealth, 5.01)
assert(nonlethal.didApplyDamage == true, "configured hit did not apply damage")
assert(nonlethal.targetHealthStateAfter.currentHealth == 80, "configured 20 damage was not applied")
assert(nonlethal.becameDead == false, "nonlethal hit reported death")
assert(nonlethal.damageEvent ~= nil, "successful hit has no damage event")
assert(nonlethal.damageEvent.damageAmount == config.BasicFirearm.DamagePerHit, "damage did not come from config")
assert(nonlethal.damageEvent.damageTypeId == config.BasicFirearm.DamageTypeId, "damage type did not come from config")
assert(nonlethal.damageEvent.serverTimestamp == 5.01, "damage event did not use server timestamp")
assert(table.isfrozen(nonlethal.damageEvent), "damage event is mutable")

local lethal = damageResolver.resolve(hit, healthState(20), 5.01)
assert(lethal.targetHealthStateAfter.currentHealth == 0, "lethal hit did not reach zero")
assert(lethal.becameDead == true, "lethal hit did not report death")

local clamped = damageResolver.resolve(hit, healthState(10), 5.01)
assert(clamped.targetHealthStateAfter.currentHealth == 0, "health was not clamped to zero")
assert(clamped.becameDead == true, "zero-clamped hit did not report death")

local missHealth = healthState(100)
local missDamage = damageResolver.resolve(missedHit, missHealth, 5.01)
assert(missDamage.damageEvent == nil, "miss created damage event")
assert(missDamage.didApplyDamage == false, "miss applied damage")
assert(missDamage.targetHealthStateAfter.currentHealth == 100, "miss changed health")
assert(missDamage.targetHealthStateAfter.processedShotIds[missedHit.shotId] == true, "miss was not terminal")

local rejectedDamage =
	damageResolver.resolve(hitResolver.resolve(rejectedFire, shotContext(), targetContext()), healthState(100), 5.01)
assert(rejectedDamage.damageEvent == nil, "rejected fire created damage")
assert(rejectedDamage.targetHealthStateAfter.currentHealth == 100, "rejected fire changed health")

local duplicate = damageResolver.resolve(hit, nonlethal.targetHealthStateAfter, 5.02)
assert(duplicate.damageEvent == nil, "duplicate ShotId created a second event")
assert(duplicate.didApplyDamage == false, "duplicate ShotId applied damage")
assert(duplicate.rejectionReasonId == reasons.ShotAlreadyResolved, "duplicate ShotId returned wrong reason")
assert(duplicate.targetHealthStateAfter.currentHealth == 80, "duplicate ShotId changed health")

local untrustedDamageHit = deepCopy(hit)
untrustedDamageHit.damageAmount = 999
untrustedDamageHit.damageTypeId = "ClientChosen"
untrustedDamageHit.serverTimestamp = -1
local authoritativeDamage = damageResolver.resolve(untrustedDamageHit, healthState(100), 8)
assert(authoritativeDamage.damageEvent.damageAmount == 20, "untrusted damage amount was used")
assert(authoritativeDamage.damageEvent.damageTypeId == "Ballistic", "untrusted damage type was used")
assert(authoritativeDamage.damageEvent.serverTimestamp == 8, "untrusted timestamp was used")

local immutableHealth = healthState(100)
local immutableHit = deepCopy(hit)
local healthBefore = deepCopy(immutableHealth)
local hitBefore = deepCopy(immutableHit)
damageResolver.resolve(immutableHit, immutableHealth, 5.01)
assert(deepEqual(immutableHealth, healthBefore), "damage resolver mutated health input")
assert(deepEqual(immutableHit, hitBefore), "damage resolver mutated hit input")

local firstHitRepeat = hitResolver.resolve(acceptedFireResult(), shotContext(), targetContext())
for _ = 1, 10 do
	local repeatedHit = hitResolver.resolve(acceptedFireResult(), shotContext(), targetContext())
	assert(deepEqual(repeatedHit, firstHitRepeat), "deterministic hit result changed")
end

local equivalentProcessedA = healthState(80)
equivalentProcessedA.processedShotIds[hit.shotId] = true
local equivalentProcessedB = deepCopy(equivalentProcessedA)
local firstDuplicate = damageResolver.resolve(hit, equivalentProcessedA, 9)
local repeatedDuplicate = damageResolver.resolve(hit, equivalentProcessedB, 9)
assert(deepEqual(firstDuplicate, repeatedDuplicate), "equivalent duplicate state changed deterministic result")

print(
	"FirearmHitDamageResolver: authority, revalidation, range, obstruction, damage, death, deduplication, determinism, and immutability checks passed"
)
