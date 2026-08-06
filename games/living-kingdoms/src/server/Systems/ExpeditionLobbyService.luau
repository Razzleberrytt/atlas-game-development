--!strict

-- Server-owned lobby state for a bounded expedition party. Clients may request
-- ready changes through a narrow validated bridge, but only this service decides
-- when the party is launchable.

export type Service = {
	join: (self: Service, playerId: number) -> any,
	leave: (self: Service, playerId: number) -> any,
	setReady: (self: Service, playerId: number, ready: boolean) -> any,
	readSnapshot: (self: Service) -> any,
	consumeLaunch: (self: Service) -> any,
	destroy: (self: Service) -> (),
}

local Service = {}
Service.__index = Service

local function validPlayerId(playerId: number): boolean
	return type(playerId) == "number" and playerId % 1 == 0 and playerId > 0
end

local function result(accepted: boolean, reasonId: string, snapshot: any?)
	return table.freeze({ Accepted = accepted, ReasonId = reasonId, Snapshot = snapshot })
end

local function copySnapshot(selfAny: any): any
	local members = {}
	for playerId, member in selfAny._members do
		table.insert(members, table.freeze({ PlayerId = playerId, Ready = member.Ready }))
	end
	table.sort(members, function(left, right) return left.PlayerId < right.PlayerId end)
	local allReady = #members >= selfAny._minimumPlayers
	for _, member in members do
		if not member.Ready then allReady = false break end
	end
	return table.freeze({
		Members = table.freeze(members),
		MemberCount = #members,
		MinimumPlayers = selfAny._minimumPlayers,
		MaximumPlayers = selfAny._maximumPlayers,
		AllReady = allReady,
		LaunchPending = selfAny._launchPending,
	})
end

function Service.new(minimumPlayers: number, maximumPlayers: number): Service
	assert(type(minimumPlayers) == "number" and minimumPlayers % 1 == 0 and minimumPlayers >= 1, "invalid minimum players")
	assert(type(maximumPlayers) == "number" and maximumPlayers % 1 == 0 and maximumPlayers >= minimumPlayers, "invalid maximum players")
	return setmetatable({
		_minimumPlayers = minimumPlayers,
		_maximumPlayers = maximumPlayers,
		_members = {},
		_launchPending = false,
		_destroyed = false,
	}, Service) :: any
end

function Service:join(playerId: number): any
	local selfAny = self :: any
	if selfAny._destroyed then return result(false, "ServiceDestroyed", nil) end
	if not validPlayerId(playerId) then return result(false, "InvalidPlayerId", copySnapshot(selfAny)) end
	if selfAny._launchPending then return result(false, "LaunchPending", copySnapshot(selfAny)) end
	if selfAny._members[playerId] ~= nil then return result(false, "AlreadyJoined", copySnapshot(selfAny)) end
	local count = 0
	for _ in selfAny._members do count += 1 end
	if count >= selfAny._maximumPlayers then return result(false, "LobbyFull", copySnapshot(selfAny)) end
	selfAny._members[playerId] = { Ready = false }
	return result(true, "PlayerJoined", copySnapshot(selfAny))
end

function Service:leave(playerId: number): any
	local selfAny = self :: any
	if selfAny._destroyed then return result(false, "ServiceDestroyed", nil) end
	if selfAny._members[playerId] == nil then return result(false, "PlayerNotJoined", copySnapshot(selfAny)) end
	selfAny._members[playerId] = nil
	selfAny._launchPending = false
	return result(true, "PlayerLeft", copySnapshot(selfAny))
end

function Service:setReady(playerId: number, ready: boolean): any
	local selfAny = self :: any
	if selfAny._destroyed then return result(false, "ServiceDestroyed", nil) end
	if type(ready) ~= "boolean" then return result(false, "InvalidReadyState", copySnapshot(selfAny)) end
	local member = selfAny._members[playerId]
	if member == nil then return result(false, "PlayerNotJoined", copySnapshot(selfAny)) end
	if selfAny._launchPending then return result(false, "LaunchPending", copySnapshot(selfAny)) end
	member.Ready = ready
	local snapshot = copySnapshot(selfAny)
	if snapshot.AllReady then selfAny._launchPending = true; snapshot = copySnapshot(selfAny) end
	return result(true, if ready then "PlayerReady" else "PlayerUnready", snapshot)
end

function Service:readSnapshot(): any
	local selfAny = self :: any
	if selfAny._destroyed then return nil end
	return copySnapshot(selfAny)
end

function Service:consumeLaunch(): any
	local selfAny = self :: any
	if selfAny._destroyed then return result(false, "ServiceDestroyed", nil) end
	if not selfAny._launchPending then return result(false, "LaunchNotReady", copySnapshot(selfAny)) end
	local snapshot = copySnapshot(selfAny)
	selfAny._launchPending = false
	for _, member in selfAny._members do member.Ready = false end
	return result(true, "LaunchConsumed", snapshot)
end

function Service:destroy()
	local selfAny = self :: any
	if selfAny._destroyed then return end
	selfAny._destroyed = true
	table.clear(selfAny._members)
	selfAny._launchPending = false
end

return table.freeze(Service)
