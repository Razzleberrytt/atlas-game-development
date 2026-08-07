--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "HROI-0105 combat modifier assertion failed", 2)
	end
end

local CONTRACTS_TOKEN = {}
local FIREARM_CONFIG_TOKEN = {}

local attributes = {
	RunDamageMultiplier = 1,
	RunCadenceMultiplier = 1,
	RunAmmoConservationChance = 0,
	RunCullDamageMultiplier = 1,
	RunCullHealthThreshold = 30,
	RunPatternDamageMultiplier = 1,
	RunSpecialEnemyDamageMultiplier = 1,
	RunLastMagazineDamageMultiplier = 1,
	RunLastMagazineReserveFraction = 0.2,
}

local progressionNetwork = {
	GetAttribute = function(_self: unknown, attributeName: string)
		return attributes[attributeName]
	end,
}

local contracts = {
	OperativeCombatStateIds = table.freeze({ Ready = "Ready" }),
	WeaponReadinessStateIds = table.freeze({ Ready = "Ready" }),
	AutomaticFireRejectionReasonIds = table.freeze({
		NoSelectedTarget = "NoSelectedTarget",
		SelectedTargetInvalid = "SelectedTargetInvalid",
		OperativeStateInvalid = "OperativeStateInvalid",
		NoAmmunition = "NoAmmunition",
		WeaponNotReady = "WeaponNotReady",
		CadenceBlocked = "CadenceBlocked",
	}),
	AuthoritativeFireStatusIds = table.freeze({ Fired = "Fired", Rejected = "Rejected" }),
	FirearmHitRejectionReasonIds = table.freeze({
		MissingShotIdentity = "MissingShotIdentity",
		ShotAlreadyResolved = "ShotAlreadyResolved",
		TargetMismatch = "TargetMismatch",
		WeaponInvalid = "WeaponInvalid",
	}),
}

local firearmConfig = {
	BasicFirearm = table.freeze({
		WeaponId = "weapon.basic_firearm",
		DamageTypeId = "Ballistic",
		CadenceSeconds = 0.2,
		DamagePerHit = 20,
	}),
}

local replicatedStorage = {
	Shared = {
		Combat = { CombatContracts = CONTRACTS_TOKEN },
		Config = { FirearmConfig = FIREARM_CONFIG_TOKEN },
	},
	FindFirstChild = function(_self: unknown, name: string)
		return if name == "ProgressionNetwork" then progressionNetwork else nil
	end,
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
		if token == FIREARM_CONFIG_TOKEN then
			return firearmConfig
		end
		error("unexpected module request")
	end,
}

local automaticFireResolver = luau.load(
	fs.readFile("games/living-kingdoms/src/server/Systems/AutomaticFireResolver.luau"),
	{ debugName = "AutomaticFireResolver", environment = environment, injectGlobals = true }
)()
local damageResolver = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/DamageResolver.luau"), {
	debugName = "DamageResolver",
	environment = environment,
	injectGlobals = true,
})()

local function operative()
	return { entityId = "operative.alpha", combatStateId = "Ready" }
end

local function target()
	return {
		operativeEntityId = "operative.alpha",
		targetEntityId = "hostile.fixture",
		isValid = true,
		selectionReasonId = "ValidClosest",
		selectedAtServerTimestamp = nil,
	}
end

local function weapon(loadedRounds: number)
	return {
		weaponId = "weapon.basic_firearm",
		readinessStateId = "Ready",
		ammunition = {
			weaponId = "weapon.basic_firearm",
			loadedRounds = loadedRounds,
			reserveRounds = 24,
			magazineCapacity = 12,
		},
		cadence = {
			weaponId = "weapon.basic_firearm",
			lastFireServerTimestamp = nil,
			nextAllowedFireServerTimestamp = 0,
		},
		reloadState = nil,
	}
end

local baselineShot = automaticFireResolver.resolve(operative(), target(), weapon(10), 5)
assert(baselineShot.decision.shouldFire and baselineShot.weaponStateAfter.ammunition.loadedRounds == 9)
assert(math.abs(baselineShot.weaponStateAfter.cadence.nextAllowedFireServerTimestamp - 5.2) < 1e-9)

attributes.RunCadenceMultiplier = 0.76
local rapidShot = automaticFireResolver.resolve(operative(), target(), weapon(10), 5)
assert(rapidShot.decision.shouldFire, "trusted cadence modifier should remain fireable")
assert(math.abs(rapidShot.weaponStateAfter.cadence.nextAllowedFireServerTimestamp - 5.152) < 1e-9)

attributes.RunAmmoConservationChance = 0.45
local conservedTimestamp = nil
for index = 1, 200 do
	local timestamp = index / 10
	local result = automaticFireResolver.resolve(operative(), target(), weapon(10), timestamp)
	if result.weaponStateAfter.ammunition.loadedRounds == 10 then
		conservedTimestamp = timestamp
		local repeated = automaticFireResolver.resolve(operative(), target(), weapon(10), timestamp)
		assert(repeated.weaponStateAfter.ammunition.loadedRounds == 10, "Echo Chamber must be deterministic")
		break
	end
end
assert(conservedTimestamp ~= nil, "bounded sample should contain a deterministic conserved round")

attributes.RunAmmoConservationChance = 0.9
local invalidChance = automaticFireResolver.resolve(operative(), target(), weapon(10), 5)
assert(not invalidChance.decision.shouldFire and invalidChance.decision.rejectionReasonId == "WeaponNotReady")
attributes.RunAmmoConservationChance = 0
attributes.RunCadenceMultiplier = 1

