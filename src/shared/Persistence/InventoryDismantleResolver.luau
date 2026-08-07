--!strict

--[[
	Blueprint v2.0 queue item 3 — dismantle and salvage transaction safety
	(v1.9 Ticket 143).

	Dismantling destroys a valuable item, so it is the most dangerous mutation in
	the inventory. This pure resolver owns the whole decision: it validates the
	request, applies the rejection matrix in a stable order, and returns the next
	record with the item removed exactly once.

	Idempotency is by `TransactionId`. A replayed transaction is *accepted* and
	returns the original outcome rather than being rejected, because a client
	that retried after a dropped response must not be told its item still exists.
	A second, distinct transaction naming the same item is rejected: the item is
	already gone.

	Deliberate boundary — this resolver does not price salvage. No currency or
	material category exists yet, and the blueprint forbids expanding content
	categories before ownership, retry, migration, and recovery are proven. It
	instead reports the facts of what was destroyed (`SalvagedPower`,
	`SalvagedRarity`, `SalvagedDefinitionId`) so an economy can price them later
	without this boundary being rewritten.

	This module owns no state, reads no services, and never mutates its inputs.
]]

local Contracts = require(script.Parent.PlayerInventoryContracts)
local EquipmentContracts = require(script.Parent.Parent.Equipment.EquipmentRewardContracts)

export type PlayerInventoryRecord = Contracts.PlayerInventoryRecord
export type EquipmentRarityId = EquipmentContracts.EquipmentRarityId

export type DismantleRequest = {
	-- Derived from the connection by the caller, never from a client payload.
	RequesterId: number,
	OwnerId: number,
	InstanceId: string,
	TransactionId: string,
	NowUnix: number,
}

export type DismantleState = {
	Record: PlayerInventoryRecord?,
	HasSessionLease: boolean,
	-- Outcomes of transactions already applied for this owner, keyed by
	-- TransactionId, so a retry can be answered without re-destroying anything.
	AppliedTransactions: { [string]: DismantleOutcome },
	-- Server timestamps of recent accepted requests, used for the rate bound.
	RecentRequestTimestamps: { number },
}

export type DismantleOutcome = {
	InstanceId: string,
	SalvagedDefinitionId: string,
	SalvagedRarity: EquipmentRarityId,
	SalvagedPower: number,
}

export type DismantleResult = {
	Accepted: boolean,
	ReasonId: string,
	Replayed: boolean,
	Outcome: DismantleOutcome?,
	NextRecord: PlayerInventoryRecord?,
}

-- A bound, not a tuning value: it exists so a stuck or hostile client cannot
-- drive unbounded writes. It is deliberately far above any human dismantle rate.
local MAXIMUM_REQUESTS_PER_WINDOW = 10
local RATE_WINDOW_SECONDS = 10

local function isPositiveInteger(value: any): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and value > 0
end

local function isIdentifier(value: any): boolean
	return type(value) == "string" and #value >= 1 and #value <= 128
end

local function reject(reasonId: string): DismantleResult
	return table.freeze({
		Accepted = false,
		ReasonId = reasonId,
		Replayed = false,
		Outcome = nil,
		NextRecord = nil,
	})
end

--[[
	Rebuilds the record without the dismantled item. The applied-reward ledgers
	are deliberately preserved: they are replay protection for *granting*, and
	clearing them on dismantle would let the same reward be granted a second
	time by re-running its original transaction.
]]
local function recordWithoutItem(
	record: PlayerInventoryRecord,
	instanceId: string,
	nowUnix: number
): PlayerInventoryRecord
	local inventory = {}
	for id, reward in record.InventoryByInstanceId do
		if id ~= instanceId then
			inventory[id] = reward
		end
	end

	local equipped = {}
	for slotId, equippedInstanceId in record.EquippedBySlot do
		if equippedInstanceId ~= instanceId then
			equipped[slotId] = equippedInstanceId
		end
	end

	return table.freeze({
		SchemaVersion = record.SchemaVersion,
		PlayerId = record.PlayerId,
		InventoryByInstanceId = table.freeze(inventory),
		EquippedBySlot = table.freeze(equipped),
		AppliedRewardInstanceIds = table.freeze(table.clone(record.AppliedRewardInstanceIds)),
		AppliedRewardGrantIds = table.freeze(table.clone(record.AppliedRewardGrantIds)),
		AppliedDismantleTransactions = table.freeze(table.clone(record.AppliedDismantleTransactions or {})),
		UpdatedAtUnix = nowUnix,
	})
