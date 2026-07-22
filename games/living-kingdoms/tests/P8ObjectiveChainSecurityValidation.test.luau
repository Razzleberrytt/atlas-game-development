--!strict

-- P8-0108 objective-chain security matrix. The authored chain is progressed only
-- by the server-owned, presence-driven runtime through the pure resolver, so the
-- adversarial surface is the sample itself. This fixture exercises that surface
-- directly and audits the runtime's authority boundary.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function loadSimple(path: string, debugName: string)
	return luau.load(fs.readFile(path), { debugName = debugName, injectGlobals = true })()
end

local config = loadSimple("games/living-kingdoms/src/shared/Config/ObjectiveChainConfig.luau", "ObjectiveChainConfig")
local resolver =
	loadSimple("games/living-kingdoms/src/shared/Mission/ObjectiveChainResolver.luau", "ObjectiveChainResolver")

local relayId = config.Objectives[1].objectiveId
local boosterId = config.Objectives[2].objectiveId
local floodId = config.Objectives[3].objectiveId
local worker = { operativeEntityId = "operative:x", classId = "class.medic" }
local engineer = { operativeEntityId = "operative:e", classId = config.AssistingClassId }

local function freshState()
	local state = {}
	for _, definition in config.Objectives do
		state[definition.objectiveId] = { progress = 0, completed = false }
	end
	return state
end

local function sample(state, phaseId, delta, workers, revision, expected)
	return resolver.resolveSample({
		config = config,
		phaseId = phaseId,
		activePhaseIds = config.ActiveChainPhaseIds,
		revision = revision or 1,
		expectedRevision = expected or 1,
		deltaSeconds = delta,
		stateByObjectiveId = state,
		workersByObjectiveId = workers or {},
		assistingClassId = config.AssistingClassId,
	})
end

-- 1. Replay / remote spam is structurally impossible: the mission runtime exposes
--    no client remote to declare objective progress, and the controller sends
--    nothing. Progress is server-sampled only.
local missionSource = fs.readFile("games/living-kingdoms/src/server/Systems/MissionDirectorService.luau")
local controllerSource = fs.readFile("games/living-kingdoms/src/client/Controllers/MissionController.luau")
for _, forbidden in { "OnServerEvent", "FireServer", "InvokeServer", "RemoteFunction" } do
	assert(
		not string.find(missionSource, forbidden, 1, true),
		"the objective runtime must accept no client remote: " .. forbidden
	)
end
for _, forbidden in { "FireServer", "InvokeServer" } do
	assert(not string.find(controllerSource, forbidden, 1, true), "the mission client must send nothing: " .. forbidden)
end

-- 2. Wrong phase: no objective advances outside the authored chain phases.
assert(sample(freshState(), "Insertion", 1, { [relayId] = { worker } }).rejectionReasonId == "InvalidPhase")
assert(sample(freshState(), "Resolved", 1, { [relayId] = { worker } }).rejectionReasonId == "InvalidPhase")
assert(sample(freshState(), "Holdout", 1, { [relayId] = { worker } }).rejectionReasonId == "InvalidPhase")

-- 3. Stale revision: a sample against a superseded revision commits nothing.
assert(sample(freshState(), "Infiltration", 1, { [relayId] = { worker } }, 5, 6).rejectionReasonId == "StaleRevision")

-- 4. Invalid delta: negative or NaN time never advances or regresses progress.
assert(sample(freshState(), "Infiltration", -1, { [relayId] = { worker } }).rejectionReasonId == "InvalidDelta")
assert(sample(freshState(), "Infiltration", 0 / 0, { [relayId] = { worker } }).rejectionReasonId == "InvalidDelta")

-- 5. Prerequisite skip: the booster and floodlights cannot progress before their
--    prerequisites are committed, so a required step can never be skipped.
local skipState = freshState()
local skipBooster = sample(skipState, "Infiltration", 1, { [boosterId] = { worker, engineer } })
for _, update in skipBooster.updates do
	if update.objectiveId == boosterId then
		assert(update.stateId == "Locked" and update.progress == 0, "booster cannot progress before the relay")
	end
end
local skipFloodState = freshState()
skipFloodState[relayId] = { progress = 4, completed = true }
local skipFlood = sample(skipFloodState, "Exfiltration", 1, { [floodId] = { engineer } })
for _, update in skipFlood.updates do
	if update.objectiveId == floodId then
		assert(update.stateId == "Locked", "floodlights cannot progress before the booster")
	end
end

-- 6. No class gate: the required objectives ignore class entirely; only the
--    optional floodlights benefit from an engineer, and never require one.
local classState = freshState()
classState[relayId] = { progress = 4, completed = true }
local nonEngineerBooster = sample(classState, "Infiltration", 1, { [boosterId] = { worker } })
local engineerBooster = sample(classState, "Infiltration", 1, { [boosterId] = { engineer } })
local nonEngineerProgress, engineerProgress
for _, update in nonEngineerBooster.updates do
	if update.objectiveId == boosterId then
		nonEngineerProgress = update.progress
	end
end
for _, update in engineerBooster.updates do
	if update.objectiveId == boosterId then
		engineerProgress = update.progress
	end
end
assert(nonEngineerProgress == engineerProgress, "a mandatory objective must not advantage any class")

-- 7. Impossible distance: the resolver only advances objectives that have present
--    workers (the runtime range-filters presence before sampling), so an empty
--    worker set commits nothing.
local distanceState = freshState()
local noWorkers = sample(distanceState, "Infiltration", 1, {})
for _, update in noWorkers.updates do
	assert(update.progress == 0, "no in-range worker means no progress")
end

-- 8. Bounded work: an arbitrarily large delta commits at most one authored step.
local hitch = sample(freshState(), "Infiltration", 1e9, { [relayId] = { worker } })
for _, update in hitch.updates do
	if update.objectiveId == relayId then
		assert(update.progress <= config.MaxSampleDeltaSeconds + 1e-6, "a hitch cannot skip authored progress")
	end
end

-- 9. Optional never unlocks extraction; only the required objective does.
local unlockState = freshState()
unlockState[relayId] = { progress = 4, completed = true }
unlockState[floodId] = { progress = config.Objectives[3].completionUnits - 0.1, completed = false }
local floodComplete = sample(unlockState, "Exfiltration", 1, { [floodId] = { engineer } })
assert(floodComplete.unlockedExtraction == false, "the optional objective never unlocks extraction")
assert(floodComplete.requiredChainComplete == false, "the required chain is still open without the booster")

print(
	"P8ObjectiveChainSecurityValidation: no-remote authority, phase, revision, delta, prerequisite, class, distance, bounds, and optional-gate coverage passed"
)
