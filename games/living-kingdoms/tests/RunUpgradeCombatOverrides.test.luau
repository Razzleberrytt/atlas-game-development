--!strict

-- HROI-0105 combat modifier fixture: optional server values are applied by the
-- pure combat resolvers, invalid values fall back to baseline config, and no
-- client-supplied state is introduced.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local CONTRACTS_TOKEN = {}
local CONFIG_TOKEN = {}

local contracts = {
	OperativeCombatStateIds = table.freeze({
		Ready = "Ready",
		Reloading = "Reloading",
		Incapacitated = "Incapacitated",
		Dead = "Dead",
	}),
	WeaponReadinessStateIds = table.freeze({
		Ready = "Ready",
		Reloading = "Reloading",
		Empty = "Empty",
		Disabled = "Disabled",
	}),
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
	ReloadRejectionReasonIds = table.freeze({
		OperativeStateInvalid = "OperativeStateInvalid",
		WeaponInvalid = "WeaponInvalid",
		WeaponNotReady = "WeaponNotReady",
		AlreadyReloading = "AlreadyReloading",
		MagazineFull = "MagazineFull",
		NoReserveAmmunition = "NoReserveAmmunition",
		ReloadNotInProgress = "ReloadNotInProgress",
		ReloadNotComplete = "ReloadNotComplete",
		ReloadInterrupted = "ReloadInterrupted",
	}),
}

local firearmConfig = {
	BasicFirearm = table.freeze({
		WeaponId = "weapon.basic_firearm",
		DamageTypeId = "Ballistic",
		CadenceSeconds = 0.2,
		MagazineCapacity = 12,
		ReloadDurationSeconds = 2,
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
		GetService = function(_, serviceName)
			assert(serviceName == "ReplicatedStorage")
			return replicatedStorage
		end,
	},
	require = function(token)
		if token == CONTRACTS_TOKEN then
			return contracts
		elseif token == CONFIG_TOKEN then
			return firearmConfig
		end
		error("unexpected resolver dependency")
	end,
}

local function load(path: string, name: string)
	return luau.load(fs.readFile(path), {
		debugName = name,
		environment = environment,
		injectGlobals = true,
	})()
end

local automatic = load(
	"games/living-kingdoms/src/server/Systems/AutomaticFireResolver.luau",
	"AutomaticFireResolver"
)
local damage = load("games/living-kingdoms/src/server/Systems/DamageResolver.luau", "DamageResolver")
local reload = load("games/living-kingdoms/src/server/Systems/ReloadResolver.luau", "ReloadResolver")

local operative = { entityId = "operative.player:9", combatStateId = "Ready", equippedWeaponId = "weapon.basic_firearm" }
local target = {
	operativeEntityId = operative.entityId,
	targetEntityId = "enemy.fixture",
	isValid = true,
	selectionReasonId = "ValidClosest",
	selectedAtServerTimestamp = nil,
}
local function weapon()
	return {
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
			lastFireServerTimestamp = nil,
			nextAllowedFireServerTimestamp = 0,
		},
		reloadState = nil,
	}
end

local fastFire = automatic.resolve(operative, target, weapon(), 5, 0.18)
assert(math.abs(fastFire.weaponStateAfter.cadence.nextAllowedFireServerTimestamp - 5.18) < 1e-12)
local invalidFastFire = automatic.resolve(operative, target, weapon(), 5, 0.01)
assert(math.abs(invalidFastFire.weaponStateAfter.cadence.nextAllowedFireServerTimestamp - 5.2) < 1e-12)

local hit = {
	shotId = "shot:fixture",
	sourceEntityId = operative.entityId,
	targetEntityId = "enemy.fixture",
	weaponId = "weapon.basic_firearm",
	didHit = true,
	rejectionReasonId = nil,
}
local health = {
	entityId = "enemy.fixture",
	currentHealth = 45,
	processedShotIds = {},
}
local upgradedDamage = damage.resolve(hit, health, 5, 25)
assert(upgradedDamage.targetHealthStateAfter.currentHealth == 20)
assert(upgradedDamage.damageEvent ~= nil and upgradedDamage.damageEvent.damageAmount == 25)
local invalidDamage = damage.resolve(hit, health, 5, 200)
assert(invalidDamage.targetHealthStateAfter.currentHealth == 25)
assert(invalidDamage.damageEvent ~= nil and invalidDamage.damageEvent.damageAmount == 20)

local reloadWeapon = weapon()
reloadWeapon.ammunition.loadedRounds = 3
local quickReload = reload.begin(operative, reloadWeapon, 10, 1.7)
assert(quickReload.didBegin)
assert(
	quickReload.weaponStateAfter.reloadState ~= nil
		and math.abs(quickReload.weaponStateAfter.reloadState.completionServerTimestamp - 11.7) < 1e-12
)
local baselineReload = reload.begin(operative, reloadWeapon, 10, 0.1)
assert(
	baselineReload.weaponStateAfter.reloadState ~= nil
		and baselineReload.weaponStateAfter.reloadState.completionServerTimestamp == 12
)

print("RunUpgradeCombatOverrides: damage, cadence, and reload server overrides passed")
