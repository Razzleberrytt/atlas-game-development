--!strict

--[[
	Studio-only P6 validation surface. It samples read-only ammunition telemetry
	on demand and creates no production remote, scheduler, heartbeat, or gameplay
	authority path. Use the two ServerStorage BindableFunctions to reset a run and
	capture snapshots during one-, two-, and four-operative playthroughs.
]]
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local AmmunitionScarcityTelemetryService = require(script.Parent.AmmunitionScarcityTelemetryService)

export type Snapshot = {
	serverTimestamp: number,
	telemetry: AmmunitionScarcityTelemetryService.Snapshot,
}

local SERVICE_FOLDER_NAME = "LivingKingdomsAmmunitionValidation"
local READ_FUNCTION_NAME = "ReadSnapshot"
local RESET_FUNCTION_NAME = "ResetSampling"

local Service = {}
local started = false
local ownedFolder: Folder? = nil

function Service.readSnapshot(): Snapshot
	local serverTimestamp = Workspace:GetServerTimeNow()
	return table.freeze({
		serverTimestamp = serverTimestamp,
		telemetry = AmmunitionScarcityTelemetryService.sample(serverTimestamp),
	})
end

function Service.start()
	if started or not RunService:IsStudio() then
		return
	end
	started = true
	local existing = ServerStorage:FindFirstChild(SERVICE_FOLDER_NAME)
	if existing ~= nil then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = SERVICE_FOLDER_NAME
	folder.Parent = ServerStorage

	local readFunction = Instance.new("BindableFunction")
	readFunction.Name = READ_FUNCTION_NAME
	readFunction.OnInvoke = function()
		return Service.readSnapshot()
	end
	readFunction.Parent = folder

	local resetFunction = Instance.new("BindableFunction")
	resetFunction.Name = RESET_FUNCTION_NAME
	resetFunction.OnInvoke = function()
		AmmunitionScarcityTelemetryService.resetSampling()
		return true
	end
	resetFunction.Parent = folder
	ownedFolder = folder
end

function Service.stop()
	if not started then
		return
	end
	started = false
	local folder = ownedFolder
	if folder ~= nil then
		folder:Destroy()
		ownedFolder = nil
	end
end

return table.freeze(Service)
