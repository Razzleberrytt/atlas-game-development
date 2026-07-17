--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Visual/EnemyPresentationContracts.luau"), {
	debugName = "EnemyPresentationContracts",
	injectGlobals = true,
})()

local expected = {
	"EnemyPresentationBehaviorStateId",
	"EnemyPresentationLifeStateId",
	"EnemyPresentationAttackSequence",
	"EnemyPresentationAttackServerTimestamp",
	"EnemyPresentationHitSequence",
	"EnemyPresentationHitServerTimestamp",
}
local observed = {}
for _, attributeName in contracts.AttributeNames do
	assertThat(type(attributeName) == "string" and attributeName ~= "", "attribute names must be non-empty strings")
	assertThat(not observed[attributeName], "presentation attribute names must be unique")
	observed[attributeName] = true
end
for _, attributeName in expected do
	assertThat(observed[attributeName] == true, "missing presentation attribute " .. attributeName)
end
assertThat(contracts.LifeStateIds.Alive == "Alive" and contracts.LifeStateIds.Dead == "Dead", "life IDs drifted")

local mutationSucceeded = pcall(function()
	contracts.AttributeNames.AttackSequence = "mutated"
end)
assertThat(not mutationSucceeded, "presentation contracts must be immutable")

print("EnemyPresentationContracts: six unique immutable disclosure attributes passed")
