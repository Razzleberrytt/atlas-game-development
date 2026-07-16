--!strict

--[[
	MovementValidationSystem observes replicated Roblox character movement from
	the server. It corrects only clearly impossible horizontal displacement and
	does not replace normal Humanoid movement or Roblox character ownership.

	This is a prototype sanity boundary, not production-grade exploit prevention.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MovementLimits = require(ReplicatedStorage.Shared.Config.MovementLimits)
local OperativeLifeService = require(script.Parent.OperativeLifeService)

type CharacterValidationState = {
	character: Model,
	lastAcceptedPosition: Vector3?,
	lastAcceptedTimestamp: number?,
	lastWarningTimestamp: number?,
}

type MovementValidationSystem = {
	start: () -> (),
	stop: () -> (),
}

local MovementValidationSystem: MovementValidationSystem = {} :: MovementValidationSystem
local playerStates: { [Player]: CharacterValidationState } = {}
local heartbeatConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil
local elapsedSinceObservation = 0

local function getLivingCharacterParts(character: Model): (Humanoid?, BasePart?)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if humanoid == nil or humanoid.Health <= 0 then
		return nil, nil
	end

	if rootPart == nil or not rootPart:IsA("BasePart") then
		return nil, nil
	end

	return humanoid, rootPart
end

local function resetPlayerState(player: Player, character: Model?)
	if character == nil then
		playerStates[player] = nil
		return
	end

	playerStates[player] = {
		character = character,
		lastAcceptedPosition = nil,
		lastAcceptedTimestamp = nil,
		lastWarningTimestamp = nil,
	}
end

local function warnAboutCorrection(player: Player, state: CharacterValidationState, now: number)
	local lastWarningTimestamp = state.lastWarningTimestamp
	if lastWarningTimestamp ~= nil and now - lastWarningTimestamp < MovementLimits.WarningCooldownSeconds then
		return
	end

	state.lastWarningTimestamp = now
	warn(string.format("[Living Kingdoms] Corrected impossible movement for %s", player.Name))
end

local function correctCharacter(rootPart: BasePart, acceptedPosition: Vector3)
	rootPart.CFrame = CFrame.new(acceptedPosition) * rootPart.CFrame.Rotation
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
end

local function observePlayer(player: Player, now: number)
	local character = player.Character
	local state = playerStates[player]

	if character == nil or character.Parent == nil then
		resetPlayerState(player, nil)
		return
	end

	if state == nil or state.character ~= character then
		resetPlayerState(player, character)
		state = playerStates[player]
	end

	if state == nil then
		return
	end

	local _, rootPart = getLivingCharacterParts(character)
	if rootPart == nil or rootPart.Parent ~= character then
		state.lastAcceptedPosition = nil
		state.lastAcceptedTimestamp = nil
		return
	end

	local currentPosition = rootPart.Position
	local lastAcceptedPosition = state.lastAcceptedPosition
	local lastAcceptedTimestamp = state.lastAcceptedTimestamp
	if lastAcceptedPosition == nil or lastAcceptedTimestamp == nil then
		state.lastAcceptedPosition = currentPosition
		state.lastAcceptedTimestamp = now
		return
	end

	if not OperativeLifeService.isCharacterMovementAllowed(player, character) then
		correctCharacter(rootPart, lastAcceptedPosition)
		state.lastAcceptedTimestamp = now
		return
	end

	local elapsed = math.max(0, now - lastAcceptedTimestamp)
	local horizontalDisplacement =
		Vector2.new(currentPosition.X - lastAcceptedPosition.X, currentPosition.Z - lastAcceptedPosition.Z).Magnitude
	local maximumDisplacement = MovementLimits.MaximumPrototypeHorizontalSpeed * elapsed
		+ MovementLimits.HorizontalToleranceStuds

	if horizontalDisplacement > maximumDisplacement then
		correctCharacter(rootPart, lastAcceptedPosition)
		state.lastAcceptedTimestamp = now
		warnAboutCorrection(player, state, now)
		return
	end

	state.lastAcceptedPosition = currentPosition
	state.lastAcceptedTimestamp = now
end

local function observePlayers(now: number)
	for _, player in Players:GetPlayers() do
		observePlayer(player, now)
	end
end

function MovementValidationSystem.start()
	if heartbeatConnection ~= nil then
		return
	end

	elapsedSinceObservation = 0
	playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		playerStates[player] = nil
	end)
	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		elapsedSinceObservation += deltaTime
		if elapsedSinceObservation < MovementLimits.ObservationIntervalSeconds then
			return
		end

		elapsedSinceObservation = 0
		observePlayers(time())
	end)
end

function MovementValidationSystem.stop()
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

	elapsedSinceObservation = 0
	table.clear(playerStates)
end

return MovementValidationSystem
