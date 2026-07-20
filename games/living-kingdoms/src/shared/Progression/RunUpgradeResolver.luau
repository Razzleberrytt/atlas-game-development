--!strict

local RunProgressionConfig = require(script.Parent.Parent.Config.RunProgressionConfig)

export type UpgradeStacks = { [string]: number }

export type CombatModifiers = {
	damageMultiplier: number,
	cadenceMultiplier: number,
	ammoConservationChance: number,
	cullDamageMultiplier: number,
	cullHealthThreshold: number,
	incomingDamageMultiplier: number,
	xpGainMultiplier: number,
	reloadDurationMultiplier: number,
	patternDamageMultiplier: number,
}

export type ChoiceResolution = {
	didApply: boolean,
	rejectionReasonId: string?,
	upgradeId: string?,
	stackAfter: number,
	stacksAfter: UpgradeStacks,
}

local RunUpgradeResolver = {}

local definitionsById: { [string]: any } = {}
for _, definition in RunProgressionConfig.UpgradeDefinitions do
	definitionsById[definition.Id] = definition
end

local function copyStacks(stacks: UpgradeStacks): UpgradeStacks
	return table.clone(stacks)
end

local function isValidStackCount(value: unknown): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and value >= 0 and value <= 4
end

local function validateStacks(stacks: UpgradeStacks): boolean
	if type(stacks) ~= "table" then
		return false
	end
	for upgradeId, count in stacks do
		local definition = definitionsById[upgradeId]
		if definition == nil or not isValidStackCount(count) or count > definition.MaximumStacks then
			return false
		end
	end
	return true
end

