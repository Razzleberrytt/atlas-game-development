--!strict

--[[
	Patch 0.7 #89 durable record invariant checker.

	Every guard in the persistence layer prevents one bad transition. This
	answers a different question: given a record that already exists, is it
	self-consistent right now? That is what catches damage introduced by
	something no guard covered -- a partial write, a hand-edited key, a bug in a
	future migration step.

	It is deliberately a pure reader. Finding a broken record is not licence to
	repair it: a repair that guessed would destroy the evidence needed to do the
	repair properly.
]]

export type Violation = {
	Code: string,
	Detail: string,
}

export type InvariantReport = {
	Healthy: boolean,
	Violations: { Violation },
	ItemCount: number,
	EquippedCount: number,
}

local InventoryInvariantChecker = {}

local function violation(code: string, detail: string): Violation
	return table.freeze({ Code = code, Detail = detail })
end

function InventoryInvariantChecker.check(record: any): InvariantReport
	local violations: { Violation } = {}

	if type(record) ~= "table" then
		table.insert(violations, violation("RecordNotTable", "the record is not a table"))
		return table.freeze({
			Healthy = false,
			Violations = table.freeze(violations),
			ItemCount = 0,
			EquippedCount = 0,
		})
	end

	local inventory = record.InventoryByInstanceId
	local equipped = record.EquippedBySlot
	local grantIds = record.AppliedRewardGrantIds
	local instanceIds = record.AppliedRewardInstanceIds
	local signatures = record.AppliedRewardContentSignatures
	local dismantles = record.AppliedDismantleTransactions

	--[[
		Checked as pairs rather than through a table of values: a nil value simply
		does not exist as a key in a Lua table constructor, so the very ledgers
		this is meant to catch would be the ones it could not see.
	]]
	local required = {
		{ "InventoryByInstanceId", inventory },
		{ "EquippedBySlot", equipped },
		{ "AppliedRewardGrantIds", grantIds },
		{ "AppliedRewardInstanceIds", instanceIds },
	}
	for _, entry in required do
		if type(entry[2]) ~= "table" then
			table.insert(violations, violation("MissingLedger", tostring(entry[1]) .. " is missing or not a table"))
		end
	end

	if #violations > 0 then
		return table.freeze({
			Healthy = false,
			Violations = table.freeze(violations),
			ItemCount = 0,
			EquippedCount = 0,
		})
	end

	--[[
		Instance ids are the record's primary key. A duplicate would mean one
		item exists twice under one identity, which no equip or dismantle could
		then resolve unambiguously.
	]]
	local itemCount = 0
	local seenSignatures: { [string]: string } = {}
	for instanceId, reward in inventory do
		itemCount += 1
		if type(instanceId) ~= "string" or type(reward) ~= "table" then
			table.insert(violations, violation("MalformedItem", tostring(instanceId)))
		elseif reward.InstanceId ~= instanceId then
			table.insert(
				violations,
				violation(
					"ItemKeyMismatch",
					string.format("%s stored under %s", tostring(reward.InstanceId), instanceId)
				)
			)
		else
			local previous = seenSignatures[reward.InstanceId]
			if previous ~= nil then
				table.insert(violations, violation("DuplicateItem", reward.InstanceId))
			end
			seenSignatures[reward.InstanceId] = instanceId

			--[[
				An owned item whose grant is not in the ledger could be granted a
				second time, because the ledger is the only thing that refuses a
				repeat.
			]]
			if type(reward.GrantId) == "string" and grantIds[reward.GrantId] ~= true then
				table.insert(violations, violation("OwnedItemMissingGrant", reward.GrantId))
			end
			if instanceIds[instanceId] ~= true then
				table.insert(violations, violation("OwnedItemMissingInstanceLedger", instanceId))
			end
		end
	end

	--[[
		An equipped slot naming an item the player does not own is ownership
		drift: the binding outlived the item.
	]]
	local equippedCount = 0
	for slotId, instanceId in equipped do
		equippedCount += 1
		local reward = inventory[instanceId]
		if reward == nil then
			table.insert(violations, violation("EquippedItemNotOwned", string.format("%s -> %s", slotId, instanceId)))
		elseif reward.Slot ~= slotId then
			table.insert(
				violations,
				violation("EquippedSlotMismatch", string.format("%s holds a %s", slotId, reward.Slot))
			)
		end
	end

	if type(signatures) == "table" then
		for grantId in signatures do
			if grantIds[grantId] ~= true then
				table.insert(violations, violation("SignatureWithoutGrant", grantId))
			end
		end
	end

	--[[
		A dismantle outcome must stay answerable after the item is gone, so an
		incomplete outcome is damage even though nothing references it.
	]]
	if type(dismantles) == "table" then
		for transactionId, outcome in dismantles do
			if type(transactionId) ~= "string" or type(outcome) ~= "table" then
				table.insert(violations, violation("MalformedDismantleEntry", tostring(transactionId)))
			elseif type(outcome.InstanceId) ~= "string" or type(outcome.SalvagedDefinitionId) ~= "string" then
				table.insert(violations, violation("IncompleteDismantleOutcome", transactionId))
			end
		end
	end

	return table.freeze({
		Healthy = #violations == 0,
		Violations = table.freeze(violations),
		ItemCount = itemCount,
		EquippedCount = equippedCount,
	})
end

return table.freeze(InventoryInvariantChecker)
