--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local resolver = luau.load(
	fs.readFile("games/living-kingdoms/src/client/Presentation/OperativeLifePresentationResolver.luau"),
	{ debugName = "OperativeLifePresentationResolver", injectGlobals = true }
)()

local function facts(overrides: { [string]: unknown }?): { [string]: unknown }
	local result: { [string]: unknown } = {
		operativeEntityId = "operative.player:1",
		lifeStateId = "Alive",
		soloRecoveryPending = false,
		reviveStatus = nil,
		reviveProgress = nil,
		reviveTargetOperativeEntityId = nil,
	}
	if overrides ~= nil then
		for key, value in overrides do
			result[key] = value
		end
	end
	return result
end

local hidden = resolver.resolve(facts())
assert(hidden.cueId == "Hidden" and hidden.markerKindId == "None" and hidden.labelText == "")

local downed = resolver.resolve(facts({ lifeStateId = "Incapacitated" }))
assert(downed.cueId == "Downed" and downed.markerKindId == "RescueCross" and downed.labelText == "DOWNED")

local reviving = resolver.resolve(facts({
	lifeStateId = "Incapacitated",
	reviveStatus = "Active",
	reviveProgress = 0.426,
	reviveTargetOperativeEntityId = "operative.player:1",
}))
assert(reviving.cueId == "Reviving" and reviving.labelText == "REVIVING 43%")
assert(reviving.normalizedProgress == 0.426)

local clampedLow = resolver.resolve(facts({
	lifeStateId = "Incapacitated",
	reviveStatus = "Active",
	reviveProgress = -4,
	reviveTargetOperativeEntityId = "operative.player:1",
}))
assert(clampedLow.normalizedProgress == 0 and clampedLow.labelText == "REVIVING 0%")

local clampedHigh = resolver.resolve(facts({
	lifeStateId = "Incapacitated",
	reviveStatus = "Active",
	reviveProgress = 4,
	reviveTargetOperativeEntityId = "operative.player:1",
}))
assert(clampedHigh.normalizedProgress == 1 and clampedHigh.labelText == "REVIVING 100%")

local wrongTarget = resolver.resolve(facts({
	lifeStateId = "Incapacitated",
	reviveStatus = "Active",
	reviveProgress = 0.5,
	reviveTargetOperativeEntityId = "operative.player:2",
}))
assert(wrongTarget.cueId == "Downed", "reviver disclosure must not masquerade as target progress")

local malformedProgress = resolver.resolve(facts({
	lifeStateId = "Incapacitated",
	reviveStatus = "Active",
	reviveProgress = 0 / 0,
	reviveTargetOperativeEntityId = "operative.player:1",
}))
assert(malformedProgress.cueId == "Downed", "malformed progress must fail to the truthful downed cue")

local solo = resolver.resolve(facts({
	lifeStateId = "Incapacitated",
	soloRecoveryPending = true,
	reviveStatus = "Active",
	reviveProgress = 0.8,
	reviveTargetOperativeEntityId = "operative.player:1",
}))
assert(solo.cueId == "SoloRecovery" and solo.markerKindId == "RecoveryChevron")
assert(solo.labelText == "SELF RECOVERY" and solo.normalizedProgress == nil)

local dead = resolver.resolve(facts({
	lifeStateId = "Dead",
	soloRecoveryPending = true,
	reviveStatus = "Active",
	reviveProgress = 0.9,
	reviveTargetOperativeEntityId = "operative.player:1",
}))
assert(dead.cueId == "Dead" and dead.markerKindId == "DeathX" and dead.labelText == "KIA")

local first = resolver.resolve(facts({ lifeStateId = "Incapacitated" }))
local second = resolver.resolve(facts({ lifeStateId = "Incapacitated" }))
assert(first.cueId == second.cueId and first.labelText == second.labelText)
local mutationSucceeded = pcall(function()
	first.cueId = "Dead"
end)
assert(not mutationSucceeded, "resolver outputs must remain immutable")

print(
	"OperativeLifePresentationResolver: hidden, downed, revive, solo recovery, death, precedence, and immutability passed"
)
