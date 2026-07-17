--!strict

--[[
	VIS-0103 client-local state readability for the Exclusion Walker fallback.
	One RenderStepped connection reads replicated presentation facts and changes
	only Motor6D poses plus the sensor color. It does not send a remote, move an
	enemy root, select a target, predict an attack, apply damage, change health,
	or alter death and cleanup.

	The controller uses two folder-level lifecycle connections and zero per-enemy
	connections. Motor writes occur only when a resolved pose ID changes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local EnemyPresentationPoseResolver = require(script.Parent.Parent.Presentation.EnemyPresentationPoseResolver)

local EnemyPresentationController = {}

local ENEMY_FOLDER_NAME = "EnemyEntities"
local PRESENTATION_MODEL_NAME = "ExclusionWalkerPresentation"
local HIT_REACTION_SECONDS = 0.28
local MOVEMENT_THRESHOLD = 0.05
local STOPPED_SPEED_THRESHOLD = 0.01
local STRIDES_PER_SECOND = 3

local SENSOR_COLORS = table.freeze({
	Normal = Color3.fromRGB(218, 78, 53),
	Alert = Color3.fromRGB(255, 145, 54),
	Hit = Color3.fromRGB(255, 245, 210),
	Dim = Color3.fromRGB(105, 74, 62),
	Dead = Color3.fromRGB(48, 28, 28),
})

local SENSOR_TRANSPARENCY = table.freeze({
	Normal = 0,
	Alert = 0,
	Hit = 0,
	Dim = 0.35,
	Dead = 0.55,
})

type Record = {
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	healthLabel: TextLabel,
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
	lastHealth: number,
	lastHitServerTimestamp: number?,
	phaseOffsetSeconds: number,
	poseId: string,
}

local started = false
local enemyFolder: Folder? = nil
local descendantAddedConnection: RBXScriptConnection? = nil
local childRemovedConnection: RBXScriptConnection? = nil
local renderConnection: RBXScriptConnection? = nil
local records: { [Model]: Record } = {}

local function readHealth(label: TextLabel): number?
	local captured = string.match(label.Text, "Health:%s*(%-?%d+)")
	if captured == nil then
		return nil
	end
	return tonumber(captured)
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
	local billboard = root:FindFirstChild("EnemyLabel")
	local healthLabel = if billboard == nil then nil else billboard:FindFirstChild("Health")
	local torsoMotor = findMotor(model, "TorsoMotor")
	local leftArmMotor = findMotor(model, "ForearmLeftMotor")
	local rightArmMotor = findMotor(model, "ForearmRightMotor")
	local leftLegMotor = findMotor(model, "LegLeftMotor")
	local rightLegMotor = findMotor(model, "LegRightMotor")
	if
		sensor == nil
		or not sensor:IsA("BasePart")
		or healthLabel == nil
		or not healthLabel:IsA("TextLabel")
		or torsoMotor == nil
		or leftArmMotor == nil
		or rightArmMotor == nil
		or leftLegMotor == nil
		or rightLegMotor == nil
	then
		return
	end

	local currentHealth = readHealth(healthLabel)
	if currentHealth == nil then
		return
	end

	records[model] = {
		model = model,
		root = root,
		humanoid = humanoid,
		healthLabel = healthLabel,
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
		lastHealth = currentHealth,
		lastHitServerTimestamp = nil,
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

local function updateRecord(record: Record, serverTimestamp: number)
	local currentHealth = readHealth(record.healthLabel)
	if currentHealth ~= nil then
		if currentHealth < record.lastHealth then
			record.lastHitServerTimestamp = serverTimestamp
		end
		record.lastHealth = currentHealth
	end

	local lastHitAt = record.lastHitServerTimestamp
	local secondsSinceHit = if lastHitAt == nil then nil else serverTimestamp - lastHitAt
	if secondsSinceHit ~= nil and secondsSinceHit > HIT_REACTION_SECONDS then
		record.lastHitServerTimestamp = nil
		secondsSinceHit = nil
	end

	local isDead = record.root.Anchored and record.lastHealth <= 0
	local isStoodDown = not isDead and record.humanoid.WalkSpeed <= STOPPED_SPEED_THRESHOLD
	local isMoving = record.humanoid.MoveDirection.Magnitude > MOVEMENT_THRESHOLD
	local pursuitThreshold = (
		EnemyConfig.Walker.RoamSpeedStudsPerSecond + EnemyConfig.Walker.PursuitSpeedStudsPerSecond
	) / 2
	local isPursuing = record.humanoid.WalkSpeed > pursuitThreshold
	local strideIndex = math.floor((serverTimestamp + record.phaseOffsetSeconds) * STRIDES_PER_SECOND) % 2

	local pose = EnemyPresentationPoseResolver.resolve({
		isDead = isDead,
		isStoodDown = isStoodDown,
		isMoving = isMoving,
		isPursuing = isPursuing,
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
				updateRecord(record, serverTimestamp)
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
