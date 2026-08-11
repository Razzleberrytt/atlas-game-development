--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "EnvironmentAssetKitRegistry assertion failed", 2)
	end
end

local function loadModule(path: string, debugName: string)
	return luau.load(fs.readFile(path), {
		debugName = debugName,
		injectGlobals = true,
	})()
end

local contracts = loadModule(
	"games/living-kingdoms/src/shared/World/EnvironmentAssetKitContracts.luau",
	"EnvironmentAssetKitContracts"
)
local registry = loadModule(
	"games/living-kingdoms/src/shared/Config/EnvironmentAssetKitRegistry.luau",
	"EnvironmentAssetKitRegistry"
)

check(registry.Version == "ENV-ASSET-KIT-v3")
check(#registry.Definitions >= 12)
check(contracts.isValid(registry.Definitions), "expanded environment registry must validate")

local seenIds = {}
for _, definition in registry.Definitions do
	check(not seenIds[definition.id], "duplicate environment asset id: " .. definition.id)
	seenIds[definition.id] = true
	check(definition.presentationOnly == true)
	check(definition.gameplayAuthorityOwnerId == nil)
	check(string.sub(definition.id, 1, 4) == "env.")
	check(string.sub(definition.sourceModelPath, 1, 12) == "Environment/")
end

for _, requiredId in
	{
		"env.tree.corrupted.dead_pine_a",
		"env.root.corrupted.fallen_mass_a",
		"env.rock.frontier.boulder_a",
		"env.root.corrupted.stump_cluster_a",
		"env.camp.frontier.abandoned_fire_ring_a",
		"env.camp.frontier.torn_shelter_a",
		"env.prop.frontier.supply_crate_stack_a",
		"env.camp.frontier.hanging_tarp_frame_a",
	}
do
	check(seenIds[requiredId] == true, "expanded environment registry missing " .. requiredId)
end

local duplicate = table.clone(registry.Definitions)
table.insert(duplicate, registry.Definitions[1])
local duplicateIssues = contracts.validate(duplicate)
check(#duplicateIssues > 0)
local foundDuplicate = false
for _, issue in duplicateIssues do
	if issue.code == "DuplicateAssetId" then
		foundDuplicate = true
	end
end
check(foundDuplicate, "duplicate IDs must fail closed")

local authorityClaim = table.clone(registry.Definitions[1])
authorityClaim.gameplayAuthorityOwnerId = "FakeEnvironmentGameplayService"
local authorityIssues = contracts.validate({ authorityClaim })
check(#authorityIssues == 1)
check(authorityIssues[1].code == "GameplayAuthorityForbidden")

local missingMinimum = table.clone(registry.Definitions[1])
missingMinimum.qualityTiers = { "Full" }
local tierIssues = contracts.validate({ missingMinimum })
check(#tierIssues == 1)
check(tierIssues[1].code == "MinimumTierRequired")

local badSocket = table.clone(registry.Definitions[2])
badSocket.sockets = {
	{ id = "socket.same", kind = "VFX" },
	{ id = "socket.same", kind = "Audio" },
}
local socketIssues = contracts.validate({ badSocket })
check(#socketIssues == 1)
check(socketIssues[1].code == "DuplicateSocketId")
