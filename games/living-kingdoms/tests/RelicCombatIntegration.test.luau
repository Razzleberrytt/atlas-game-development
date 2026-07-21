--!strict

-- RPG-0108 (part 2) per-operative relic effects reach the authoritative combat
-- core: conditional damage through DamageResolver, wounded reload reduction
-- through ReloadResolver, and one revision-cached modifier adapter over the
-- existing run-build owner. Malformed bundles fail the shot closed.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local CONTRACTS_TOKEN = {}
local FIREARM_CONFIG_TOKEN = {}

local attributes: { [string]: number } = {
	RunDamageMultiplier = 1,
	RunCullDamageMultiplier = 1,
	RunCullHealthThreshold = 0,
	RunPatternDamageMultiplier = 1,
	RunSpecialEnemyDamageMultiplier = 1,
	RunLastMagazineDamageMultiplier = 1,
	RunLastMagazineReserveFraction = 0.2,
	RunReloadDurationMultiplier = 1,
	RunMagazineCapacityMultiplier = 1,
}

local progressionNetwork = {
	GetAttribute = function(_self: unknown, attributeName: string)
		return attributes[attributeName]
	end,
}

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
		DamagePerHit = 20,
		MagazineCapacity = 12,
		ReloadDurationSeconds = 2,
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
			assertThat(serviceName == "ReplicatedStorage", "unexpected service request")
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

local damageResolver = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/DamageResolver.luau"), {
	debugName = "DamageResolver",
	environment = environment,
	injectGlobals = true,
})()
local reloadResolver = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/ReloadResolver.luau"), {
	debugName = "ReloadResolver",
	environment = environment,
	injectGlobals = true,
})()

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

local function relicModifiers(overrides: { [string]: number }?)
	local modifiers = {
		specialEnemyDamageMultiplier = 1,
		lowReserveDamageMultiplier = 1,
		lowReserveFraction = 0,
		executionDamageMultiplier = 1,
		executionHealthFraction = 0,
	}
	for key, value in overrides or {} do
		modifiers[key] = value
	end
	return modifiers
end

local function damageContext(overrides: { [string]: any }?)
	local context = {
		reserveRounds = 24,
		maximumReserveRounds = 48,
		isSpecialEnemy = false,
		targetMaximumHealth = 100,
		relicModifiers = relicModifiers(),
	}
	for key, value in overrides or {} do
		context[key] = value
	end
	return context
end

-- A neutral bundle must leave the existing squad-only damage math untouched.
local neutral = damageResolver.resolve(hit("shot.neutral"), health(100), 10, nil, damageContext())
assertThat(neutral.damageEvent.damageAmount == 20, "an equipped-relic-free operative must deal configured damage")

-- Choir Breaker: only special enemies.
local choirContext = { relicModifiers = relicModifiers({ specialEnemyDamageMultiplier = 1.3 }) }
local ordinaryChoir =
	damageResolver.resolve(hit("shot.choir.ordinary"), health(100), 11, nil, damageContext(choirContext))
assertThat(ordinaryChoir.damageEvent.damageAmount == 20, "Choir Breaker must not affect ordinary enemies")
choirContext.isSpecialEnemy = true
local specialChoir =
	damageResolver.resolve(hit("shot.choir.special"), health(100), 12, nil, damageContext(choirContext))
assertThat(specialChoir.damageEvent.damageAmount == 26, "Choir Breaker must raise special-enemy damage")

-- Last Light: only at or below its own reserve fraction, independent of the
-- squad Last Magazine threshold.
local lastLightModifiers = relicModifiers({ lowReserveDamageMultiplier = 1.25, lowReserveFraction = 0.2 })
local stocked = damageResolver.resolve(
	hit("shot.lastlight.stocked"),
	health(100),
	13,
	nil,
	damageContext({
		relicModifiers = lastLightModifiers,
	})
)
assertThat(stocked.damageEvent.damageAmount == 20, "a stocked reserve must not activate Last Light")
local boundary = damageResolver.resolve(
	hit("shot.lastlight.boundary"),
	health(100),
	14,
	nil,
	damageContext({ relicModifiers = lastLightModifiers, reserveRounds = 10 })
)
assertThat(boundary.damageEvent.damageAmount == 20, "reserve above the floored 20% boundary must not activate")
local critical = damageResolver.resolve(
	hit("shot.lastlight.critical"),
	health(100),
	15,
	nil,
	damageContext({ relicModifiers = lastLightModifiers, reserveRounds = 9 })
)
assertThat(critical.damageEvent.damageAmount == 25, "a critical reserve must activate Last Light")

