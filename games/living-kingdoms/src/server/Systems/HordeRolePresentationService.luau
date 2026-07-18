--!strict

--[[
	Stateless presentation-only applicator for the six horde roles. It mutates
	only the massless ExclusionWalkerPresentation shell, its five presentation
	motors, eye light, and presentation metadata. It never changes the enemy root,
	Humanoid, combat state, spawning, targeting, health, damage, or rewards.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HordeRolePresentationConfig = require(ReplicatedStorage.Shared.Config.HordeRolePresentationConfig)

local HordeRolePresentationService = {}

local PRESENTATION_MODEL_NAME = "ExclusionWalkerPresentation"
local ROLE_ATTRIBUTE_NAME = "HordeRoleId"
local BASE_SIZE_ATTRIBUTE = "HordeRoleBaseSize"
local BASE_C0_ATTRIBUTE = "HordeRoleBaseC0"

local function colorFromTuple(tuple: HordeRolePresentationConfig.Triple): Color3
	return Color3.fromRGB(tuple[1], tuple[2], tuple[3])
end

local function profileFor(enemyModel: Model): HordeRolePresentationConfig.RolePresentationProfile
	return HordeRolePresentationConfig.get(enemyModel:GetAttribute(ROLE_ATTRIBUTE_NAME))
		or HordeRolePresentationConfig.Default
end

local function readOrStoreBaseSize(part: BasePart): Vector3
	local stored = part:GetAttribute(BASE_SIZE_ATTRIBUTE)
	if typeof(stored) == "Vector3" then
		return stored
	end
	local baseSize = part.Size
	part:SetAttribute(BASE_SIZE_ATTRIBUTE, baseSize)
	return baseSize
end

local function readOrStoreBaseC0(motor: Motor6D): CFrame
	local stored = motor:GetAttribute(BASE_C0_ATTRIBUTE)
	if typeof(stored) == "CFrame" then
		return stored
	end
	local baseC0 = motor.C0
	motor:SetAttribute(BASE_C0_ATTRIBUTE, baseC0)
	return baseC0
end

local function applyPart(part: BasePart, profile: HordeRolePresentationConfig.RolePresentationProfile)
	local groupId = HordeRolePresentationConfig.ComponentGroups[part.Name]
	if groupId == nil then
		return
	end
	local scale = profile.Scales[groupId]
	local color = profile.Colors[groupId]
	if scale == nil or color == nil then
		return
	end
	local baseSize = readOrStoreBaseSize(part)
	part.Size = Vector3.new(baseSize.X * scale[1], baseSize.Y * scale[2], baseSize.Z * scale[3])
	part.Color = colorFromTuple(color)
end

local function findMotor(enemyModel: Model, name: string): Motor6D?
	local candidate = enemyModel:FindFirstChild(name, true)
	return if candidate ~= nil and candidate:IsA("Motor6D") then candidate else nil
end

local function applyPosture(enemyModel: Model, profile: HordeRolePresentationConfig.RolePresentationProfile)
	local torso = findMotor(enemyModel, "TorsoMotor")
	local leftArm = findMotor(enemyModel, "ForearmLeftMotor")
	local rightArm = findMotor(enemyModel, "ForearmRightMotor")
	local leftLeg = findMotor(enemyModel, "LegLeftMotor")
	local rightLeg = findMotor(enemyModel, "LegRightMotor")
	if torso == nil or leftArm == nil or rightArm == nil or leftLeg == nil or rightLeg == nil then
		return
	end
	local posture = profile.Posture
	torso.C0 = readOrStoreBaseC0(torso)
		* CFrame.new(0, posture.TorsoHeightStuds, 0)
		* CFrame.Angles(math.rad(posture.TorsoPitchDegrees), 0, math.rad(posture.TorsoRollDegrees))
	leftArm.C0 = readOrStoreBaseC0(leftArm)
		* CFrame.Angles(math.rad(posture.LeftArmPitchDegrees), 0, math.rad(posture.LeftArmRollDegrees))
	rightArm.C0 = readOrStoreBaseC0(rightArm)
		* CFrame.Angles(math.rad(posture.RightArmPitchDegrees), 0, math.rad(posture.RightArmRollDegrees))
	leftLeg.C0 = readOrStoreBaseC0(leftLeg) * CFrame.Angles(math.rad(posture.LeftLegPitchDegrees), 0, 0)
	rightLeg.C0 = readOrStoreBaseC0(rightLeg) * CFrame.Angles(math.rad(posture.RightLegPitchDegrees), 0, 0)
end

function HordeRolePresentationService.applyRolePresentation(enemyModel: Model): boolean
	local presentation = enemyModel:FindFirstChild(PRESENTATION_MODEL_NAME)
	if presentation == nil or not presentation:IsA("Model") then
		return false
	end
	local profile = profileFor(enemyModel)
	for _, descendant in presentation:GetDescendants() do
		if descendant:IsA("BasePart") then
			applyPart(descendant, profile)
		end
	end
	applyPosture(enemyModel, profile)

	local sensor = presentation:FindFirstChild("Sensor", true)
	local eyeGlow = if sensor == nil then nil else sensor:FindFirstChild("EyeGlow")
	if sensor ~= nil and sensor:IsA("BasePart") then
		sensor.Color = colorFromTuple(profile.Colors.Sensor)
	end
	if eyeGlow ~= nil and eyeGlow:IsA("PointLight") then
		eyeGlow.Color = colorFromTuple(profile.Colors.Sensor)
		eyeGlow.Brightness = profile.SensorBrightness
		eyeGlow.Range = profile.SensorRange
	end

	presentation:SetAttribute("HordeRoleVisualSignature", profile.SignatureId)
	presentation:SetAttribute("HordeRolePresentationVersion", HordeRolePresentationConfig.Version)
	return true
end

return table.freeze(HordeRolePresentationService)
