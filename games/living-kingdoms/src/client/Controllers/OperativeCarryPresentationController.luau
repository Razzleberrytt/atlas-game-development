--!strict

--[[
	VIS-0104 client-local upper-body firearm carry fallback. The controller reads
	existing server-disclosed life and revive attributes, then offsets only the
	existing shoulder and WeaponGrip Motor6D baselines. It restores every captured
	baseline on cleanup and never owns movement, combat, health, revive, or death.
]]

local Players = game:GetService("Players")

local OperativeCarryPoseResolver = require(script.Parent.Parent.Presentation.OperativeCarryPoseResolver)

type PoseId = OperativeCarryPoseResolver.PoseId
type PoseDefinition = OperativeCarryPoseResolver.PoseDefinition
type RigId = OperativeCarryPoseResolver.RigId

local OPERATIVE_ID_ATTRIBUTE = "LK_P3_OperativeEntityId"
local LIFE_STATE_ATTRIBUTE = "LK_P3_LifeState"
local REVIVE_STATUS_ATTRIBUTE = "LK_P3_ReviveStatus"
local REVIVE_REVIVER_ATTRIBUTE = "LK_P3_ReviveReviver"
local WEAPON_GRIP_NAME = "WeaponGrip"

local WATCHED_ATTRIBUTES: { [string]: boolean } = table.freeze({
	[OPERATIVE_ID_ATTRIBUTE] = true,
	[LIFE_STATE_ATTRIBUTE] = true,
	[REVIVE_STATUS_ATTRIBUTE] = true,
	[REVIVE_REVIVER_ATTRIBUTE] = true,
})

local SHOULDER_NAMES: { [string]: boolean } = table.freeze({
	RightShoulder = true,
	LeftShoulder = true,
	["Right Shoulder"] = true,
	["Left Shoulder"] = true,
})

type CharacterBinding = {
	character: Model,
	rigId: RigId,
	rightShoulder: Motor6D?,
	rightShoulderBaseC0: CFrame?,
	leftShoulder: Motor6D?,
	leftShoulderBaseC0: CFrame?,
	gripMotor: Motor6D?,
	gripBaseC0: CFrame?,
	descendantAddedConnection: RBXScriptConnection,
	descendantRemovingConnection: RBXScriptConnection,
}

type PlayerRecord = {
	characterAddedConnection: RBXScriptConnection,
	characterRemovingConnection: RBXScriptConnection,
	attributeConnection: RBXScriptConnection,
	binding: CharacterBinding?,
}

local Controller = {}
local started = false
local playerRecords: { [Player]: PlayerRecord } = {}
local playerAddedConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil

local function rotation(rotationDegrees: OperativeCarryPoseResolver.VectorDefinition): CFrame
	return CFrame.Angles(
		math.rad(rotationDegrees.x),
		math.rad(rotationDegrees.y),
		math.rad(rotationDegrees.z)
	)
end

local function resolvePose(player: Player): PoseId
	return OperativeCarryPoseResolver.resolve({
		operativeEntityId = player:GetAttribute(OPERATIVE_ID_ATTRIBUTE),
		lifeStateId = player:GetAttribute(LIFE_STATE_ATTRIBUTE),
		reviveStatus = player:GetAttribute(REVIVE_STATUS_ATTRIBUTE),
		reviveReviverOperativeEntityId = player:GetAttribute(REVIVE_REVIVER_ATTRIBUTE),
	})
end

local function resolveRigId(character: Model): RigId
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil and humanoid.RigType == Enum.HumanoidRigType.R6 then
		return "R6"
	end
	if character:FindFirstChild("Torso") ~= nil and character:FindFirstChild("UpperTorso") == nil then
		return "R6"
	end
	return "R15"
end

local function resolveMotor(parent: Instance?, name: string): Motor6D?
	if parent == nil then
		return nil
	end
	local candidate = parent:FindFirstChild(name)
	return if candidate ~= nil and candidate:IsA("Motor6D") then candidate else nil
end

