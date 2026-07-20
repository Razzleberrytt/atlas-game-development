--!strict

-- Standalone fixtures for the pure authoritative reload transition.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local CONTRACTS_TOKEN = {}
local CONFIG_TOKEN = {}

local reasons = table.freeze({
	OperativeStateInvalid = "OperativeStateInvalid",
	WeaponInvalid = "WeaponInvalid",
	WeaponNotReady = "WeaponNotReady",
	AlreadyReloading = "AlreadyReloading",
	MagazineFull = "MagazineFull",
	NoReserveAmmunition = "NoReserveAmmunition",
	ReloadNotInProgress = "ReloadNotInProgress",
	ReloadNotComplete = "ReloadNotComplete",
	ReloadInterrupted = "ReloadInterrupted",
})

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
	ReloadRejectionReasonIds = reasons,
}

local config = {
	BasicFirearm = table.freeze({
		WeaponId = "weapon.basic_firearm",
		MagazineCapacity = 12,
		ReloadDurationSeconds = 2,
	}),
}

local progressionAttributes: { [string]: number } = {}
local progressionNetwork = {
	GetAttribute = function(_self: unknown, attributeName: string)
		return progressionAttributes[attributeName]
	end,
}
local replicatedStorage = {
	Shared = {
		Combat = { CombatContracts = CONTRACTS_TOKEN },
		Config = { FirearmConfig = CONFIG_TOKEN },
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
		if token == CONFIG_TOKEN then
			return config
		end
		error("unexpected module request")
	end,
}

local source = fs.readFile("games/living-kingdoms/src/server/Systems/ReloadResolver.luau")
local loadResolver = luau.load(source, {
	debugName = "ReloadResolver",
	environment = environment,
	injectGlobals = true,
})
local resolver = loadResolver()

local function operative()
	return {
		entityId = "operative.alpha",
		combatStateId = "Ready",
		equippedWeaponId = "weapon.basic_firearm",
	}
end

local function weaponState(loadedRounds: number?, reserveRounds: number?)
	return {
		weaponId = "weapon.basic_firearm",
		readinessStateId = "Ready",
		ammunition = {
			weaponId = "weapon.basic_firearm",
			loadedRounds = if loadedRounds == nil then 6 else loadedRounds,
			reserveRounds = if reserveRounds == nil then 24 else reserveRounds,
			magazineCapacity = 12,
		},
		cadence = {
			weaponId = "weapon.basic_firearm",
			lastFireServerTimestamp = 4,
			nextAllowedFireServerTimestamp = 5,
		},
		reloadState = nil,
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

local function begin(loadedRounds: number?, reserveRounds: number?, timestamp: number?)
	return resolver.begin(operative(), weaponState(loadedRounds, reserveRounds), timestamp or 10)
end

local function assertBeginRejected(
	result: any,
	reasonId: string,
	operativeBefore: any,
	weaponBefore: any,
	context: string
)
	assert(result.didBegin == false, context .. ": unexpectedly began")
	assert(result.rejectionReasonId == reasonId, context .. ": wrong reason")
	assert(deepEqual(result.operativeStateAfter, operativeBefore), context .. ": operative changed")
	assert(deepEqual(result.weaponStateAfter, weaponBefore), context .. ": weapon changed")
end

local validOperative = operative()
local validWeapon = weaponState()
local validBegin = resolver.begin(validOperative, validWeapon, 10)
assert(validBegin.didBegin == true, "valid reload did not begin")
assert(validBegin.rejectionReasonId == nil, "valid reload has rejection")
assert(validBegin.operativeStateAfter.combatStateId == "Reloading", "operative did not enter reload")
assert(validBegin.weaponStateAfter.readinessStateId == "Reloading", "weapon did not enter reload")
assert(validBegin.weaponStateAfter.reloadState.startedAtServerTimestamp == 10, "wrong begin timestamp")
assert(validBegin.weaponStateAfter.reloadState.completionServerTimestamp == 12, "wrong completion timestamp")
assert(validBegin.weaponStateAfter.ammunition.loadedRounds == 6, "begin moved loaded ammo")
assert(validBegin.weaponStateAfter.ammunition.reserveRounds == 24, "begin moved reserve ammo")

-- Combat Loader: a squad reload-duration multiplier published on
-- ProgressionNetwork shortens the completion deadline at begin() while the
-- reload commitment floor and the pure completion check are preserved. Absent
-- the attribute the duration is the unmodified two seconds (asserted above).
progressionAttributes.RunReloadDurationMultiplier = 0.5
local fasterBegin = resolver.begin(operative(), weaponState(), 10)
assert(fasterBegin.didBegin == true, "reduced-duration reload should still begin")
assert(
	fasterBegin.weaponStateAfter.reloadState.completionServerTimestamp == 11,
	"Combat Loader must shorten the reload deadline (2s * 0.5 = 1s)"
)
-- The floor clamp rejects an out-of-range multiplier rather than erasing reload.
progressionAttributes.RunReloadDurationMultiplier = 0.1
local flooredBegin = resolver.begin(operative(), weaponState(), 10)
assert(
	flooredBegin.weaponStateAfter.reloadState.completionServerTimestamp == 11,
	"reload duration must not fall below the 0.5 floor (2s * 0.5 = 1s)"
)
progressionAttributes.RunReloadDurationMultiplier = nil
local restoredBegin = resolver.begin(operative(), weaponState(), 10)
assert(
	restoredBegin.weaponStateAfter.reloadState.completionServerTimestamp == 12,
	"absent Combat Loader state must restore the configured reload duration"
)

local fullOperative, fullWeapon = operative(), weaponState(12, 24)
assertBeginRejected(
	resolver.begin(fullOperative, fullWeapon, 10),
	reasons.MagazineFull,
	fullOperative,
	fullWeapon,
	"full magazine"
)

local noReserveOperative, noReserveWeapon = operative(), weaponState(6, 0)
assertBeginRejected(
	resolver.begin(noReserveOperative, noReserveWeapon, 10),
	reasons.NoReserveAmmunition,
	noReserveOperative,
	noReserveWeapon,
	"no reserve"
)

local alreadyOperative, alreadyWeapon = operative(), weaponState()
alreadyWeapon.readinessStateId = "Reloading"
alreadyWeapon.reloadState = {
	weaponId = "weapon.basic_firearm",
	startedAtServerTimestamp = 9,
	completionServerTimestamp = 11,
}
assertBeginRejected(
	resolver.begin(alreadyOperative, alreadyWeapon, 10),
	reasons.AlreadyReloading,
	alreadyOperative,
	alreadyWeapon,
	"already reloading"
)

local wrongOperative, wrongWeapon = operative(), weaponState()
wrongOperative.equippedWeaponId = "weapon.wrong"
assertBeginRejected(
	resolver.begin(wrongOperative, wrongWeapon, 10),
	reasons.WeaponInvalid,
	wrongOperative,
	wrongWeapon,
	"wrong equipped weapon"
)

for _, combatStateId in { "Incapacitated", "Dead" } do
	local blockedOperative, blockedWeapon = operative(), weaponState()
	blockedOperative.combatStateId = combatStateId
	assertBeginRejected(
		resolver.begin(blockedOperative, blockedWeapon, 10),
		reasons.OperativeStateInvalid,
		blockedOperative,
		blockedWeapon,
		combatStateId .. " operative"
	)
end

local notReadyOperative, notReadyWeapon = operative(), weaponState()
notReadyWeapon.readinessStateId = "Disabled"
assertBeginRejected(
	resolver.begin(notReadyOperative, notReadyWeapon, 10),
	reasons.WeaponNotReady,
	notReadyOperative,
	notReadyWeapon,
	"disabled weapon begin"
)

local justBefore = resolver.complete(validBegin.operativeStateAfter, validBegin.weaponStateAfter, 11.999999)
assert(justBefore.didComplete == false, "just-before completion succeeded")
assert(justBefore.rejectionReasonId == reasons.ReloadNotComplete, "just-before returned wrong reason")
assert(deepEqual(justBefore.weaponStateAfter, validBegin.weaponStateAfter), "just-before changed weapon state")

local exact = resolver.complete(validBegin.operativeStateAfter, validBegin.weaponStateAfter, 12)
assert(exact.didComplete == true, "exact completion timestamp rejected")
assert(exact.weaponStateAfter.ammunition.loadedRounds == 12, "partial magazine did not fill")
assert(exact.weaponStateAfter.ammunition.reserveRounds == 18, "wrong reserve transfer")
assert(exact.weaponStateAfter.ammunition.magazineCapacity == 12, "capacity changed")
assert(exact.weaponStateAfter.reloadState == nil, "completion retained reload state")
assert(exact.operativeStateAfter.combatStateId == "Ready", "completion did not restore ready operative")
assert(6 + 24 == 12 + 18, "loaded plus reserve was not conserved")

local smallReserveBegin = begin(6, 2)
local smallReserveComplete =
	resolver.complete(smallReserveBegin.operativeStateAfter, smallReserveBegin.weaponStateAfter, 12)
assert(smallReserveComplete.weaponStateAfter.ammunition.loadedRounds == 8, "small reserve transferred incorrectly")
assert(smallReserveComplete.weaponStateAfter.ammunition.reserveRounds == 0, "small reserve did not empty")

local largeReserveBegin = begin(10, 24)
local largeReserveComplete =
	resolver.complete(largeReserveBegin.operativeStateAfter, largeReserveBegin.weaponStateAfter, 12)
assert(largeReserveComplete.weaponStateAfter.ammunition.loadedRounds == 12, "large reserve over/under-filled")
assert(largeReserveComplete.weaponStateAfter.ammunition.reserveRounds == 22, "large reserve transfer wrong")
assert(
	largeReserveComplete.weaponStateAfter.ammunition.loadedRounds
			+ largeReserveComplete.weaponStateAfter.ammunition.reserveRounds
		== 34,
	"large reserve total changed"
)

for _, nonInterruptingField in { "isMoving", "tookDamage" } do
	local nonInterruptingBegin = begin()
	nonInterruptingBegin.operativeStateAfter[nonInterruptingField] = true
	local completed =
		resolver.complete(nonInterruptingBegin.operativeStateAfter, nonInterruptingBegin.weaponStateAfter, 12)
	assert(completed.didComplete == true, nonInterruptingField .. " interrupted reload")
end

local function assertInterrupted(mutate: (any, any) -> (), context: string)
	local startedReload = begin()
	local operativeDuring = deepCopy(startedReload.operativeStateAfter)
	local weaponDuring = deepCopy(startedReload.weaponStateAfter)
	local loadedBefore = weaponDuring.ammunition.loadedRounds
	local reserveBefore = weaponDuring.ammunition.reserveRounds
	mutate(operativeDuring, weaponDuring)
	local result = resolver.complete(operativeDuring, weaponDuring, 12)
	assert(result.didComplete == false, context .. ": completed")
	assert(result.wasInterrupted == true, context .. ": not marked interrupted")
	assert(result.rejectionReasonId == reasons.ReloadInterrupted, context .. ": wrong reason")
	assert(result.weaponStateAfter.ammunition.loadedRounds == loadedBefore, context .. ": loaded ammo changed")
	assert(result.weaponStateAfter.ammunition.reserveRounds == reserveBefore, context .. ": reserve ammo changed")
	assert(result.weaponStateAfter.reloadState == nil, context .. ": reload state retained")
end

assertInterrupted(function(operativeDuring)
	operativeDuring.combatStateId = "Incapacitated"
end, "incapacitation")
assertInterrupted(function(operativeDuring)
	operativeDuring.combatStateId = "Dead"
end, "death")
assertInterrupted(function(_, weaponDuring)
	weaponDuring.readinessStateId = "Disabled"
end, "weapon disabled")
assertInterrupted(function(operativeDuring)
	operativeDuring.equippedWeaponId = "weapon.other"
end, "equipped weapon changed")

local repeated = resolver.complete(exact.operativeStateAfter, exact.weaponStateAfter, 20)
assert(repeated.didComplete == false, "repeated completion succeeded")
assert(repeated.rejectionReasonId == reasons.ReloadNotInProgress, "repeated completion wrong reason")
assert(deepEqual(repeated.weaponStateAfter, exact.weaponStateAfter), "repeated completion transferred twice")

local immutableOperative, immutableWeapon = operative(), weaponState()
local immutableOperativeBefore, immutableWeaponBefore = deepCopy(immutableOperative), deepCopy(immutableWeapon)
resolver.begin(immutableOperative, immutableWeapon, 10)
assert(deepEqual(immutableOperative, immutableOperativeBefore), "begin mutated operative input")
assert(deepEqual(immutableWeapon, immutableWeaponBefore), "begin mutated weapon input")
local completionOperativeBefore = deepCopy(validBegin.operativeStateAfter)
local completionWeaponBefore = deepCopy(validBegin.weaponStateAfter)
resolver.complete(validBegin.operativeStateAfter, validBegin.weaponStateAfter, 12)
assert(deepEqual(validBegin.operativeStateAfter, completionOperativeBefore), "complete mutated operative input")
assert(deepEqual(validBegin.weaponStateAfter, completionWeaponBefore), "complete mutated weapon input")

local precedenceOperative, precedenceWeapon = operative(), weaponState(12, 0)
precedenceOperative.combatStateId = "Dead"
precedenceOperative.equippedWeaponId = "weapon.wrong"
precedenceWeapon.readinessStateId = "Reloading"
assertBeginRejected(
	resolver.begin(precedenceOperative, precedenceWeapon, 10),
	reasons.OperativeStateInvalid,
	precedenceOperative,
	precedenceWeapon,
	"operative precedence"
)
local weaponPrecedenceOperative, weaponPrecedenceWeapon = operative(), weaponState(12, 0)
weaponPrecedenceOperative.equippedWeaponId = "weapon.wrong"
weaponPrecedenceWeapon.readinessStateId = "Reloading"
assertBeginRejected(
	resolver.begin(weaponPrecedenceOperative, weaponPrecedenceWeapon, 10),
	reasons.WeaponInvalid,
	weaponPrecedenceOperative,
	weaponPrecedenceWeapon,
	"weapon precedence"
)

local untrustedOperative, authoritativeWeapon = operative(), weaponState(6, 24)
untrustedOperative.clientTimestamp = -1000
untrustedOperative.clientLoadedRounds = 999
untrustedOperative.clientReserveRounds = 999
local authorityBegin = resolver.begin(untrustedOperative, authoritativeWeapon, 50)
assert(authorityBegin.weaponStateAfter.reloadState.startedAtServerTimestamp == 50, "client timestamp influenced begin")
local authorityComplete = resolver.complete(authorityBegin.operativeStateAfter, authorityBegin.weaponStateAfter, 52)
assert(authorityComplete.weaponStateAfter.ammunition.loadedRounds == 12, "client loaded ammo influenced transfer")
assert(authorityComplete.weaponStateAfter.ammunition.reserveRounds == 18, "client reserve ammo influenced transfer")

print(
	"ReloadResolver: begin, completion, transfer, interruption, authority, precedence, conservation, and immutability checks passed"
)
