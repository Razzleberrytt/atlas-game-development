--!strict

-- BA-032 first-repeatable-dungeon fixture: the canonical seed must assemble the
-- authored seven-room path, and its concrete compositions must stay attached to
-- canonical enemy archetypes / horde roles without activating any runtime owner.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "BA-032 first dungeon content assertion failed", 2)
	end
end

local roomContracts =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Expeditions/RoomAssemblyContracts.luau"), {
		debugName = "RoomAssemblyContracts",
		injectGlobals = true,
	})()

local enemyContracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Combat/EnemyContracts.luau"), {
	debugName = "EnemyContracts",
	injectGlobals = true,
})()

local hordeConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/HordeExperienceConfig.luau"), {
	debugName = "HordeExperienceConfig",
	injectGlobals = true,
})()

local ROOM_CONTRACTS_TOKEN = {}
local roomConfig = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RoomAssemblyConfig.luau"), {
	debugName = "RoomAssemblyConfig",
	environment = {
		script = { Parent = { Parent = { Expeditions = { RoomAssemblyContracts = ROOM_CONTRACTS_TOKEN } } } },
		require = function(token: unknown)
			assert(token == ROOM_CONTRACTS_TOKEN, "unexpected RoomAssemblyConfig dependency")
			return roomContracts
		end,
	},
	injectGlobals = true,
})()

local ENEMY_CONTRACTS_TOKEN = {}
local HORDE_CONFIG_TOKEN = {}
local FIRST_ROOM_CONFIG_TOKEN = {}
local FIRST_ROOM_CONTRACTS_TOKEN = {}
local content = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/FirstDungeonContentConfig.luau"), {
	debugName = "FirstDungeonContentConfig",
	environment = {
		script = {
			Parent = {
				Parent = {
					Combat = { EnemyContracts = ENEMY_CONTRACTS_TOKEN },
					Expeditions = { RoomAssemblyContracts = FIRST_ROOM_CONTRACTS_TOKEN },
				},
				HordeExperienceConfig = HORDE_CONFIG_TOKEN,
				RoomAssemblyConfig = FIRST_ROOM_CONFIG_TOKEN,
			},
		},
		require = function(token: unknown)
			if token == ENEMY_CONTRACTS_TOKEN then
				return enemyContracts
			end
			if token == HORDE_CONFIG_TOKEN then
				return hordeConfig
			end
			if token == FIRST_ROOM_CONFIG_TOKEN then
				return roomConfig
			end
			if token == FIRST_ROOM_CONTRACTS_TOKEN then
				return roomContracts
			end
			error("unexpected FirstDungeonContentConfig dependency")
		end,
	},
	injectGlobals = true,
})()

local ASSEMBLER_CONTRACTS_TOKEN = {}
local ASSEMBLER_CONFIG_TOKEN = {}
local assembler = luau.load(fs.readFile("games/living-kingdoms/src/shared/Expeditions/RoomSequenceAssembler.luau"), {
	debugName = "RoomSequenceAssembler",
	environment = {
		script = {
			Parent = {
				RoomAssemblyContracts = ASSEMBLER_CONTRACTS_TOKEN,
				Parent = { Config = { RoomAssemblyConfig = ASSEMBLER_CONFIG_TOKEN } },
			},
		},
		require = function(token: unknown)
			if token == ASSEMBLER_CONTRACTS_TOKEN then
				return roomContracts
			end
			if token == ASSEMBLER_CONFIG_TOKEN then
				return roomConfig
			end
			error("unexpected RoomSequenceAssembler dependency")
		end,
	},
	injectGlobals = true,
})()

local expectedRoomSequence = {
	"descent-entry",
	"collapsed-gallery",
	"warden-barracks",
	"broken-sanctum",
	"sunken-archive",
	"warden-threshold",
	"keeper-core",
}

