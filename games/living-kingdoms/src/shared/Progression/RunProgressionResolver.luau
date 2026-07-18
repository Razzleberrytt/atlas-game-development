--!strict

local RunProgressionConfig = require(script.Parent.Parent.Config.RunProgressionConfig)
local RunUpgradeContracts = require(script.Parent.RunUpgradeContracts)

type CombatModifiers = RunUpgradeContracts.CombatModifiers
type UpgradeId = RunUpgradeContracts.UpgradeId
type UpgradeOffer = RunUpgradeContracts.UpgradeOffer
type UpgradeStacks = RunUpgradeContracts.UpgradeStacks

export type AwardResult = {
	didApply: boolean,
	rejectionReasonId: string?,
	levelAfter: number,
	xpAfter: number,
	xpForNextLevel: number,
	levelsGained: number,
}

export type UpgradeSelectionResult = {
	didApply: boolean,
	rejectionReasonId: string?,
	stacksAfter: UpgradeStacks,
}

local RunProgressionResolver = {}

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function RunProgressionResolver.xpRequiredForLevel(level: number): number
	if not isFiniteNumber(level) or level % 1 ~= 0 or level < 1 or level >= RunProgressionConfig.MaximumRunLevel then
		return 0
	end
	return math.max(
		1,
		math.floor(RunProgressionConfig.BaseXpToLevel * (RunProgressionConfig.XpGrowthPerLevel ^ (level - 1)) + 0.5)
	)
end

local function awardResult(
	didApply: boolean,
	rejectionReasonId: string?,
	levelAfter: number,
	xpAfter: number,
	levelsGained: number
): AwardResult
	return table.freeze({
		didApply = didApply,
		rejectionReasonId = rejectionReasonId,
		levelAfter = levelAfter,
		xpAfter = xpAfter,
		xpForNextLevel = RunProgressionResolver.xpRequiredForLevel(levelAfter),
		levelsGained = levelsGained,
	}) :: AwardResult
end

function RunProgressionResolver.applyAward(levelBefore: number, xpBefore: number, awardAmount: number): AwardResult
	if
		not isFiniteNumber(levelBefore)
		or levelBefore % 1 ~= 0
		or levelBefore < 1
		or levelBefore > RunProgressionConfig.MaximumRunLevel
		or not isFiniteNumber(xpBefore)
		or xpBefore < 0
		or xpBefore % 1 ~= 0
		or not isFiniteNumber(awardAmount)
		or awardAmount <= 0
		or awardAmount % 1 ~= 0
	then
		return awardResult(false, "InvalidProgressionFacts", levelBefore, xpBefore, 0)
	end

	local requiredBefore = RunProgressionResolver.xpRequiredForLevel(levelBefore)
	if levelBefore < RunProgressionConfig.MaximumRunLevel and xpBefore >= requiredBefore then
		return awardResult(false, "InvalidProgressionFacts", levelBefore, xpBefore, 0)
	end
	if levelBefore == RunProgressionConfig.MaximumRunLevel then
		return awardResult(true, nil, levelBefore, 0, 0)
	end

	local levelAfter = levelBefore
	local xpAfter = xpBefore + awardAmount
	local levelsGained = 0
	while levelAfter < RunProgressionConfig.MaximumRunLevel do
		local required = RunProgressionResolver.xpRequiredForLevel(levelAfter)
		if required <= 0 or xpAfter < required then
			break
		end
		xpAfter -= required
		levelAfter += 1
		levelsGained += 1
	end
	if levelAfter >= RunProgressionConfig.MaximumRunLevel then
		xpAfter = 0
	end

	return awardResult(true, nil, levelAfter, xpAfter, levelsGained)
end

function RunProgressionResolver.createUpgradeStacks(): UpgradeStacks
	return {
		[RunUpgradeContracts.UpgradeIds.BallisticCalibration] = 0,
		[RunUpgradeContracts.UpgradeIds.RapidCycling] = 0,
		[RunUpgradeContracts.UpgradeIds.QuickHands] = 0,
	}
end

