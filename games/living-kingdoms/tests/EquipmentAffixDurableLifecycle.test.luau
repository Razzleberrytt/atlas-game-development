--!strict

-- Patch 0.3 composed durable-affix lifecycle regression.
--
-- This fixture deliberately crosses the production pure/server boundaries that
-- already own the feature instead of inventing a test-only persistence or
-- equipment authority:
--
-- deterministic EquipmentRewardService
--   -> PlayerInventoryPersistenceService durable save/load
--   -> EquippedEquipmentModifierResolver authoritative slot selection
--   -> EquipmentAffixModifierResolver bounded live facts
--
-- A fresh persistence-service instance simulates reconnect reconstruction. The
-- fixture covers one Rare weapon, Armor, and Relic carrying both live effect
-- families for that ownership shape.

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

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[key] = deepCopy(child)
	end
	return copy
end

local AFFIX_CONTRACTS_TOKEN = {}
local REWARD_CONTRACTS_TOKEN = {}
local COMBAT_CONTRACTS_TOKEN = {}
local REWARD_CONFIG_TOKEN = {}
local AFFIX_CONFIG_TOKEN = {}
local AFFIX_RESOLVER_TOKEN = {}
local RUN_CONFIG_TOKEN = {}
local RUN_MODIFIER_TOKEN = {}
local AFFIX_MODIFIER_TOKEN = {}
local INVENTORY_CONTRACTS_TOKEN = {}
local DISMANTLE_TOKEN = {}

local affixContracts =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Equipment/EquipmentAffixContracts.luau"), {
		debugName = "EquipmentAffixContracts",
		injectGlobals = true,
	})()

local rewardContracts =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Equipment/EquipmentRewardContracts.luau"), {
		debugName = "EquipmentRewardContracts",
		environment = {
			script = { Parent = { EquipmentAffixContracts = AFFIX_CONTRACTS_TOKEN } },
			require = function(token: unknown)
				assertThat(token == AFFIX_CONTRACTS_TOKEN, "unexpected reward-contract dependency")
				return affixContracts
			end,
		},
		injectGlobals = true,
	})()

local combatContracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Combat/CombatContracts.luau"), {
	debugName = "CombatContracts",
	injectGlobals = true,
})()

local rewardConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/EquipmentRewardConfig.luau"), {
	debugName = "EquipmentRewardConfig",
	environment = {
		script = {
			Parent = {
				Parent = {
					Equipment = { EquipmentRewardContracts = REWARD_CONTRACTS_TOKEN },
					Combat = { CombatContracts = COMBAT_CONTRACTS_TOKEN },
				},
			},
		},
		require = function(token: unknown)
			if token == COMBAT_CONTRACTS_TOKEN then
				return combatContracts
			end
			assertThat(token == REWARD_CONTRACTS_TOKEN, "unexpected reward-config dependency")
			return rewardContracts
		end,
	},
	injectGlobals = true,
})()

local affixConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/EquipmentAffixConfig.luau"), {
	debugName = "EquipmentAffixConfig",
	environment = {
		script = {
			Parent = {
				Parent = {
					Equipment = { EquipmentAffixContracts = AFFIX_CONTRACTS_TOKEN },
				},
			},
		},
		require = function(token: unknown)
			assertThat(token == AFFIX_CONTRACTS_TOKEN, "unexpected affix-config dependency")
			return affixContracts
		end,
	},
	injectGlobals = true,
})()

local affixResolver =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Equipment/EquipmentAffixResolver.luau"), {
		debugName = "EquipmentAffixResolver",
		environment = {
			script = { Parent = { EquipmentAffixContracts = AFFIX_CONTRACTS_TOKEN } },
			require = function(token: unknown)
				assertThat(token == AFFIX_CONTRACTS_TOKEN, "unexpected affix-resolver dependency")
				return affixContracts
			end,
		},
		injectGlobals = true,
	})()

