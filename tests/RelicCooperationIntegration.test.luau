--!strict

-- RPG-0109 cooperative relics inside the authoritative P3 life core: Guardian
-- Signal's expiring temporary armor absorbs incoming damage before health, and
-- Second Wind spends one operation charge to convert an incapacitating hit into
-- a fragile survival. Neither may bypass replay protection or repeat.

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

local contractsModule = luau.load(fs.readFile("games/living-kingdoms/src/shared/Health/OperativeLifeContracts.luau"), {
	debugName = "OperativeLifeContracts",
	environment = {
		game = {
			GetService = function()
				return { Shared = { Combat = { CombatContracts = {} } } }
			end,
		},
		script = { Parent = { Parent = { Combat = { CombatContracts = {} } } } },
		require = function()
			return {}
		end,
	},
	injectGlobals = true,
})()

local LifeStateIds = contractsModule.OperativeLifeStateIds

-- The pure health resolver under test is the production module; only its
-- dependencies are stubbed.
local LIFE_CONTRACTS_TOKEN = {}
local LIFE_CONFIG_TOKEN = {}
local lifeConfig = {
	MaximumHealth = 100,
	BleedOutDurationSeconds = 60,
	SoloRecoveriesPerOperation = 1,
	SoloRecoveryDurationSeconds = 10,
}

local healthResolver = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/OperativeHealthResolver.luau"), {
	debugName = "OperativeHealthResolver",
	environment = {
		game = {
			GetService = function()
				return {
					Shared = {
						Health = { OperativeLifeContracts = LIFE_CONTRACTS_TOKEN },
						Config = { OperativeLifeConfig = LIFE_CONFIG_TOKEN },
					},
				}
			end,
		},
		require = function(token: unknown)
			if token == LIFE_CONTRACTS_TOKEN then
				return contractsModule
			elseif token == LIFE_CONFIG_TOKEN then
				return lifeConfig
			end
			error("unexpected OperativeHealthResolver dependency")
		end,
		injectGlobals = true,
	},
	injectGlobals = true,
})()

local function snapshot(currentHealth: number)
	return {
		operativeEntityId = "operative.player:1",
		lifeStateId = LifeStateIds.Alive,
		healthState = { currentHealth = currentHealth, maximumHealth = 100 },
		incapacitationState = nil,
		soloRecoveryState = {
			isEligible = false,
			recoveriesUsed = 0,
			recoveryStartedAtServerTimestamp = nil,
			recoveryCompletionServerTimestamp = nil,
		},
		processedDamageEventIds = {},
	}
end

local function damage(damageEventId: string, damageAmount: number, serverTimestamp: number)
	return {
		damageEventId = damageEventId,
		sourceEntityId = "hostile.fixture",
		targetEntityId = "operative.player:1",
		damageAmount = damageAmount,
		serverTimestamp = serverTimestamp,
	}
end

-- Baseline: the pure boundary the relics reuse still resolves ordinary and
-- incapacitating damage exactly as before.
local ordinary = healthResolver.resolveDamage(snapshot(100), damage("damage:1", 30, 5), 5)
assertThat(
	ordinary.didTransition and ordinary.snapshotAfter.healthState.currentHealth == 70,
	"ordinary damage must remain unchanged"
)
local lethal = healthResolver.resolveDamage(snapshot(30), damage("damage:2", 30, 6), 6)
assertThat(
	lethal.didTransition and lethal.snapshotAfter.lifeStateId == LifeStateIds.Incapacitated,
	"lethal damage must still incapacitate"
)

-- Second Wind's reduced re-resolve leaves the operative alive at the configured
-- survival health, and the reduced event keeps its identity for replay protection.
local relicRuntimeConfig = (function()
	local RPG_CONTRACTS_TOKEN = {}
	local RPG_CONFIG_TOKEN = {}
	local rpgContracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/RPG/RunRpgContracts.luau"), {
		debugName = "RunRpgContracts",
		injectGlobals = true,
	})()
	local rpgConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RunRpgConfig.luau"), {
		debugName = "RunRpgConfig",
		environment = {
			script = { Parent = { Parent = { RPG = { RunRpgContracts = RPG_CONTRACTS_TOKEN } } } },
			require = function()
				return rpgContracts
			end,
		},
		injectGlobals = true,
	})()
	return luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RelicRuntimeConfig.luau"), {
		debugName = "RelicRuntimeConfig",
		environment = {
			game = {
				GetService = function()
					return {
						Shared = {
							RPG = { RunRpgContracts = RPG_CONTRACTS_TOKEN },
							Config = { RunRpgConfig = RPG_CONFIG_TOKEN },
						},
					}
				end,
			},
			require = function(token: unknown)
				if token == RPG_CONTRACTS_TOKEN then
					return rpgContracts
				elseif token == RPG_CONFIG_TOKEN then
					return rpgConfig
				end
				error("unexpected RelicRuntimeConfig dependency")
			end,
		},
		injectGlobals = true,
	})()
end)()

local survivalHealth = relicRuntimeConfig.SecondWind.survivalHealth
local reprieve = healthResolver.resolveDamage(snapshot(90), damage("damage:3", 90 - survivalHealth, 7), 7)
assertThat(
	reprieve.didTransition
		and reprieve.snapshotAfter.lifeStateId == LifeStateIds.Alive
		and reprieve.snapshotAfter.healthState.currentHealth == survivalHealth,
	"the Second Wind reduction must leave the operative alive at the configured survival health"
)
assertThat(
	reprieve.snapshotAfter.processedDamageEventIds["damage:3"] == true,
	"a reduced reprieve event must still be recorded for replay protection"
)

