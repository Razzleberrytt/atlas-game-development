--!strict

local fs = require("@lune/fs")

local function assert(condition: unknown, message: string?)
	if not condition then error(message or "Patch 0.9 room content coverage audit failed", 2) end
end
local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local rooms = fs.readFile("games/living-kingdoms/src/shared/Config/RoomAssemblyConfig.luau")
local content = fs.readFile("games/living-kingdoms/src/shared/Config/FirstDungeonContentConfig.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionServerBootstrap.luau")

assert(contains(rooms, '"flooded-passage"'), "flooded passage must remain in the assembly pool")
assert(contains(rooms, '"fungal-vault"'), "fungal vault must remain in the assembly pool")
assert(contains(content, '["flooded-passage"] = encounter'), "flooded passage needs authored encounter content")
assert(contains(content, '["fungal-vault"] = encounter'), "fungal vault needs authored encounter content")
assert(contains(content, "for _, definition in RoomAssemblyConfig.Rooms do\n\tvalidateEncounter"), "every assembly room must be content-covered")
assert(contains(content, "encounter content targets a room outside the assembly pool"), "stale encounter entries must fail authoring")
assert(contains(bootstrap, "FirstDungeonContentConfig.Encounters[record.RoomId]"), "runtime must consume the room content library by assembled room id")
assert(contains(bootstrap, "RoomSequenceAssembler.assemble(parameters.Seed)"), "runtime route remains seed-owned by the existing assembler")

print("Patch09RoomContentCoverageSourceAudit.test.luau passed")