-- Execution Protocol: only at or below the target's own maximum-health fraction,
-- which follows elite health scaling rather than a fixed value.
local executionModifiers = relicModifiers({ executionDamageMultiplier = 1.4, executionHealthFraction = 0.3 })
local healthy = damageResolver.resolve(
	hit("shot.execution.healthy"),
	health(31),
	16,
	nil,
	damageContext({ relicModifiers = executionModifiers })
)
assertThat(healthy.damageEvent.damageAmount == 20, "a target above the execute threshold takes configured damage")
local executable = damageResolver.resolve(
	hit("shot.execution.wounded"),
	health(30),
	17,
	nil,
	damageContext({ relicModifiers = executionModifiers })
)
assertThat(executable.damageEvent.damageAmount == 28, "a target at the execute threshold takes execution damage")
local elite = damageResolver.resolve(
	hit("shot.execution.elite"),
	health(30),
	18,
	nil,
	damageContext({ relicModifiers = executionModifiers, targetMaximumHealth = 300 })
)
assertThat(elite.damageEvent.damageAmount == 28, "the execute threshold must scale with the elite's own maximum health")
local unknownMaximum = damageResolver.resolve(hit("shot.execution.unknown"), health(30), 19, nil, {
	reserveRounds = 24,
	maximumReserveRounds = 48,
	isSpecialEnemy = false,
	relicModifiers = executionModifiers,
})
assertThat(unknownMaximum.damageEvent.damageAmount == 20, "an unknown maximum health must not execute")

-- Stacked relics compose but stay inside the hard configured*3 ceiling shared
-- with the squad Field Upgrades.
local stacked = damageResolver.resolve(
	hit("shot.stacked"),
	health(30),
	20,
	nil,
	damageContext({
		isSpecialEnemy = true,
		reserveRounds = 9,
		relicModifiers = relicModifiers({
			specialEnemyDamageMultiplier = 1.3,
			lowReserveDamageMultiplier = 1.25,
			lowReserveFraction = 0.2,
			executionDamageMultiplier = 1.4,
			executionHealthFraction = 0.3,
		}),
	})
)
assertThat(stacked.damageEvent.damageAmount == 46, "stacked relics must compose within the shared ceiling")
attributes.RunDamageMultiplier = 1.8
attributes.RunSpecialEnemyDamageMultiplier = 1.6
local ceiling = damageResolver.resolve(
	hit("shot.ceiling"),
	health(30),
	21,
	nil,
	damageContext({
		isSpecialEnemy = true,
		reserveRounds = 9,
		relicModifiers = relicModifiers({
			specialEnemyDamageMultiplier = 1.3,
			lowReserveDamageMultiplier = 1.25,
			lowReserveFraction = 0.2,
			executionDamageMultiplier = 1.4,
			executionHealthFraction = 0.3,
		}),
	})
)
assertThat(
	ceiling.didApplyDamage and ceiling.damageEvent.damageAmount == 60,
	"a maxed squad and relic build must clamp to the 3x ceiling, not reject the shot"
)
attributes.RunDamageMultiplier = 1
attributes.RunSpecialEnemyDamageMultiplier = 1

-- Any malformed relic bundle fails the shot closed instead of silently ignoring
-- the relic, so a wiring defect is loud.
for _, malformed in
	{
		relicModifiers({ specialEnemyDamageMultiplier = 5 }),
		relicModifiers({ executionDamageMultiplier = 0.5 }),
		relicModifiers({ lowReserveFraction = 1 }),
		relicModifiers({ executionHealthFraction = -1 }),
	}
do
	local rejected = damageResolver.resolve(
		hit(
			"shot.malformed."
				.. tostring(malformed.specialEnemyDamageMultiplier)
				.. tostring(malformed.executionDamageMultiplier)
				.. tostring(malformed.lowReserveFraction)
				.. tostring(malformed.executionHealthFraction)
		),
		health(30),
		22,
		nil,
		damageContext({
			relicModifiers = malformed,
		})
	)
	assertThat(
		not rejected.didApplyDamage and rejected.rejectionReasonId == "WeaponInvalid",
		"a malformed relic bundle must fail the shot closed"
	)
end

-- Emergency Chamber shortens only reloads accepted while critically wounded and
-- never crosses the shared reload floor.
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

local baselineReload = reloadResolver.begin(operative(), weaponState(), 10)
assertThat(
	baselineReload.didBegin and baselineReload.weaponStateAfter.reloadState.completionServerTimestamp == 12,
	"an unmodified reload must keep the configured duration"
)
local healthyReload = reloadResolver.begin(operative(), weaponState(), 10, {
	woundedReloadDurationMultiplier = 0.75,
	isCriticallyWounded = false,
})
assertThat(
	healthyReload.weaponStateAfter.reloadState.completionServerTimestamp == 12,
	"Emergency Chamber must not shorten a healthy operative's reload"
)
local woundedReload = reloadResolver.begin(operative(), weaponState(), 10, {
	woundedReloadDurationMultiplier = 0.75,
	isCriticallyWounded = true,
})
assertThat(
	woundedReload.weaponStateAfter.reloadState.completionServerTimestamp == 11.5,
	"Emergency Chamber must shorten a critically wounded operative's reload"
)
attributes.RunReloadDurationMultiplier = 0.8
local combinedReload = reloadResolver.begin(operative(), weaponState(), 10, {
	woundedReloadDurationMultiplier = 0.5,
	isCriticallyWounded = true,
})
assertThat(
	combinedReload.weaponStateAfter.reloadState.completionServerTimestamp == 11,
	"the composed squad and relic reduction must clamp to the shared reload floor"
)
attributes.RunReloadDurationMultiplier = 1

