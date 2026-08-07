--!strict

--[[
	P7-0107 Studio-only validation surface. It exposes immutable read-only class
	metrics through ServerStorage BindableFunctions for the authored multiplayer
	matrix. It creates no client remote, scheduler, or gameplay mutation path.
]]

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local ClassService = require(script.Parent.ClassService)

local SERVICE_FOLDER_NAME = "LivingKingdomsClassValidation"
local Service = {}
local started = false
local ownedFolder: Folder? = nil

function Service.readSnapshot()
	return table.freeze({
		serverTimestamp = Workspace:GetServerTimeNow(),
		roster = ClassService.readRoster(),
		telemetry = ClassService.readValidationTelemetry(),
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
	readFunction.Name = "ReadSnapshot"
	readFunction.OnInvoke = Service.readSnapshot
	readFunction.Parent = folder

	local resetFunction = Instance.new("BindableFunction")
	resetFunction.Name = "ResetSampling"
	resetFunction.OnInvoke = function()
		ClassService.resetValidationTelemetry()
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
	if ownedFolder ~= nil then
		ownedFolder:Destroy()
		ownedFolder = nil
	end
end

return table.freeze(Service)
