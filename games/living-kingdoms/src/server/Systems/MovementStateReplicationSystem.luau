--!strict

--[[
	MovementStateReplicationSystem derives presentation state from character
	motion observed by the server. It accepts no client transform or movement
	state messages; Roblox's normal character replication remains responsible
	for replicating the character itself.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MovementStateConfig = require(ReplicatedStorage.Shared.Config.MovementStateConfig)

type PlayerMovementState = {
	character: Model,
	lastObservedPosition: Vector3?,
	lastObservedTimestamp: number?,
	lastFacingDirection: Vector3?,
}

type MovementStateReplicationSystem = {
	start: () -> (),
	stop: () -> (),
}

local MovementStateReplicationSystem: MovementStateReplicationSystem = {} :: MovementStateReplicationSystem
local playerStates: { [Player]: PlayerMovementState } = {}
local heartbeatConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil
local elapsedSinceObservation = 0

local function getHorizontalUnitDirection(direction: Vector3): Vector3?
	local horizontalDirection = Vector3.new(direction.X, 0, direction.Z)
	if horizontalDirection.Magnitude == 0 then
		return nil
	end

	return horizontalDirection.Unit
end

local function clearReplicatedState(character: Model)
	character:SetAttribute(MovementStateConfig.MovementStateAttribute, nil)
	character:SetAttribute(MovementStateConfig.FacingDirectionAttribute, nil)
end

local function setReplicatedState(character: Model, movementState: string, facingDirection: Vector3?)
	if character:GetAttribute(MovementStateConfig.MovementStateAttribute) ~= movementState then
		character:SetAttribute(MovementStateConfig.MovementStateAttribute, movementState)
	end

	if
		facingDirection ~= nil
		and character:GetAttribute(MovementStateConfig.FacingDirectionAttribute) ~= facingDirection
	then
		character:SetAttribute(MovementStateConfig.FacingDirectionAttribute, facingDirection)
	end
end

local function clearPlayerState(player: Player)
	local state = playerStates[player]
	if state ~= nil then
		clearReplicatedState(state.character)
	end

	playerStates[player] = nil
end

local function bindCharacter(player: Player, character: Model): PlayerMovementState
	clearPlayerState(player)

	local state: PlayerMovementState = {
		character = character,
		lastObservedPosition = nil,
		lastObservedTimestamp = nil,
		lastFacingDirection = nil,
	}
	playerStates[player] = state
	return state
end

local function getLivingRootPart(character: Model): BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return nil
	end

	return rootPart
end

local function observePlayer(player: Player, now: number)
	local character = player.Character
	if character == nil or character.Parent == nil then
		clearPlayerState(player)
		return
	end

	local state = playerStates[player]
	if state == nil or state.character ~= character then
		state = bindCharacter(player, character)
	end

	local rootPart = getLivingRootPart(character)
	if rootPart == nil or rootPart.Parent ~= character then
		state.lastObservedPosition = nil
		state.lastObservedTimestamp = nil
		setReplicatedState(character, MovementStateConfig.IdleState, state.lastFacingDirection)
		return
	end

	local currentPosition = rootPart.Position
	local lastObservedPosition = state.lastObservedPosition
	local lastObservedTimestamp = state.lastObservedTimestamp
	if lastObservedPosition == nil or lastObservedTimestamp == nil then
		local initialFacingDirection = getHorizontalUnitDirection(rootPart.CFrame.LookVector)
		state.lastObservedPosition = currentPosition
		state.lastObservedTimestamp = now
		state.lastFacingDirection = initialFacingDirection
		setReplicatedState(character, MovementStateConfig.IdleState, initialFacingDirection)
		return
	end

	local elapsed = math.max(0, now - lastObservedTimestamp)
	local horizontalDisplacement =
		Vector3.new(currentPosition.X - lastObservedPosition.X, 0, currentPosition.Z - lastObservedPosition.Z)
	local horizontalSpeed = if elapsed > 0 then horizontalDisplacement.Magnitude / elapsed else 0

	if horizontalSpeed >= MovementStateConfig.MinimumMovingSpeed then
		local facingDirection = getHorizontalUnitDirection(rootPart.CFrame.LookVector)
		state.lastFacingDirection = facingDirection or state.lastFacingDirection
		setReplicatedState(character, MovementStateConfig.MovingState, state.lastFacingDirection)
	else
		setReplicatedState(character, MovementStateConfig.IdleState, state.lastFacingDirection)
	end

	state.lastObservedPosition = currentPosition
	state.lastObservedTimestamp = now
end

local function observePlayers(now: number)
	for _, player in Players:GetPlayers() do
		observePlayer(player, now)
	end
end

function MovementStateReplicationSystem.start()
	if heartbeatConnection ~= nil then
		return
	end

	elapsedSinceObservation = 0
	playerRemovingConnection = Players.PlayerRemoving:Connect(clearPlayerState)
	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		elapsedSinceObservation += deltaTime
		if elapsedSinceObservation < MovementStateConfig.ObservationIntervalSeconds then
			return
		end

		elapsedSinceObservation = 0
		observePlayers(time())
	end)
end

function MovementStateReplicationSystem.stop()
	local currentHeartbeatConnection = heartbeatConnection
	if currentHeartbeatConnection ~= nil then
		currentHeartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end

	local currentPlayerRemovingConnection = playerRemovingConnection
	if currentPlayerRemovingConnection ~= nil then
		currentPlayerRemovingConnection:Disconnect()
		playerRemovingConnection = nil
	end

	for _, state in playerStates do
		clearReplicatedState(state.character)
	end

	elapsedSinceObservation = 0
	table.clear(playerStates)
end

return MovementStateReplicationSystem
