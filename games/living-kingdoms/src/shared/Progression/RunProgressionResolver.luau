--!strict

local RunProgressionConfig = require(script.Parent.Parent.Config.RunProgressionConfig)

export type AwardResult = {
	didApply: boolean,
	rejectionReasonId: string?,
	levelAfter: number,
	xpAfter: number,
	xpForNextLevel: number,
	levelsGained: number,
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

local function result(
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
		return result(false, "InvalidProgressionFacts", levelBefore, xpBefore, 0)
	end

	local requiredBefore = RunProgressionResolver.xpRequiredForLevel(levelBefore)
	if levelBefore < RunProgressionConfig.MaximumRunLevel and xpBefore >= requiredBefore then
		return result(false, "InvalidProgressionFacts", levelBefore, xpBefore, 0)
	end
	if levelBefore == RunProgressionConfig.MaximumRunLevel then
		return result(true, nil, levelBefore, 0, 0)
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

	return result(true, nil, levelAfter, xpAfter, levelsGained)
end

return table.freeze(RunProgressionResolver)
