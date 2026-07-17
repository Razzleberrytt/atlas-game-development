--!strict

--[[
	Post-merge P5-0104 runtime guard for placeholder enemy assemblies. The
	lifecycle model factory intentionally keeps visible body parts non-collidable,
	but a Humanoid assembly still needs one grounded, non-massless root part for
	reliable locomotion and floor contact.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)

local Service = {}
local started = false
local folderConnection: RBXScriptConnection? = nil

local function configureModel(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local root = instance:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	root.CanCollide = true
	root.CanTouch = false
	root.Massless = false
	root.Anchored = false
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
end

function Service.start()
	if started then
		return
	end
	started = true
	local folder = Workspace:WaitForChild(EnemyConfig.ModelFolderName)
	for _, child in folder:GetChildren() do
		configureModel(child)
	end
	folderConnection = folder.ChildAdded:Connect(configureModel)
end

function Service.stop()
	if not started then
		return
	end
	started = false
	if folderConnection ~= nil then
		folderConnection:Disconnect()
		folderConnection = nil
	end
end

return Service
