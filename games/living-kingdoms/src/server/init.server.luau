--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ensureRunBuildNetwork()
	local existingNetwork = ReplicatedStorage:FindFirstChild("RunBuildNetwork")
	local network: Folder
	if existingNetwork == nil then
		network = Instance.new("Folder")
		network.Name = "RunBuildNetwork"
		network.Parent = ReplicatedStorage
	else
		assert(existingNetwork:IsA("Folder"), "RunBuildNetwork must be a Folder")
		network = existingNetwork
	end
	for _, remoteName in { "State", "SubmitRelicChoice", "SubmitRelicReplacement" } do
		local existingRemote = network:FindFirstChild(remoteName)
		if existingRemote == nil then
			local remote = Instance.new("RemoteEvent")
			remote.Name = remoteName
			remote.Parent = network
		else
			assert(existingRemote:IsA("RemoteEvent"), "RunBuildNetwork." .. remoteName .. " must be a RemoteEvent")
		end
	end
	local existingReadState = network:FindFirstChild("ReadState")
	if existingReadState == nil then
		local readState = Instance.new("RemoteFunction")
		readState.Name = "ReadState"
		readState.Parent = network
	else
		assert(existingReadState:IsA("RemoteFunction"), "RunBuildNetwork.ReadState must be a RemoteFunction")
	end
end

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
	for _, remoteName in { "SelectionIntent", "ActionIntent", "State" } do
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

local function ensureWeaponLoadoutNetwork()
	local existingNetwork = ReplicatedStorage:FindFirstChild("WeaponLoadoutNetwork")
	local network: Folder
	if existingNetwork == nil then
		network = Instance.new("Folder")
		network.Name = "WeaponLoadoutNetwork"
		network.Parent = ReplicatedStorage
	else
		assert(existingNetwork:IsA("Folder"), "WeaponLoadoutNetwork must be a Folder")
		network = existingNetwork
	end
	for _, remoteName in { "SelectionIntent", "State" } do
		local existing = network:FindFirstChild(remoteName)
		if existing == nil then
			local remote = Instance.new("RemoteEvent")
			remote.Name = remoteName
			remote.Parent = network
		else
			assert(existing:IsA("RemoteEvent"), remoteName .. " must be a RemoteEvent")
		end
	end
	local existingRead = network:FindFirstChild("ReadState")
	if existingRead == nil then
		local read = Instance.new("RemoteFunction")
		read.Name = "ReadState"
		read.Parent = network
	else
		assert(existingRead:IsA("RemoteFunction"), "WeaponLoadoutNetwork.ReadState must be a RemoteFunction")
	end
end

local function ensureProgressionNetwork()
	ensureRunBuildNetwork()
	local existingNetwork = ReplicatedStorage:FindFirstChild("ProgressionNetwork")
	local network: Folder
	if existingNetwork == nil then
		network = Instance.new("Folder")
		network.Name = "ProgressionNetwork"
		network.Parent = ReplicatedStorage
	else
		assert(existingNetwork:IsA("Folder"), "ProgressionNetwork must be a Folder")
		network = existingNetwork
	end
	for _, remoteName in { "State", "ChooseUpgrade" } do
		local existingRemote = network:FindFirstChild(remoteName)
		if existingRemote == nil then
			local remote = Instance.new("RemoteEvent")
			remote.Name = remoteName
			remote.Parent = network
		else
			assert(existingRemote:IsA("RemoteEvent"), "ProgressionNetwork." .. remoteName .. " must be a RemoteEvent")
		end
	end
	local existingReadState = network:FindFirstChild("ReadState")
	if existingReadState == nil then
		local readState = Instance.new("RemoteFunction")
		readState.Name = "ReadState"
		readState.Parent = network
	else
		assert(existingReadState:IsA("RemoteFunction"), "ProgressionNetwork.ReadState must be a RemoteFunction")
	end
end

ensureFlashlightNetwork()
ensureSquadPingNetwork()
ensureMissionNetwork()
ensureClassNetwork()
ensureWeaponLoadoutNetwork()
ensureProgressionNetwork()

local AmmunitionCacheService = require(script.Systems.AmmunitionCacheService)
local AmmunitionScarcityValidationProbeService = require(script.Systems.AmmunitionScarcityValidationProbeService)
local ClassService = require(script.Systems.ClassService)
local ClassValidationProbeService = require(script.Systems.ClassValidationProbeService)
local MovementValidationSystem = require(script.Systems.MovementValidationSystem)
local MovementStateReplicationSystem = require(script.Systems.MovementStateReplicationSystem)
local EnemyDirectorService = require(script.Systems.EnemyDirectorService)
local EnemyLootService = require(script.Systems.EnemyLootService)
local EnemyPresentationService = require(script.Systems.EnemyPresentationService)
local EnemyValidationProbeService = require(script.Systems.EnemyValidationProbeService)
local HordeExperienceService = require(script.Systems.HordeExperienceService)
local OperativeCombatRuntimeService = require(script.Systems.OperativeCombatRuntimeService)
local OperativeLifeDevelopmentHarness = require(script.Systems.OperativeLifeDevelopmentHarness)
local OperativeLifeService = require(script.Systems.OperativeLifeService)
local OperativeLifeRuntimeService = require(script.Systems.OperativeLifeRuntimeService)
local OperativeReviveSessionService = require(script.Systems.OperativeReviveSessionService)
local RunBuildService = require(script.Systems.RunBuildService)
local RunProgressionService = require(script.Systems.RunProgressionService)
local ScreamerInterruptRewardService = require(script.Systems.ScreamerInterruptRewardService)
local SquadFailureService = require(script.Systems.SquadFailureService)
local PersonalFlashlightService = require(script.Systems.PersonalFlashlightService)
local SquadPingService = require(script.Systems.SquadPingService)
local WorldFoundationService = require(script.Systems.WorldFoundationService)
local MatchResultService = require(script.Systems.MatchResultService)
local MissionDirectorService = require(script.Systems.MissionDirectorService)
local WeaponLoadoutService = require(script.Systems.WeaponLoadoutService)

WorldFoundationService.start()
-- The contribution ledger records only already-committed facts, so it starts
-- before every owner that could commit one and before the mission can reach its
-- terminal boundary.
MatchResultService.start()
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
RunBuildService.start()
RunProgressionService.start()
HordeExperienceService.start()
ScreamerInterruptRewardService.start()
EnemyPresentationService.start()
EnemyValidationProbeService.start()
OperativeCombatRuntimeService.start()
AmmunitionCacheService.start()
EnemyLootService.start()
AmmunitionScarcityValidationProbeService.start()
MissionDirectorService.start()
ClassService.start()
ClassValidationProbeService.start()
WeaponLoadoutService.start()

print("[Living Kingdoms] Server bootstrap started")
