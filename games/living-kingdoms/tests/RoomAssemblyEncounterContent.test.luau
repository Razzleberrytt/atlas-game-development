--!strict

-- BA-030 dungeon/expedition content contract fixture: every handcrafted room
-- carries an encounter slot, a non-negative intensity, and a reward
-- reference exactly when its role authorizes one. This is data/contract
-- coverage only -- no spawner or reward owner is invoked here.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "RoomAssemblyEncounterContent assertion failed", 2)
	end
end

local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Expeditions/RoomAssemblyContracts.luau"), {
	debugName = "RoomAssemblyContracts",
	injectGlobals = true,
})()

local CONTRACTS_TOKEN = {}
local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RoomAssemblyConfig.luau"), {
	debugName = "RoomAssemblyConfig",
	environment = {
		script = { Parent = { Parent = { Expeditions = { RoomAssemblyContracts = CONTRACTS_TOKEN } } } },
		require = function(token: unknown)
			assert(token == CONTRACTS_TOKEN, "unexpected RoomAssemblyConfig dependency")
			return contracts
		end,
	},
	injectGlobals = true,
})()

local RoleIds = contracts.RoleIds
local EncounterSlotIds = contracts.EncounterSlotIds
local RoomRewardSourceIds = contracts.RoomRewardSourceIds

local byId: { [string]: any } = {}
for _, definition in config.Rooms do
	byId[definition.Id] = definition
end

-- Every room declares an encounter slot and a non-negative intensity.
for _, definition in config.Rooms do
	assert(definition.EncounterSlotId ~= nil, definition.Id .. " is missing an encounter slot")
	assert(definition.EncounterIntensity >= 0, definition.Id .. " has a negative encounter intensity")
end

-- Entry stays a safe arrival room: no encounter, no reward.
local entry = byId["descent-entry"]
assert(entry.EncounterSlotId == EncounterSlotIds.None, "entry must not stage an encounter")
assert(entry.EncounterIntensity == 0, "entry must not carry encounter intensity")
assert(entry.RewardSourceId == nil, "entry must not authorize a reward")

-- Traversal/Combat rooms carry an encounter but never a reward reference.
for _, id in { "collapsed-gallery", "flooded-passage", "broken-sanctum" } do
	local definition = byId[id]
	assert(definition.EncounterSlotId == EncounterSlotIds.LightPatrol, id .. " must use the light patrol slot")
	assert(definition.RewardSourceId == nil, id .. " must not authorize a reward")
end
for _, id in { "warden-barracks", "fungal-vault", "sunken-archive" } do
	local definition = byId[id]
	assert(definition.EncounterSlotId == EncounterSlotIds.StandardSquad, id .. " must use the standard squad slot")
	assert(definition.RewardSourceId == nil, id .. " must not authorize a reward")
end

-- Elite/Boss rooms are the only reward-authorizing content slots, and their
-- reward reference reuses the same two source IDs EquipmentRewardContracts
-- already keys rewards by ("Elite" | "Boss").
local elite = byId["warden-threshold"]
assert(elite.EncounterSlotId == EncounterSlotIds.EliteGuard, "elite room must use the elite guard slot")
assert(elite.RewardSourceId == RoomRewardSourceIds.Elite, "elite room must authorize the elite reward source")

local boss = byId["keeper-core"]
assert(boss.EncounterSlotId == EncounterSlotIds.BossEncounter, "boss room must use the boss encounter slot")
assert(boss.RewardSourceId == RoomRewardSourceIds.Boss, "boss room must authorize the boss reward source")

-- Reward references stay exclusive to the Elite/Boss roles across the whole
-- pool -- the config's own load-time assertions already enforce this, but the
-- fixture re-checks it as an explicit regression guard independent of the
-- config internals.
for _, definition in config.Rooms do
	if definition.Role == RoleIds.Elite or definition.Role == RoleIds.Boss then
		assert(definition.RewardSourceId ~= nil, definition.Id .. " must authorize a reward")
	else
		assert(definition.RewardSourceId == nil, definition.Id .. " must not authorize a reward")
	end
end

print("RoomAssemblyEncounterContent: BA-030 encounter-slot/reward-reference content contract passed")
