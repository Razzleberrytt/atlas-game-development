--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local resolver =
	luau.load(fs.readFile("games/living-kingdoms/src/client/Presentation/MissionObjectPresentationResolver.luau"), {
		debugName = "MissionObjectPresentationResolver",
		injectGlobals = true,
	})()

local function resolve(phaseId: unknown, objectiveStateId: unknown, extractionUnlocked: unknown, outcomeId: unknown)
	return resolver.resolve({
		phaseId = phaseId,
		objectiveStateId = objectiveStateId,
		extractionUnlocked = extractionUnlocked,
		outcomeId = outcomeId,
	})
end

local insertion = resolve("Insertion", "Inactive", false, nil)
assertThat(insertion.relay.stateId == "Standby", "insertion must show relay standby")
assertThat(insertion.relay.labelText == "RELAY STANDBY", "standby label drifted")
assertThat(insertion.extraction.stateId == "Hidden", "locked extraction must remain hidden")

local infiltration = resolve("Infiltration", "Active", false, nil)
assertThat(infiltration.relay.stateId == "Active", "infiltration must show active relay")
assertThat(infiltration.relay.labelText == "RESTORE RELAY", "active relay label drifted")

local exfiltration = resolve("Exfiltration", "Completed", true, nil)
assertThat(exfiltration.relay.stateId == "Completed", "completed relay must remain online")
assertThat(exfiltration.extraction.stateId == "Open", "exfiltration must show open extraction")
assertThat(exfiltration.extraction.labelText == "EXTRACTION OPEN", "open extraction label drifted")

local holdout = resolve("Holdout", "Completed", true, nil)
assertThat(holdout.extraction.stateId == "Holdout", "holdout must have distinct extraction state")
assertThat(holdout.extraction.labelText == "HOLD POSITION", "holdout label drifted")

local success = resolve("Resolved", "Completed", true, "Success")
assertThat(success.extraction.stateId == "Success", "success must be disclosed at extraction")
assertThat(success.extraction.labelText == "EXTRACTED", "success label drifted")

local failure = resolve("Resolved", "Completed", true, "Failure")
assertThat(failure.extraction.stateId == "Failure", "failure must be disclosed at extraction")
assertThat(failure.extraction.labelText == "EXTRACTION LOST", "failure label drifted")

for _, inconsistent in
	{
		resolve("Insertion", "Active", false, nil),
		resolve("Infiltration", "Completed", false, nil),
		resolve("Holdout", "Completed", false, nil),
		resolve("Resolved", "Completed", true, nil),
		resolve("Unknown", "Unknown", true, "Success"),
	}
do
	if inconsistent.relay.stateId ~= "Completed" then
		assertThat(
			inconsistent.relay.stateId == "Hidden",
			"inconsistent relay facts must not fabricate a visible state"
		)
	end
	assertThat(
		inconsistent.extraction.stateId == "Hidden",
		"inconsistent extraction facts must not fabricate a visible state"
	)
end

local frozen = resolve("Exfiltration", "Completed", true, nil)
local didMutate = pcall(function()
	frozen.relay.stateId = "Hidden"
end)
assertThat(not didMutate, "resolver output must remain immutable")

print("MissionObjectPresentationResolver: authoritative state mapping and malformed-fact rejection passed")