local function restoreMotor(motor: Motor6D?, baseC0: CFrame?)
	if motor ~= nil and motor.Parent ~= nil and baseC0 ~= nil then
		motor.C0 = baseC0
	end
end

local function restoreShoulders(binding: CharacterBinding)
	restoreMotor(binding.rightShoulder, binding.rightShoulderBaseC0)
	restoreMotor(binding.leftShoulder, binding.leftShoulderBaseC0)
end

local function restoreBinding(binding: CharacterBinding)
	restoreShoulders(binding)
	restoreMotor(binding.gripMotor, binding.gripBaseC0)
end

local function captureShoulders(binding: CharacterBinding)
	local torsoName = if binding.rigId == "R6" then "Torso" else "UpperTorso"
	local torso = binding.character:FindFirstChild(torsoName)
	local rightName = if binding.rigId == "R6" then "Right Shoulder" else "RightShoulder"
	local leftName = if binding.rigId == "R6" then "Left Shoulder" else "LeftShoulder"
	local rightShoulder = resolveMotor(torso, rightName)
	local leftShoulder = resolveMotor(torso, leftName)
	if rightShoulder ~= binding.rightShoulder then
		restoreMotor(binding.rightShoulder, binding.rightShoulderBaseC0)
		binding.rightShoulder = rightShoulder
		binding.rightShoulderBaseC0 = if rightShoulder == nil then nil else rightShoulder.C0
	end
	if leftShoulder ~= binding.leftShoulder then
		restoreMotor(binding.leftShoulder, binding.leftShoulderBaseC0)
		binding.leftShoulder = leftShoulder
		binding.leftShoulderBaseC0 = if leftShoulder == nil then nil else leftShoulder.C0
	end
end

local function captureGrip(binding: CharacterBinding)
	local candidate = binding.character:FindFirstChild(WEAPON_GRIP_NAME, true)
	local gripMotor = if candidate ~= nil and candidate:IsA("Motor6D") then candidate else nil
	if gripMotor ~= nil then
		local part1 = gripMotor.Part1
		if part1 == nil or not part1:IsDescendantOf(binding.character) then
			gripMotor = nil
		end
	end
	if gripMotor == binding.gripMotor then
		return
	end
	restoreMotor(binding.gripMotor, binding.gripBaseC0)
	binding.gripMotor = gripMotor
	binding.gripBaseC0 = if gripMotor == nil then nil else gripMotor.C0
end

local function applyMotorPose(motor: Motor6D?, baseC0: CFrame?, rotationDegrees: OperativeCarryPoseResolver.VectorDefinition)
	if motor == nil or motor.Parent == nil or baseC0 == nil then
		return
	end
	motor.C0 = baseC0 * rotation(rotationDegrees)
end

local function applyGripPose(binding: CharacterBinding, definition: PoseDefinition)
	local gripMotor = binding.gripMotor
	local baseC0 = binding.gripBaseC0
	if gripMotor == nil or gripMotor.Parent == nil or baseC0 == nil then
		return
	end
	local offset = definition.gripOffset
	gripMotor.C0 = baseC0
		* CFrame.new(offset.x, offset.y, offset.z)
		* rotation(definition.gripRotationDegrees)
end

local function applyBinding(player: Player, binding: CharacterBinding)
	if binding.character.Parent == nil then
		return
	end
	binding.rigId = resolveRigId(binding.character)
	captureShoulders(binding)
	captureGrip(binding)
	local poseId = resolvePose(player)
	local definition = OperativeCarryPoseResolver.definitionFor(binding.rigId, poseId)
	if definition == nil then
		restoreBinding(binding)
		return
	end
	if poseId == "Ready" and binding.gripMotor == nil then
		restoreShoulders(binding)
		return
	end
	applyMotorPose(binding.rightShoulder, binding.rightShoulderBaseC0, definition.rightShoulderRotationDegrees)
	applyMotorPose(binding.leftShoulder, binding.leftShoulderBaseC0, definition.leftShoulderRotationDegrees)
	applyGripPose(binding, definition)
