--!strict

local fs = require("@lune/fs")
local source = fs.readFile("games/living-kingdoms/src/server/expedition-live.server.luau")

local function has(text: string): boolean
	return string.find(source, text, 1, true) ~= nil
end

assert(has('game:GetService("ServerStorage")'), "diagnostic mount must remain in server storage")
assert(has('Instance.new("BindableFunction")'), "diagnostic mount must remain bindable")

local expected = {
	Start = "startExpedition",
	Stop = "stopExpedition",
	ReadSnapshot = "readSnapshot",
	ReadRoomPlan = "readRoomPlan",
	ReadRunVariationPlan = "readRunVariationPlan",
	ReadRunVariationEncounterView = "readRunVariationEncounterView",
	ReadRunVariationComposition = "readRunVariationComposition",
	ReadLastStartFailure = "readLastStartFailure",
}

for action, method in expected do
	assert(has('action == "' .. action .. '"'), "missing action " .. action)
	assert(has("ExpeditionLiveRuntimeService." .. method), "missing service binding " .. action)
end

print("Expedition debug action source audit passed")
