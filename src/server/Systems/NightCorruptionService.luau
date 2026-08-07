--!strict

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.NightCorruptionConfig)

local Service = {}
local network = ReplicatedStorage:WaitForChild("HordeNetwork")
local started = false
local startedAt = 0
local lastTier = -1
local transitionSequence = 0
local accumulated = 0
local heartbeatConnection: RBXScriptConnection? = nil

local function evaluateAt(serverTimestamp: number)
	local elapsed = math.max(0, serverTimestamp - startedAt)
	local dayNumber = math.floor(elapsed / Config.CycleSeconds) + 1
	local cycleElapsed = elapsed % Config.CycleSeconds
	local isNight = cycleElapsed >= Config.DaylightSeconds
	local tier = 0
	local intensity = 0
	if isNight then
		local nightElapsed = cycleElapsed - Config.DaylightSeconds
		tier = math.clamp(math.floor(nightElapsed / Config.NightTierSeconds) + 1, 1, Config.MaximumTier)
		intensity = math.clamp(nightElapsed / (Config.CycleSeconds - Config.DaylightSeconds), 0, 1)
	end
	if tier ~= lastTier then
		lastTier = tier
		transitionSequence += 1
	end

	network:SetAttribute("NightDayNumber", dayNumber)
	network:SetAttribute("NightIsActive", isNight)
	network:SetAttribute("NightCorruptionTier", tier)
	network:SetAttribute("NightCorruptionIntensity", intensity)
	network:SetAttribute("NightCorruptionSequence", transitionSequence)
	network:SetAttribute("NightCorruptionThreatBonus", intensity * Config.MaximumThreatBonus)
	network:SetAttribute("NightCorruptionEnemySpeedMultiplier", 1 + tier * Config.EnemySpeedBonusPerTier)
	network:SetAttribute("NightCorruptionXpMultiplier", 1 + tier * Config.XpBonusPerTier)

	if isNight then
		Lighting.ClockTime = Config.NightStartClockTime
			+ (Config.DeepNightClockTime + 24 - Config.NightStartClockTime) * intensity
		if Lighting.ClockTime >= 24 then
			Lighting.ClockTime -= 24
		end
		Lighting.Brightness = 2.05 - intensity * 0.8
		Lighting.ExposureCompensation = 0.12 - intensity * 0.42
		Lighting.FogEnd = 485 - intensity * (485 - Config.MinimumFogEnd)
		Lighting.Ambient = Color3.fromRGB(
			35 - math.floor(intensity * 20),
			44 - math.floor(intensity * 25),
			56 - math.floor(intensity * 25)
		)
	else
		local daylightProgress = cycleElapsed / Config.DaylightSeconds
		Lighting.ClockTime = Config.DayClockTime + daylightProgress * (Config.NightStartClockTime - Config.DayClockTime)
		Lighting.Brightness = 2.5
		Lighting.ExposureCompensation = 0.3
		Lighting.FogEnd = 485
		Lighting.Ambient = Color3.fromRGB(52, 58, 61)
	end
end

function Service.start()
	if started then
		return
	end
	started = true
	startedAt = Workspace:GetServerTimeNow()
	lastTier = -1
	transitionSequence = 0
	evaluateAt(startedAt)
	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		accumulated += deltaTime
		if accumulated >= 0.5 then
			accumulated = 0
			evaluateAt(Workspace:GetServerTimeNow())
		end
	end)
end

function Service.stop()
	started = false
	if heartbeatConnection ~= nil then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	accumulated = 0
end

return table.freeze(Service)
