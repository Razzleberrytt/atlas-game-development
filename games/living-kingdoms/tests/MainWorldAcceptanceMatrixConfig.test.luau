--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "BA-014 acceptance matrix assertion failed", 2)
	end
end

local CONFIG_PATH = "games/living-kingdoms/src/shared/Config/MainWorldAcceptanceMatrixConfig.luau"
local REPRESENTATION_PATH = "games/living-kingdoms/src/shared/Config/MainWorldRepresentationConfig.luau"
local HUB_INTERACTION_PATH = "games/living-kingdoms/src/shared/Config/HubInteractionConfig.luau"

-- The BA-011 representation config has no dependencies of its own, so the real
-- file is loaded: the matrix must resolve against the committed streaming
-- groups and the real held-runtime flag, not a convenient stub.
local representationConfig = luau.load(fs.readFile(REPRESENTATION_PATH), {
	debugName = "MainWorldRepresentationConfig",
	injectGlobals = true,
})()

local REPRESENTATION_TOKEN = {}
local config = luau.load(fs.readFile(CONFIG_PATH), {
	debugName = "MainWorldAcceptanceMatrixConfig",
	environment = {
		script = {
			Parent = {
				MainWorldRepresentationConfig = REPRESENTATION_TOKEN,
			},
		},
		require = function(token: unknown)
			if token == REPRESENTATION_TOKEN then
				return representationConfig
			end
			error("unexpected MainWorldAcceptanceMatrixConfig dependency")
		end,
	},
	injectGlobals = true,
})()

-- Identity and hold state.
assert(config.Version == "BA-014-v1")
assert(config.RuntimeEnabled == false, "BA-014 activates nothing")
assert(config.MatrixExecuted == false, "BA-014 must ship without a recorded run")
assert(config.EvidenceLevel == "E1", "defining acceptance does not raise the evidence level")
assert(config.isActivationAcceptable() == false, "an unrun matrix cannot accept Main World activation")

