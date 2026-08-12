--!strict

local fs = require("@lune/fs")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "MainWorldStudioSnapshotSourceAudit assertion failed", 2)
	end
end

local function contains(text: string, needle: string): boolean
	return string.find(text, needle, 1, true) ~= nil
end

local gameRoot = "games/living-kingdoms/"
local projectPath = gameRoot .. "main-world.project.json"
local importRoot = gameRoot .. "imports/studio-2026-08-11-main-world/"
local manifestPath = importRoot .. "revision-manifest.json"
local referenceEvidencePath = importRoot .. "reference-evidence.json"
local modelRoot = gameRoot .. "assets/recovered-world/models/main-world-studio-2026-08-11/"

check(fs.isFile(projectPath))
check(fs.isFile(manifestPath))
check(fs.isFile(referenceEvidencePath))

local project = fs.readFile(projectPath)
check(contains(project, "src/main-world/server/MainWorldServer.server.luau"))
check(contains(project, "src/main-world/client/MainWorldClient.client.luau"))
check(not contains(project, "MainWorldArrival.model.json"), "partial HubCore mapping must not be active")
check(not contains(project, "AmbientAnimation.server.luau"), "quarantined Studio scripts must stay inactive")

local requiredGroups = {
	"HubCore",
	"Routes",
	"Environment",
	"Structures",
	"Props",
	"NPCs",
	"Dark",
	"Village",
	"Forest",
	"Castle",
	"Zones",
	"Crystal",
	"Beach",
	"Volcanic",
	"Desert",
	"Swamp",
	"Snow",
	"Jungle",
	"Autumn",
	"Sky",
	"Meadow",
	"Mushroom",
	"Ruins",
	"Ocean",
	"Ice",
	"Bamboo",
	"Geyser",
	"Lavender",
	"Cherry",
	"Tundra",
	"Canyon",
	"Coral",
	"Geothermal",
	"Oasis",
	"CrystalDesert",
}

for _, groupName in requiredGroups do
	local fileName = "MainWorld-" .. groupName .. ".model.json"
	local modelPath = modelRoot .. fileName
	check(fs.isFile(modelPath), "missing imported Main World model: " .. groupName)
	check(contains(project, fileName), "project does not map imported group: " .. groupName)
end

local manifest = fs.readFile(manifestPath)
local sourceSha = "e71ff34b2075e2da2314fc4c156b4ae1b1f0f20c42b82c517c2a4b9a7e3e43e1"
check(contains(manifest, '"importId":"studio-2026-08-11-main-world"'))
check(contains(manifest, '"sha256":"' .. sourceSha .. '"'))
check(contains(manifest, '"instanceCount":884'))
check(contains(manifest, '"componentModelCount":35'))
check(contains(manifest, '"studioOnlyScriptsActivated":false'))
check(contains(manifest, '"referencePropertyCount":8'))
