--!strict

--[[
	The grant ledger crosses an ownership boundary: PlayerInventoryPersistenceService
	writes it, OperativeProgressionService reads it, and OperativeProgressionResolver
	interprets it. Each side had its own fixture and both were green, because the
	resolver's fixture fed it arrays of grant-id strings -- a shape persistence
	never produces.

	Production stores a set (grantId -> true). Iterated for values that yields
	booleans, so every non-empty real ledger was rejected as malformed and
	operative progression died for exactly the players who had earned something.
	An empty ledger iterates zero times, so a fresh account looked healthy.

	This fixture refuses to invent a ledger. It takes whatever the real
	persistence service actually wrote and hands it to the real resolver.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local EQUIPMENT_TOKEN, AFFIX_TOKEN = {}, {}
local equipmentContracts = {
	SlotIds = { Primary = "Primary", Secondary = "Secondary", Armor = "Armor", Relic = "Relic" },
	RarityIds = { Common = "Common", Uncommon = "Uncommon", Rare = "Rare" },
	SourceIds = { Elite = "Elite", Boss = "Boss" },
}

local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Persistence/PlayerInventoryContracts.luau"), {
	debugName = "PlayerInventoryContracts",
	environment = {
		script = { Parent = { Parent = { Equipment = { EquipmentRewardContracts = EQUIPMENT_TOKEN } } } },
		require = function(): any
			return equipmentContracts
		end,
	},
	injectGlobals = true,
})()

local storageResults =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Persistence/StorageResultContracts.luau"), {
		debugName = "StorageResultContracts",
		injectGlobals = true,
	})()

local RESOLVER_CONTRACTS_TOKEN, RESOLVER_EQUIPMENT_TOKEN = {}, {}
local dismantleResolver =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Persistence/InventoryDismantleResolver.luau"), {
		debugName = "InventoryDismantleResolver",
		environment = {
			script = {
				Parent = {
					PlayerInventoryContracts = RESOLVER_CONTRACTS_TOKEN,
					Parent = { Equipment = { EquipmentRewardContracts = RESOLVER_EQUIPMENT_TOKEN } },
				},
			},
			require = function(token: unknown): any
				if token == RESOLVER_CONTRACTS_TOKEN then
					return contracts
				end
				return equipmentContracts
			end,
		},
		injectGlobals = true,
	})()

local CONTRACTS_TOKEN, DISMANTLE_TOKEN, RESULTS_TOKEN = {}, {}, {}
local persistenceModule =
	luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/PlayerInventoryPersistenceService.luau"), {
		debugName = "PlayerInventoryPersistenceService",
		environment = {
			game = {
				GetService = function(): any
					return {
						Shared = {
							Persistence = {
								PlayerInventoryContracts = CONTRACTS_TOKEN,
								InventoryDismantleResolver = DISMANTLE_TOKEN,
								StorageResultContracts = RESULTS_TOKEN,
							},
							Equipment = {
								EquipmentRewardContracts = EQUIPMENT_TOKEN,
								EquipmentAffixContracts = AFFIX_TOKEN,
							},
						},
					}
				end,
			},
			require = function(token: unknown): any
				if token == CONTRACTS_TOKEN then
					return contracts
				elseif token == EQUIPMENT_TOKEN then
					return equipmentContracts
				elseif token == AFFIX_TOKEN then
					return { EffectIds = { DamagePercent = "DamagePercent" } }
				elseif token == DISMANTLE_TOKEN then
					return dismantleResolver
				elseif token == RESULTS_TOKEN then
					return storageResults
				end
				error("unexpected persistence dependency")
			end,
		},
		injectGlobals = true,
	})()

local progressionResolver =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Progression/OperativeProgressionResolver.luau"), {
		debugName = "OperativeProgressionResolver",
		injectGlobals = true,
	})()

local progressionConfig =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/OperativeProgressionConfig.luau"), {
		debugName = "OperativeProgressionConfig",
		environment = {
			script = { Parent = { Parent = {} } },
			require = function(): any
				return {}
			end,
		},
		injectGlobals = true,
	})()

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

