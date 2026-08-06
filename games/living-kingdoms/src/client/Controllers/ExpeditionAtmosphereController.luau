--!strict

-- Expedition-only post-processing and local environmental ambience. The
-- controller activates while Workspace.ExpeditionRooms exists and restores all
-- previous Lighting values when the run ends.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Controller = {}
local started = false
local heartbeat: RBXScriptConnection? = nil
local childAdded: RBXScriptConnection? = nil
local childRemoved: RBXScriptConnection? = nil
local active = false
local elapsed = 0
local originals: any = nil
local effects: { Instance } = {}
local drone: Sound? = nil

local function remember()
	originals = {
		Brightness = Lighting.Brightness,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		FogColor = Lighting.FogColor,
		FogStart = Lighting.FogStart,
		FogEnd = Lighting.FogEnd,
		EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
		EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
	}
end

local function restore()
	if originals ~= nil then
		for key, value in originals do
			(Lighting :: any)[key] = value
		end
	end
	for _, effect in effects do effect:Destroy() end
	table.clear(effects)
	if drone then drone:Destroy(); drone = nil end
	originals = nil
end

local function addEffect(className: string, name: string): any
	local effect = Instance.new(className)
	effect.Name = name
	effect.Parent = Lighting
	table.insert(effects, effect)
	return effect
end

local function activate()
	if active then return end
	active = true
	remember()
	Lighting.Brightness = 1.35
	Lighting.Ambient = Color3.fromRGB(31, 38, 48)
	Lighting.OutdoorAmbient = Color3.fromRGB(20, 24, 31)
	Lighting.FogColor = Color3.fromRGB(28, 37, 46)
	Lighting.FogStart = 70
	Lighting.FogEnd = 310
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.65

	local atmosphere = addEffect("Atmosphere", "ExpeditionAtmosphere")
	atmosphere.Color = Color3.fromRGB(126, 153, 170)
	atmosphere.Decay = Color3.fromRGB(54, 65, 81)
	atmosphere.Density = 0.34
	atmosphere.Haze = 1.8
	atmosphere.Glare = 0.1

	local bloom = addEffect("BloomEffect", "ExpeditionBloom")
	bloom.Intensity = 0.42
	bloom.Size = 28
	bloom.Threshold = 1.25

	local color = addEffect("ColorCorrectionEffect", "ExpeditionColorGrade")
	color.Brightness = -0.025
	color.Contrast = 0.18
	color.Saturation = -0.12
	color.TintColor = Color3.fromRGB(210, 226, 235)

	local depth = addEffect("DepthOfFieldEffect", "ExpeditionDepth")
	depth.FarIntensity = 0.08
	depth.FocusDistance = 70
	depth.InFocusRadius = 55
	depth.NearIntensity = 0.02

	-- Placeholder synthesized ambience uses no external asset dependency. It is
	-- intentionally silent until a vetted SoundId is assigned in Studio.
	drone = Instance.new("Sound")
	drone.Name = "ExpeditionAmbientDrone"
	drone.Looped = true
	drone.Volume = 0.18
	drone.RollOffMaxDistance = 180
	drone:SetAttribute("NeedsSoundAsset", true)
	drone.Parent = SoundService
end

local function deactivate()
	if not active then return end
	active = false
	restore()
end

local function nearestRoomRole(): string?
	local root = Workspace:FindFirstChild("ExpeditionRooms")
	local character = Players.LocalPlayer.Character
	local pivot = character and character:GetPivot()
	if root == nil or pivot == nil then return nil end
	local nearestRole: string? = nil
	local nearestDistance = math.huge
	for _, child in root:GetChildren() do
		if child:IsA("Model") and child.PrimaryPart then
			local distance = (child.PrimaryPart.Position - pivot.Position).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
				nearestRole = child:GetAttribute("RoomRoleId")
			end
		end
	end
	return nearestRole
end

local function step(deltaTime: number)
	if not active then return end
	elapsed += deltaTime
	if elapsed < 0.5 then return end
	elapsed = 0
	local role = nearestRoomRole()
	local color = Lighting:FindFirstChild("ExpeditionColorGrade")
	local bloom = Lighting:FindFirstChild("ExpeditionBloom")
	if color and color:IsA("ColorCorrectionEffect") then
		if role == "Boss" then
			color.TintColor = Color3.fromRGB(188, 215, 255)
			color.Contrast = 0.25
		elseif role == "Elite" then
			color.TintColor = Color3.fromRGB(226, 196, 255)
			color.Contrast = 0.22
		elseif role == "Combat" then
			color.TintColor = Color3.fromRGB(255, 218, 193)
			color.Contrast = 0.2
		else
			color.TintColor = Color3.fromRGB(210, 226, 235)
			color.Contrast = 0.18
		end
	end
	if bloom and bloom:IsA("BloomEffect") then
		bloom.Intensity = if role == "Boss" then 0.65 elseif role == "Elite" then 0.52 else 0.42
	end
end

function Controller.start()
	if started then return end
	started = true
	if Workspace:FindFirstChild("ExpeditionRooms") then activate() end
	childAdded = Workspace.ChildAdded:Connect(function(child)
		if child.Name == "ExpeditionRooms" then activate() end
	end)
	childRemoved = Workspace.ChildRemoved:Connect(function(child)
		if child.Name == "ExpeditionRooms" then deactivate() end
	end)
	heartbeat = RunService.Heartbeat:Connect(step)
end

function Controller.stop()
	if not started then return end
	started = false
	if heartbeat then heartbeat:Disconnect(); heartbeat = nil end
	if childAdded then childAdded:Disconnect(); childAdded = nil end
	if childRemoved then childRemoved:Disconnect(); childRemoved = nil end
	deactivate()
end

return Controller
