--!strict

local fs = require("@lune/fs")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "Patch 0.9 role affix coverage audit failed", 2)
	end
end
local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local affixes = fs.readFile("games/living-kingdoms/src/shared/Config/EquipmentAffixConfig.luau")
local rewards = fs.readFile("games/living-kingdoms/src/shared/Config/EquipmentRewardConfig.luau")
local resolver = fs.readFile("games/living-kingdoms/src/shared/Equipment/EquipmentAffixResolver.luau")

assert(contains(affixes, '"suppressive"'), "LMG sustained-fire role needs a dedicated affix")
assert(contains(affixes, '"belt-fed"'), "LMG support role needs a dedicated affix")
assert(contains(affixes, '"crowd-cutter"'), "SMG horde-control role needs a dedicated affix")
assert(contains(affixes, '"hot-swap"'), "SMG identity needs a dedicated affix")
assert(contains(affixes, "catalogTags[requiredTag] == true"), "dead required tags must fail authoring")
assert(contains(affixes, "must have at least one role-aware affix"), "durable weapons must be role-affix covered")
assert(contains(rewards, '"sustained-fire"'), "LMG durable item must carry its role tag")
assert(contains(rewards, '"horde-control"'), "SMG durable item must carry its role tag")
assert(
	contains(resolver, "hasRequiredTags(context.Tags, definition.RequiredTags)"),
	"affix resolver must actually consume authored tags"
)

print("Patch09RoleAffixCoverageSourceAudit.test.luau passed")
