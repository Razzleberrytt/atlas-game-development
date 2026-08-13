--!strict

-- Atomic per-player inventory leases. A live server must own a non-expired lease
-- before loading or mutating the player's inventory record.

export type Store = {
	update: (self: Store, key: string, transform: (any) -> any) -> (boolean, any),
}

export type Service = {
	acquire: (self: Service, playerId: number, nowUnix: number) -> any,
	renew: (self: Service, playerId: number, nowUnix: number) -> any,
	release: (self: Service, playerId: number) -> any,
	hasLease: (self: Service, playerId: number, nowUnix: number) -> boolean,
	releaseAll: (self: Service) -> (),
	destroy: (self: Service) -> (),
}

local Service = {}
Service.__index = Service

local function validPlayerId(playerId: number): boolean
	return type(playerId) == "number" and playerId % 1 == 0 and playerId > 0
end

local function keyFor(playerId: number): string
	return string.format("player:%d:lease", playerId)
end

local function result(accepted: boolean, reasonId: string, expiresAtUnix: number?)
	return table.freeze({ Accepted = accepted, ReasonId = reasonId, ExpiresAtUnix = expiresAtUnix })
end

function Service.new(store: Store, ownerId: string, leaseDurationSeconds: number): Service
	assert(type(store) == "table" and type(store.update) == "function", "invalid lease store")
	assert(type(ownerId) == "string" and #ownerId >= 8 and #ownerId <= 128, "invalid lease owner")
	assert(
		type(leaseDurationSeconds) == "number" and leaseDurationSeconds >= 30 and leaseDurationSeconds % 1 == 0,
		"invalid lease duration"
	)
	return setmetatable({
		_store = store,
		_ownerId = ownerId,
		_duration = leaseDurationSeconds,
		_leases = {},
		_destroyed = false,
	}, Service) :: any
end

function Service:acquire(playerId: number, nowUnix: number): any
	local selfAny = self :: any
	if selfAny._destroyed then
		return result(false, "ServiceDestroyed", nil)
	end
	if not validPlayerId(playerId) or type(nowUnix) ~= "number" or nowUnix < 0 then
		return result(false, "InvalidAcquireRequest", nil)
	end

	local acquired = false
	local blocked = false
	local nextExpiry = nowUnix + selfAny._duration
	local ok, value = selfAny._store:update(keyFor(playerId), function(current)
		--[[
			The transform may run more than once for a single update: the store
			adapter retries a failed attempt with this same closure, and
			UpdateAsync itself re-runs the transform when the key changes under
			contention. Only the final invocation describes what was written, so
			the decision flags reset here instead of accumulating. Letting a
			stale `blocked` survive into a successful acquisition would report
			LeaseHeldByAnotherServer while this server silently squatted the
			lease it had just written, untracked and unreleased until expiry.
		]]
		acquired = false
		blocked = false
		if
			type(current) == "table"
			and type(current.OwnerId) == "string"
			and type(current.ExpiresAtUnix) == "number"
			and current.OwnerId ~= selfAny._ownerId
			and current.ExpiresAtUnix > nowUnix
		then
			blocked = true
			return current
		end
		acquired = true
		return {
			OwnerId = selfAny._ownerId,
			AcquiredAtUnix = if type(current) == "table" and current.OwnerId == selfAny._ownerId
				then current.AcquiredAtUnix or nowUnix
				else nowUnix,
			RenewedAtUnix = nowUnix,
			ExpiresAtUnix = nextExpiry,
		}
	end)
	if not ok then
		return result(false, "LeaseStoreFailed", nil)
	end
	if blocked or not acquired or type(value) ~= "table" or value.OwnerId ~= selfAny._ownerId then
		return result(false, "LeaseHeldByAnotherServer", if type(value) == "table" then value.ExpiresAtUnix else nil)
	end
	selfAny._leases[playerId] = nextExpiry
	return result(true, "LeaseAcquired", nextExpiry)
end

function Service:renew(playerId: number, nowUnix: number): any
	local selfAny = self :: any
	if selfAny._destroyed then
		return result(false, "ServiceDestroyed", nil)
	end
	if not validPlayerId(playerId) or type(nowUnix) ~= "number" or nowUnix < 0 then
		return result(false, "InvalidRenewRequest", nil)
	end
	if selfAny._leases[playerId] == nil then
		return result(false, "LeaseNotOwned", nil)
	end

	local renewed = false
	local nextExpiry = nowUnix + selfAny._duration
	local ok, value = selfAny._store:update(keyFor(playerId), function(current)
		-- Same retry contract as acquire. A lost renewal is already caught by the
		-- owner check on the returned value below; resetting here keeps the flag
		-- from being the thing that has to be right.
		renewed = false
		if type(current) ~= "table" or current.OwnerId ~= selfAny._ownerId then
			return current
		end
		renewed = true
		return {
			OwnerId = selfAny._ownerId,
			AcquiredAtUnix = current.AcquiredAtUnix or nowUnix,
			RenewedAtUnix = nowUnix,
			ExpiresAtUnix = nextExpiry,
		}
	end)
	if not ok then
		return result(false, "LeaseStoreFailed", nil)
	end
	if not renewed or type(value) ~= "table" or value.OwnerId ~= selfAny._ownerId then
		selfAny._leases[playerId] = nil
		return result(false, "LeaseLost", nil)
	end
	selfAny._leases[playerId] = nextExpiry
	return result(true, "LeaseRenewed", nextExpiry)
end

function Service:release(playerId: number): any
	local selfAny = self :: any
	if selfAny._destroyed then
		return result(false, "ServiceDestroyed", nil)
	end
	if not validPlayerId(playerId) then
		return result(false, "InvalidReleaseRequest", nil)
	end

	local released = false
	local ok = selfAny._store:update(keyFor(playerId), function(current)
		-- Same retry contract as acquire/renew; only the final invocation counts.
		released = false
		if type(current) == "table" and current.OwnerId == selfAny._ownerId then
			released = true
			return nil
		end
		return current
	end)
	selfAny._leases[playerId] = nil
	if not ok then
		return result(false, "LeaseStoreFailed", nil)
	end
	return result(released, if released then "LeaseReleased" else "LeaseNotOwned", nil)
end

function Service:hasLease(playerId: number, nowUnix: number): boolean
	local selfAny = self :: any
	local expiry = selfAny._leases[playerId]
	return not selfAny._destroyed and type(expiry) == "number" and expiry > nowUnix
end

function Service:releaseAll()
	local selfAny = self :: any
	local playerIds = {}
	for playerId in selfAny._leases do
		table.insert(playerIds, playerId)
	end
	for _, playerId in playerIds do
		self:release(playerId)
	end
end

function Service:destroy()
	local selfAny = self :: any
	if selfAny._destroyed then
		return
	end
	self:releaseAll()
	selfAny._destroyed = true
end

return table.freeze(Service)