local runModifierConfig = {
	ModifierCeilings = {
		maximumDamageMultiplier = 3,
		minimumCadenceMultiplier = 0.55,
		maximumAmmunitionConservationChance = 0.5,
		maximumIncomingDamageReduction = 0.3,
		maximumFieldXpMultiplier = 1.5,
		minimumReloadDurationMultiplier = 0.5,
		maximumPatternDamageMultiplier = 2,
		maximumSpecialEnemyDamageMultiplier = 2,
		maximumMagazineCapacityMultiplier = 1.75,
		maximumLootPickupRadiusBonusStuds = 4.5,
		maximumConditionalDamageMultiplier = 1.5,
		maximumMovementSpeedMultiplier = 1.35,
		maximumAutomaticHealingPerTrigger = 25,
		maximumTemporaryArmorFractionOfMaximumHealth = 0.4,
		maximumLootChanceAdditiveBonus = 0.15,
		maximumLootRoundsAdditiveBonus = 6,
		maximumKillChainExtensionSeconds = 2,
		maximumGeneralProcChance = 0.35,
	},
}

local runModifierResolver =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Progression/RunModifierResolver.luau"), {
		debugName = "RunModifierResolver",
		environment = {
			script = { Parent = { Parent = { Config = { RunRpgConfig = RUN_CONFIG_TOKEN } } } },
			require = function(token: unknown)
				assertThat(token == RUN_CONFIG_TOKEN, "unexpected run-modifier dependency")
				return runModifierConfig
			end,
		},
		injectGlobals = true,
	})()

local affixModifierResolver =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Equipment/EquipmentAffixModifierResolver.luau"), {
		debugName = "EquipmentAffixModifierResolver",
		environment = {
			script = {
				Parent = {
					EquipmentRewardContracts = REWARD_CONTRACTS_TOKEN,
					Parent = { Progression = { RunModifierResolver = RUN_MODIFIER_TOKEN } },
				},
			},
			require = function(token: unknown)
				if token == REWARD_CONTRACTS_TOKEN then
					return rewardContracts
				end
				assertThat(token == RUN_MODIFIER_TOKEN, "unexpected affix-modifier dependency")
				return runModifierResolver
			end,
		},
		injectGlobals = true,
	})()

local equippedResolver =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Equipment/EquippedEquipmentModifierResolver.luau"), {
		debugName = "EquippedEquipmentModifierResolver",
		environment = {
			script = {
				Parent = {
					Parent = { Config = { EquipmentRewardConfig = REWARD_CONFIG_TOKEN } },
					EquipmentRewardContracts = REWARD_CONTRACTS_TOKEN,
					EquipmentAffixModifierResolver = AFFIX_MODIFIER_TOKEN,
				},
			},
			require = function(token: unknown)
				if token == REWARD_CONFIG_TOKEN then
					return rewardConfig
				end
				if token == REWARD_CONTRACTS_TOKEN then
					return rewardContracts
				end
				assertThat(token == AFFIX_MODIFIER_TOKEN, "unexpected equipped-modifier dependency")
				return affixModifierResolver
			end,
		},
		injectGlobals = true,
	})()

local inventoryContracts =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Persistence/PlayerInventoryContracts.luau"), {
		debugName = "PlayerInventoryContracts",
		environment = {
			script = { Parent = { Parent = { Equipment = { EquipmentRewardContracts = REWARD_CONTRACTS_TOKEN } } } },
			require = function(token: unknown)
				assertThat(token == REWARD_CONTRACTS_TOKEN, "unexpected inventory-contract dependency")
				return rewardContracts
			end,
		},
		injectGlobals = true,
	})()

local dismantleResolver =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Persistence/InventoryDismantleResolver.luau"), {
		debugName = "InventoryDismantleResolver",
		environment = {
			script = {
				Parent = {
					PlayerInventoryContracts = INVENTORY_CONTRACTS_TOKEN,
					Parent = { Equipment = { EquipmentRewardContracts = REWARD_CONTRACTS_TOKEN } },
				},
			},
			require = function(token: unknown)
				if token == INVENTORY_CONTRACTS_TOKEN then
					return inventoryContracts
				end
				assertThat(token == REWARD_CONTRACTS_TOKEN, "unexpected dismantle dependency")
				return rewardContracts
			end,
		},
		injectGlobals = true,
	})()