function RunUpgradeResolver.generateChoices(
	stacks: UpgradeStacks,
	offerSequence: number,
	squadKills: number
): { string }
	if
		not validateStacks(stacks)
		or type(offerSequence) ~= "number"
		or offerSequence ~= offerSequence
		or offerSequence % 1 ~= 0
		or offerSequence < 1
		or type(squadKills) ~= "number"
		or squadKills ~= squadKills
		or squadKills % 1 ~= 0
		or squadKills < 0
	then
		return table.freeze({})
	end

	local eligible = {}
	for _, definition in RunProgressionConfig.UpgradeDefinitions do
		if (stacks[definition.Id] or 0) < definition.MaximumStacks then
			table.insert(eligible, definition.Id)
		end
	end
	if #eligible == 0 then
		return table.freeze({})
	end

	local count = math.min(RunProgressionConfig.UpgradeChoiceCount, #eligible)
	local offset = ((offerSequence * 5 + squadKills * 3) % #eligible) + 1
	local choices = {}
	for index = 0, count - 1 do
		local eligibleIndex = ((offset + index - 1) % #eligible) + 1
		table.insert(choices, eligible[eligibleIndex])
	end
	return table.freeze(choices)
end

function RunUpgradeResolver.applyChoice(
	stacks: UpgradeStacks,
	pendingChoiceIds: { string },
	selectedUpgradeId: string
): ChoiceResolution
	local stacksAfter = copyStacks(stacks)
	if not validateStacks(stacks) or type(pendingChoiceIds) ~= "table" or type(selectedUpgradeId) ~= "string" then
		return table.freeze({
			didApply = false,
			rejectionReasonId = "InvalidUpgradeFacts",
			upgradeId = nil,
			stackAfter = 0,
			stacksAfter = table.freeze(stacksAfter),
		})
	end

	local wasOffered = false
	for _, upgradeId in pendingChoiceIds do
		if upgradeId == selectedUpgradeId then
			wasOffered = true
			break
		end
	end
	if not wasOffered then
		return table.freeze({
			didApply = false,
			rejectionReasonId = "UpgradeNotOffered",
			upgradeId = nil,
			stackAfter = 0,
			stacksAfter = table.freeze(stacksAfter),
		})
	end

	local definition = definitionsById[selectedUpgradeId]
	local stackBefore = stacks[selectedUpgradeId] or 0
	if definition == nil or stackBefore >= definition.MaximumStacks then
		return table.freeze({
			didApply = false,
			rejectionReasonId = "UpgradeAtMaximumStacks",
			upgradeId = nil,
			stackAfter = stackBefore,
			stacksAfter = table.freeze(stacksAfter),
		})
	end

	local stackAfter = stackBefore + 1
	stacksAfter[selectedUpgradeId] = stackAfter
	return table.freeze({
		didApply = true,
		rejectionReasonId = nil,
		upgradeId = selectedUpgradeId,
		stackAfter = stackAfter,
		stacksAfter = table.freeze(stacksAfter),
	})
end

function RunUpgradeResolver.deriveCombatModifiers(stacks: UpgradeStacks): CombatModifiers
	if not validateStacks(stacks) then
		return table.freeze({
			damageMultiplier = 1,
			cadenceMultiplier = 1,
			ammoConservationChance = 0,
			cullDamageMultiplier = 1,
			cullHealthThreshold = RunProgressionConfig.CullHealthThreshold,
			incomingDamageMultiplier = 1,
			xpGainMultiplier = 1,
			reloadDurationMultiplier = 1,
			patternDamageMultiplier = 1,
		})
	end

	local damageMultiplier = 1
	local cadenceMultiplier = 1
	local ammoConservationChance = 0
	local cullDamageMultiplier = 1
	local incomingDamageReduction = 0
	local xpGainBonus = 0
	local reloadDurationReduction = 0
	local patternDamageBonus = 0
	for _, definition in RunProgressionConfig.UpgradeDefinitions do
		local stackCount = stacks[definition.Id] or 0
		if definition.DamageMultiplierPerStack ~= nil then
			damageMultiplier += stackCount * definition.DamageMultiplierPerStack
		end
		if definition.CadenceReductionPerStack ~= nil then
			cadenceMultiplier -= stackCount * definition.CadenceReductionPerStack
		end
		if definition.AmmoConservationChancePerStack ~= nil then
			ammoConservationChance += stackCount * definition.AmmoConservationChancePerStack
		end
		if definition.CullDamageMultiplierPerStack ~= nil then
			cullDamageMultiplier += stackCount * definition.CullDamageMultiplierPerStack
		end
		if definition.IncomingDamageReductionPerStack ~= nil then
			incomingDamageReduction += stackCount * definition.IncomingDamageReductionPerStack
		end
		if definition.XpGainMultiplierPerStack ~= nil then
			xpGainBonus += stackCount * definition.XpGainMultiplierPerStack
		end
		if definition.ReloadDurationReductionPerStack ~= nil then
			reloadDurationReduction += stackCount * definition.ReloadDurationReductionPerStack
		end
		if definition.PatternDamageMultiplierPerStack ~= nil then
			patternDamageBonus += stackCount * definition.PatternDamageMultiplierPerStack
		end
	end

	local boundedReduction = math.clamp(incomingDamageReduction, 0, RunProgressionConfig.MaximumIncomingDamageReduction)
	return table.freeze({
		damageMultiplier = math.clamp(damageMultiplier, 1, RunProgressionConfig.MaximumDamageMultiplier),
		cadenceMultiplier = math.max(RunProgressionConfig.MinimumCadenceMultiplier, cadenceMultiplier),
		ammoConservationChance = math.clamp(
			ammoConservationChance,
			0,
			RunProgressionConfig.MaximumAmmoConservationChance
		),
		cullDamageMultiplier = math.clamp(cullDamageMultiplier, 1, RunProgressionConfig.MaximumDamageMultiplier),
		cullHealthThreshold = RunProgressionConfig.CullHealthThreshold,
		incomingDamageMultiplier = 1 - boundedReduction,
		xpGainMultiplier = math.clamp(1 + xpGainBonus, 1, RunProgressionConfig.MaximumXpGainMultiplier),
		reloadDurationMultiplier = math.max(
			RunProgressionConfig.MinimumReloadDurationMultiplier,
			1 - reloadDurationReduction
		),
		patternDamageMultiplier = math.clamp(
			1 + patternDamageBonus,
			1,
			RunProgressionConfig.MaximumPatternDamageMultiplier
		),
	})
end

function RunUpgradeResolver.readDefinition(upgradeId: string): any?
	return definitionsById[upgradeId]
end

return table.freeze(RunUpgradeResolver)
