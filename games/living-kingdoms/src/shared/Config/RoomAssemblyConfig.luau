--!strict

--[[
	VS-0104 bounded handcrafted room pool for the first expedition.
	The route is linear for the vertical slice: entry, a deterministic mixture of
	traversal/combat rooms, elite arena, and boss arena. Optional branches arrive
	in VS-0106 rather than being smuggled into the first assembler.
]]

local Contracts = require(script.Parent.Parent.Expeditions.RoomAssemblyContracts)
local RoleIds = Contracts.RoleIds

local function room(
	id: string,
	role: string,
	weight: number,
	minimumDepth: number,
	maximumDepth: number,
	allowRepeats: boolean,
	tags: { string }
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
		room("descent-entry", RoleIds.Entry, 1, 0, 0, false, { "safe", "spawn" }),
		room("collapsed-gallery", RoleIds.Traversal, 4, 1, 5, false, { "ruins", "verticality" }),
		room("flooded-passage", RoleIds.Traversal, 3, 1, 5, false, { "water", "slow-route" }),
		room("broken-sanctum", RoleIds.Traversal, 2, 2, 5, false, { "cover", "lore" }),
		room("warden-barracks", RoleIds.Combat, 5, 1, 5, false, { "arena", "flank" }),
		room("fungal-vault", RoleIds.Combat, 4, 1, 5, false, { "arena", "hazard" }),
		room("sunken-archive", RoleIds.Combat, 3, 2, 5, false, { "arena", "cover" }),
		room("warden-threshold", RoleIds.Elite, 1, 6, 6, false, { "elite", "gate" }),
		room("keeper-core", RoleIds.Boss, 1, 7, 7, false, { "boss", "arena" }),
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
	roleCounts[definition.Role] = (roleCounts[definition.Role] or 0) + 1
end

assert(roleCounts[RoleIds.Entry] == 1, "the first room pool requires exactly one entry")
assert(roleCounts[RoleIds.Elite] == 1, "the first room pool requires exactly one elite arena")
assert(roleCounts[RoleIds.Boss] == 1, "the first room pool requires exactly one boss arena")
assert(roleCounts[RoleIds.Combat] >= RoomAssemblyConfig.Route.RequiredCombatRooms, "combat pool is too small")

return table.freeze(RoomAssemblyConfig)
