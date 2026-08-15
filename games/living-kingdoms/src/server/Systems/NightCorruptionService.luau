--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.NightCorruptionConfig)
local EnvironmentProfileService = require(script.Parent.EnvironmentProfileService)

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
	local cycleElapsed = if Config.RuntimeEnabled then elapsed % Config.CycleSeconds else 0
	local isNight = Config.RuntimeEnabled and cycleElapsed >= Config.DaylightSeconds
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
		local clockTime = Config.NightStartClockTime
			+ (Config.DeepNightClockTime + 24 - Config.NightStartClockTime) * intensity
		if clockTime >= 24 then
			clockTime -= 24
		end
		EnvironmentProfileService.applyCorruption(clockTime, intensity, Config.MinimumFogEnd)
	else
		local daylightProgress = cycleElapsed / Config.DaylightSeconds
		local clockTime = Config.DayClockTime + daylightProgress * (Config.NightStartClockTime - Config.DayClockTime)
		EnvironmentProfileService.applyDaylight(clockTime)
	end
end

function Service.start()
	if started then
		return
	end
	started = true
	EnvironmentProfileService.start()
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
