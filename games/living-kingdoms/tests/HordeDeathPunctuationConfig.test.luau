--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local source = fs.readFile("games/living-kingdoms/src/shared/Config/HordeDeathPunctuationConfig.luau")
local config = luau.load(source, {
	debugName = "HordeDeathPunctuationConfig",
	injectGlobals = true,
})()

local expectedTitles = {
	[config.KindIds.Screamer] = "CHOIR SILENCED",
	[config.KindIds.ScreamerInterrupted] = "SUMMON INTERRUPTED",
	[config.KindIds.Bloater] = "ROT BURST ARMED",
	[config.KindIds.BrutePhaseOne] = "BRUTE PHASE BROKEN",
	[config.KindIds.BruteFinal] = "BRUTE ERADICATED",
}

for kindId, expectedTitle in expectedTitles do
	local definition = config.get(kindId)
	assert(definition ~= nil, kindId .. " definition is missing")
	assert(definition.Title == expectedTitle, kindId .. " title drifted")
	assert(#definition.Color == 3, kindId .. " text color is not RGB")
	assert(#definition.BloodColor == 3, kindId .. " blood color is not RGB")
	assert(definition.BloodDiameterStuds >= 5 and definition.BloodDiameterStuds <= 10, kindId .. " pool is unbounded")
	assert(
		definition.ShakeMagnitude > config.GenericShakeMagnitude
			and definition.ShakeMagnitude <= config.MaximumShakeMagnitude,
		kindId .. " shake magnitude is unbounded"
	)
	assert(
		definition.BillboardLifetimeSeconds >= config.GenericBillboardLifetimeSeconds
			and definition.BillboardLifetimeSeconds <= 2,
		kindId .. " billboard lifetime is unbounded"
	)
end

local firstBrute = config.get(config.KindIds.BrutePhaseOne)
local finalBrute = config.get(config.KindIds.BruteFinal)
assert(firstBrute ~= nil and finalBrute ~= nil, "both Brute phases require punctuation")
assert(finalBrute.ShakeMagnitude > firstBrute.ShakeMagnitude, "final Brute death must punctuate more strongly")
assert(finalBrute.BloodDiameterStuds > firstBrute.BloodDiameterStuds, "final Brute pool must be visually distinct")
assert(config.BruteFinalEntityMarker == "brute-phase2", "final Brute marker must match the authoritative spawn prefix")
assert(config.get("Unknown") == nil, "unknown punctuation kind must fail closed")
assert(config.get(nil) == nil, "missing punctuation kind must fail closed")

print("HordeDeathPunctuationConfig: special copy, bounded intensity, and final Brute escalation passed")
