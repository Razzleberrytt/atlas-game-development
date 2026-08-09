--!strict

--[[
	VS-0104 bounded handcrafted room pool for the first expedition.
	The route is linear for the vertical slice: entry, a deterministic mixture of
	traversal/combat rooms, elite arena, and boss arena. Optional branches arrive
	in VS-0106 rather than being smuggled into the first assembler.
]]

local Contracts = require(script.Parent.Parent.Expeditions.RoomAssemblyContracts)
local RoleIds = Contracts.RoleIds
local EncounterSlotIds = Contracts.EncounterSlotIds
local RoomRewardSourceIds = Contracts.RoomRewardSourceIds

local function room(
	id: string,
	role: string,
	weight: number,
	minimumDepth: number,
	maximumDepth: number,
	allowRepeats: boolean,
	tags: { string },
	encounterSlotId: string,
	encounterIntensity: number,
	rewardSourceId: string?
)
	return table.freeze({
		Id = id,
		Version = "1.0.0",
		Role = role,
		Weight = weight,
		MinimumDepth = minimumDepth,
		MaximumDepth = maximumDepth,
		AllowRepeats = allowRepeats,
		Tags = table.freeze(tags),
		EncounterSlotId = encounterSlotId,
		EncounterIntensity = encounterIntensity,
		RewardSourceId = rewardSourceId,
	})
end

local RoomAssemblyConfig = {
	Version = "VS-0104-v1",
	DefinitionId = "first-expedition-room-plan",
	DefinitionVersion = "1.0.0",
	Route = table.freeze({
		MinimumVariableRooms = 3,
		MaximumVariableRooms = 5,
		RequiredCombatRooms = 2,
	}),
	Rooms = table.freeze({
		room("descent-entry", RoleIds.Entry, 1, 0, 0, false, { "safe", "spawn" }, EncounterSlotIds.None, 0, nil),
		room(
			"collapsed-gallery",
			RoleIds.Traversal,
			4,
			1,
			5,
			false,
			{ "ruins", "verticality" },
			EncounterSlotIds.LightPatrol,
			1,
			nil
		),
		room(
			"flooded-passage",
			RoleIds.Traversal,
			3,
			1,
			5,
			false,
			{ "water", "slow-route" },
			EncounterSlotIds.LightPatrol,
			1,
			nil
		),
		room(
			"broken-sanctum",
			RoleIds.Traversal,
			2,
			2,
			5,
			false,
			{ "cover", "lore" },
			EncounterSlotIds.LightPatrol,
			1,
			nil
		),
		room(
			"warden-barracks",
			RoleIds.Combat,
			5,
			1,
			5,
			false,
			{ "arena", "flank" },
			EncounterSlotIds.StandardSquad,
			2,
			nil
		),
		room(
			"fungal-vault",
			RoleIds.Combat,
			4,
			1,
			5,
			false,
			{ "arena", "hazard" },
			EncounterSlotIds.StandardSquad,
			2,
			nil
		),
		room(
			"sunken-archive",
			RoleIds.Combat,
			3,
			2,
			5,
			false,
			{ "arena", "cover" },
			EncounterSlotIds.StandardSquad,
			2,
			nil
		),
		room(
			"warden-threshold",
			RoleIds.Elite,
			1,
			6,
			6,
			false,
			{ "elite", "gate" },
			EncounterSlotIds.EliteGuard,
			1,
			RoomRewardSourceIds.Elite
		),
		room(
			"keeper-core",
			RoleIds.Boss,
			1,
			7,
			7,
			false,
			{ "boss", "arena" },
			EncounterSlotIds.BossEncounter,
			3,
			RoomRewardSourceIds.Boss
		),
	}),
}

assert(RoomAssemblyConfig.Route.MinimumVariableRooms >= 3, "the slice requires meaningful route variation")
assert(
	RoomAssemblyConfig.Route.MaximumVariableRooms >= RoomAssemblyConfig.Route.MinimumVariableRooms,
	"variable room bounds are invalid"
)
assert(
	RoomAssemblyConfig.Route.RequiredCombatRooms <= RoomAssemblyConfig.Route.MinimumVariableRooms,
	"every minimum-length plan must fit its required combat rooms"
)

local roleCounts = {}
local ids = {}
for _, definition in RoomAssemblyConfig.Rooms do
	assert(ids[definition.Id] == nil, "room IDs must be unique")
	ids[definition.Id] = true
	assert(definition.Weight >= 1 and definition.Weight % 1 == 0, "room weights must be positive integers")
	assert(definition.MaximumDepth >= definition.MinimumDepth, "room depth bounds are invalid")
	assert(definition.EncounterIntensity >= 0, "encounter intensity cannot be negative")
	if definition.Role == RoleIds.Elite then
		assert(
			definition.EncounterSlotId == EncounterSlotIds.EliteGuard,
			"elite rooms require the elite encounter slot"
		)
		assert(definition.RewardSourceId == RoomRewardSourceIds.Elite, "elite rooms require the elite reward source")
	elseif definition.Role == RoleIds.Boss then
		assert(
			definition.EncounterSlotId == EncounterSlotIds.BossEncounter,
			"boss rooms require the boss encounter slot"
		)
		assert(definition.RewardSourceId == RoomRewardSourceIds.Boss, "boss rooms require the boss reward source")
	else
		assert(definition.RewardSourceId == nil, "only elite/boss rooms authorize a reward source")
	end
	roleCounts[definition.Role] = (roleCounts[definition.Role] or 0) + 1
end

assert(roleCounts[RoleIds.Entry] == 1, "the first room pool requires exactly one entry")
assert(roleCounts[RoleIds.Elite] == 1, "the first room pool requires exactly one elite arena")
assert(roleCounts[RoleIds.Boss] == 1, "the first room pool requires exactly one boss arena")
assert(roleCounts[RoleIds.Combat] >= RoomAssemblyConfig.Route.RequiredCombatRooms, "combat pool is too small")

return table.freeze(RoomAssemblyConfig)
