--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ensureFlashlightNetwork()
	local existingNetwork = ReplicatedStorage:FindFirstChild("FlashlightNetwork")
	local network: Folder
	if existingNetwork == nil then
		network = Instance.new("Folder")
		network.Name = "FlashlightNetwork"
		network.Parent = ReplicatedStorage
	else
		assert(existingNetwork:IsA("Folder"), "FlashlightNetwork must be a Folder")
		network = existingNetwork
	end
	for _, remoteName in { "ToggleIntent", "State" } do
		local existingRemote = network:FindFirstChild(remoteName)
		if existingRemote == nil then
			local remote = Instance.new("RemoteEvent")
			remote.Name = remoteName
			remote.Parent = network
		else
			assert(existingRemote:IsA("RemoteEvent"), remoteName .. " must be a RemoteEvent")
		end
	end
end

local function ensureSquadPingNetwork()
	local existingNetwork = ReplicatedStorage:FindFirstChild("SquadPingNetwork")
	local network: Folder
	if existingNetwork == nil then
		network = Instance.new("Folder")
		network.Name = "SquadPingNetwork"
		network.Parent = ReplicatedStorage
	else
		assert(existingNetwork:IsA("Folder"), "SquadPingNetwork must be a Folder")
		network = existingNetwork
	end
	for _, remoteName in { "Intent", "State" } do
		local existingRemote = network:FindFirstChild(remoteName)
		if existingRemote == nil then
			local remote = Instance.new("RemoteEvent")
			remote.Name = remoteName
			remote.Parent = network
		else
			assert(existingRemote:IsA("RemoteEvent"), remoteName .. " must be a RemoteEvent")
		end
	end
end

local function ensureMissionNetwork()
	local existingNetwork = ReplicatedStorage:FindFirstChild("MissionNetwork")
	local network: Folder
	if existingNetwork == nil then
		network = Instance.new("Folder")
		network.Name = "MissionNetwork"
		network.Parent = ReplicatedStorage
	else
		assert(existingNetwork:IsA("Folder"), "MissionNetwork must be a Folder")
		network = existingNetwork
	end
	local existingRemote = network:FindFirstChild("State")
	if existingRemote == nil then
		local remote = Instance.new("RemoteEvent")
		remote.Name = "State"
		remote.Parent = network
	else
		assert(existingRemote:IsA("RemoteEvent"), "State must be a RemoteEvent")
	end
end

local function ensureClassNetwork()
	local existingNetwork = ReplicatedStorage:FindFirstChild("ClassNetwork")
	local network: Folder
	if existingNetwork == nil then
		network = Instance.new("Folder")
		network.Name = "ClassNetwork"
		network.Parent = ReplicatedStorage
	else
		assert(existingNetwork:IsA("Folder"), "ClassNetwork must be a Folder")
		network = existingNetwork
	end
	for _, remoteName in { "SelectionIntent", "State" } do
		local existingRemote = network:FindFirstChild(remoteName)
		if existingRemote == nil then
			local remote = Instance.new("RemoteEvent")
			remote.Name = remoteName
			remote.Parent = network
		else
			assert(existingRemote:IsA("RemoteEvent"), remoteName .. " must be a RemoteEvent")
		end
	end
	local existingReadState = network:FindFirstChild("ReadState")
	if existingReadState == nil then
		local readState = Instance.new("RemoteFunction")
		readState.Name = "ReadState"
		readState.Parent = network
	else
		assert(existingReadState:IsA("RemoteFunction"), "ReadState must be a RemoteFunction")
	end
end

ensureFlashlightNetwork()
ensureSquadPingNetwork()
ensureMissionNetwork()
ensureClassNetwork()

local AmmunitionCacheService = require(script.Systems.AmmunitionCacheService)
local AmmunitionScarcityValidationProbeService = require(script.Systems.AmmunitionScarcityValidationProbeService)
local ClassService = require(script.Systems.ClassService)
local MovementValidationSystem = require(script.Systems.MovementValidationSystem)
local MovementStateReplicationSystem = require(script.Systems.MovementStateReplicationSystem)
local EnemyDirectorService = require(script.Systems.EnemyDirectorService)
local EnemyValidationProbeService = require(script.Systems.EnemyValidationProbeService)
local OperativeCombatRuntimeService = require(script.Systems.OperativeCombatRuntimeService)
local OperativeLifeDevelopmentHarness = require(script.Systems.OperativeLifeDevelopmentHarness)
local OperativeLifeService = require(script.Systems.OperativeLifeService)
local OperativeLifeRuntimeService = require(script.Systems.OperativeLifeRuntimeService)
local OperativeReviveSessionService = require(script.Systems.OperativeReviveSessionService)
local SquadFailureService = require(script.Systems.SquadFailureService)
local PersonalFlashlightService = require(script.Systems.PersonalFlashlightService)
local SquadPingService = require(script.Systems.SquadPingService)
local WorldFoundationService = require(script.Systems.WorldFoundationService)
local MissionDirectorService = require(script.Systems.MissionDirectorService)

WorldFoundationService.start()
OperativeLifeService.start()
SquadFailureService.start()
PersonalFlashlightService.start()
SquadPingService.start()
OperativeLifeRuntimeService.start()
OperativeReviveSessionService.start()
OperativeLifeDevelopmentHarness.start()
MovementValidationSystem.start()
MovementStateReplicationSystem.start()
EnemyDirectorService.start()
EnemyValidationProbeService.start()
OperativeCombatRuntimeService.start()
AmmunitionCacheService.start()
AmmunitionScarcityValidationProbeService.start()
MissionDirectorService.start()
ClassService.start()

print("[Living Kingdoms] Server bootstrap started")
