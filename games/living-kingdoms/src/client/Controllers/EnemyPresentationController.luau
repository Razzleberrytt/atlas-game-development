--!strict

--[[
	VIS-0103 client-local state readability for the Exclusion Walker fallback.
	One RenderStepped connection reads server-authored presentation attributes
	and changes only Motor6D poses plus the sensor appearance. It does not send
	a remote, move an enemy root, select a target, predict an attack, apply
	damage, change health, or alter death and cleanup.

	The controller uses two folder-level lifecycle connections and zero per-enemy
	connections. Motor writes occur only when a resolved pose ID changes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local EnemyContracts = require(ReplicatedStorage.Shared.Combat.EnemyContracts)
local EnemyPresentationContracts = require(ReplicatedStorage.Shared.Visual.EnemyPresentationContracts)
local EnemyPresentationPoseResolver = require(script.Parent.Parent.Presentation.EnemyPresentationPoseResolver)

local EnemyPresentationController = {}

local BehaviorStateIds = EnemyContracts.EnemyBehaviorStateIds
local PresentationAttributeNames = EnemyPresentationContracts.AttributeNames
local PresentationLifeStateIds = EnemyPresentationContracts.LifeStateIds

local ENEMY_FOLDER_NAME = "EnemyEntities"
local PRESENTATION_MODEL_NAME = "ExclusionWalkerPresentation"
local MOVEMENT_THRESHOLD = 0.05
local STRIDES_PER_SECOND = 3

local SENSOR_COLORS = table.freeze({
	Normal = Color3.fromRGB(218, 78, 53),
	Alert = Color3.fromRGB(255, 145, 54),
	Windup = Color3.fromRGB(255, 176, 48),
	Strike = Color3.fromRGB(255, 204, 74),
	Hit = Color3.fromRGB(255, 245, 210),
	Dim = Color3.fromRGB(105, 74, 62),
	Dead = Color3.fromRGB(48, 28, 28),
})

local SENSOR_TRANSPARENCY = table.freeze({
	Normal = 0,
	Alert = 0,
	Windup = 0,
	Strike = 0,
	Hit = 0,
	Dim = 0.35,
	Dead = 0.55,
})

type Record = {
	root: BasePart,
	humanoid: Humanoid,
	sensor: BasePart,
	torsoMotor: Motor6D,
	leftArmMotor: Motor6D,
	rightArmMotor: Motor6D,
	leftLegMotor: Motor6D,
	rightLegMotor: Motor6D,
	torsoBaseC0: CFrame,
	leftArmBaseC0: CFrame,
	rightArmBaseC0: CFrame,
	leftLegBaseC0: CFrame,
	rightLegBaseC0: CFrame,
	windupSequence: number,
	windupStartedServerTimestamp: number?,
	windupCommitServerTimestamp: number?,
	attackSequence: number,
	attackServerTimestamp: number?,
	hitSequence: number,
	hitServerTimestamp: number?,
	phaseOffsetSeconds: number,
	poseId: string,
}

local started = false
local enemyFolder: Folder? = nil
local descendantAddedConnection: RBXScriptConnection? = nil
local childRemovedConnection: RBXScriptConnection? = nil
local renderConnection: RBXScriptConnection? = nil
local records: { [Model]: Record } = {}

local function readNumberAttribute(model: Model, attributeName: string): number?
	local value = model:GetAttribute(attributeName)
	return if type(value) == "number" then value else nil
end

local function readStringAttribute(model: Model, attributeName: string): string?
	local value = model:GetAttribute(attributeName)
	return if type(value) == "string" then value else nil
end

local function stablePhaseOffset(model: Model): number
	local entityId = model:GetAttribute("CombatEntityId")
	if type(entityId) ~= "string" then
		return 0
	end
	local hash = 0
	for index = 1, #entityId do
		hash = (hash + string.byte(entityId, index) * index) % 997
	end
	return hash / 997
end

local function findMotor(model: Model, name: string): Motor6D?
	local instance = model:FindFirstChild(name, true)
	if instance ~= nil and instance:IsA("Motor6D") then
		return instance
	end
	return nil
end

local function findEnemyModel(instance: Instance): Model?
	local folder = enemyFolder
	local current: Instance? = instance
	while current ~= nil and current ~= folder do
		if current:IsA("Model") and current:GetAttribute("EnemyArchetypeId") == EnemyConfig.Walker.ArchetypeId then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function trackModel(model: Model)
	if records[model] ~= nil or model:GetAttribute("EnemyArchetypeId") ~= EnemyConfig.Walker.ArchetypeId then
		return
	end

	local presentation = model:FindFirstChild(PRESENTATION_MODEL_NAME)
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if
		presentation == nil
		or not presentation:IsA("Model")
		or root == nil
		or not root:IsA("BasePart")
		or humanoid == nil
	then
		return
	end

	local sensor = presentation:FindFirstChild("Sensor", true)
	local torsoMotor = findMotor(model, "TorsoMotor")
	local leftArmMotor = findMotor(model, "ForearmLeftMotor")
	local rightArmMotor = findMotor(model, "ForearmRightMotor")
	local leftLegMotor = findMotor(model, "LegLeftMotor")
	local rightLegMotor = findMotor(model, "LegRightMotor")
	if
		sensor == nil
		or not sensor:IsA("BasePart")
		or torsoMotor == nil
		or leftArmMotor == nil
		or rightArmMotor == nil
		or leftLegMotor == nil
		or rightLegMotor == nil
	then
		return
	end

	local windupSequence = readNumberAttribute(model, PresentationAttributeNames.WindupSequence)
	local windupStartedServerTimestamp =
		readNumberAttribute(model, PresentationAttributeNames.WindupStartedServerTimestamp)
	local windupCommitServerTimestamp =
		readNumberAttribute(model, PresentationAttributeNames.WindupCommitServerTimestamp)
	local attackSequence = readNumberAttribute(model, PresentationAttributeNames.AttackSequence)
	local attackServerTimestamp = readNumberAttribute(model, PresentationAttributeNames.AttackServerTimestamp)
	local hitSequence = readNumberAttribute(model, PresentationAttributeNames.HitSequence)
	local hitServerTimestamp = readNumberAttribute(model, PresentationAttributeNames.HitServerTimestamp)
	if
		windupSequence == nil
		or windupStartedServerTimestamp == nil
		or windupCommitServerTimestamp == nil
		or attackSequence == nil
		or attackServerTimestamp == nil
		or hitSequence == nil
		or hitServerTimestamp == nil
	then
		return
	end

	records[model] = {
		root = root,
		humanoid = humanoid,
		sensor = sensor,
		torsoMotor = torsoMotor,
		leftArmMotor = leftArmMotor,
		rightArmMotor = rightArmMotor,
		leftLegMotor = leftLegMotor,
		rightLegMotor = rightLegMotor,
		torsoBaseC0 = torsoMotor.C0,
		leftArmBaseC0 = leftArmMotor.C0,
		rightArmBaseC0 = rightArmMotor.C0,
		leftLegBaseC0 = leftLegMotor.C0,
		rightLegBaseC0 = rightLegMotor.C0,
		windupSequence = windupSequence,
		windupStartedServerTimestamp = if windupSequence > 0 and windupStartedServerTimestamp > 0
			then windupStartedServerTimestamp
			else nil,
		windupCommitServerTimestamp = if windupSequence > 0
				and windupCommitServerTimestamp > windupStartedServerTimestamp
			then windupCommitServerTimestamp
			else nil,
		attackSequence = attackSequence,
		attackServerTimestamp = if attackSequence > 0 and attackServerTimestamp > 0 then attackServerTimestamp else nil,
		hitSequence = hitSequence,
		hitServerTimestamp = if hitSequence > 0 and hitServerTimestamp > 0 then hitServerTimestamp else nil,
		phaseOffsetSeconds = stablePhaseOffset(model),
		poseId = "",
	}
end

local function restoreRecord(record: Record)
	record.torsoMotor.C0 = record.torsoBaseC0
	record.leftArmMotor.C0 = record.leftArmBaseC0
	record.rightArmMotor.C0 = record.rightArmBaseC0
	record.leftLegMotor.C0 = record.leftLegBaseC0
	record.rightLegMotor.C0 = record.rightLegBaseC0
	record.sensor.Color = SENSOR_COLORS.Normal
	record.sensor.Transparency = SENSOR_TRANSPARENCY.Normal
end

local function untrackModel(model: Model)
	local record = records[model]
	if record == nil then
		return
	end
	restoreRecord(record)
	records[model] = nil
end

local function applyPose(record: Record, pose: EnemyPresentationPoseResolver.Pose)
	record.torsoMotor.C0 = record.torsoBaseC0
		* CFrame.Angles(math.rad(pose.torsoPitchDegrees), 0, math.rad(pose.torsoRollDegrees))
	record.leftArmMotor.C0 = record.leftArmBaseC0
		* CFrame.Angles(math.rad(pose.leftArmPitchDegrees), 0, math.rad(pose.leftArmRollDegrees))
	record.rightArmMotor.C0 = record.rightArmBaseC0
		* CFrame.Angles(math.rad(pose.rightArmPitchDegrees), 0, math.rad(pose.rightArmRollDegrees))
	record.leftLegMotor.C0 = record.leftLegBaseC0 * CFrame.Angles(math.rad(pose.leftLegPitchDegrees), 0, 0)
	record.rightLegMotor.C0 = record.rightLegBaseC0 * CFrame.Angles(math.rad(pose.rightLegPitchDegrees), 0, 0)

	local color = SENSOR_COLORS[pose.sensorMode]
	local transparency = SENSOR_TRANSPARENCY[pose.sensorMode]
	if color ~= nil and transparency ~= nil then
		record.sensor.Color = color
		record.sensor.Transparency = transparency
	end
	record.poseId = pose.id
end

local function updateRecord(model: Model, record: Record, serverTimestamp: number)
	local windupSequence = readNumberAttribute(model, PresentationAttributeNames.WindupSequence)
	local windupStartedServerTimestamp =
		readNumberAttribute(model, PresentationAttributeNames.WindupStartedServerTimestamp)
	local windupCommitServerTimestamp =
		readNumberAttribute(model, PresentationAttributeNames.WindupCommitServerTimestamp)
	local currentWindupStartedAt = record.windupStartedServerTimestamp or 0
	if
		windupSequence ~= nil
		and windupStartedServerTimestamp ~= nil
		and windupCommitServerTimestamp ~= nil
		and windupSequence >= record.windupSequence
		and windupStartedServerTimestamp > currentWindupStartedAt
		and windupCommitServerTimestamp > windupStartedServerTimestamp
	then
		record.windupSequence = windupSequence
		record.windupStartedServerTimestamp = windupStartedServerTimestamp
		record.windupCommitServerTimestamp = windupCommitServerTimestamp
	end

	local attackSequence = readNumberAttribute(model, PresentationAttributeNames.AttackSequence)
	local attackServerTimestamp = readNumberAttribute(model, PresentationAttributeNames.AttackServerTimestamp)
	if
		attackSequence ~= nil
		and attackServerTimestamp ~= nil
		and attackSequence >= record.attackSequence
		and attackServerTimestamp > (record.attackServerTimestamp or 0)
	then
		record.attackSequence = attackSequence
		record.attackServerTimestamp = attackServerTimestamp
	end

	local hitSequence = readNumberAttribute(model, PresentationAttributeNames.HitSequence)
	local hitServerTimestamp = readNumberAttribute(model, PresentationAttributeNames.HitServerTimestamp)
	if
		hitSequence ~= nil
		and hitServerTimestamp ~= nil
		and hitSequence >= record.hitSequence
		and hitServerTimestamp > (record.hitServerTimestamp or 0)
	then
		record.hitSequence = hitSequence
		record.hitServerTimestamp = hitServerTimestamp
	end

	local behaviorStateId = readStringAttribute(model, PresentationAttributeNames.BehaviorStateId)
	local lifeStateId = readStringAttribute(model, PresentationAttributeNames.LifeStateId)
	if behaviorStateId == nil or lifeStateId == nil then
		return
	end

	local windupStartedAt = record.windupStartedServerTimestamp
	local windupCommitAt = record.windupCommitServerTimestamp
	local attackAt = record.attackServerTimestamp
	local hitAt = record.hitServerTimestamp
	local secondsSinceAttack = if attackAt == nil then nil else serverTimestamp - attackAt
	local secondsSinceHit = if hitAt == nil then nil else serverTimestamp - hitAt
	local isDead = lifeStateId == PresentationLifeStateIds.Dead
	local isStoodDown = behaviorStateId == BehaviorStateIds.StandDown
	local isWindingUp = behaviorStateId == BehaviorStateIds.WindingUp
	local windupProgress = nil
	if isWindingUp and windupStartedAt ~= nil and windupCommitAt ~= nil and windupCommitAt > windupStartedAt then
		windupProgress = math.clamp((serverTimestamp - windupStartedAt) / (windupCommitAt - windupStartedAt), 0, 1)
	end
	local isMoving = record.humanoid.MoveDirection.Magnitude > MOVEMENT_THRESHOLD
	local isPursuing = behaviorStateId == BehaviorStateIds.Pursuing
		or behaviorStateId == BehaviorStateIds.WindingUp
		or behaviorStateId == BehaviorStateIds.Attacking
	local strideScaleValue = model:GetAttribute("HordeRoleStrideScale")
	local strideScale = if type(strideScaleValue) == "number"
			and strideScaleValue == strideScaleValue
			and strideScaleValue >= 0.5
			and strideScaleValue <= 2
		then strideScaleValue
		else 1
	local strideIndex = math.floor((serverTimestamp + record.phaseOffsetSeconds) * STRIDES_PER_SECOND * strideScale) % 2

	local pose = EnemyPresentationPoseResolver.resolve({
		isDead = isDead,
		isStoodDown = isStoodDown,
		isMoving = isMoving,
		isPursuing = isPursuing,
		isWindingUp = isWindingUp,
		windupSequence = record.windupSequence,
		windupProgress = windupProgress,
		attackSequence = record.attackSequence,
		secondsSinceAttack = secondsSinceAttack,
		secondsSinceHit = secondsSinceHit,
		strideIndex = strideIndex,
	})
	if pose.id ~= record.poseId then
		applyPose(record, pose)
	end
end

function EnemyPresentationController.start()
	if started then
		return
	end
	started = true

	local folder = Workspace:WaitForChild(ENEMY_FOLDER_NAME)
	assert(folder:IsA("Folder"), "EnemyEntities must be a Folder")
	enemyFolder = folder
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			trackModel(child)
		end
	end

	descendantAddedConnection = folder.DescendantAdded:Connect(function(descendant)
		local model = findEnemyModel(descendant)
		if model ~= nil then
			trackModel(model)
		end
	end)
	childRemovedConnection = folder.ChildRemoved:Connect(function(child)
		if child:IsA("Model") then
			untrackModel(child)
		end
	end)
	renderConnection = RunService.RenderStepped:Connect(function()
		local serverTimestamp = Workspace:GetServerTimeNow()
		for model, record in records do
			if model.Parent == nil then
				records[model] = nil
			else
				updateRecord(model, record, serverTimestamp)
			end
		end
	end)
end

function EnemyPresentationController.stop()
	if not started then
		return
	end
	started = false
	if descendantAddedConnection ~= nil then
		descendantAddedConnection:Disconnect()
		descendantAddedConnection = nil
	end
	if childRemovedConnection ~= nil then
		childRemovedConnection:Disconnect()
		childRemovedConnection = nil
	end
	if renderConnection ~= nil then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	for model, record in records do
		restoreRecord(record)
		records[model] = nil
	end
	enemyFolder = nil
end

return table.freeze(EnemyPresentationController)