function RunProgressionResolver.createUpgradeOffer(level: number, offerSequence: number): UpgradeOffer?
	if
		not isFiniteNumber(level)
		or level % 1 ~= 0
		or level < 2
		or level > RunProgressionConfig.MaximumRunLevel
		or not isFiniteNumber(offerSequence)
		or offerSequence % 1 ~= 0
		or offerSequence < 1
	then
		return nil
	end
	local source = RunProgressionConfig.UpgradeOrder
	local offset = (level + offerSequence - 3) % #source
	local upgradeIds: { UpgradeId } = {}
	for index = 1, #source do
		local sourceIndex = ((index + offset - 1) % #source) + 1
		table.insert(upgradeIds, source[sourceIndex] :: UpgradeId)
	end
	return table.freeze({
		offerId = string.format("squad-run-upgrade:%d:%d", level, offerSequence),
		upgradeIds = table.freeze(upgradeIds),
	}) :: UpgradeOffer
end

function RunProgressionResolver.applyUpgradeSelection(
	stacksBefore: UpgradeStacks,
	offer: UpgradeOffer?,
	offerId: string,
	upgradeId: UpgradeId
): UpgradeSelectionResult
	local stacksAfter = table.clone(stacksBefore)
	if not RunUpgradeContracts.validateStacks(stacksAfter, RunProgressionConfig.MaximumUpgradeStacks) then
		return table.freeze({
			didApply = false,
			rejectionReasonId = "InvalidUpgradeState",
			stacksAfter = table.freeze(stacksAfter),
		}) :: UpgradeSelectionResult
	end
	if offer == nil then
		return table.freeze({
			didApply = false,
			rejectionReasonId = "NoPendingOffer",
			stacksAfter = table.freeze(stacksAfter),
		}) :: UpgradeSelectionResult
	end
	if offer.offerId ~= offerId then
		return table.freeze({
			didApply = false,
			rejectionReasonId = "OfferMismatch",
			stacksAfter = table.freeze(stacksAfter),
		}) :: UpgradeSelectionResult
	end
	if not RunUpgradeContracts.isUpgradeId(upgradeId) or table.find(offer.upgradeIds, upgradeId) == nil then
		return table.freeze({
			didApply = false,
			rejectionReasonId = "UpgradeNotOffered",
			stacksAfter = table.freeze(stacksAfter),
		}) :: UpgradeSelectionResult
	end
	local currentStacks = stacksAfter[upgradeId]
	if currentStacks == nil or currentStacks >= RunProgressionConfig.MaximumUpgradeStacks then
		return table.freeze({
			didApply = false,
			rejectionReasonId = "UpgradeAtMaximum",
			stacksAfter = table.freeze(stacksAfter),
		}) :: UpgradeSelectionResult
	end
	stacksAfter[upgradeId] = currentStacks + 1
	return table.freeze({
		didApply = true,
		rejectionReasonId = nil,
		stacksAfter = table.freeze(stacksAfter),
	}) :: UpgradeSelectionResult
end

function RunProgressionResolver.deriveCombatModifiers(stacks: UpgradeStacks): CombatModifiers
	if not RunUpgradeContracts.validateStacks(stacks, RunProgressionConfig.MaximumUpgradeStacks) then
		return table.freeze({
			damageBonus = 0,
			cadenceMultiplier = 1,
			reloadMultiplier = 1,
		}) :: CombatModifiers
	end
	local damageStacks = stacks[RunUpgradeContracts.UpgradeIds.BallisticCalibration]
	local cadenceStacks = stacks[RunUpgradeContracts.UpgradeIds.RapidCycling]
	local reloadStacks = stacks[RunUpgradeContracts.UpgradeIds.QuickHands]
	return table.freeze({
		damageBonus = damageStacks * RunProgressionConfig.DamageBonusPerStack,
		cadenceMultiplier = math.max(
			RunProgressionConfig.MinimumCadenceMultiplier,
			RunProgressionConfig.CadenceMultiplierPerStack ^ cadenceStacks
		),
		reloadMultiplier = math.max(
			RunProgressionConfig.MinimumReloadMultiplier,
			RunProgressionConfig.ReloadMultiplierPerStack ^ reloadStacks
		),
	}) :: CombatModifiers
end

return table.freeze(RunProgressionResolver)
