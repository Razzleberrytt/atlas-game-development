--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local assetRoot = "games/living-kingdoms/assets/visual/enemy/standard-hostile/"
local generator = fs.readFile(assetRoot .. "generate_exclusion_walker.py")
local manifest = fs.readFile(assetRoot .. "asset-manifest.json")
local readme = fs.readFile(assetRoot .. "README.md")
local presenter = fs.readFile("games/living-kingdoms/src/server/Systems/EnemyPresentationService.luau")
local director = fs.readFile("games/living-kingdoms/src/server/Systems/EnemyDirectorService.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")
local roadmap = fs.readFile("docs/roadmap/VISUAL-PRODUCTION-TRACK.md")

for _, componentName in
	{
		"TorsoCore",
		"RibCage",
		"ChestPlate",
		"Head",
		"Sensor",
		"DorsalSpine",
		"ShoulderLeft",
		"ShoulderRight",
		"ForearmLeft",
		"ForearmRight",
		"ClawLeft",
		"ClawRight",
		"HipGuard",
		"LegLeft",
		"LegRight",
		"FootLeft",
		"FootRight",
		"BackCanister",
	}
do
	assertThat(
		string.find(generator, '"' .. componentName .. '"', 1, true) ~= nil,
		"walker source generator missing component " .. componentName
	)
	assertThat(
		string.find(presenter, '"' .. componentName .. '"', 1, true) ~= nil,
		"walker runtime fallback missing component " .. componentName
	)
end

for _, required in
	{
		'local PRESENTATION_MODEL_NAME = "ExclusionWalkerPresentation"',
		'presentation:SetAttribute("VisualCandidateId", "exclusion-walker.v1")',
		'presentation:SetAttribute("VisualStatus", "ProceduralFallback")',
		'presentation:SetAttribute("GameplayFootprintId", "enemy.exclusion_walker")',
		'attachment.Name = "AttackOrigin"',
		'root.Transparency = 0.88',
		'root.Material = Enum.Material.Neon',
		'folder.ChildAdded:Connect',
		'part.CanCollide = false',
		'part.CanTouch = false',
		'part.CanQuery = false',
		'part.Massless = true',
	}
do
	assertThat(string.find(presenter, required, 1, true) ~= nil, "walker presenter missing: " .. required)
end

local _, childAddedCount = string.gsub(presenter, "ChildAdded:Connect", "")
assertThat(childAddedCount == 1, "walker presentation must use exactly one folder listener")

assertThat(
	string.find(director, "root.Size = Vector3.new(3, 5.6, 3)", 1, true) ~= nil,
	"walker presentation must preserve the authoritative collider size"
)
assertThat(
	string.find(director, "root:SetNetworkOwner(nil)", 1, true) ~= nil,
	"walker movement ownership must remain server-controlled"
)

local directorStart = string.find(bootstrap, "EnemyDirectorService.start()", 1, true)
local presentationStart = string.find(bootstrap, "EnemyPresentationService.start()", 1, true)
assertThat(
	directorStart ~= nil and presentationStart ~= nil and directorStart < presentationStart,
	"walker presentation must start after the authoritative enemy folder owner"
)

assertThat(string.find(generator, 'scene.export(file_type="obj")', 1, true) ~= nil, "walker generator must emit OBJ")
assertThat(
	string.find(generator, "exclusion_walker_preview.svg", 1, true) ~= nil,
	"walker generator must emit a review preview"
)
assertThat(
	string.find(manifest, '"componentMeshCount": 18', 1, true) ~= nil,
	"walker manifest must record the fixed component count"
)
assertThat(
	string.find(manifest, '"changedByCandidate": false', 1, true) ~= nil,
	"walker manifest must preserve the gameplay footprint"
)
assertThat(
	string.find(manifest, '"status": "source-candidate-not-runtime-approved"', 1, true) ~= nil,
	"walker source must not claim Studio approval"
)
assertThat(string.find(readme, "presentation only", 1, true) ~= nil, "walker docs must preserve authority")
assertThat(
	string.find(roadmap, "A deterministic 18-component Exclusion Walker source candidate", 1, true) ~= nil,
	"VIS-0103 roadmap must record the fallback slice"
)

for _, forbidden in
	{
		"Heartbeat",
		"RenderStepped",
		"task.delay",
		"task.spawn",
		"RemoteEvent",
		"RemoteFunction",
		"FireServer",
		"FireClient",
		"OnServerEvent",
		"Humanoid:MoveTo",
		"TakeDamage",
		"MaximumHealth =",
		"AttackDamage =",
	}
do
	assertThat(
		not string.find(presenter, forbidden, 1, true),
		"walker presentation must not contain scheduler, network, or gameplay-authority token " .. forbidden
	)
end

for _, forbidden in { "rbxassetid://", "requests.get", "urllib.request", "subprocess" } do
	assertThat(not string.find(generator, forbidden, 1, true), "walker source must not fetch external content")
end

print("ExclusionWalkerPresentationSourceAudit: source, footprint, bootstrap, and authority checks passed")
