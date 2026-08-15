--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.EnvironmentVisualConfig)
local EnvironmentProfileService = require(script.Parent.Systems.EnvironmentProfileService)

EnvironmentProfileService.start()

local startedAt = Workspace:GetServerTimeNow()

while true do
	local elapsed = math.max(0, Workspace:GetServerTimeNow() - startedAt)
	local clockTime = (Config.Cycle.StartClockTime + elapsed * (24 / Config.Cycle.Seconds)) % 24
	EnvironmentProfileService.applyClock(clockTime)
	task.wait(Config.Cycle.UpdateIntervalSeconds)
end
