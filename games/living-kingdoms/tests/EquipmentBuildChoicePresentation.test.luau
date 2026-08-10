--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "build-choice presentation assertion failed", 2)
	end
end

local Presentation =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Equipment/EquipmentBuildChoicePresentation.luau"), {
		debugName = "EquipmentBuildChoicePresentation",
		injectGlobals = true,
	})()

local affixes = {
	{ EffectId = "ReloadSpeedPercent", Value = 8 },
	{ EffectId = "DamagePercent", Value = 5 },
}
assert(Presentation.formatAffixes(affixes) == "DMG +5% • RELOAD +8%", "affix facts are compact and stable")
assert(Presentation.formatAffixes({}) == "NO AFFIXES", "empty affix lists remain explicit")

local deltas = {
	{ EffectId = "MoveSpeedPercent", CandidateValue = 3, IncumbentValue = 0, Delta = 3 },
	{ EffectId = "DamagePercent", CandidateValue = 0, IncumbentValue = 5, Delta = -5 },
}
assert(
	Presentation.formatAffixDeltas(deltas) == "DMG -5% • MOVE +3%",
	"tradeoff deltas state gains and losses without choosing a build"
)
assert(Presentation.formatAffixDeltas({}) == "NO AFFIX CHANGE", "unchanged affix facts remain explicit")

assert(
	Presentation.formatVerdict({ VerdictId = "Upgrade", PowerDelta = 3, RarityDelta = 1, FillsEmptySlot = false })
		== "↑ +3P",
	"power improvement is compact"
)
assert(
	Presentation.formatVerdict({ VerdictId = "Downgrade", PowerDelta = -2, RarityDelta = 0, FillsEmptySlot = false })
		== "↓ -2P",
	"power loss is compact"
)
assert(
	Presentation.formatVerdict({ VerdictId = "Sidegrade", PowerDelta = 0, RarityDelta = 1, FillsEmptySlot = false })
		== "↔",
	"mixed/equal tradeoffs are not mislabeled as upgrades"
)
assert(
	Presentation.formatVerdict({ VerdictId = "Upgrade", PowerDelta = 0, RarityDelta = 0, FillsEmptySlot = true })
		== "↑ NEW",
	"empty-slot additions are explicit"
)

print("EquipmentBuildChoicePresentation fixture passed")