-- The store never hands out a second charge for a once-per-operation relic.
local STORE_CONTRACTS = {}
local STORE_CONFIG = {}
local STORE_MODIFIER = {}
local STORE_REWARD = {}
local rpgContracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/RPG/RunRpgContracts.luau"), {
	debugName = "RunRpgContracts",
	injectGlobals = true,
})()
local rpgConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RunRpgConfig.luau"), {
	debugName = "RunRpgConfig",
	environment = {
		script = { Parent = { Parent = { RPG = { RunRpgContracts = {} } } } },
		require = function()
			return rpgContracts
		end,
	},
	injectGlobals = true,
})()
local function loadShared(path: string, debugName: string, modules)
	return luau.load(fs.readFile(path), {
		debugName = debugName,
		environment = {
			game = {
				GetService = function()
					return {
						Shared = {
							RPG = {
								RunRpgContracts = STORE_CONTRACTS,
								RelicModifierResolver = STORE_MODIFIER,
								RelicRewardResolver = STORE_REWARD,
							},
							Config = { RunRpgConfig = STORE_CONFIG, RelicRuntimeConfig = STORE_CONFIG },
							Progression = { RunModifierResolver = STORE_CONFIG },
						},
					}
				end,
			},
			require = function(token: unknown)
				if token == STORE_CONTRACTS then
					return rpgContracts
				elseif token == STORE_CONFIG then
					return rpgConfig
				elseif token == STORE_MODIFIER then
					return modules.modifierResolver
				elseif token == STORE_REWARD then
					return modules.rewardResolver
				end
				error("unexpected " .. debugName .. " dependency")
			end,
		},
		injectGlobals = true,
	})()
end

local modifierResolver = loadShared("games/living-kingdoms/src/shared/RPG/RelicModifierResolver.luau", "modifier", {})
local rewardResolver = loadShared("games/living-kingdoms/src/shared/RPG/RelicRewardResolver.luau", "reward", {})
local storeModule = loadShared("games/living-kingdoms/src/server/Systems/RunBuildStateStore.luau", "store", {
	modifierResolver = modifierResolver,
	rewardResolver = rewardResolver,
})

local store = storeModule.new()
local generation = store:startOperation()
store:registerOperative("operative-a")
local offered, _, sequence =
	store:enqueueRelicReward(generation, "off:1", "operative-a", "reward-source.elite-kill", {})
assertThat(offered and sequence ~= nil, "reward offer failed")
local offer = store:readSafeSnapshot("operative-a").pendingRewards[1]
local chosenRelicId = offer.offeredRelicIds[1]
assertThat(store:chooseRelic(generation, "ch:1", "operative-a", sequence, chosenRelicId), "relic choice failed")

local chargedRelic: any = nil
for _, definition in rpgConfig.RelicCatalog do
	if definition.relicId == chosenRelicId then
		chargedRelic = definition
	end
end
assertThat(chargedRelic ~= nil, "chosen relic must exist in the catalog")
assertThat(
	store:readSafeSnapshot("operative-a").relicSlots[1].chargeCount == chargedRelic.maximumCharges,
	"equipping must initialise the relic's declared operation charges"
)
local expectedCharges = chargedRelic.maximumCharges
for index = 1, expectedCharges do
	assertThat(
		store:consumeRelicCharge("operative-a", chosenRelicId),
		"declared charge " .. index .. " must be spendable"
	)
end
assertThat(not store:consumeRelicCharge("operative-a", chosenRelicId), "a spent relic must not yield another charge")
assertThat(not store:consumeRelicCharge("operative-a", "relic.not-equipped"), "an unequipped relic has no charge")
store:stopOperation()
assertThat(not store:consumeRelicCharge("operative-a", chosenRelicId), "a torn-down operation holds no charges")

-- Source audits: the life owner remains the only authority, and armor never
-- becomes replicated life state or fully negates an authoritative event.
local lifeService = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeLifeService.luau")
local reviveService = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeReviveSessionService.luau")

assertThat(
	contains(lifeService, "math.max(0, math.floor(damageAmount) - 1)"),
	"temporary armor must never absorb an entire authoritative damage event"
)
assertThat(
	contains(lifeService, "RelicModifierService.consumeSecondWindCharge(player)"),
	"the reprieve must spend its charge before re-resolving"
)
assertThat(
	contains(lifeService, "OperativeHealthResolver.resolveDamage(")
		and not contains(lifeService, "entry.snapshot.healthState.currentHealth ="),
	"the reprieve must go through the pure resolver rather than writing health directly"
)
assertThat(
	contains(lifeService, "temporaryArmorByPlayer[player] = nil")
		and contains(lifeService, "table.clear(temporaryArmorByPlayer)"),
	"armor pools must be released on unregister and teardown"
)
assertThat(
	not contains(lifeService, "temporaryArmor = armor") and not contains(lifeService, "snapshot.temporaryArmor"),
	"temporary armor must stay out of the replicated life snapshot"
)
assertThat(
	contains(reviveService, "grantGuardianSignalArmor(session, serverTimestamp)")
		and contains(reviveService, "OperativeLifeService.grantTemporaryArmor"),
	"Guardian Signal must grant through the life owner on a committed revive"
)
assertThat(
	contains(reviveService, "read.snapshot.healthState.maximumHealth * fraction"),
	"armor must derive from each operative's own authoritative maximum health"
)

print("RelicCooperationIntegration: bounded armor absorption, one-charge reprieve, and life-core audits passed")
