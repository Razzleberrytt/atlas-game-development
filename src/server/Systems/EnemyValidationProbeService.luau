--!strict

--[[
	Studio-only, read-only P5 validation probe. It creates no production remote,
	scheduler, heartbeat, enemy mutation, or gameplay authority path. A tester
	may invoke ServerStorage.LivingKingdomsEnemyValidation.ReadSnapshot from the
	Studio server to capture the retained EnemyDirectorService state during the
	full multiplayer pressure-loop playthrough.
]]

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local EnemyDirectorService = require(script.Parent.EnemyDirectorService)

export type Snapshot = {
	serverTimestamp: number,
	activeEnemyCount: number,
	pendingSpawnCount: number,
	ownedModelCount: number,
	ownedBasePartCount: number,
	livingCombatFactCount: number,
	isPressureActive: boolean,
	isStoodDown: boolean,
	escalationLevel: number,
	nextRoamingSpawnServerTimestamp: number?,
	recoveryWindowEndServerTimestamp: number?,
}

local SERVICE_FOLDER_NAME = "LivingKingdomsEnemyValidation"
local READ_FUNCTION_NAME = "ReadSnapshot"
local ENEMY_FOLDER_NAME = "EnemyEntities"

local Service = {}
local started = false
local ownedFolder: Folder? = nil

local function countOwnedInstances(): (number, number)
	local folder = Workspace:FindFirstChild(ENEMY_FOLDER_NAME)
	if folder == nil then
		return 0, 0
	end
	local models = 0
	local baseParts = 0
	for _, descendant in folder:GetDescendants() do
		if descendant:IsA("Model") then
			models += 1
		elseif descendant:IsA("BasePart") then
			baseParts += 1
		end
	end
	return models, baseParts
end

function Service.readSnapshot(): Snapshot
	local pressure = EnemyDirectorService.readPressureState()
	local ownedModelCount, ownedBasePartCount = countOwnedInstances()
	return table.freeze({
		serverTimestamp = Workspace:GetServerTimeNow(),
		activeEnemyCount = pressure.activeEnemyCount,
		pendingSpawnCount = pressure.pendingSpawnCount,
		ownedModelCount = ownedModelCount,
		ownedBasePartCount = ownedBasePartCount,
		livingCombatFactCount = #EnemyDirectorService.readEnemyCombatFacts(),
		isPressureActive = pressure.isPressureActive,
		isStoodDown = pressure.isStoodDown,
		escalationLevel = pressure.escalationLevel,
		nextRoamingSpawnServerTimestamp = pressure.nextRoamingSpawnServerTimestamp,
		recoveryWindowEndServerTimestamp = pressure.recoveryWindowEndServerTimestamp,
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
