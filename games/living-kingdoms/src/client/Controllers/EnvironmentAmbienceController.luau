--!strict

-- Low-cost local presentation for wind-touched canopy and unreliable emergency
-- power. It never changes collision, gameplay light state, or mission state.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local EnvironmentAmbienceController = {}

local UPDATE_INTERVAL_SECONDS = 0.1
local WIND_SPEED = 0.7
local WIND_TILT_RADIANS = math.rad(1.6)

local started = false
local destroyed = false
local elapsed = 0
local accumulated = 0
local heartbeatConnection: RBXScriptConnection? = nil
local baseCFrames: { [BasePart]: CFrame } = {}

local function updateWind()
	local live: { [BasePart]: boolean } = {}
	for _, instance in CollectionService:GetTagged("LK_WindAnimated") do
		if instance:IsA("BasePart") and instance.Parent ~= nil then
			live[instance] = true
			local base = baseCFrames[instance]
			if base == nil then
				base = instance.CFrame
				baseCFrames[instance] = base
			end
			local phase = instance:GetAttribute("WindPhase")
			local strength = instance:GetAttribute("WindStrength")
			if typeof(phase) == "number" and typeof(strength) == "number" then
				local sway = math.sin(elapsed * WIND_SPEED + phase) * WIND_TILT_RADIANS * strength
				instance.CFrame = base * CFrame.Angles(sway * 0.35, 0, sway)
			end
		end
	end
	for part in baseCFrames do
		if not live[part] then
			baseCFrames[part] = nil
		end
	end
end

local function updateFlicker()
	for _, instance in CollectionService:GetTagged("LK_EnvironmentFlicker") do
		if instance:IsA("BasePart") and instance.Parent ~= nil then
			local light = instance:FindFirstChildOfClass("PointLight")
			local baseBrightness = instance:GetAttribute("BaseLightBrightness")
			if light ~= nil and typeof(baseBrightness) == "number" then
				local noise = math.noise(elapsed * 1.9, instance.Position.X * 0.01, instance.Position.Z * 0.01)
				local hardDip = math.noise(elapsed * 0.27, instance.Position.Z * 0.02, 9) > 0.42
				light.Brightness = baseBrightness * (if hardDip then 0.18 else 0.82 + noise * 0.24)
			end
		end
	end
end

function EnvironmentAmbienceController.init()
	-- No external assets or authoritative state are required.
end

function EnvironmentAmbienceController.start()
	if started or destroyed then
		return
	end
	started = true
	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		accumulated += deltaTime
		if accumulated < UPDATE_INTERVAL_SECONDS then
			return
		end
		accumulated = 0
		updateWind()
		updateFlicker()
	end)
end

function EnvironmentAmbienceController.stop()
	if not started then
		return
	end
	started = false
	if heartbeatConnection ~= nil then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	for part, base in baseCFrames do
		if part.Parent ~= nil then
			part.CFrame = base
		end
	end
	table.clear(baseCFrames)
	elapsed = 0
	accumulated = 0
end

function EnvironmentAmbienceController.destroy()
	if destroyed then
		return
	end
	EnvironmentAmbienceController.stop()
	destroyed = true
end

return EnvironmentAmbienceController
