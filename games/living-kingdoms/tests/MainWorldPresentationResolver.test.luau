--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "MainWorldPresentationResolver assertion failed", 2)
	end
end

local function loadModule(path: string, debugName: string)
	return luau.load(fs.readFile(path), {
		debugName = debugName,
		injectGlobals = true,
	})()
end

local composition = loadModule(
	"games/living-kingdoms/src/shared/Config/MainWorldHubCoreCompositionConfig.luau",
	"MainWorldHubCoreCompositionConfig"
)
local resolverSource = fs.readFile("games/living-kingdoms/src/shared/World/MainWorldPresentationResolver.luau")
local resolver = luau.load(resolverSource, {
	debugName = "MainWorldPresentationResolver",
	injectGlobals = true,
})()

check(string.find(resolverSource, "WaitForChild", 1, true) == nil, "resolver must never block on streamed presentation")

local root = {
	Arrival = {
		SpawnLocation = { marker = "arrival" },
	},
	Civic = {
		CentralFountain = { marker = "fountain" },
		GrandStaircase = { marker = "staircase" },
		HubArchway = { marker = "archway" },
	},
	ExpeditionGate = {
		DungeonPortal = { marker = "portal" },
	},
}

local function findChild(parent: any, name: string): any?
	return parent[name]
end

for _, component in composition.Components do
	local resolved = resolver.resolve(composition, component.id, root, findChild)
	check(resolved.status == "Present", "expected present: " .. component.id)
	check(resolved.contentId == component.id)
	check(resolved.relativePath == component.targetRelativePath)
	check(resolved.value ~= nil)
	check(resolved.missingSegment == nil)
	check(resolver.pathForContentId(composition, component.id) == component.targetRelativePath)
end

local missingRoot = {
	Arrival = root.Arrival,
	Civic = root.Civic,
}
local missing = resolver.resolve(composition, "portal.expedition.primary", missingRoot, findChild)
check(missing.status == "Missing")
check(missing.contentId == "portal.expedition.primary")
check(missing.relativePath == "ExpeditionGate/DungeonPortal")
check(missing.value == nil)
check(missing.missingSegment == "ExpeditionGate")

local partialRoot = {
	ExpeditionGate = {},
}
local partial = resolver.resolve(composition, "portal.expedition.primary", partialRoot, findChild)
check(partial.status == "Missing")
check(partial.missingSegment == "DungeonPortal")
check(partial.value == nil)

local unknown = resolver.resolve(composition, "main_world.unknown", root, findChild)
check(unknown.status == "UnknownContentId")
check(unknown.relativePath == nil)
check(unknown.value == nil)
check(unknown.missingSegment == nil)
check(resolver.pathForContentId(composition, "main_world.unknown") == nil)
