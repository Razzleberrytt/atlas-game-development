--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/CharacterStatConfig.luau"), {
	debugName = "CharacterStatConfig",
	injectGlobals = true,
})()
local resolver = luau.load(fs.readFile("games/living-kingdoms/src/shared/Progression/CharacterBuildResolver.luau"), {
	debugName = "CharacterBuildResolver",
	injectGlobals = true,
})()

local initial = resolver.defaultState(config)
assertThat(initial ~= nil, "valid stat config must create a default build")
assertThat(resolver.totalEarnedAttributePoints(1, config) == 0, "level one must begin with no unearned build points")
assertThat(resolver.totalEarnedAttributePoints(11, config) == 10, "every crossed level must earn a stat point")

local multi = resolver.summarizeLevelRewards(7, 11, config)
assertThat(multi ~= nil and multi.LevelsCrossed == 4, "7 to 11 must represent four crossed levels")
assertThat(multi ~= nil and multi.AttributePointsAwarded == 4, "7 to 11 must cumulatively award four attribute points")
assertThat(multi ~= nil and multi.PerkPointsAwarded == 1, "configured perk interval must be counted across multi-level gains")

local allocated = resolver.allocate(initial, 11, config.AttributeIds.Power, 4, config)
assertThat(allocated.Accepted == true, "valid allocation within earned points must succeed")
assertThat(allocated.State.AllocatedAttributes.Power == 4, "successful allocation must update only the requested attribute")
assertThat(allocated.AvailableAttributePoints == 6, "allocation must consume available earned points")

local second = resolver.allocate(allocated.State, 11, config.AttributeIds.Vitality, 6, config)
assertThat(second.Accepted == true and second.AvailableAttributePoints == 0, "remaining earned points must be allocatable")
local insufficient = resolver.allocate(second.State, 11, config.AttributeIds.Agility, 1, config)
assertThat(insufficient.Accepted == false and insufficient.ReasonId == "InsufficientAttributePoints", "overspending earned points must reject")

for _, invalidAmount in { -1, 0, 1.5, math.huge, 0 / 0, "1" } do
	local rejected = resolver.allocate(initial, 11, config.AttributeIds.Power, invalidAmount, config)
	assertThat(rejected.Accepted == false and rejected.ReasonId == "InvalidAmount", "invalid allocation amount must reject")
end
local invalidAttribute = resolver.allocate(initial, 11, "Luck", 1, config)
assertThat(invalidAttribute.Accepted == false and invalidAttribute.ReasonId == "InvalidAttribute", "unknown attribute names must reject")

local capAttempt = resolver.allocate(initial, 100, config.AttributeIds.Power, 31, config)
assertThat(capAttempt.Accepted == false and capAttempt.ReasonId == "AttributeCapReached", "individual attributes must enforce their configured cap")

local respecced = resolver.respec(second.State, 11, config)
assertThat(respecced.Accepted == true and respecced.RefundedAttributePoints == 10, "respec must refund all allocated points")
assertThat(respecced.State.AllocatedAttributes.Power == 0 and respecced.State.AllocatedAttributes.Vitality == 0, "respec must clear allocations")
assertThat(respecced.AvailableAttributePoints == 10, "respec must restore all earned allocation capacity")

local modifiers = resolver.progressionModifiers(second.State, 11, config)
assertThat(modifiers ~= nil and #modifiers == 3, "level scaling plus allocated attributes must emit compact canonical modifiers")
local modifiersAgain = resolver.progressionModifiers(second.State, 11, config)
assertThat(modifiersAgain ~= nil and #modifiersAgain == #modifiers, "progression modifier generation must be deterministic")
for index, modifier in modifiers do
	assertThat(modifiersAgain[index].SourceId == modifier.SourceId, "deterministic modifiers must preserve source ordering")
	assertThat(modifiersAgain[index].Value == modifier.Value, "deterministic modifiers must preserve values")
end

local malformed = resolver.normalizeState({ AllocatedAttributes = { Power = -10, Vitality = "oops" } }, config)
assertThat(malformed ~= nil and malformed.RecoveredState == true, "malformed persisted allocations must fail closed into a recovered build")
assertThat(malformed.AllocatedAttributes.Power == 0 and malformed.AllocatedAttributes.Vitality == 0, "recovered allocations must never preserve invalid points")

print("CharacterBuildResolver: level rewards, multi-level grants, allocation validation, caps, respec, and deterministic modifiers passed")
