--!strict

--[[
	Blueprint v2.0 queue item 1 — owner-only inventory snapshots.

	One pure boundary converts an authoritative `PlayerInventoryRecord` into the
	only shape a client may ever observe. Two rules are enforced here rather than
	at each call site:

	1. A snapshot is produced for exactly one owner, and only for a requester who
	   is that owner. Cross-player reads are rejected, not filtered.
	2. Server-only bookkeeping never leaves the server. `AppliedRewardInstanceIds`
	   and `AppliedRewardGrantIds` are replay-protection ledgers, and `GrantId` is
	   the idempotency key for a grant. Disclosing any of them hands a client the
	   vocabulary of the reward transaction boundary, so they are dropped.

	This module owns no state, reads no services, and performs no mutation.
]]

local Contracts = require(script.Parent.PlayerInventoryContracts)
local EquipmentContracts = require(script.Parent.Parent.Equipment.EquipmentRewardContracts)

export type PlayerInventoryRecord = Contracts.PlayerInventoryRecord
export type EquipmentSlotId = EquipmentContracts.EquipmentSlotId
export type EquipmentRarityId = EquipmentContracts.EquipmentRarityId
export type RewardSourceId = EquipmentContracts.RewardSourceId

-- The disclosed shape of one owned item. Deliberately narrower than
-- `EquipmentReward`: no GrantId, no RunId, no Seed.
export type InventoryItemView = {
	InstanceId: string,
	ContentSignature: string,
	DefinitionId: string,
	DefinitionVersion: string,
	DisplayName: string,
	Slot: EquipmentSlotId,
	Rarity: EquipmentRarityId,
	Power: number,
	SourceId: RewardSourceId,
	Equipped: boolean,
}

export type PlayerInventorySnapshot = {
	OwnerId: number,
	SchemaVersion: number,
	UpdatedAtUnix: number,
	ItemCount: number,
	Items: { InventoryItemView },
	EquippedBySlot: { [EquipmentSlotId]: string? },
}

export type SnapshotResult = {
	Accepted: boolean,
	ReasonId: string,
	Snapshot: PlayerInventorySnapshot?,
}

local function isPositiveInteger(value: any): boolean
	return type(value) == "number" and value % 1 == 0 and value > 0
end

local function reject(reasonId: string): SnapshotResult
	return table.freeze({ Accepted = false, ReasonId = reasonId, Snapshot = nil })
end

--[[
	Items are ordered by InstanceId so the same record always produces the same
	snapshot. A client-visible ordering that depends on table iteration would make
	snapshots impossible to compare or diff.
]]
local function sortedInstanceIds(record: PlayerInventoryRecord): { string }
	local instanceIds = {}
	for instanceId in record.InventoryByInstanceId do
		table.insert(instanceIds, instanceId)
	end
	table.sort(instanceIds)
	return instanceIds
end

local PlayerInventorySnapshot = {}

--[[
	Builds the owner-only snapshot. `requesterId` is the identity the server
	derived from the connection, never a client-supplied field; `ownerId` is the
	inventory being read. They must match.
]]
function PlayerInventorySnapshot.forOwner(
	requesterId: number,
	ownerId: number,
	record: PlayerInventoryRecord?
): SnapshotResult
	if not isPositiveInteger(requesterId) or not isPositiveInteger(ownerId) then
		return reject("InvalidPlayerIdentity")
	end
	if requesterId ~= ownerId then
		return reject("CrossPlayerInventoryAccess")
	end
	if record == nil then
		return reject("InventoryNotLoaded")
	end
	-- A record loaded under a different identity is a server-side ownership bug,
	-- not a client error. Fail closed rather than disclose it.
	if record.PlayerId ~= ownerId then
		return reject("InventoryOwnerMismatch")
	end

	local equipped = table.clone(record.EquippedBySlot)

	local items = {}
	for _, instanceId in sortedInstanceIds(record) do
		local reward = record.InventoryByInstanceId[instanceId]
		table.insert(
			items,
			table.freeze({
				InstanceId = reward.InstanceId,
				ContentSignature = reward.ContentSignature,
				DefinitionId = reward.DefinitionId,
				DefinitionVersion = reward.DefinitionVersion,
				DisplayName = reward.DisplayName,
				Slot = reward.Slot,
				Rarity = reward.Rarity,
				Power = reward.Power,
				SourceId = reward.SourceId,
				Equipped = equipped[reward.Slot] == reward.InstanceId,
			})
		)
	end

	return table.freeze({
		Accepted = true,
		ReasonId = "InventoryDisclosed",
		Snapshot = table.freeze({
			OwnerId = ownerId,
			SchemaVersion = record.SchemaVersion,
			UpdatedAtUnix = record.UpdatedAtUnix,
			ItemCount = #items,
			Items = table.freeze(items),
			EquippedBySlot = table.freeze(equipped),
		}),
	})
end

return table.freeze(PlayerInventorySnapshot)