end

local function acceptedRequestsInWindow(timestamps: { number }, nowUnix: number): number
	local count = 0
	for _, timestamp in timestamps do
		if type(timestamp) == "number" and nowUnix - timestamp < RATE_WINDOW_SECONDS then
			count += 1
		end
	end
	return count
end

local InventoryDismantleResolver = {}

InventoryDismantleResolver.MaximumRequestsPerWindow = MAXIMUM_REQUESTS_PER_WINDOW
InventoryDismantleResolver.RateWindowSeconds = RATE_WINDOW_SECONDS

--[[
	Rejection order is fixed so a caller always learns the most fundamental
	problem first, and so an attacker cannot use the reason to probe for
	information they are not entitled to — identity is checked before anything
	about the record is read.
]]
function InventoryDismantleResolver.resolve(request: DismantleRequest, state: DismantleState): DismantleResult
	if type(request) ~= "table" or type(state) ~= "table" then
		return reject("InvalidDismantleRequest")
	end
	if not isPositiveInteger(request.RequesterId) or not isPositiveInteger(request.OwnerId) then
		return reject("InvalidPlayerIdentity")
	end
	if request.RequesterId ~= request.OwnerId then
		return reject("CrossPlayerInventoryAccess")
	end
	if not isIdentifier(request.InstanceId) or not isIdentifier(request.TransactionId) then
		return reject("InvalidDismantleRequest")
	end
	if type(request.NowUnix) ~= "number" or request.NowUnix ~= request.NowUnix or request.NowUnix < 0 then
		return reject("InvalidDismantleRequest")
	end

	--[[
		Replay is answered before every other check. A client that retried after
		a dropped response must get its original outcome, even if the session
		lease has since lapsed or the item is now absent — it is absent because
		this very transaction removed it.
	]]
	local applied = state.AppliedTransactions[request.TransactionId]
	if applied ~= nil then
		return table.freeze({
			Accepted = true,
			ReasonId = "TransactionAlreadyApplied",
			Replayed = true,
			Outcome = applied,
			NextRecord = nil,
		})
	end

	-- The session lease is the write lock. Without it another server may own
	-- this profile, and a destructive write would race.
	if state.HasSessionLease ~= true then
		return reject("SessionLeaseRequired")
	end
	if acceptedRequestsInWindow(state.RecentRequestTimestamps, request.NowUnix) >= MAXIMUM_REQUESTS_PER_WINDOW then
		return reject("RateLimited")
	end

	local record = state.Record
	if record == nil then
		return reject("InventoryNotLoaded")
	end
	if record.PlayerId ~= request.OwnerId then
		return reject("InventoryOwnerMismatch")
	end
	if type(request.NowUnix) == "number" and request.NowUnix < record.UpdatedAtUnix then
		return reject("StaleDismantleRequest")
	end

	-- An unknown instance id and another player's instance id are the same
	-- rejection on purpose: neither reveals whether the item exists elsewhere.
	local reward = record.InventoryByInstanceId[request.InstanceId]
	if reward == nil then
		return reject("ItemNotOwned")
	end

	-- Equipped items are protected. Destroying what the operative is carrying
	-- would desync the combat runtime from persistence.
	if record.EquippedBySlot[reward.Slot] == request.InstanceId then
		return reject("ItemEquipped")
	end

	local outcome: DismantleOutcome = table.freeze({
		InstanceId = reward.InstanceId,
		SalvagedDefinitionId = reward.DefinitionId,
		SalvagedRarity = reward.Rarity,
		SalvagedPower = reward.Power,
	})

	return table.freeze({
		Accepted = true,
		ReasonId = "ItemDismantled",
		Replayed = false,
		Outcome = outcome,
		NextRecord = recordWithoutItem(record, request.InstanceId, request.NowUnix),
	})
end

return table.freeze(InventoryDismantleResolver)