end

local function unbindCharacter(record: PlayerRecord)
	local binding = record.binding
	if binding == nil then
		return
	end
	restoreBinding(binding)
	binding.descendantAddedConnection:Disconnect()
	binding.descendantRemovingConnection:Disconnect()
	record.binding = nil
end

local function bindCharacter(player: Player, record: PlayerRecord, character: Model)
	unbindCharacter(record)
	if not started or character.Parent == nil then
		return
	end
	local binding = {} :: CharacterBinding
	binding.character = character
	binding.rigId = resolveRigId(character)
	binding.rightShoulder = nil
	binding.rightShoulderBaseC0 = nil
	binding.leftShoulder = nil
	binding.leftShoulderBaseC0 = nil
	binding.gripMotor = nil
	binding.gripBaseC0 = nil
	binding.descendantAddedConnection = character.DescendantAdded:Connect(function(descendant)
		if
			descendant:IsA("Humanoid")
			or (descendant:IsA("Motor6D") and (descendant.Name == WEAPON_GRIP_NAME or SHOULDER_NAMES[descendant.Name]))
		then
			applyBinding(player, binding)
		end
	end)
	binding.descendantRemovingConnection = character.DescendantRemoving:Connect(function(descendant)
		if descendant == binding.gripMotor then
			binding.gripMotor = nil
			binding.gripBaseC0 = nil
			if resolvePose(player) == "Ready" then
				restoreShoulders(binding)
			end
		elseif descendant == binding.rightShoulder then
			binding.rightShoulder = nil
			binding.rightShoulderBaseC0 = nil
		elseif descendant == binding.leftShoulder then
			binding.leftShoulder = nil
			binding.leftShoulderBaseC0 = nil
		end
	end)
	record.binding = binding
	applyBinding(player, binding)
end

local function applyPlayer(player: Player)
	local record = playerRecords[player]
	if record == nil then
		return
	end
	local character = player.Character
	if character == nil then
		unbindCharacter(record)
		return
	end
	local binding = record.binding
	if binding == nil or binding.character ~= character then
		bindCharacter(player, record, character)
		return
	end
	applyBinding(player, binding)
end

local function untrackPlayer(player: Player)
	local record = playerRecords[player]
	if record == nil then
		return
	end
	unbindCharacter(record)
	record.characterAddedConnection:Disconnect()
	record.characterRemovingConnection:Disconnect()
	record.attributeConnection:Disconnect()
	playerRecords[player] = nil
end

local function trackPlayer(player: Player)
	if playerRecords[player] ~= nil then
		return
	end
	local record = {} :: PlayerRecord
	record.binding = nil
	record.characterAddedConnection = player.CharacterAdded:Connect(function(character)
		bindCharacter(player, record, character)
	end)
	record.characterRemovingConnection = player.CharacterRemoving:Connect(function(character)
		local binding = record.binding
		if binding ~= nil and binding.character == character then
			unbindCharacter(record)
		end
	end)
	record.attributeConnection = player.AttributeChanged:Connect(function(attributeName)
		if WATCHED_ATTRIBUTES[attributeName] then
			applyPlayer(player)
		end
	end)
	playerRecords[player] = record
	applyPlayer(player)
end

function Controller.start()
	if started then
		return
	end
	started = true
	for _, player in Players:GetPlayers() do
		trackPlayer(player)
	end
	playerAddedConnection = Players.PlayerAdded:Connect(trackPlayer)
	playerRemovingConnection = Players.PlayerRemoving:Connect(untrackPlayer)
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	if playerAddedConnection ~= nil then
		playerAddedConnection:Disconnect()
		playerAddedConnection = nil
	end
	if playerRemovingConnection ~= nil then
		playerRemovingConnection:Disconnect()
		playerRemovingConnection = nil
	end
	local trackedPlayers = {}
	for player in playerRecords do
		table.insert(trackedPlayers, player)
	end
	for _, player in trackedPlayers do
		untrackPlayer(player)
	end
end

return table.freeze(Controller)
