--!strict

-- Development-only Ticket 138 probe. This is intentionally not mounted to any
-- production remote. Studio/test harnesses may call run() and capture the result.

local EquipmentRewardService = require(script.Parent.EquipmentRewardService)

local Probe = {}

local REPEAT_COUNT = 100
local DISTINCT_CONTEXT_COUNT = 5_000

local function assertReward(result: any): any
	assert(result.Accepted == true, "reward claim must be accepted")
	assert(result.Reward ~= nil, "accepted reward must exist")
	return result.Reward
end

function Probe.run(): any
	local repeatedSignature: string? = nil
	local repeatedInstanceIds: { [string]: boolean } = {}

	for ordinal = 1, REPEAT_COUNT do
		local service = EquipmentRewardService.new("ticket138:repeat", 12345)
		local reward = assertReward(service:claimReward("Boss"))
		if repeatedSignature == nil then
			repeatedSignature = reward.ContentSignature
		else
			assert(reward.ContentSignature == repeatedSignature, "same context changed content signature")
		end
		assert(not repeatedInstanceIds[reward.InstanceId], "same context reused an instance ID")
		repeatedInstanceIds[reward.InstanceId] = true
		service:destroy()
	end

	local distinctInstanceIds: { [string]: boolean } = {}
	local signatureCounts: { [string]: number } = {}
	for seed = 1, DISTINCT_CONTEXT_COUNT do
		local sourceId = if seed % 2 == 0 then "Elite" else "Boss"
		local service = EquipmentRewardService.new(string.format("ticket138:%08d", seed), seed)
		local reward = assertReward(service:claimReward(sourceId))
		assert(not distinctInstanceIds[reward.InstanceId], "distinct contexts reused an instance ID")
		distinctInstanceIds[reward.InstanceId] = true
		signatureCounts[reward.ContentSignature] = (signatureCounts[reward.ContentSignature] or 0) + 1
		service:destroy()
	end

	local distinctSignatureCount = 0
	for _ in signatureCounts do
		distinctSignatureCount += 1
	end
	assert(distinctSignatureCount > 1, "distinct contexts produced no content variation")

	return table.freeze({
		RepeatedContexts = REPEAT_COUNT,
		DistinctContexts = DISTINCT_CONTEXT_COUNT,
		RepeatedContentSignature = repeatedSignature,
		UniqueRepeatedInstanceIds = REPEAT_COUNT,
		UniqueDistinctInstanceIds = DISTINCT_CONTEXT_COUNT,
		DistinctContentSignatures = distinctSignatureCount,
	})
end

return table.freeze(Probe)
