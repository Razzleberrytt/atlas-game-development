--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "HROI-0105 run progression resolver assertion failed", 2)
	end
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/RunProgressionConfig.luau"), {
	debugName = "RunProgressionConfig",
	injectGlobals = true,
})()
local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Progression/RunUpgradeContracts.luau"), {
	debugName = "RunUpgradeContracts",
	injectGlobals = true,
})()

local CONFIG_TOKEN = {}
local CONTRACTS_TOKEN = {}
local resolver = luau.load(
	fs.readFile("games/living-kingdoms/src/shared/Progression/RunProgressionResolver.luau"),
	{
		debugName = "RunProgressionResolver",
		environment = {
			script = {
				Parent = {
					RunUpgradeContracts = CONTRACTS_TOKEN,
					Parent = {
						Config = { RunProgressionConfig = CONFIG_TOKEN },
					},
				},
			},
			require = function(token: unknown)
				if token == CONFIG_TOKEN then
					return config
				elseif token == CONTRACTS_TOKEN then
					return contracts
				end
				error("unexpected progression resolver dependency")
			end,
		},
		injectGlobals = true,
	}
)()

assert(config.FieldXpPerConfirmedEnemyDeath == 20, "one confirmed death should award the prototype 20 Field XP")
assert(resolver.xpRequiredForLevel(1) == 100, "the first run level should require 100 XP")
assert(resolver.xpRequiredForLevel(2) == 130, "the second threshold should grow gradually")
assert(resolver.xpRequiredForLevel(config.MaximumRunLevel) == 0, "maximum level has no next threshold")

local oneKill = resolver.applyAward(1, 0, config.FieldXpPerConfirmedEnemyDeath)
assert(oneKill.didApply and oneKill.levelAfter == 1 and oneKill.xpAfter == 20)
assert(oneKill.levelsGained == 0 and oneKill.xpForNextLevel == 100)
assert(table.isfrozen(oneKill), "award results must be immutable")

local firstLevel = resolver.applyAward(1, 80, config.FieldXpPerConfirmedEnemyDeath)
assert(firstLevel.didApply and firstLevel.levelAfter == 2 and firstLevel.xpAfter == 0)
assert(firstLevel.levelsGained == 1 and firstLevel.xpForNextLevel == 130)

local multipleLevels = resolver.applyAward(1, 90, 150)
assert(multipleLevels.didApply and multipleLevels.levelAfter == 3 and multipleLevels.xpAfter == 10)
assert(multipleLevels.levelsGained == 2)

local invalid = resolver.applyAward(1, 0, 0)
assert(not invalid.didApply and invalid.rejectionReasonId == "InvalidProgressionFacts")

local maximum = resolver.applyAward(1, 0, 100000000)
assert(maximum.didApply and maximum.levelAfter == config.MaximumRunLevel)
assert(maximum.xpAfter == 0 and maximum.xpForNextLevel == 0)

local stacks = resolver.createUpgradeStacks()
assert(contracts.validateStacks(stacks, config.MaximumUpgradeStacks))
local baselineModifiers = resolver.deriveCombatModifiers(stacks)
assert(baselineModifiers.damageBonus == 0)
assert(baselineModifiers.cadenceMultiplier == 1)
assert(baselineModifiers.reloadMultiplier == 1)
assert(table.isfrozen(baselineModifiers))

local offer = resolver.createUpgradeOffer(2, 1)
assert(offer ~= nil and contracts.validateOffer(offer))
assert(table.isfrozen(offer) and table.isfrozen(offer.upgradeIds))
local seen = {}
for _, upgradeId in offer.upgradeIds do
	assert(not seen[upgradeId], "upgrade offers must contain three unique choices")
	seen[upgradeId] = true
end

local wrongOffer = resolver.applyUpgradeSelection(
	stacks,
	offer,
	"wrong-offer",
	contracts.UpgradeIds.BallisticCalibration
)
assert(not wrongOffer.didApply and wrongOffer.rejectionReasonId == "OfferMismatch")

local damageSelection = resolver.applyUpgradeSelection(
	stacks,
	offer,
	offer.offerId,
	contracts.UpgradeIds.BallisticCalibration
)
assert(damageSelection.didApply and damageSelection.rejectionReasonId == nil)
assert(damageSelection.stacksAfter[contracts.UpgradeIds.BallisticCalibration] == 1)
assert(stacks[contracts.UpgradeIds.BallisticCalibration] == 0, "selection must not mutate caller stacks")
local damageModifiers = resolver.deriveCombatModifiers(damageSelection.stacksAfter)
assert(damageModifiers.damageBonus == config.DamageBonusPerStack)
assert(damageModifiers.cadenceMultiplier == 1 and damageModifiers.reloadMultiplier == 1)

local cadenceSelection = resolver.applyUpgradeSelection(
	damageSelection.stacksAfter,
	resolver.createUpgradeOffer(3, 2),
	"squad-run-upgrade:3:2",
	contracts.UpgradeIds.RapidCycling
)
assert(cadenceSelection.didApply)
local cadenceModifiers = resolver.deriveCombatModifiers(cadenceSelection.stacksAfter)
assert(math.abs(cadenceModifiers.cadenceMultiplier - config.CadenceMultiplierPerStack) < 1e-12)

local reloadSelection = resolver.applyUpgradeSelection(
	cadenceSelection.stacksAfter,
	resolver.createUpgradeOffer(4, 3),
	"squad-run-upgrade:4:3",
	contracts.UpgradeIds.QuickHands
)
assert(reloadSelection.didApply)
local allModifiers = resolver.deriveCombatModifiers(reloadSelection.stacksAfter)
assert(math.abs(allModifiers.reloadMultiplier - config.ReloadMultiplierPerStack) < 1e-12)
assert(contracts.validateModifiers(allModifiers))

assert(contracts.validateSelectionIntent({
	requestId = "selection:1",
	offerId = offer.offerId,
	upgradeId = contracts.UpgradeIds.BallisticCalibration,
}))
assert(not contracts.validateSelectionIntent({
	requestId = "selection:1",
	offerId = offer.offerId,
	upgradeId = contracts.UpgradeIds.BallisticCalibration,
	forgedXp = 999,
}))

print("RunProgressionResolver: XP, offers, selection validation, stacks, and modifiers passed")
