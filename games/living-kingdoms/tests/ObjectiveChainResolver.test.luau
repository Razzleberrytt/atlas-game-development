--!strict

-- P8-0101/P8-0102 authored objective chain: vocabulary, authored configuration
-- invariants, and the pure server-owned progression resolver.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "P8 objective chain fixture assertion failed", 2)
	end
end

local function loadSimple(path: string, debugName: string)
	return luau.load(fs.readFile(path), {
		debugName = debugName,
		injectGlobals = true,
	})()
end

local contracts = loadSimple("games/living-kingdoms/src/shared/Mission/ObjectiveContracts.luau", "ObjectiveContracts")
local config = loadSimple("games/living-kingdoms/src/shared/Config/ObjectiveChainConfig.luau", "ObjectiveChainConfig")
local resolver =
	loadSimple("games/living-kingdoms/src/shared/Mission/ObjectiveChainResolver.luau", "ObjectiveChainResolver")
local world = loadSimple("games/living-kingdoms/src/shared/Config/WorldFoundationConfig.luau", "WorldFoundationConfig")

local ObjectiveIds = contracts.ObjectiveIds

-- 1. Vocabulary + authored configuration invariants.
assert(config.Version == "OBJECTIVE-CHAIN-001-v1")
assert(#config.Objectives == 3, "the chain must author exactly three objectives")

local landmarkById = {}
for _, landmark in world.Landmarks do
	landmarkById[landmark.id] = landmark
end

local requiredForExtraction = 0
local seenObjectiveIds = {}
for _, definition in config.Objectives do
	assert(contracts.validateObjectiveDefinition(definition), "objective definition must validate: " .. definition.objectiveId)
	assert(seenObjectiveIds[definition.objectiveId] == nil, "objective ids are unique")
	seenObjectiveIds[definition.objectiveId] = true
	-- Every objective sits on its named existing landmark.
	local landmark = landmarkById[definition.landmarkId]
	assert(landmark ~= nil, "objective landmark must exist: " .. definition.landmarkId)
	local dx = definition.center.x - landmark.x
	local dz = definition.center.z - landmark.z
	assert(
		dx * dx + dz * dz <= landmark.radius * landmark.radius,
		"objective must sit on its landmark: " .. definition.objectiveId
	)
	if definition.isRequiredForExtraction then
		requiredForExtraction += 1
	end
end
assert(requiredForExtraction == 1, "exactly one objective unlocks extraction")

-- The authored chain ids match the shared vocabulary.
assert(config.Objectives[1].objectiveId == ObjectiveIds.RestoreRelay)
assert(config.Objectives[2].objectiveId == ObjectiveIds.ChargeBooster)
assert(config.Objectives[3].objectiveId == ObjectiveIds.RestoreFloodlights)
assert(config.Objectives[2].prerequisiteObjectiveId == ObjectiveIds.RestoreRelay)
assert(config.Objectives[3].prerequisiteObjectiveId == ObjectiveIds.ChargeBooster)
assert(config.Objectives[3].isOptional == true and config.Objectives[3].isRequiredForExtraction == false)

-- Malformed definitions are rejected.
assert(not contracts.validateObjectiveDefinition({}))
assert(not contracts.validateObjectiveDefinition("nope"))
local malformed = table.clone(config.Objectives[1] :: any)
malformed.interactionKindId = "TeleportInstantly"
assert(not contracts.validateObjectiveDefinition(malformed), "unknown interaction kind is rejected")
local noPhase = table.clone(config.Objectives[1] :: any)
noPhase.activePhaseIds = {}
assert(not contracts.validateObjectiveDefinition(noPhase), "an objective needs at least one active phase")

-- Resolver helpers.
local function freshState()
	local state = {}
	for _, definition in config.Objectives do
		state[definition.objectiveId] = { progress = 0, completed = false }
	end
	return state
end

local function applyResult(state, result)
	for _, update in result.updates do
		local entry = state[update.objectiveId]
		entry.progress = update.progress
		if update.completedNow then
			entry.completed = true
		end
	end
end

local function sample(state, phaseId, deltaSeconds, workersByObjectiveId, revision, expectedRevision)
	return resolver.resolveSample({
		config = config,
		phaseId = phaseId,
		activePhaseIds = config.ActiveChainPhaseIds,
		revision = revision or 5,
		expectedRevision = expectedRevision or 5,
		deltaSeconds = deltaSeconds,
		stateByObjectiveId = state,
		workersByObjectiveId = workersByObjectiveId or {},
		assistingClassId = config.AssistingClassId,
	})
end

local worker = { operativeEntityId = "operative:alpha", classId = "class.medic" }
local engineer = { operativeEntityId = "operative:eng", classId = config.AssistingClassId }

-- 2. Relay is a held channel: accumulates only while worked, completes at units.
local state = freshState()
local relayWorkers = { [ObjectiveIds.RestoreRelay] = { worker } }
for _ = 1, 3 do
	local result = sample(state, "Infiltration", 1, relayWorkers)
	assert(result.rejectionReasonId == nil)
	applyResult(state, result)
end
assert(state[ObjectiveIds.RestoreRelay].completed == false, "relay needs its full channel (4s) to complete")
assert(math.abs(state[ObjectiveIds.RestoreRelay].progress - 3) < 1e-6)
-- The channel pauses with nobody present (no decay).
local pausedResult = sample(state, "Infiltration", 1, {})
applyResult(state, pausedResult)
assert(math.abs(state[ObjectiveIds.RestoreRelay].progress - 3) < 1e-6, "a held channel does not decay")
-- Booster stays Locked while its relay prerequisite is unmet, even if worked.
-- (The relay is deliberately not worked here so it stays short of completion.)
local lockedBoosterResult = sample(state, "Infiltration", 1, {
	[ObjectiveIds.ChargeBooster] = { worker, engineer },
})
for _, update in lockedBoosterResult.updates do
	if update.objectiveId == ObjectiveIds.ChargeBooster then
		assert(update.stateId == "Locked" and update.progress == 0, "booster cannot progress before relay")
	end
end
applyResult(state, lockedBoosterResult)
-- Finish the relay.
local relayDone = sample(state, "Infiltration", 1, relayWorkers)
applyResult(state, relayDone)
assert(state[ObjectiveIds.RestoreRelay].completed == true)
assert(table.find(relayDone.completedObjectiveIds, ObjectiveIds.RestoreRelay) ~= nil)
-- Relay does not unlock extraction (it is not the extraction-required objective).
assert(relayDone.unlockedExtraction == false and relayDone.requiredChainComplete == false)
-- Its authored wave/radio ride along on the completing update.
for _, update in relayDone.updates do
	if update.objectiveId == ObjectiveIds.RestoreRelay then
		assert(update.waveIndexOnComplete == 1 and update.radioLineIdOnComplete == "RelayRestored")
	end
end

-- 3. Booster is a decaying charge: fills when held, drains when abandoned.
local boosterWorkers = { [ObjectiveIds.ChargeBooster] = { worker } }
for _ = 1, 10 do
	applyResult(state, sample(state, "Infiltration", 1, boosterWorkers))
end
assert(math.abs(state[ObjectiveIds.ChargeBooster].progress - 10) < 1e-6)
-- Abandon it: charge drains at half rate (a 1s sample drains 0.5 units).
local drain = sample(state, "Infiltration", 1, {})
for _, update in drain.updates do
	if update.objectiveId == ObjectiveIds.ChargeBooster then
		assert(update.decaying == true, "an abandoned booster reports decaying")
	end
end
applyResult(state, drain)
assert(math.abs(state[ObjectiveIds.ChargeBooster].progress - 9.5) < 1e-6, "booster drains at 0.5/s")
-- Hold it the rest of the way to completion.
for _ = 1, 20 do
	applyResult(state, sample(state, "Infiltration", 1, boosterWorkers))
end
local boosterState = state[ObjectiveIds.ChargeBooster]
assert(boosterState.completed == true, "held booster completes")
-- Re-run one sample at the completing moment to inspect the completion signal.
local boosterFreshState = freshState()
boosterFreshState[ObjectiveIds.RestoreRelay] = { progress = 4, completed = true }
boosterFreshState[ObjectiveIds.ChargeBooster] = { progress = 23.5, completed = false }
local boosterComplete = sample(boosterFreshState, "Infiltration", 1, boosterWorkers)
assert(boosterComplete.unlockedExtraction == true, "booster unlocks extraction")
assert(boosterComplete.requiredChainComplete == true, "required chain complete after booster")
for _, update in boosterComplete.updates do
	if update.objectiveId == ObjectiveIds.ChargeBooster then
		assert(update.completedNow and update.unlockedExtraction and update.waveIndexOnComplete == 2)
	end
end

-- 4. Optional floodlights: locked/out-of-phase during Infiltration, engineer-fast
--    vs slower manual bypass during Exfiltration; never gates extraction.
local exfilState = freshState()
exfilState[ObjectiveIds.RestoreRelay] = { progress = 4, completed = true }
exfilState[ObjectiveIds.ChargeBooster] = { progress = 24, completed = true }
-- During Infiltration the floodlights are not in phase (and disclose no progress).
local floodInfiltration = sample(exfilState, "Infiltration", 1, {
	[ObjectiveIds.RestoreFloodlights] = { engineer },
})
for _, update in floodInfiltration.updates do
	if update.objectiveId == ObjectiveIds.RestoreFloodlights then
		assert(update.progress == 0, "floodlights do not progress out of their phase")
	end
end
-- Manual bypass (no engineer): 0.4/s over three 1s samples reaches 1.2 units.
local manualState = table.clone(exfilState)
manualState[ObjectiveIds.RestoreFloodlights] = { progress = 0, completed = false }
for _ = 1, 3 do
	applyResult(manualState, sample(manualState, "Exfiltration", 1, {
		[ObjectiveIds.RestoreFloodlights] = { worker },
	}))
end
assert(math.abs(manualState[ObjectiveIds.RestoreFloodlights].progress - 1.2) < 1e-6, "manual repair is 0.4/s")
assert(manualState[ObjectiveIds.RestoreFloodlights].completed == false)
-- Engineer assist: 1.0/s over the same three samples reaches 3.0 units.
local engineerState = table.clone(exfilState)
engineerState[ObjectiveIds.RestoreFloodlights] = { progress = 0, completed = false }
for _ = 1, 3 do
	applyResult(engineerState, sample(engineerState, "Exfiltration", 1, {
		[ObjectiveIds.RestoreFloodlights] = { engineer },
	}))
end
assert(math.abs(engineerState[ObjectiveIds.RestoreFloodlights].progress - 3) < 1e-6, "engineer repair is 1.0/s")
assert(
	engineerState[ObjectiveIds.RestoreFloodlights].progress > manualState[ObjectiveIds.RestoreFloodlights].progress,
	"engineer must be faster than the manual bypass"
)
-- Drive the engineer repair to completion; it never unlocks extraction.
local floodDone
for _ = 1, 4 do
	floodDone = sample(engineerState, "Exfiltration", 1, {
		[ObjectiveIds.RestoreFloodlights] = { engineer },
	})
	applyResult(engineerState, floodDone)
end
assert(engineerState[ObjectiveIds.RestoreFloodlights].completed == true, "engineer completes the repair")
assert(floodDone.unlockedExtraction == false, "optional objective never unlocks extraction")

-- 5. Bounded sample: a huge delta commits at most one authored step.
local hitchState = freshState()
local hitch = sample(hitchState, "Infiltration", 100, { [ObjectiveIds.RestoreRelay] = { worker } })
for _, update in hitch.updates do
	if update.objectiveId == ObjectiveIds.RestoreRelay then
		assert(update.progress <= config.MaxSampleDeltaSeconds + 1e-6, "a long hitch cannot skip authored progress")
	end
end

-- 6. Trust surface: bad phase, stale revision, and invalid delta are rejected.
assert(sample(freshState(), "Insertion", 1, {}).rejectionReasonId == "InvalidPhase")
assert(sample(freshState(), "Resolved", 1, {}).rejectionReasonId == "InvalidPhase")
assert(sample(freshState(), "Infiltration", 1, {}, 5, 6).rejectionReasonId == "StaleRevision")
assert(sample(freshState(), "Infiltration", -1, {}).rejectionReasonId == "InvalidDelta")
assert(sample(freshState(), "Infiltration", 0 / 0, {}).rejectionReasonId == "InvalidDelta")

-- 7. Safe objective snapshot validation.
assert(contracts.validateSafeObjectiveSnapshot({
	objectiveId = ObjectiveIds.RestoreRelay,
	displayText = "Restore the emergency relay",
	stateId = "Active",
	progressRatio = 0.5,
	decaying = false,
	isOptional = false,
	destinationDisplayName = "Forest Service Lookout",
}))
assert(not contracts.validateSafeObjectiveSnapshot({
	objectiveId = ObjectiveIds.RestoreRelay,
	displayText = "x",
	stateId = "Nonsense",
	progressRatio = 0.5,
	decaying = false,
	isOptional = false,
	destinationDisplayName = "y",
}))
assert(not contracts.validateSafeObjectiveSnapshot({
	objectiveId = ObjectiveIds.RestoreRelay,
	displayText = "x",
	stateId = "Active",
	progressRatio = 1.5,
	decaying = false,
	isOptional = false,
	destinationDisplayName = "y",
}), "progress ratio outside 0..1 is rejected")

print("ObjectiveChainResolver: P8-0101/0102 contracts, authored chain, and pure progression passed")