assert(content.DefinitionId == roomConfig.DefinitionId, "dungeon content must reuse the canonical room definition ID")
assert(
	content.DefinitionVersion == roomConfig.DefinitionVersion,
	"dungeon content must pin the canonical room definition version"
)
assert(content.Repeatable == true, "the first authored dungeon must remain repeatable")
assert(content.CanonicalSeed == 202, "changing the canonical seed requires an explicit content-version decision")
assert(#content.RoomSequence == #expectedRoomSequence, "the first authored dungeon length changed unexpectedly")

for index, expectedRoomId in expectedRoomSequence do
	assert(content.RoomSequence[index] == expectedRoomId, "the authored dungeon room order changed at index " .. index)
end

local firstPlan = assembler.assemble(content.CanonicalSeed)
local repeatedPlan = assembler.assemble(content.CanonicalSeed)
assert(#firstPlan.Nodes == #expectedRoomSequence, "canonical seed must assemble the authored short route")
assert(#repeatedPlan.Nodes == #firstPlan.Nodes, "repeat assembly must preserve route length")
for index, expectedRoomId in expectedRoomSequence do
	assert(firstPlan.Nodes[index].RoomId == expectedRoomId, "canonical seed no longer assembles the authored route")
	assert(repeatedPlan.Nodes[index].RoomId == expectedRoomId, "same canonical seed must remain deterministic")
end

local collapsed = content.Encounters["collapsed-gallery"]
assert(collapsed.EncounterSlotId == roomContracts.EncounterSlotIds.LightPatrol, "gallery must remain a light patrol")
assert(collapsed.Waves[1].Units[1].ArchetypeId == enemyContracts.EnemyArchetypeIds.ExclusionWalker)
assert(collapsed.Waves[1].Units[1].HordeRoleId == hordeConfig.Roles.Basic.Id)

local barracks = content.Encounters["warden-barracks"]
assert(
	barracks.EncounterSlotId == roomContracts.EncounterSlotIds.StandardSquad,
	"barracks must remain a standard squad"
)
assert(barracks.Waves[1].Units[2].HordeRoleId == hordeConfig.Roles.Runner.Id, "barracks must introduce runner pressure")

local sanctum = content.Encounters["broken-sanctum"]
assert(
	sanctum.Waves[1].Units[1].HordeRoleId == hordeConfig.Roles.Crawler.Id,
	"sanctum must preserve low-profile pressure"
)

local archive = content.Encounters["sunken-archive"]
local archiveHasSpitter = false
for _, authoredUnit in archive.Waves[1].Units do
	if authoredUnit.ArchetypeId == enemyContracts.EnemyArchetypeIds.BlightSpitter then
		archiveHasSpitter = true
	end
end
assert(archiveHasSpitter, "the second combat room must introduce the canonical Blight Spitter")

local elite = content.Encounters["warden-threshold"]
assert(elite.EncounterSlotId == roomContracts.EncounterSlotIds.EliteGuard, "threshold must remain the elite slot")
assert(
	elite.RewardSourceId == roomContracts.RoomRewardSourceIds.Elite,
	"elite slot must preserve the canonical reward ref"
)
local eliteHasBrute = false
for _, authoredUnit in elite.Waves[1].Units do
	if authoredUnit.HordeRoleId == hordeConfig.Roles.Brute.Id then
		eliteHasBrute = true
	end
end
assert(eliteHasBrute, "the elite guard must include the canonical Brute role")

local boss = content.Encounters["keeper-core"]
assert(boss.EncounterSlotId == roomContracts.EncounterSlotIds.BossEncounter, "keeper core must remain the boss slot")
assert(
	boss.RewardSourceId == roomContracts.RoomRewardSourceIds.Boss,
	"boss slot must preserve the canonical reward ref"
)
assert(#boss.Waves == 1 and #boss.Waves[1].Units == 1, "boss room must author one canonical boss spawn")
assert(
	boss.Waves[1].Units[1].ArchetypeId == enemyContracts.EnemyArchetypeIds.Progenitor,
	"keeper core must use The Progenitor"
)
assert(boss.Waves[1].Units[1].Count == 1, "the first dungeon must not duplicate the boss")

print("BA-032 FirstDungeonContentConfig fixture passed")