local issuedInstanceIds = 0
local httpService = {
	GenerateGUID = function(_self: unknown, withBraces: boolean): string
		assertThat(withBraces == false, "reward GUIDs must omit braces")
		issuedInstanceIds += 1
		return string.format("00000000-0000-4000-8000-%012d", issuedInstanceIds)
	end,
}

local replicatedStorage = {
	Shared = {
		Equipment = {
			EquipmentRewardContracts = REWARD_CONTRACTS_TOKEN,
			EquipmentAffixContracts = AFFIX_CONTRACTS_TOKEN,
			EquipmentAffixResolver = AFFIX_RESOLVER_TOKEN,
		},
		Config = {
			EquipmentRewardConfig = REWARD_CONFIG_TOKEN,
			EquipmentAffixConfig = AFFIX_CONFIG_TOKEN,
		},
		Persistence = {
			PlayerInventoryContracts = INVENTORY_CONTRACTS_TOKEN,
			InventoryDismantleResolver = DISMANTLE_TOKEN,
		},
	},
}

local function requireProductionToken(token: unknown)
	if token == REWARD_CONTRACTS_TOKEN then
		return rewardContracts
	elseif token == AFFIX_CONTRACTS_TOKEN then
		return affixContracts
	elseif token == REWARD_CONFIG_TOKEN then
		return rewardConfig
	elseif token == AFFIX_CONFIG_TOKEN then
		return affixConfig
	elseif token == AFFIX_RESOLVER_TOKEN then
		return affixResolver
	elseif token == INVENTORY_CONTRACTS_TOKEN then
		return inventoryContracts
	elseif token == DISMANTLE_TOKEN then
		return dismantleResolver
	end
	error("unexpected production dependency", 2)
end

local gameStub = {
	GetService = function(_self: unknown, serviceName: string)
		if serviceName == "HttpService" then
			return httpService
		end
		assertThat(serviceName == "ReplicatedStorage", "unexpected service request")
		return replicatedStorage
	end,
}

local rewardServiceModule =
	luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/EquipmentRewardService.luau"), {
		debugName = "EquipmentRewardService",
		environment = {
			game = gameStub,
			require = requireProductionToken,
		},
		injectGlobals = true,
	})()

local persistenceServiceModule =
	luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/PlayerInventoryPersistenceService.luau"), {
		debugName = "PlayerInventoryPersistenceService",
		environment = {
			game = gameStub,
			require = requireProductionToken,
		},
		injectGlobals = true,
	})()

local EffectIds = affixContracts.EffectIds
local SlotIds = rewardContracts.SlotIds
local SourceIds = rewardContracts.SourceIds
local RarityIds = rewardContracts.RarityIds

type Reward = any

type FoundReward = {
	reward: Reward,
	seed: number,
}

local function effectSet(reward: Reward): { [string]: boolean }
	local effects = {}
	for _, affix in reward.Affixes do
		effects[affix.EffectId] = true
	end
	return effects
end

local function classification(reward: Reward): string?
	if reward.Rarity ~= RarityIds.Rare then
		return nil
	end
	local effects = effectSet(reward)
	if
		(reward.Slot == SlotIds.Primary or reward.Slot == SlotIds.Secondary)
		and effects[EffectIds.DamagePercent]
		and effects[EffectIds.ReloadSpeedPercent]
	then
		return "Weapon"
	elseif
		reward.Slot == SlotIds.Armor
		and effects[EffectIds.MaxHealthPercent]
		and effects[EffectIds.MoveSpeedPercent]
	then
		return "Armor"
	elseif
		reward.Slot == SlotIds.Relic
		and effects[EffectIds.AbilityHastePercent]
		and effects[EffectIds.AbilityPowerPercent]
	then
		return "Relic"
	end
	return nil
