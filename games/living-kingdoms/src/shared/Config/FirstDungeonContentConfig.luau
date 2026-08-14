--!strict

--[[
	Authored encounter content library for the first repeatable dungeon kit.

	Patch 0.9 upgrades the original canonical-sequence table into a complete room
	content library: every room in RoomAssemblyConfig owns valid encounter content
	before any seed is allowed to select it. The current canonical seed remains
	unchanged for verification stability; this closes the authoring hole that would
	otherwise turn seed rotation into missing combat at runtime.
]]

local EnemyContracts = require(script.Parent.Parent.Combat.EnemyContracts)
local HordeExperienceConfig = require(script.Parent.HordeExperienceConfig)
local RoomAssemblyConfig = require(script.Parent.RoomAssemblyConfig)
local RoomAssemblyContracts = require(script.Parent.Parent.Expeditions.RoomAssemblyContracts)

local EnemyArchetypeIds = EnemyContracts.EnemyArchetypeIds
local EnemySpawnSourceIds = EnemyContracts.EnemySpawnSourceIds
local EncounterSlotIds = RoomAssemblyContracts.EncounterSlotIds
local HordeRoles = HordeExperienceConfig.Roles

local function unit(archetypeId: string, count: number, hordeRoleId: string?)
	return table.freeze({ ArchetypeId = archetypeId, Count = count, HordeRoleId = hordeRoleId })
end

local function wave(units: { any })
	return table.freeze({ Units = table.freeze(units) })
end

local function encounter(
	roomId: string,
	encounterSlotId: string,
	encounterIntensity: number,
	waves: { any },
	rewardSourceId: string?
)
	return table.freeze({
		RoomId = roomId,
		EncounterSlotId = encounterSlotId,
		EncounterIntensity = encounterIntensity,
		SpawnSourceId = if #waves > 0 then EnemySpawnSourceIds.AuthoredWave else nil,
		Waves = table.freeze(waves),
		RewardSourceId = rewardSourceId,
	})
end

local FirstDungeonContentConfig = {
	Version = "PATCH-0.9-ROOM-CONTENT-v2",
	DefinitionId = RoomAssemblyConfig.DefinitionId,
	DefinitionVersion = RoomAssemblyConfig.DefinitionVersion,
	SequenceId = "first-descent-repeatable",
	SequenceVersion = "1.0.0",
	DisplayName = "The First Descent",
	CanonicalSeed = 202,
	Repeatable = true,
	RoomSequence = table.freeze({
		"descent-entry",
		"collapsed-gallery",
		"warden-barracks",
		"broken-sanctum",
		"sunken-archive",
		"warden-threshold",
		"keeper-core",
	}),
	-- This is a room-content library, not merely the current seven-room route.
	-- Every room in RoomAssemblyConfig must appear here so any future permitted
	-- seed/route choice remains spawnable without a bespoke runtime branch.
	Encounters = table.freeze({
		["descent-entry"] = encounter("descent-entry", EncounterSlotIds.None, 0, {}, nil),
		["collapsed-gallery"] = encounter("collapsed-gallery", EncounterSlotIds.LightPatrol, 1, {
			wave({ unit(EnemyArchetypeIds.ExclusionWalker, 2, HordeRoles.Basic.Id) }),
		}, nil),
		["flooded-passage"] = encounter("flooded-passage", EncounterSlotIds.LightPatrol, 1, {
			wave({
				unit(EnemyArchetypeIds.ExclusionWalker, 1, HordeRoles.Basic.Id),
				unit(EnemyArchetypeIds.ExclusionWalker, 1, HordeRoles.Runner.Id),
			}),
		}, nil),
		["broken-sanctum"] = encounter("broken-sanctum", EncounterSlotIds.LightPatrol, 1, {
			wave({ unit(EnemyArchetypeIds.ExclusionWalker, 2, HordeRoles.Crawler.Id) }),
		}, nil),
		["warden-barracks"] = encounter("warden-barracks", EncounterSlotIds.StandardSquad, 2, {
			wave({
				unit(EnemyArchetypeIds.ExclusionWalker, 2, HordeRoles.Basic.Id),
				unit(EnemyArchetypeIds.ExclusionWalker, 1, HordeRoles.Runner.Id),
			}),
		}, nil),
		["fungal-vault"] = encounter("fungal-vault", EncounterSlotIds.StandardSquad, 2, {
			wave({
				unit(EnemyArchetypeIds.ExclusionWalker, 2, HordeRoles.Crawler.Id),
				unit(EnemyArchetypeIds.BlightSpitter, 1, nil),
			}),
		}, nil),
		["sunken-archive"] = encounter("sunken-archive", EncounterSlotIds.StandardSquad, 2, {
			wave({
				unit(EnemyArchetypeIds.ExclusionWalker, 2, HordeRoles.Basic.Id),
				unit(EnemyArchetypeIds.BlightSpitter, 1, nil),
			}),
		}, nil),
		["warden-threshold"] = encounter("warden-threshold", EncounterSlotIds.EliteGuard, 1, {
			wave({
				unit(EnemyArchetypeIds.ExclusionWalker, 1, HordeRoles.Brute.Id),
				unit(EnemyArchetypeIds.ExclusionWalker, 1, HordeRoles.Screamer.Id),
			}),
		}, "Elite"),
		["keeper-core"] = encounter("keeper-core", EncounterSlotIds.BossEncounter, 3, {
			wave({ unit(EnemyArchetypeIds.Progenitor, 1, nil) }),
		}, "Boss"),
	}),
}