-- Every BA-010 checklist area is represented, and every check ships unrun.
local expectedCategories = {
	"ArrivalAndFlow",
	"NavigationAndComposition",
	"LandmarkAndReadability",
	"VisualEnvironment",
	"Audio",
	"StreamingAndLifecycle",
	"PerformanceAndMemory",
}
for _, categoryId in expectedCategories do
	assert(config.Categories[categoryId] == categoryId, `missing acceptance category {categoryId}`)
	assert(#config.checksForCategory(categoryId) > 0, `category {categoryId} has no checks`)
end

local categoryCount = 0
for _ in config.Categories do
	categoryCount += 1
end
assert(categoryCount == #expectedCategories, "acceptance categories drifted from the BA-010 checklist areas")

assert(#config.Checks > 0)
for _, check in config.Checks do
	assert(check.status == config.ResultStatuses.NotRun, `check {check.id} must ship unrun`)
	assert(config.ChecksById[check.id] == check, `check {check.id} is missing from the id index`)
end

local blocking = config.blockingChecks()
assert(#blocking > 0, "the matrix must have blocking checks or it gates nothing")
assert(#blocking < #config.Checks, "record-only and refinement checks must remain non-blocking")

-- The committed matrix is frozen, so no consumer can flip a result in place.
local mutated = pcall(function()
	config.MatrixExecuted = true
end)
assert(mutated == false, "the committed matrix must be read-only")
mutated = pcall(function()
	config.Checks[1].status = "Pass"
end)
assert(mutated == false, "a recorded check result must be read-only")

-- Declaring a run executed must not by itself accept activation: the gate is
-- every blocking check passing. Reload the module with only that flag flipped.
local executedSource = string.gsub(fs.readFile(CONFIG_PATH), "MatrixExecuted = false", "MatrixExecuted = true", 1)
executedSource =
	string.gsub(executedSource, "assert%(MainWorldAcceptanceMatrixConfig%.MatrixExecuted == false[^\n]+\n", "")
local executedConfig = luau.load(executedSource, {
	debugName = "MainWorldAcceptanceMatrixConfigExecutedProbe",
	environment = {
		script = { Parent = { MainWorldRepresentationConfig = REPRESENTATION_TOKEN } },
		require = function(token: unknown)
			if token == REPRESENTATION_TOKEN then
				return representationConfig
			end
			error("unexpected MainWorldAcceptanceMatrixConfig dependency")
		end,
	},
	injectGlobals = true,
})()
assert(executedConfig.MatrixExecuted == true, "the probe must actually flip the executed flag")
assert(
	executedConfig.isActivationAcceptable() == false,
	"declaring a run executed cannot accept a matrix whose blocking checks are unrun"
)

-- Threshold provenance keeps inherited numbers separate from invented ones.
local provenanceSeen = {}
for key, threshold in config.Thresholds do
	assert(type(threshold.value) == "number", `threshold {key} needs a numeric value`)
	assert(#threshold.unit > 0, `threshold {key} needs a unit`)
	assert(
		threshold.comparison == "at-most" or threshold.comparison == "at-least",
		`threshold {key} needs a comparison direction`
	)
	provenanceSeen[threshold.provenance] = true
end
assert(provenanceSeen["ba-010-checklist"], "the matrix must inherit BA-010 checklist thresholds")
assert(provenanceSeen["ba-013-provisional"], "the matrix must inherit BA-013 provisional targets")
assert(provenanceSeen["ba-014-authoring-target"], "invented starting lines must be labelled as authoring targets")

-- The BA-013 performance targets are carried forward exactly.
assert(config.Thresholds.DesktopFullMedianFrameMs.value == 16.7)
assert(config.Thresholds.DesktopFullP95FrameMs.value == 25.0)
assert(config.Thresholds.MobileMinimumReadableP95FrameMs.value == 33.3)
assert(config.Thresholds.PostWarmupStreamingHitchMs.value == 100)
assert(config.Thresholds.CleanupDriftPercent.value == 5)
assert(config.Thresholds.TraversalCycleMinutes.value == 10)
assert(config.Thresholds.OrientationRecognitionSeconds.value == 10)
assert(config.Thresholds.SimultaneousArrivalPlayers.value == 4)

-- The BA-013 visible-scene ceilings are carried forward exactly, and each tier
-- may only reduce ambient cost relative to the one above it.
local tiersById = {}
for _, tier in config.QualityTiers do
	tiersById[tier.id] = tier
end
assert(tiersById.Full and tiersById.Reduced and tiersById.MinimumReadable)
assert(tiersById.Full.ceilings.visibleEnabledLocalDynamicLights == 16)
assert(tiersById.Reduced.ceilings.visibleEnabledLocalDynamicLights == 8)
assert(tiersById.MinimumReadable.ceilings.visibleEnabledLocalDynamicLights == 4)
assert(tiersById.Full.ceilings.estimatedLiveAmbientParticles == 300)
assert(tiersById.MinimumReadable.ceilings.visibleAmbientParticleEmitters == 0)
assert(tiersById.MinimumReadable.ceilings.steadyStateAmbientBeds == 1, "minimum readable keeps one ambient bed")

for ceilingKey, fullValue in tiersById.Full.ceilings do
	local reduced = tiersById.Reduced.ceilings[ceilingKey]
	local minimum = tiersById.MinimumReadable.ceilings[ceilingKey]
	assert(reduced ~= nil and minimum ~= nil, `ceiling {ceilingKey} is missing from a lower tier`)
	assert(reduced <= fullValue, `Reduced tier raises the {ceilingKey} ceiling`)
	assert(minimum <= reduced, `MinimumReadable tier raises the {ceilingKey} ceiling`)
end

-- Fixed cameras cover the BA-010 composition beats, and tier captures reuse them.
local expectedBeats = {
	"ArrivalThreshold",
	"OrientationCenter",
	"PreparationRing",
	"InteractionEdge",
	"AdventureGate",
	"ExplorationBranch",
	"ReturnSeam",
}
assert(#config.FixedCameras == #expectedBeats, "fixed cameras drifted from the composition beats")
local beatsSeen = {}
for _, camera in config.FixedCameras do
	beatsSeen[camera.compositionBeat] = true
end
for _, beat in expectedBeats do
	assert(beatsSeen[beat], `no fixed camera covers the {beat} beat`)
end

local tiersCaptured = {}
for _, mode in config.CaptureModes do
	tiersCaptured[mode.qualityTierId] = true
end
assert(
	tiersCaptured.Full and tiersCaptured.Reduced and tiersCaptured.MinimumReadable,
	"every quality tier needs a capture mode"
)

-- Run identity must be recorded before any result counts as evidence.
local identityFields = {}
for _, field in config.RequiredRunIdentityFields do
	identityFields[field] = true
end
for _, required in { "repositoryCommit", "placeArtifactSha256", "studioVersion", "rollbackCheckpointCommit" } do
	assert(identityFields[required], `run identity must record {required}`)
end

-- Cross-contract references resolve against the committed BA-011 and BA-012 sources.
local representationGroups = {}
for _, group in representationConfig.StreamingGroups do
	representationGroups[group.id] = true
end
local coveredGroups = {}
for _, check in config.Checks do
	for _, groupId in check.streamingGroupIds do
		assert(representationGroups[groupId], `check {check.id} references unknown streaming group {groupId}`)
		coveredGroups[groupId] = true
	end
end
for groupId in representationGroups do
	assert(coveredGroups[groupId], `no acceptance check covers streaming group {groupId}`)
end

local hubInteractionSource = fs.readFile(HUB_INTERACTION_PATH)
local anchorsReferenced = 0
for _, check in config.Checks do
	for _, anchorId in check.hubAnchorIds do
		assert(
			string.find(hubInteractionSource, `"{anchorId}"`, 1, true) ~= nil,
			`check {check.id} references anchor {anchorId} that BA-012 does not define`
		)
		anchorsReferenced += 1
	end
end
assert(anchorsReferenced > 0, "the matrix must bind at least one BA-012 interaction anchor")

-- Boundary audit: the matrix defines acceptance, it does not own runtime.
local source = fs.readFile(CONFIG_PATH)
assert(string.find(source, "game:GetService", 1, true) == nil, "the matrix must not reach for live services")
assert(string.find(source, "FireServer", 1, true) == nil, "the matrix owns no networking")
assert(string.find(source, "DataStore", 1, true) == nil, "the matrix owns no persistence")
assert(string.find(source, "Instance.new", 1, true) == nil, "the matrix creates no instances")
assert(string.find(source, "rbxassetid://", 1, true) == nil, "the matrix invents no asset IDs")
assert(string.find(source, "Workspace/", 1, true) == nil, "placement stays in the BA-011 representation contract")

print("BA-014 MainWorldAcceptanceMatrixConfig fixture passed")
