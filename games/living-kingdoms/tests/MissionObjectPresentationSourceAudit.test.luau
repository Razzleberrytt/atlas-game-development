--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local resolver = fs.readFile("games/living-kingdoms/src/client/Presentation/MissionObjectPresentationResolver.luau")
local factory = fs.readFile("games/living-kingdoms/src/client/Presentation/MissionObjectPresentationFactory.luau")
local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/MissionObjectPresentationController.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")
local registry = fs.readFile("games/living-kingdoms/src/shared/Config/VisualAssetConfig.luau")
local relayReadme = fs.readFile("games/living-kingdoms/assets/visual/objective/relay-console/README.md")
local relayManifest = fs.readFile("games/living-kingdoms/assets/visual/objective/relay-console/asset-manifest.json")
local extractionReadme = fs.readFile("games/living-kingdoms/assets/visual/extraction/beacon/README.md")
local extractionManifest = fs.readFile("games/living-kingdoms/assets/visual/extraction/beacon/asset-manifest.json")
local roadmap = fs.readFile("docs/roadmap/VISUAL-PRODUCTION-TRACK.md")
local inventory = fs.readFile("docs/specifications/visual-placeholder-inventory.md")

for _, required in {
	'export type RelayStateId = "Hidden" | "Standby" | "Active" | "Completed"',
	'export type ExtractionStateId = "Hidden" | "Open" | "Holdout" | "Success" | "Failure"',
	'facts.objectiveStateId == "Inactive" and facts.phaseId == "Insertion"',
	'facts.objectiveStateId == "Active" and facts.phaseId == "Infiltration"',
	'facts.extractionUnlocked ~= true',
	'facts.phaseId == "Resolved" and facts.outcomeId == "Success"',
	'facts.phaseId == "Resolved" and facts.outcomeId == "Failure"',
} do
	assertThat(string.find(resolver, required, 1, true) ~= nil, "mission-object resolver missing: " .. required)
end

for _, required in {
	'visualParts: { BasePart }',
	'model.Name = "RelayConsolePresentation"',
	'model.Name = "ExtractionBeaconPresentation"',
	'VisualAssetContracts.AssetKeys.ObjectiveRelayConsoleModel',
	'VisualAssetContracts.AssetKeys.ExtractionBeaconModel',
	'"RelayStateLabel"',
	'"ExtractionStateLabel"',
	'billboard.AlwaysOnTop = false',
	'function Factory.applyRelayState',
	'function Factory.applyExtractionState',
} do
	assertThat(string.find(factory, required, 1, true) ~= nil, "mission-object factory missing: " .. required)
end
local makePartCount = select(2, string.gsub(factory, "makePart%(", ""))
assertThat(makePartCount == 24, "factory must contain one helper plus exactly 23 bounded part declarations")

for _, required in {
	'MissionContracts.validateSafeMissionSnapshot(payload)',
	'snapshot.revision <= previous.revision',
	'stateRemote.OnClientEvent:Connect(onSnapshot)',
	'Workspace.DescendantAdded:Connect(inspectInstance)',
	'Workspace.DescendantRemoving:Connect(onDescendantRemoving)',
	'MissionObjectPresentationResolver.resolve',
	'MissionObjectPresentationFactory.createRelay',
	'MissionObjectPresentationFactory.createExtraction',
	'MissionObjectPresentationFactory.applyRelayState',
	'MissionObjectPresentationFactory.applyExtractionState',
	'binding.body.LocalTransparencyModifier = binding.bodyLocalTransparencyModifier',
	'binding.pillar.LocalTransparencyModifier = binding.pillarLocalTransparencyModifier',
	'serverLight.Enabled = binding.serverLightWasEnabled',
	'serverMarker.Enabled = binding.serverMarkerWasEnabled',
	'unbindRelay()',
	'unbindExtraction()',
} do
	assertThat(string.find(controller, required, 1, true) ~= nil, "mission-object controller missing: " .. required)
end
local connectionCount = select(2, string.gsub(controller, ":Connect%(", ""))
assertThat(connectionCount == 3, "mission-object controller must use exactly three global connections")

for _, forbidden in {
	"FireServer",
	"InvokeServer",
	"RemoteFunction",
	"RunService",
	"Heartbeat",
	"RenderStepped",
	"Stepped",
	"task.",
	"Triggered:Connect",
	"prompt.Enabled",
	"CanCollide =",
	"PivotTo",
	"SetNetworkOwner",
	"requestObjectiveInteraction",
	"evaluateExtractionPresenceAt",
	"snapshot.phaseId =",
	"snapshot.objectiveStateId =",
	"snapshot.extractionUnlocked =",
	"snapshot.outcomeId =",
} do
	assertThat(not string.find(controller, forbidden, 1, true), "mission-object controller contains authority token: " .. forbidden)
end

local missionStart = string.find(bootstrap, "MissionController.start()", 1, true)
local objectStart = string.find(bootstrap, "MissionObjectPresentationController.start()", 1, true)
assertThat(missionStart ~= nil and objectStart ~= nil and missionStart < objectStart, "mission UI must start before world objects")

assertThat(string.find(relayManifest, '"maximumPresentationParts": 11', 1, true) ~= nil, "relay part bound missing")
assertThat(string.find(extractionManifest, '"maximumPresentationParts": 12', 1, true) ~= nil, "extraction part bound missing")
for _, manifest in { relayManifest, extractionManifest } do
	assertThat(string.find(manifest, '"perObjectConnections": 0', 1, true) ~= nil, "per-object connection bound missing")
	assertThat(string.find(manifest, '"frameConnections": 0', 1, true) ~= nil, "frame-loop bound missing")
	assertThat(string.find(manifest, '"timerCount": 0', 1, true) ~= nil, "timer bound missing")
	assertThat(string.find(manifest, '"newRemoteCount": 0', 1, true) ~= nil, "remote bound missing")
	assertThat(string.find(manifest, '"studioApproved": false', 1, true) ~= nil, "Studio gate must remain pending")
end
assertThat(string.find(relayReadme, "Roblox Studio", 1, true) ~= nil, "relay README must preserve Studio gate")
assertThat(string.find(extractionReadme, "Roblox Studio", 1, true) ~= nil, "extraction README must preserve Studio gate")

assertThat(string.find(registry, '"RelayConsolePresentation"', 1, true) ~= nil, "registry relay root missing")
assertThat(string.find(registry, '"ExtractionBeaconPresentation"', 1, true) ~= nil, "registry extraction root missing")
assertThat(string.find(registry, '"src/client/Controllers/MissionObjectPresentationController.luau"', 1, true) ~= nil, "registry owner missing")
assertThat(string.find(roadmap, "Validated monotonic safe mission snapshots", 1, true) ~= nil, "VIS-0105 mission-object status missing")
assertThat(string.find(inventory, "MissionObjectPresentationController", 1, true) ~= nil, "placeholder inventory owner missing")

print("MissionObjectPresentationSourceAudit: bounded geometry, hidden truth, cleanup, authority, docs, and Studio gates passed")
