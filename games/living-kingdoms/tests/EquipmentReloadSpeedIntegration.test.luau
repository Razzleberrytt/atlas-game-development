--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function assertNear(actual: number, expected: number, message: string)
	assertThat(math.abs(actual - expected) < 1e-9, message)
end

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

local resolver = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/ReloadResolver.luau"), {
	debugName = "ReloadResolverEquipmentIntegration",
	environment = {
		game = {
			GetService = function(_self: unknown, serviceName: string)
				assertThat(serviceName == "ReplicatedStorage", "unexpected service request")
				return replicatedStorage
			end,
		},
		require = function(token: unknown)
			if token == CONTRACTS_TOKEN then
				return contracts
			elseif token == CONFIG_TOKEN then
				return config
			end
			error("unexpected reload-resolver dependency")
		end,
	},
	injectGlobals = true,
})()

local function operative()
	return {
		entityId = "operative.alpha",
		combatStateId = "Ready",
		equippedWeaponId = "weapon.basic_firearm",
	}
end

local function weaponState()
	return {
		weaponId = "weapon.basic_firearm",
		readinessStateId = "Ready",
		ammunition = {
			weaponId = "weapon.basic_firearm",
			loadedRounds = 6,
			reserveRounds = 24,
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

local function completion(context: any?): number
	local result = resolver.begin(operative(), weaponState(), 10, context)
	assertThat(result.didBegin == true, "valid reload context must begin")
	return result.weaponStateAfter.reloadState.completionServerTimestamp
end

assertThat(completion(nil) == 12, "neutral reload must preserve configured duration")
assertNear(
	completion({
		woundedReloadDurationMultiplier = 1,
		isCriticallyWounded = false,
		equipmentReloadDurationMultiplier = 0.9,
	}),
	11.8,
	"equipment reload speed must always shorten the active weapon reload"
)
assertNear(
	completion({
		woundedReloadDurationMultiplier = 0.75,
		isCriticallyWounded = false,
		equipmentReloadDurationMultiplier = 0.9,
	}),
	11.8,
	"healthy Emergency Chamber must not leak into equipment reload speed"
)
assertNear(
	completion({
		woundedReloadDurationMultiplier = 0.75,
		isCriticallyWounded = true,
		equipmentReloadDurationMultiplier = 0.9,
	}),
	11.35,
	"wounded relic and equipped reload speed must compose"
)

progressionAttributes.RunReloadDurationMultiplier = 0.8
assertNear(
	completion({
		woundedReloadDurationMultiplier = 0.75,
		isCriticallyWounded = true,
		equipmentReloadDurationMultiplier = 0.9,
	}),
	11.08,
	"squad, relic, and equipment reload modifiers must compose once"
)
progressionAttributes.RunReloadDurationMultiplier = 0.5
assertThat(completion({
	woundedReloadDurationMultiplier = 0.5,
	isCriticallyWounded = true,
	equipmentReloadDurationMultiplier = 0.5,
}) == 11, "combined reload modifiers must respect the authoritative 0.5 floor")
progressionAttributes.RunReloadDurationMultiplier = nil
assertThat(completion({
	woundedReloadDurationMultiplier = 1,
	isCriticallyWounded = false,
	equipmentReloadDurationMultiplier = 0 / 0,
}) == 12, "malformed equipment reload facts must fail neutral")

local affixSource = fs.readFile("games/living-kingdoms/src/shared/Equipment/EquipmentAffixModifierResolver.luau")
local equippedSource = fs.readFile("games/living-kingdoms/src/shared/Equipment/EquippedEquipmentModifierResolver.luau")
local compositionSource = fs.readFile("games/living-kingdoms/src/server/Systems/RelicModifierService.luau")
local runtimeSource = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau")
local reloadSource = fs.readFile("games/living-kingdoms/src/server/Systems/ReloadResolver.luau")

assertThat(
	string.find(affixSource, 'RELOAD_SPEED_EFFECT_ID = "ReloadSpeedPercent"', 1, true) ~= nil,
	"reload-speed affix must be translated by the shared bounded adapter"
)
assertThat(
	string.find(affixSource, "reloadDurationReduction = reloadSpeedPercent / PERCENT_SCALE", 1, true) ~= nil,
	"reload-speed percentage must route through canonical modifier arithmetic"
)
assertThat(
	string.find(equippedSource, "reloadDurationMultiplier = modifiers.reloadDurationMultiplier", 1, true) ~= nil,
	"equipped weapon resolver must expose the active item's reload modifier"
)
assertThat(
	string.find(compositionSource, "resolveForWeapon(record, activeWeaponId)", 1, true) ~= nil
		and string.find(
			compositionSource,
			"combined.equipmentReloadDurationMultiplier = weaponModifiers.reloadDurationMultiplier",
			1,
			true
		) ~= nil,
	"server composition seam must join the authoritative inventory reload fact"
)
assertThat(
	string.find(
		runtimeSource,
		"equipmentReloadDurationMultiplier = modifiers.equipmentReloadDurationMultiplier",
		1,
		true
	) ~= nil,
	"combat runtime must pass the server-composed equipment fact into reload authority"
)
assertThat(
	string.find(reloadSource, "value * relicMultiplier * equipmentMultiplier", 1, true) ~= nil,
	"ReloadResolver must remain the one composition owner"
)

print("EquipmentReloadSpeedIntegration: authoritative equipment reload routing passed")