end

local found: { [string]: FoundReward } = {}
for seed = 1, 2_000 do
	local runId = string.format("affix-lifecycle-%d", seed)
	local service = rewardServiceModule.new(runId, seed)
	local claimed = service:claimReward(SourceIds.Boss)
	assertThat(claimed.Accepted and claimed.Reward ~= nil, "deterministic boss reward should resolve")
	local target = classification(claimed.Reward)
	if target ~= nil and found[target] == nil then
		found[target] = { reward = claimed.Reward, seed = seed }
	end
	service:destroy()
	if found.Weapon ~= nil and found.Armor ~= nil and found.Relic ~= nil then
		break
	end
end

assertThat(found.Weapon ~= nil, "bounded seed search must find Rare weapon damage+reload lifecycle sample")
assertThat(found.Armor ~= nil, "bounded seed search must find Rare Armor health+movement lifecycle sample")
assertThat(found.Relic ~= nil, "bounded seed search must find Rare Relic haste+power lifecycle sample")

local function assertAffixesEqual(expected, actual, label: string)
	assertThat(#actual == #expected, label .. " affix count changed across persistence")
	for index, original in expected do
		local reconstructed = actual[index]
		assertThat(reconstructed.Id == original.Id, label .. " affix ID changed")
		assertThat(reconstructed.Version == original.Version, label .. " affix version changed")
		assertThat(reconstructed.DisplayName == original.DisplayName, label .. " affix display name changed")
		assertThat(reconstructed.EffectId == original.EffectId, label .. " affix effect changed")
		assertThat(reconstructed.Value == original.Value, label .. " affix value changed")
	end
end

local store = { data = {} }
function store:load(key: string)
	return deepCopy(self.data[key])
end
function store:save(key: string, value: any): boolean
	self.data[key] = deepCopy(value)
	return true
end

local playerId = 8_080
local persistence = persistenceServiceModule.new(store)
local initial = persistence:loadPlayer(playerId, 10_000)
assertThat(initial.Accepted, "fresh durable inventory must load")

local orderedTargets = { "Weapon", "Armor", "Relic" }
for index, target in orderedTargets do
	local reward = found[target].reward
	local applied = persistence:applyReward(playerId, reward, 10_000 + index)
	assertThat(applied.Accepted, target .. " reward must enter durable inventory")
	local equipped = persistence:equip(playerId, reward.Slot, reward.InstanceId, 10_100 + index)
	assertThat(equipped.Accepted, target .. " reward must equip through durable authority")
end

local beforeReconnect = persistence:getRecord(playerId)
assertThat(beforeReconnect ~= nil, "durable record must exist before reconnect")

-- A new owner instance loading the same backing store models reconnect/profile
-- reconstruction. The original in-memory service is deliberately not reused.
local reconnectService = persistenceServiceModule.new(store)
local reconnect = reconnectService:loadPlayer(playerId, 11_000)
assertThat(reconnect.Accepted and not reconnect.Migrated, "current-schema durable profile must reconstruct directly")
local reconstructedRecord = reconnect.Record

local definitionsById = {}
for _, definition in rewardConfig.Definitions do
	definitionsById[definition.Id] = definition
end

local function assertModifierBundle(actual, expected, label: string)
	assertNear(actual.damageMultiplier, expected.damageMultiplier, label .. " damage fact changed")
	assertNear(actual.reloadDurationMultiplier, expected.reloadDurationMultiplier, label .. " reload fact changed")
	assertNear(actual.maximumHealthMultiplier, expected.maximumHealthMultiplier, label .. " health fact changed")
	assertNear(actual.movementSpeedMultiplier, expected.movementSpeedMultiplier, label .. " movement fact changed")
	assertNear(
		actual.abilityCooldownDurationMultiplier,
		expected.abilityCooldownDurationMultiplier,
		label .. " ability-haste fact changed"
	)
	assertNear(actual.abilityPowerMultiplier, expected.abilityPowerMultiplier, label .. " ability-power fact changed")
end

for _, target in orderedTargets do
	local originalReward = found[target].reward
	local reconstructedReward = reconstructedRecord.InventoryByInstanceId[originalReward.InstanceId]
	assertThat(reconstructedReward ~= nil, target .. " reward disappeared after reconnect reconstruction")
	assertThat(
		reconstructedReward.ContentSignature == originalReward.ContentSignature,
		target .. " deterministic content signature changed"
	)
	assertThat(reconstructedReward.GrantId == originalReward.GrantId, target .. " durable grant identity changed")
	assertThat(reconstructedReward.Seed == originalReward.Seed, target .. " affix seed changed")
	assertAffixesEqual(originalReward.Affixes, reconstructedReward.Affixes, target)
	assertThat(
		reconstructedRecord.EquippedBySlot[originalReward.Slot] == originalReward.InstanceId,
		target .. " equipped slot did not survive reconnect"
	)

	local expectedModifiers = affixModifierResolver.resolve(originalReward.Affixes)
	local actualModifiers
	if target == "Weapon" then
		local definition = definitionsById[originalReward.DefinitionId]
		assertThat(definition ~= nil and type(definition.WeaponId) == "string", "weapon definition must retain combat link")
		actualModifiers = equippedResolver.resolveForWeapon(reconstructedRecord, definition.WeaponId)
	else
		actualModifiers = equippedResolver.resolveForSlot(reconstructedRecord, originalReward.Slot)
	end
	assertThat(actualModifiers.sourceInstanceId == originalReward.InstanceId, target .. " selected wrong durable instance")
	assertModifierBundle(actualModifiers, expectedModifiers, target)
end

-- The complete six-effect vocabulary is represented by the three reconstructed
-- samples, not inferred from configuration alone.
local representedEffects = {}
for _, target in orderedTargets do
	for _, affix in found[target].reward.Affixes do
		representedEffects[affix.EffectId] = true
	end
end
for _, effectId in EffectIds do
	assertThat(representedEffects[effectId] == true, "lifecycle sample did not exercise live effect " .. effectId)
end

-- Removing authoritative equip state must immediately make the corresponding
-- consequence neutral. A mismatched weapon identity must also fail closed.
local unequipped = deepCopy(reconstructedRecord)
local armorReward = found.Armor.reward
local relicReward = found.Relic.reward
unequipped.EquippedBySlot[armorReward.Slot] = nil
unequipped.EquippedBySlot[relicReward.Slot] = nil
local neutralArmor = equippedResolver.resolveForSlot(unequipped, SlotIds.Armor)
local neutralRelic = equippedResolver.resolveForSlot(unequipped, SlotIds.Relic)
local mismatchedWeapon = equippedResolver.resolveForWeapon(reconstructedRecord, "weapon.not-authored")
assertThat(neutralArmor.sourceInstanceId == nil, "unequipped Armor must have no modifier source")
assertThat(neutralArmor.maximumHealthMultiplier == 1 and neutralArmor.movementSpeedMultiplier == 1, "unequipped Armor must be neutral")
assertThat(neutralRelic.sourceInstanceId == nil, "unequipped Relic must have no modifier source")
assertThat(
	neutralRelic.abilityCooldownDurationMultiplier == 1 and neutralRelic.abilityPowerMultiplier == 1,
	"unequipped Relic must be neutral"
)
assertThat(mismatchedWeapon.sourceInstanceId == nil, "mismatched weapon identity must have no modifier source")
assertThat(
	mismatchedWeapon.damageMultiplier == 1 and mismatchedWeapon.reloadDurationMultiplier == 1,
	"mismatched weapon identity must be neutral"
)

persistence:destroy()
reconnectService:destroy()

print(string.format(
	"EquipmentAffixDurableLifecycle: weapon seed=%d, Armor seed=%d, Relic seed=%d survived generation -> persistence -> reconnect -> equip -> live facts",
	found.Weapon.seed,
	found.Armor.seed,
	found.Relic.seed
))