local function hit(shotId: string)
	return {
		shotId = shotId,
		didHit = true,
		targetEntityId = "hostile.fixture",
		weaponId = "weapon.basic_firearm",
		sourceEntityId = "operative.alpha",
		rejectionReasonId = nil,
	}
end

local function health(currentHealth: number)
	return {
		entityId = "hostile.fixture",
		currentHealth = currentHealth,
		processedShotIds = {},
	}
end

local baselineDamage = damageResolver.resolve(hit("shot.baseline"), health(45), 10)
assert(baselineDamage.didApplyDamage and baselineDamage.damageEvent.damageAmount == 20)
assert(baselineDamage.targetHealthStateAfter.currentHealth == 25)

attributes.RunDamageMultiplier = 1.4
local overpressure = damageResolver.resolve(hit("shot.overpressure"), health(45), 11)
assert(overpressure.damageEvent.damageAmount == 28 and overpressure.targetHealthStateAfter.currentHealth == 17)

attributes.RunDamageMultiplier = 1
attributes.RunCullDamageMultiplier = 1.35
local cull = damageResolver.resolve(hit("shot.cull"), health(25), 12)
assert(cull.damageEvent.damageAmount == 27 and cull.becameDead, "Cull Protocol should finish wounded enemies")

-- Regression: legitimate stacked damage (1.8x) and cull (2.05x) combine past the
-- 3x ceiling. The product must clamp to the cap and still apply, not reject and
-- deal zero damage to a wounded enemy.
attributes.RunDamageMultiplier = 1.8
attributes.RunCullDamageMultiplier = 2.05
local stackedCull = damageResolver.resolve(hit("shot.stacked-cull"), health(25), 17)
assert(
	stackedCull.didApplyDamage and stackedCull.damageEvent.damageAmount == 60,
	"maxed damage x cull must clamp to the 3x ceiling, not reject the shot"
)
attributes.RunDamageMultiplier = 1
attributes.RunCullDamageMultiplier = 1

attributes.RunDamageMultiplier = 4
local invalidDamage = damageResolver.resolve(hit("shot.invalid"), health(45), 13)
assert(not invalidDamage.didApplyDamage and invalidDamage.rejectionReasonId == "WeaponInvalid")
assert(invalidDamage.targetHealthStateAfter.currentHealth == 45)

-- Pattern Amplifier: raises secondary cleave/pierce damage toward full primary,
-- capped at the primary amount so it never reaches the hard damage ceiling.
attributes.RunDamageMultiplier = 1
local baselinePattern = damageResolver.resolvePattern(hit("shot.pattern.baseline"), health(45), 14, 0.7)
assert(baselinePattern.damageEvent.damageAmount == 14, "unamplified 0.7 secondary of base 20 deals 14")
attributes.RunPatternDamageMultiplier = 1.45
local amplifiedPattern = damageResolver.resolvePattern(hit("shot.pattern.amplified"), health(45), 15, 0.7)
assert(amplifiedPattern.damageEvent.damageAmount == 20, "Pattern Amplifier raises 0.7 secondary to full primary damage")
local cappedPattern = damageResolver.resolvePattern(hit("shot.pattern.capped"), health(45), 16, 1)
assert(cappedPattern.damageEvent.damageAmount == 20, "amplified secondary never exceeds primary damage")
attributes.RunPatternDamageMultiplier = 1

local standardContext = { reserveRounds = 24, maximumReserveRounds = 48, isSpecialEnemy = false }
local specialContext = { reserveRounds = 24, maximumReserveRounds = 48, isSpecialEnemy = true }
attributes.RunSpecialEnemyDamageMultiplier = 1.6
local ordinarySpecialist =
	damageResolver.resolve(hit("shot.specialist.ordinary"), health(100), 18, nil, standardContext)
assert(ordinarySpecialist.damageEvent.damageAmount == 20, "ordinary enemies must not consume Specialist Munitions")
local specialSpecialist = damageResolver.resolve(hit("shot.specialist.special"), health(100), 19, nil, specialContext)
assert(specialSpecialist.damageEvent.damageAmount == 32, "special enemies must consume Specialist Munitions")
attributes.RunSpecialEnemyDamageMultiplier = 1

attributes.RunLastMagazineDamageMultiplier = 1.45
local stocked = damageResolver.resolve(hit("shot.last-mag.stocked"), health(100), 20, nil, standardContext)
assert(stocked.damageEvent.damageAmount == 20, "stocked reserve must not activate Last Magazine")
local lowReserve = damageResolver.resolve(
	hit("shot.last-mag.low"),
	health(100),
	21,
	nil,
	{ reserveRounds = 9, maximumReserveRounds = 48, isSpecialEnemy = false }
)
assert(lowReserve.damageEvent.damageAmount == 29, "critical reserve must activate Last Magazine")
local boundaryReserve = damageResolver.resolve(
	hit("shot.last-mag.boundary"),
	health(100),
	22,
	nil,
	{ reserveRounds = 10, maximumReserveRounds = 48, isSpecialEnemy = false }
)
assert(boundaryReserve.damageEvent.damageAmount == 20, "reserve above the floored 20% boundary must not activate")
attributes.RunLastMagazineDamageMultiplier = 1

print("RunUpgradeCombatModifiers: cadence, scarcity, special, pattern, cull, and hard caps passed")