local store = { data = {} }
function store:read(key: string): any
	local value = deepCopy(self.data[key])
	if value == nil then
		return storageResults.missing()
	end
	return storageResults.found(value)
end
function store:write(key: string, value: any): any
	self.data[key] = deepCopy(value)
	return storageResults.committed(deepCopy(value))
end

local PLAYER = 9090
local persistence = persistenceModule.new(store)
check(persistence:loadPlayer(PLAYER, 1000).Accepted, "the player loads")

local function bossReward(runId: string, instanceSuffix: string): any
	return {
		InstanceId = "item_" .. instanceSuffix .. "_guid",
		GrantId = string.format("reward:%s:Boss", runId),
		ContentSignature = "v1|keeper-relic|1.0.0|Rare|18|Boss|" .. instanceSuffix,
		DefinitionId = "keeper-relic",
		DefinitionVersion = "1.0.0",
		DisplayName = "Keeper Relic",
		Slot = "Relic",
		Rarity = "Rare",
		Power = 18,
		Affixes = {},
		SourceId = "Boss",
		RunId = runId,
		Seed = 41,
	}
end

-- A fresh account resolves, which is exactly why the defect stayed hidden.
local freshLedger = persistence:getRecord(PLAYER).AppliedRewardGrantIds
local fresh = progressionResolver.resolve(progressionConfig, freshLedger)
check(fresh.Accepted, "an empty durable ledger must resolve")
check(fresh.CompletedExpeditions == 0, "a fresh operative has no clears")

-- The moment a real reward lands, the ledger stops being empty.
check(persistence:applyReward(PLAYER, bossReward("expedition:alpha", "alpha"), 1010).Accepted, "first boss reward")

local earnedLedger = persistence:getRecord(PLAYER).AppliedRewardGrantIds
local earnedKeyCount = 0
for _ in earnedLedger do
	earnedKeyCount += 1
end
check(earnedKeyCount == 1, "the durable ledger must hold exactly the one grant that was applied")
check(earnedLedger["reward:expedition:alpha:Boss"] == true, "the ledger must be keyed by grant id and valued true")

local earned = progressionResolver.resolve(progressionConfig, earnedLedger)
check(earned.Accepted, "a ledger written by persistence must be readable by progression")
check(earned.ReasonId ~= "InvalidGrantLedger", "the canonical durable shape must never read as malformed")
check(earned.CompletedExpeditions == 1, "one boss grant must count as one completed expedition")
check(earned.Rank == 2, "one clear must promote past the opening rank")

-- Several runs, still through the real write path.
for index = 2, 6 do
	local runId = "expedition:run-" .. tostring(index)
	check(
		persistence:applyReward(PLAYER, bossReward(runId, "run" .. tostring(index)), 1000 + index * 10).Accepted,
		"boss reward for " .. runId
	)
end

local veteranLedger = persistence:getRecord(PLAYER).AppliedRewardGrantIds
local veteran = progressionResolver.resolve(progressionConfig, veteranLedger)
check(veteran.Accepted, "a six-run durable ledger must resolve")
check(veteran.CompletedExpeditions == 6, "six distinct runs must count as six clears")
check(veteran.RankId == "Veteran", "six clears must reach Veteran through the real write path")

-- The ledger survives a reload, and still reads.
local reloaded = persistenceModule.new(store):loadPlayer(PLAYER, 2000)
check(reloaded.Accepted, "the record reloads")
local reloadedProgression = progressionResolver.resolve(progressionConfig, reloaded.Record.AppliedRewardGrantIds)
check(reloadedProgression.Accepted, "a reloaded ledger must still resolve")
check(
	reloadedProgression.CompletedExpeditions == 6,
	"progression must survive a reload rather than resetting to a fresh account"
)

print("OperativeProgressionLedgerShape: persistence-written ledgers resolve through the real progression resolver")
