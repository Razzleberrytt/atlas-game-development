--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ensureNetworkFolder(folderName: string, remoteNames: { string })
	local existingNetwork = ReplicatedStorage:FindFirstChild(folderName)
	local network: Folder
	if existingNetwork == nil then
		network = Instance.new("Folder")
		network.Name = folderName
		network.Parent = ReplicatedStorage
	else
		assert(existingNetwork:IsA("Folder"), folderName .. " must be a Folder")
		network = existingNetwork
	end
	for _, remoteName in remoteNames do
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

local function ensureFlashlightNetwork()
	ensureNetworkFolder("FlashlightNetwork", { "ToggleIntent", "State" })
end

local function ensureSquadPingNetwork()
	ensureNetworkFolder("SquadPingNetwork", { "Intent", "State" })
end

local function ensureMissionNetwork()
	ensureNetworkFolder("MissionNetwork", { "State" })
end

local function ensureHordeNetwork()
	ensureNetworkFolder("HordeNetwork", { "State", "ChooseUpgrade" })
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
ensureHordeNetwork()
ensureClassNetwork()

local AmmunitionCacheService = require(script.Systems.AmmunitionCacheService)
local AmmunitionScarcityValidationProbeService = require(script.Systems.AmmunitionScarcityValidationProbeService)
local ClassService = require(script.Systems.ClassService)
local MovementValidationSystem = require(script.Systems.MovementValidationSystem)
local MovementStateReplicationSystem = require(script.Systems.MovementStateReplicationSystem)
local EnemyDirectorService = require(script.Systems.EnemyDirectorService)
local EnemyPresentationService = require(script.Systems.EnemyPresentationService)
local EnemyValidationProbeService = require(script.Systems.EnemyValidationProbeService)
local HordeExperienceService = require(script.Systems.HordeExperienceService)
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
EnemyPresentationService.start()
EnemyValidationProbeService.start()
OperativeCombatRuntimeService.start()
AmmunitionCacheService.start()
AmmunitionScarcityValidationProbeService.start()
HordeExperienceService.start()
MissionDirectorService.start()
ClassService.start()

print("[Living Kingdoms] Server bootstrap started — horde vertical slice active")
