--!strict

local fs = require("@lune/fs")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "MainWorldStudioSnapshotSourceAudit assertion failed", 2)
	end
end

local projectPath = "games/living-kingdoms/main-world.project.json"
local manifestPath = "games/living-kingdoms/imports/studio-2026-08-11-main-world/revision-manifest.json"
local referenceEvidencePath = "games/living-kingdoms/imports/studio-2026-08-11-main-world/reference-evidence.json"
local modelRoot = "games/living-kingdoms/assets/recovered-world/models/main-world-studio-2026-08-11"

check(fs.isFile(projectPath))
check(fs.isFile(manifestPath))
check(fs.isFile(referenceEvidencePath))

local project = fs.readFile(projectPath)
check(string.find(project, "src/main%-world/server/MainWorldServer%.server%.luau") ~= nil)
check(string.find(project, "src/main%-world/client/MainWorldClient%.client%.luau") ~= nil)
check(
	string.find(project, "MainWorldArrival%.model%.json") == nil,
	"partial HubCore mapping must not double-author the imported Studio Main World"
)
check(
	string.find(project, "AmbientAnimation%.server%.luau") == nil,
	"quarantined Studio presentation scripts must not be auto-activated"
)

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
	local modelPath = modelRoot .. "/MainWorld-" .. groupName .. ".model.json"
	check(fs.isFile(modelPath), "missing imported Main World model: " .. groupName)
	check(
		string.find(project, "MainWorld%-" .. groupName .. "%.model%.json") ~= nil,
		"project does not map imported group: " .. groupName
	)
end

local manifest = fs.readFile(manifestPath)
check(string.find(manifest, '"importId":"studio-2026-08-11-main-world"', 1, true) ~= nil)
check(
	string.find(
		manifest,
		'"sha256":"e71ff34b2075e2da2314fc4c156b4ae1b1f0f20c42b82c517c2a4b9a7e3e43e1"',
		1,
		true
	) ~= nil
)
check(string.find(manifest, '"instanceCount":884', 1, true) ~= nil)
check(string.find(manifest, '"componentModelCount":35', 1, true) ~= nil)
check(string.find(manifest, '"studioOnlyScriptsActivated":false', 1, true) ~= nil)
check(string.find(manifest, '"referencePropertyCount":8', 1, true) ~= nil)