-- The modifier adapter derives once per build revision and releases its cache.
local RESOLVER_TOKEN = {}
local BUILD_SERVICE_TOKEN = {}
local deriveCalls = 0
local relicResolver = {
	deriveModifiers = function(relicIds)
		deriveCalls += 1
		return table.freeze({ relicIds = table.clone(relicIds) })
	end,
}
local equippedRead: any = nil
local buildService = {
	readEquippedRelicIds = function()
		return equippedRead
	end,
}
local relicModifierService =
	luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/RelicModifierService.luau"), {
		debugName = "RelicModifierService",
		environment = {
			game = {
				GetService = function(_self: unknown, serviceName: string)
					assertThat(serviceName == "ReplicatedStorage", "unexpected service request")
					return { Shared = { RPG = { RelicModifierResolver = RESOLVER_TOKEN } } }
				end,
			},
			script = { Parent = { RunBuildService = BUILD_SERVICE_TOKEN } },
			require = function(token: unknown)
				if token == RESOLVER_TOKEN then
					return relicResolver
				elseif token == BUILD_SERVICE_TOKEN then
					return buildService
				end
				error("unexpected RelicModifierService dependency")
			end,
		},
		injectGlobals = true,
	})()

local player = { UserId = 1 } :: any
assertThat(deriveCalls == 1, "the neutral bundle must be derived exactly once at load")
assertThat(relicModifierService.read(player) ~= nil, "an untracked operative must still receive a bundle")
assertThat(deriveCalls == 1, "an untracked operative must not derive a new bundle")

equippedRead = table.freeze({ revision = 7, relicIds = table.freeze({ "Relic.BloodBattery" }) })
local firstRead = relicModifierService.read(player)
assertThat(deriveCalls == 2 and firstRead.relicIds[1] == "Relic.BloodBattery", "an equipped relic must be derived")
assertThat(relicModifierService.read(player) == firstRead, "an unchanged build revision must reuse the cached bundle")
assertThat(deriveCalls == 2, "an unchanged build revision must not re-derive")

equippedRead = table.freeze({ revision = 8, relicIds = table.freeze({ "Relic.LastLight" }) })
local secondRead = relicModifierService.read(player)
assertThat(deriveCalls == 3 and secondRead.relicIds[1] == "Relic.LastLight", "a new build revision must re-derive")

relicModifierService.forget(player)
relicModifierService.read(player)
assertThat(deriveCalls == 4, "a forgotten operative must derive again")
relicModifierService.clear()
relicModifierService.read(player)
assertThat(deriveCalls == 5, "a cleared cache must derive again")

-- Source audits: the authoritative owners, not a parallel relic runtime, apply
-- the effects, and the relic read never becomes a client surface.
local combatRuntime = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau")
local buildStore = fs.readFile("games/living-kingdoms/src/server/Systems/RunBuildStateStore.luau")
local buildServiceSource = fs.readFile("games/living-kingdoms/src/server/Systems/RunBuildService.luau")
local adapter = fs.readFile("games/living-kingdoms/src/server/Systems/RelicModifierService.luau")

assertThat(
	contains(combatRuntime, "relicModifiers = RelicModifierService.read(player)"),
	"the combat owner must supply per-operative relic damage modifiers"
)
assertThat(
	contains(combatRuntime, "relicReloadContext(player)"),
	"the combat owner must supply the per-operative relic reload context"
)
assertThat(
	contains(combatRuntime, "RelicModifierService.forget(player)")
		and contains(combatRuntime, "RelicModifierService.clear()"),
	"the combat owner must release cached relic modifiers on disconnect and teardown"
)
assertThat(
	contains(combatRuntime, "OperativeLifeService.read(player)"),
	"the wounded fact must come from the authoritative life owner"
)
assertThat(
	not contains(adapter, "RemoteEvent") and not contains(adapter, "FireClient"),
	"the relic modifier adapter must add no network surface"
)
assertThat(
	contains(buildStore, "function store:readEquippedRelicIds"),
	"equipped relics must be read from the existing run-build owner"
)
assertThat(
	contains(buildServiceSource, "RunBuildService.readEquippedRelicIds"),
	"the run-build service must expose the server-only relic read"
)

print("RelicCombatIntegration: bounded per-operative relic damage, reload, caching, and audits passed")
