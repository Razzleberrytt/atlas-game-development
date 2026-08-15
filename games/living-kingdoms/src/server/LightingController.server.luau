--!strict

--[[
	Single recurring owner for the operation's global day/night presentation.
	EnvironmentProfileService performs the property writes; this controller only
	computes time, daylight weight, and the already-disclosed corruption mood.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.WorldFoundationConfig)
local EnvironmentProfileService = require(script.Parent.Systems.EnvironmentProfileService)

local cycle = Config.Lighting.Cycle
local hordeNetwork = ReplicatedStorage:WaitForChild("HordeNetwork")

local function smoothstep(edge0: number, edge1: number, value: number): number
	local alpha = math.clamp((value - edge0) / (edge1 - edge0), 0, 1)
	return alpha * alpha * (3 - 2 * alpha)
end

local function readThreatIntensity(): number
	local value = hordeNetwork:GetAttribute("NightCorruptionIntensity")
	if typeof(value) ~= "number" then
		return 0
	end
	return math.clamp(value, 0, 1)
end

if cycle.DurationSeconds <= 0 or cycle.UpdateIntervalSeconds <= 0 then
	error("Lighting cycle durations must be positive")
end

local worldRoot = Workspace:WaitForChild(Config.WorldRootName)
if not worldRoot:IsA("Folder") then
	error(Config.WorldRootName .. " must be a Folder")
end

-- WorldFoundationService is synchronous after creating the root. Waiting for its
-- insertion marker prevents its legacy one-time setup from racing this owner.
while worldRoot:FindFirstChild("SquadInsertion", true) == nil do
	task.wait(0.1)
end

EnvironmentProfileService.start()

local cycleStartedAt = Workspace:GetServerTimeNow()
while true do
	local elapsed = Workspace:GetServerTimeNow() - cycleStartedAt
	local progress = (elapsed % cycle.DurationSeconds) / cycle.DurationSeconds
	local clockTime = (cycle.StartClockTime + progress * 24) % 24
	local sunHeight = math.sin(((clockTime - 6) / 24) * math.pi * 2)
	local daylightAlpha = smoothstep(-0.18, 0.24, sunHeight)

	EnvironmentProfileService.applyCycle(clockTime, daylightAlpha, readThreatIntensity())
	task.wait(cycle.UpdateIntervalSeconds)
end
