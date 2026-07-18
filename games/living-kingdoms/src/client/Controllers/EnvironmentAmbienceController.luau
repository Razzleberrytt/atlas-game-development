--!strict

--[[
	HROI-ENV-001 presentation-only environment mood pass.

	Selected non-collidable canopy still receives low-cost wind motion and authored
	emergency lights still fluctuate locally. The controller now also turns the
	server-disclosed horde threat snapshot into a smoothly escalating color grade,
	bloom response, stronger wind, and bounded distant-storm pulses.

	It never creates gameplay light coverage, infers hidden enemies, changes
	collision, mutates mission state, or sends a client request.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EnvironmentAmbienceController = {}

local stateRemote = ReplicatedStorage:WaitForChild("HordeNetwork"):WaitForChild("State") :: RemoteEvent

local UPDATE_INTERVAL_SECONDS = 0.1
local BASE_WIND_SPEED = 0.7
local BASE_WIND_TILT_RADIANS = math.rad(1.85)
local THREAT_RESPONSE_RATE = 2.4
local INITIAL_STORM_DELAY_SECONDS = 11
local MINIMUM_STORM_INTERVAL_SECONDS = 9
local MAXIMUM_STORM_INTERVAL_SECONDS = 24
local STORM_PULSE_DURATION_SECONDS = 0.48
local MOOD_GRADE_NAME = "LivingKingdomsThreatMoodGrade"
local MOOD_BLOOM_NAME = "LivingKingdomsThreatMoodBloom"
local BASE_TINT = Color3.fromRGB(224, 232, 238)
local ALERT_TINT = Color3.fromRGB(202, 188, 196)

local started = false
local destroyed = false
local elapsed = 0
local accumulated = 0
local threatTarget = 0
local threatVisual = 0
local lastThreatRevision = -1
local stormSequence = 0
local stormPulseStartedAt = -math.huge
local nextStormPulseAt = INITIAL_STORM_DELAY_SECONDS
local heartbeatConnection: RBXScriptConnection? = nil
local threatConnection: RBXScriptConnection? = nil
local moodGrade: ColorCorrectionEffect? = nil
local moodBloom: BloomEffect? = nil
local baseCFrames: { [BasePart]: CFrame } = {}

local function readStormPulse(): number
	local age = elapsed - stormPulseStartedAt
	if age < 0 or age > STORM_PULSE_DURATION_SECONDS then
		return 0
	end

	-- Two short peaks read as distant lightning without a per-frame task loop.
	local firstPeak = math.max(0, 1 - age / 0.09)
	local secondPeakAge = math.abs(age - 0.22)
	local secondPeak = math.max(0, 1 - secondPeakAge / 0.11) * 0.62
	return math.max(firstPeak, secondPeak) * (0.18 + threatVisual * 0.28)
end

local function scheduleNextStormPulse()
	stormSequence += 1
	local noise = math.noise(stormSequence * 0.73, 4.1, 8.2)
	local normalizedNoise = math.clamp((noise + 1) / 2, 0, 1)
	local threatCompressedMaximum = MAXIMUM_STORM_INTERVAL_SECONDS - threatVisual * 7
	local interval = MINIMUM_STORM_INTERVAL_SECONDS
		+ (threatCompressedMaximum - MINIMUM_STORM_INTERVAL_SECONDS) * normalizedNoise
	nextStormPulseAt = elapsed + math.max(MINIMUM_STORM_INTERVAL_SECONDS, interval)
end

local function updateStormPulse()
	if elapsed < nextStormPulseAt then
		return
	end
	stormPulseStartedAt = elapsed
	scheduleNextStormPulse()
end

local function updateThreatResponse()
	local alpha = 1 - math.exp(-THREAT_RESPONSE_RATE * UPDATE_INTERVAL_SECONDS)
	threatVisual += (threatTarget - threatVisual) * alpha
end

local function updateWind()
	local live: { [BasePart]: boolean } = {}
	local windSpeed = BASE_WIND_SPEED + threatVisual * 0.24
	local windTilt = BASE_WIND_TILT_RADIANS * (1 + threatVisual * 0.38)
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
				local sway = math.sin(elapsed * windSpeed + phase) * windTilt * strength
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

local function updateFlicker(stormPulse: number)
	local flickerSpeed = 1.9 + threatVisual * 0.9
	local hardDipThreshold = 0.42 - threatVisual * 0.06
	local stormGridDip = math.clamp(stormPulse * 1.6, 0, 0.72)
	for _, instance in CollectionService:GetTagged("LK_EnvironmentFlicker") do
		if instance:IsA("BasePart") and instance.Parent ~= nil then
			local light = instance:FindFirstChildOfClass("PointLight")
			local baseBrightness = instance:GetAttribute("BaseLightBrightness")
			if light ~= nil and typeof(baseBrightness) == "number" then
				local noise = math.noise(elapsed * flickerSpeed, instance.Position.X * 0.01, instance.Position.Z * 0.01)
				local hardDip = math.noise(elapsed * 0.27, instance.Position.Z * 0.02, 9) > hardDipThreshold
				local unstableBrightness = if hardDip then 0.18 else 0.82 + noise * (0.24 + threatVisual * 0.08)
				light.Brightness = baseBrightness * unstableBrightness * (1 - stormGridDip)
			end
		end
	end
end

local function updateAviationBlink()
	local lit = elapsed % 2.4 < 0.18
	for _, instance in CollectionService:GetTagged("LK_EnvironmentBlink") do
		if instance:IsA("BasePart") and instance.Parent ~= nil then
			local light = instance:FindFirstChildOfClass("PointLight")
			local baseBrightness = instance:GetAttribute("BaseLightBrightness")
			if light ~= nil and typeof(baseBrightness) == "number" then
				light.Brightness = if lit then baseBrightness else 0
				instance.Transparency = if lit then 0 else 0.45
			end
		end
	end
end

local function createMoodEffects()
	for _, name in { MOOD_GRADE_NAME, MOOD_BLOOM_NAME } do
		local stale = Lighting:FindFirstChild(name)
		if stale ~= nil then
			stale:Destroy()
		end
	end

	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = MOOD_GRADE_NAME
	grade.Brightness = -0.005
	grade.Contrast = 0.02
	grade.Saturation = -0.025
	grade.TintColor = BASE_TINT
	grade.Parent = Lighting
	moodGrade = grade

	local bloom = Instance.new("BloomEffect")
	bloom.Name = MOOD_BLOOM_NAME
	bloom.Intensity = 0.1
	bloom.Size = 24
	bloom.Threshold = 1.25
	bloom.Parent = Lighting
	moodBloom = bloom
end

local function updateMood(stormPulse: number)
	local grade = moodGrade
	local bloom = moodBloom
	if grade == nil or bloom == nil then
		return
	end

	local ambientDrift = math.noise(elapsed * 0.08, 2.7, 5.2) * 0.004
	grade.Brightness = -0.005 - threatVisual * 0.032 + ambientDrift + stormPulse * 0.22
	grade.Contrast = 0.02 + threatVisual * 0.075 + stormPulse * 0.05
	grade.Saturation = -0.025 - threatVisual * 0.11
	grade.TintColor = BASE_TINT:Lerp(ALERT_TINT, threatVisual * 0.68)

	bloom.Intensity = 0.1 + threatVisual * 0.2 + stormPulse * 0.7
	bloom.Size = 24 + threatVisual * 10
	bloom.Threshold = 1.25 - threatVisual * 0.16
end

local function restoreTaggedLights()
	for _, tag in { "LK_EnvironmentFlicker", "LK_EnvironmentBlink" } do
		for _, instance in CollectionService:GetTagged(tag) do
			if instance:IsA("BasePart") and instance.Parent ~= nil then
				local light = instance:FindFirstChildOfClass("PointLight")
				local baseBrightness = instance:GetAttribute("BaseLightBrightness")
				if light ~= nil and typeof(baseBrightness) == "number" then
					light.Brightness = baseBrightness
				end
				if tag == "LK_EnvironmentBlink" then
					instance.Transparency = 0
				end
			end
		end
	end
end

local function onHordeState(payload: unknown)
	if type(payload) ~= "table" then
		return
	end
	local snapshot = payload :: any
	if type(snapshot.revision) ~= "number" or snapshot.revision <= lastThreatRevision then
		return
	end
	if type(snapshot.threat) ~= "number" or snapshot.threat ~= snapshot.threat then
		return
	end
	lastThreatRevision = snapshot.revision
	threatTarget = math.clamp(snapshot.threat / 100, 0, 1)
end

function EnvironmentAmbienceController.init()
	-- No external assets or authoritative state are required.
end

function EnvironmentAmbienceController.start()
	if started or destroyed then
		return
	end
	started = true
	createMoodEffects()
	threatConnection = stateRemote.OnClientEvent:Connect(onHordeState)
	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		accumulated += deltaTime
		if accumulated < UPDATE_INTERVAL_SECONDS then
			return
		end
		accumulated -= UPDATE_INTERVAL_SECONDS
		updateThreatResponse()
		updateStormPulse()
		local stormPulse = readStormPulse()
		updateWind()
		updateFlicker(stormPulse)
		updateAviationBlink()
		updateMood(stormPulse)
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
	if threatConnection ~= nil then
		threatConnection:Disconnect()
		threatConnection = nil
	end
	for part, base in baseCFrames do
		if part.Parent ~= nil then
			part.CFrame = base
		end
	end
	restoreTaggedLights()
	if moodGrade ~= nil then
		moodGrade:Destroy()
		moodGrade = nil
	end
	if moodBloom ~= nil then
		moodBloom:Destroy()
		moodBloom = nil
	end
	table.clear(baseCFrames)
	elapsed = 0
	accumulated = 0
	threatTarget = 0
	threatVisual = 0
	lastThreatRevision = -1
	stormSequence = 0
	stormPulseStartedAt = -math.huge
	nextStormPulseAt = INITIAL_STORM_DELAY_SECONDS
end

function EnvironmentAmbienceController.destroy()
	if destroyed then
		return
	end
	EnvironmentAmbienceController.stop()
	destroyed = true
end

return EnvironmentAmbienceController