assert(FirstDungeonContentConfig.Repeatable, "the first dungeon content must remain replayable")
assert(
	FirstDungeonContentConfig.CanonicalSeed >= 1 and FirstDungeonContentConfig.CanonicalSeed % 1 == 0,
	"the canonical dungeon seed must be a positive integer"
)
assert(#FirstDungeonContentConfig.RoomSequence == 7, "the verification route must remain a short seven-room run")

local roomDefinitions = {}
for _, definition in RoomAssemblyConfig.Rooms do roomDefinitions[definition.Id] = definition end

local knownEnemyArchetypeIds = {}
for _, archetypeId in EnemyArchetypeIds do knownEnemyArchetypeIds[archetypeId] = true end
local knownHordeRoleIds = {}
for _, role in HordeRoles do knownHordeRoleIds[role.Id] = true end

local function validateEncounter(definition: any, content: any)
	assert(content ~= nil, "every room in the assembly pool requires authored encounter content: " .. definition.Id)
	assert(content.RoomId == definition.Id, "encounter content room identity must match its room definition")
	assert(content.EncounterSlotId == definition.EncounterSlotId, "encounter content must honor the room encounter slot")
	assert(content.EncounterIntensity == definition.EncounterIntensity, "encounter content must honor room intensity")
	assert(content.RewardSourceId == definition.RewardSourceId, "encounter content must preserve the room reward source")
	if content.EncounterSlotId == EncounterSlotIds.None then
		assert(#content.Waves == 0, "non-encounter rooms cannot author enemy waves")
		assert(content.SpawnSourceId == nil, "non-encounter rooms cannot declare an authored-wave source")
	else
		assert(#content.Waves >= 1, "encounter rooms require at least one authored wave")
		assert(content.SpawnSourceId == EnemySpawnSourceIds.AuthoredWave, "dungeon combat must use the canonical authored-wave source")
	end
	for _, authoredWave in content.Waves do
		assert(#authoredWave.Units >= 1, "authored dungeon waves cannot be empty")
		for _, authoredUnit in authoredWave.Units do
			assert(knownEnemyArchetypeIds[authoredUnit.ArchetypeId] == true, "unknown enemy archetype in dungeon content")
			assert(authoredUnit.Count >= 1 and authoredUnit.Count % 1 == 0, "enemy counts must be positive integers")
			if authoredUnit.ArchetypeId == EnemyArchetypeIds.ExclusionWalker then
				assert(
					authoredUnit.HordeRoleId ~= nil and knownHordeRoleIds[authoredUnit.HordeRoleId] == true,
					"walker dungeon content must reference a canonical horde role"
				)
			else
				assert(authoredUnit.HordeRoleId == nil, "special/boss archetypes cannot borrow a walker horde role")
			end
		end
	end
end

-- Production-pipeline invariant: the content library must cover the complete
-- assembly pool in both directions. A room without content or stale content for
-- a deleted room is an authoring failure before it can reach a live seed.
for _, definition in RoomAssemblyConfig.Rooms do
	validateEncounter(definition, FirstDungeonContentConfig.Encounters[definition.Id])
end
for roomId in FirstDungeonContentConfig.Encounters do
	assert(roomDefinitions[roomId] ~= nil, "encounter content targets a room outside the assembly pool: " .. roomId)
end

local seenRoomIds = {}
for index, roomId in FirstDungeonContentConfig.RoomSequence do
	assert(seenRoomIds[roomId] == nil, "the canonical dungeon sequence cannot repeat a room")
	seenRoomIds[roomId] = true
	local definition = roomDefinitions[roomId]
	assert(definition ~= nil, "canonical dungeon content references an unknown room: " .. roomId)
	if index == 1 then
		assert(definition.Role == RoomAssemblyContracts.RoleIds.Entry, "the canonical dungeon must begin at the safe entry")
	elseif index == #FirstDungeonContentConfig.RoomSequence - 1 then
		assert(definition.Role == RoomAssemblyContracts.RoleIds.Elite, "the canonical dungeon must stage an elite before its boss")
	elseif index == #FirstDungeonContentConfig.RoomSequence then
		assert(definition.Role == RoomAssemblyContracts.RoleIds.Boss, "the canonical dungeon must terminate in the boss room")
	end
end

return table.freeze(FirstDungeonContentConfig)
