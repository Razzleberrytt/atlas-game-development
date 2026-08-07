--!strict

--[[
	Blueprint v2.7 R2 preparation primitive.

	This module is intentionally transport-agnostic and has no Roblox service
	dependencies. It retains the latest pre-ready payload by:

		owner + remoteId + semanticKey

	and flushes exactly one current value per retained semantic key when that
	owner becomes ready. R2 does not yet suppress unchanged change tokens; that
	belongs to R3. Keeping that distinction explicit prevents stage blending.

	This module is dormant preparation until a later accepted rollout change
	wires it into an active server publisher.
]]

local ReadyGatedStatePublisher = {}
ReadyGatedStatePublisher.__index = ReadyGatedStatePublisher

export type SemanticCounters = {
	Attempts: number,
	Accepted: number,
	SuppressedUnchanged: number,
}

export type DeliveryCounters = {
	Sent: number,
	BufferedLatest: number,
	SuppressedBeforeReady: number,
}

type PendingEntry = {
	changeToken: any,
	payload: any,
}

type PendingBySemanticKey = { [string]: PendingEntry }
type PendingByRemote = { [string]: PendingBySemanticKey }
type SendCallback = (owner: any, remoteId: string, payload: any) -> ()

export type Publisher = typeof(setmetatable(
	{} :: {
		_send: SendCallback,
		_ready: { [any]: boolean },
		_pending: { [any]: PendingByRemote },
		_semanticCounters: { [string]: SemanticCounters },
		_deliveryCounters: { [string]: DeliveryCounters },
	},
	ReadyGatedStatePublisher
))

local function semanticCounterFor(self: Publisher, semanticKey: string): SemanticCounters
	local existing = self._semanticCounters[semanticKey]
	if existing ~= nil then
		return existing
	end
	local created: SemanticCounters = {
		Attempts = 0,
		Accepted = 0,
		SuppressedUnchanged = 0,
	}
	self._semanticCounters[semanticKey] = created
	return created
end

local function deliveryCounterFor(self: Publisher, remoteId: string): DeliveryCounters
	local existing = self._deliveryCounters[remoteId]
	if existing ~= nil then
		return existing
	end
	local created: DeliveryCounters = {
		Sent = 0,
		BufferedLatest = 0,
		SuppressedBeforeReady = 0,
	}
	self._deliveryCounters[remoteId] = created
	return created
end

function ReadyGatedStatePublisher.new(sendCallback: SendCallback): Publisher
	assert(type(sendCallback) == "function", "sendCallback must be a function")
	return setmetatable({
		_send = sendCallback,
		_ready = {},
		_pending = {},
		_semanticCounters = {},
		_deliveryCounters = {},
	}, ReadyGatedStatePublisher) :: Publisher
end

function ReadyGatedStatePublisher.publish(
	self: Publisher,
	owner: any,
	remoteId: string,
	semanticKey: string,
	changeToken: any,
	payload: any
): string
	assert(owner ~= nil, "owner is required")
	assert(type(remoteId) == "string" and remoteId ~= "", "remoteId is required")
	assert(type(semanticKey) == "string" and semanticKey ~= "", "semanticKey is required")

	local semantic = semanticCounterFor(self, semanticKey)
	local delivery = deliveryCounterFor(self, remoteId)
	semantic.Attempts += 1
	semantic.Accepted += 1

	if self._ready[owner] == true then
		self._send(owner, remoteId, payload)
		delivery.Sent += 1
		return "sent"
	end

	local ownerPending = self._pending[owner]
	if ownerPending == nil then
		ownerPending = {}
		self._pending[owner] = ownerPending
	end
	local remotePending = ownerPending[remoteId]
	if remotePending == nil then
		remotePending = {}
		ownerPending[remoteId] = remotePending
	end
	remotePending[semanticKey] = {
		changeToken = changeToken,
		payload = payload,
	}
	delivery.BufferedLatest += 1
	delivery.SuppressedBeforeReady += 1
	return "buffered"
end

function ReadyGatedStatePublisher.markReady(self: Publisher, owner: any): number
	assert(owner ~= nil, "owner is required")
	if self._ready[owner] == true then
		return 0
	end
	self._ready[owner] = true

	local ownerPending = self._pending[owner]
	if ownerPending == nil then
		return 0
	end

	local entries = {}
	for remoteId, bySemanticKey in ownerPending do
		for semanticKey, entry in bySemanticKey do
			table.insert(entries, {
				remoteId = remoteId,
				semanticKey = semanticKey,
				entry = entry,
			})
		end
	end
	table.sort(entries, function(left, right)
		if left.remoteId == right.remoteId then
			return left.semanticKey < right.semanticKey
		end
		return left.remoteId < right.remoteId
	end)

	for _, retained in entries do
		self._send(owner, retained.remoteId, retained.entry.payload)
		deliveryCounterFor(self, retained.remoteId).Sent += 1
	end
	self._pending[owner] = nil
	return #entries
end

function ReadyGatedStatePublisher.markNotReady(self: Publisher, owner: any)
	assert(owner ~= nil, "owner is required")
	self._ready[owner] = nil
end

function ReadyGatedStatePublisher.remove(self: Publisher, owner: any)
	if owner == nil then
		return
	end
	self._ready[owner] = nil
	self._pending[owner] = nil
end

function ReadyGatedStatePublisher.isReady(self: Publisher, owner: any): boolean
	return self._ready[owner] == true
end

function ReadyGatedStatePublisher.readPendingCount(self: Publisher, owner: any): number
	local ownerPending = self._pending[owner]
	if ownerPending == nil then
		return 0
	end
	local count = 0
	for _, bySemanticKey in ownerPending do
		for _ in bySemanticKey do
			count += 1
		end
	end
	return count
end

function ReadyGatedStatePublisher.readSemanticCounters(self: Publisher): { [string]: SemanticCounters }
	local copy: { [string]: SemanticCounters } = {}
	for semanticKey, counters in self._semanticCounters do
		copy[semanticKey] = {
			Attempts = counters.Attempts,
			Accepted = counters.Accepted,
			SuppressedUnchanged = counters.SuppressedUnchanged,
		}
	end
	return copy
end

function ReadyGatedStatePublisher.readDeliveryCounters(self: Publisher): { [string]: DeliveryCounters }
	local copy: { [string]: DeliveryCounters } = {}
	for remoteId, counters in self._deliveryCounters do
		copy[remoteId] = {
			Sent = counters.Sent,
			BufferedLatest = counters.BufferedLatest,
			SuppressedBeforeReady = counters.SuppressedBeforeReady,
		}
	end
	return copy
end

return table.freeze(ReadyGatedStatePublisher)
