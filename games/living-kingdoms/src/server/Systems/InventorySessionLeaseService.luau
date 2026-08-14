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
	releaseAll: (self: Service) -> any,
	destroy: (self: Service) -> (),
}

local Service = {}
Service.__index = Service

local generationCounter = 0
local MAXIMUM_RELEASE_ATTEMPTS = 3

local function validPlayerId(playerId: number): boolean
	return type(playerId) == "number" and playerId % 1 == 0 and playerId > 0
end

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function validNowUnix(nowUnix: number): boolean
	return isFiniteNumber(nowUnix) and nowUnix >= 0
end

local function keyFor(playerId: number): string
	return string.format("player:%d:lease", playerId)
end

local function result(accepted: boolean, reasonId: string, expiresAtUnix: number?)
	return table.freeze({ Accepted = accepted, ReasonId = reasonId, ExpiresAtUnix = expiresAtUnix })
end

--[[
	A lease record is only meaningful if every field a decision depends on is
	present and well typed. Anything else is a record we cannot reason about.
]]
local function isWellFormedLease(current: any): boolean
	return type(current) == "table"
		and type(current.OwnerId) == "string"
		and current.OwnerId ~= ""
		and isFiniteNumber(current.ExpiresAtUnix)
		and isFiniteNumber(current.AcquiredAtUnix)
		and isFiniteNumber(current.RenewedAtUnix)
end

function Service.new(store: Store, ownerId: string, leaseDurationSeconds: number): Service
	assert(type(store) == "table" and type(store.update) == "function", "invalid lease store")
	assert(type(ownerId) == "string" and #ownerId >= 8 and #ownerId <= 128, "invalid lease owner")
	assert(
		type(leaseDurationSeconds) == "number" and leaseDurationSeconds >= 30 and leaseDurationSeconds % 1 == 0,
		"invalid lease duration"
	)
	--[[
		A JobId can be recycled and an owner id can be reconstructed, so the
		record also carries a generation that is unique to this service instance.
		Two lease services that somehow share an owner id are still
		distinguishable in a stored record, which makes a recycled identity
		diagnosable instead of invisible.
	]]
	generationCounter += 1

	return setmetatable({
		_store = store,
		_ownerId = ownerId,
		_ownerGeneration = string.format("%s#%d", ownerId, generationCounter),
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
	if not validPlayerId(playerId) or not validNowUnix(nowUnix) then
		return result(false, "InvalidAcquireRequest", nil)
	end

	local acquired = false
	local blocked = false
	local malformed = false
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
		malformed = false

		--[[
			A record that exists but cannot be parsed is the dangerous case. The
			previous guard required every field to be well typed *and* the owner
			to differ *and* the expiry to be in the future -- so a rival lease
			with, say, a string ExpiresAtUnix failed the condition and fell
			through to the overwrite below. Two servers would then both believe
			they owned the player, which is the single thing this lease exists
			to prevent.

			So an unparseable record is now honoured rather than replaced. That
			trades a recoverable lockout for an unrecoverable divergence: the
			player cannot play until someone clears one key, but no two servers
			ever write the same inventory. The reason id names it so the key is
			findable.
		]]
		if current ~= nil and not isWellFormedLease(current) then
			malformed = true
			return current
		end
		if current ~= nil and current.OwnerId ~= selfAny._ownerId and current.ExpiresAtUnix > nowUnix then
			blocked = true
			return current
		end
		acquired = true
		return {
			OwnerId = selfAny._ownerId,
			OwnerGeneration = selfAny._ownerGeneration,
			AcquiredAtUnix = if current ~= nil and current.OwnerId == selfAny._ownerId
				then current.AcquiredAtUnix
				else nowUnix,
			RenewedAtUnix = nowUnix,
			ExpiresAtUnix = nextExpiry,
		}
	end)
	if not ok then
		return result(false, "LeaseStoreFailed", nil)
	end
	if malformed then
		return result(false, "LeaseRecordMalformed", nil)
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
	if not validPlayerId(playerId) or not validNowUnix(nowUnix) then
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
		-- A malformed record cannot be confirmed as ours, so it is left alone
		-- and the renewal reports a loss rather than repairing a record whose
		-- owner is unknown.
		if not isWellFormedLease(current) or current.OwnerId ~= selfAny._ownerId then
			return current
		end
		renewed = true
		return {
			OwnerId = selfAny._ownerId,
			OwnerGeneration = selfAny._ownerGeneration,
			AcquiredAtUnix = current.AcquiredAtUnix,
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

--[[
	Shutdown release, with the outcome made observable.

	This used to call release in a loop and discard every result. A store failure
	during BindToClose therefore left a durable lease behind with nothing
	recording it, and the player stayed locked out of every server until the
	lease expired on its own -- indistinguishable, from the outside, from a clean
	shutdown.

	Retries are bounded rather than open-ended: BindToClose has a limited budget,
	and spending it all on a store that is already failing would risk losing the
	releases that could still succeed.
]]
function Service:releaseAll(): any
	local selfAny = self :: any
	local playerIds = {}
	for playerId in selfAny._leases do
		table.insert(playerIds, playerId)
	end
	table.sort(playerIds)

	local requested = #playerIds
	local released = 0
	local unresolved: { number } = {}

	for _, playerId in playerIds do
		local resolved = false
		for _ = 1, MAXIMUM_RELEASE_ATTEMPTS do
			local outcome = self:release(playerId)
			if outcome.Accepted then
				released += 1
				resolved = true
				break
			end
			-- LeaseNotOwned is a settled answer: someone else holds the key, so
			-- there is nothing here left to release. Only a store failure is
			-- worth another attempt.
			if outcome.ReasonId ~= "LeaseStoreFailed" then
				resolved = true
				break
			end
		end
		if not resolved then
			table.insert(unresolved, playerId)
		end
	end

	if #unresolved > 0 then
		warn(
			string.format(
				"[AtlasPersistence] %d inventory lease(s) survived shutdown release and will hold until expiry: %s",
				#unresolved,
				table.concat(unresolved, ", ")
			)
		)
	end

	return table.freeze({
		Requested = requested,
		Released = released,
		Unresolved = #unresolved,
		UnresolvedPlayerIds = table.freeze(unresolved),
	})
end

function Service:destroy(): any
	local selfAny = self :: any
	if selfAny._destroyed then
		return table.freeze({ Requested = 0, Released = 0, Unresolved = 0, UnresolvedPlayerIds = table.freeze({}) })
	end
	local summary = self:releaseAll()
	selfAny._destroyed = true
	return summary
end

return table.freeze(Service)
