--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

--[[
	Network publication is atomic for every newly-created network. Build and
	validate the complete remote family while its Folder is still unparented,
	then publish the Folder to ReplicatedStorage in one final step. This closes
	the replication window where a client could observe the parent network before
	one of its required children existed.

	Existing folders are still repaired in place for Studio/reload compatibility;
	wrong instance classes continue to fail closed rather than being replaced.
]]
local function ensureNetwork(
	networkName: string,
	remoteEventNames: { string },
	remoteFunctionNames: { string }?
): Folder
	local existingNetwork = ReplicatedStorage:FindFirstChild(networkName)
	local network: Folder
	local publishWhenComplete = false

	if existingNetwork == nil then
		network = Instance.new("Folder")
		network.Name = networkName
		publishWhenComplete = true
	else
		assert(existingNetwork:IsA("Folder"), networkName .. " must be a Folder")
		network = existingNetwork
	end

	for _, remoteName in remoteEventNames do
		local existingRemote = network:FindFirstChild(remoteName)
		if existingRemote == nil then
			local remote = Instance.new("RemoteEvent")
			remote.Name = remoteName
			remote.Parent = network
		else
			assert(
				existingRemote:IsA("RemoteEvent"),
				string.format("%s.%s must be a RemoteEvent", networkName, remoteName)
			)
		end
	end

	for _, remoteName in remoteFunctionNames or {} do
		local existingRemote = network:FindFirstChild(remoteName)
		if existingRemote == nil then
			local remote = Instance.new("RemoteFunction")
			remote.Name = remoteName
			remote.Parent = network
		else
			assert(
				existingRemote:IsA("RemoteFunction"),
				string.format("%s.%s must be a RemoteFunction", networkName, remoteName)
			)
		end
	end

	if publishWhenComplete then
		network.Parent = ReplicatedStorage
	end

	return network
end

local function ensureCombatNetwork()
	ensureNetwork("CombatNetwork", { "CombatPresentation", "FireIntent", "ReloadIntent" })
end

local function ensureRunBuildNetwork()
	ensureNetwork("RunBuildNetwork", { "State", "SubmitRelicChoice", "SubmitRelicReplacement" }, { "ReadState" })
end

local function ensureFlashlightNetwork()
	ensureNetwork("FlashlightNetwork", { "ToggleIntent", "State" })
end

local function ensureSurvivalNetwork()
	ensureNetwork("SurvivalNetwork", { "State" }, { "ReadState" })
end

local function ensureSquadPingNetwork()
	ensureNetwork("SquadPingNetwork", { "Intent", "State" })
end

local function ensureMissionNetwork()
	-- State is the live mission snapshot; Result is the one terminal debrief. Both
	-- are server-to-client disclosure only -- the mission owner accepts nothing.
	ensureNetwork("MissionNetwork", { "State", "Result" })
end

local function ensureClassNetwork()
	ensureNetwork("ClassNetwork", { "SelectionIntent", "ActionIntent", "State" }, { "ReadState" })
end

local function ensureWeaponLoadoutNetwork()
	ensureNetwork("WeaponLoadoutNetwork", { "SelectionIntent", "State" }, { "ReadState" })
end

local function ensureProgressionNetwork()
	ensureRunBuildNetwork()
	ensureNetwork("ProgressionNetwork", { "State", "ChooseUpgrade" }, { "ReadState" })
end

ensureCombatNetwork()
ensureFlashlightNetwork()
ensureSurvivalNetwork()
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
local OperationLifecycleService = require(script.Systems.OperationLifecycleService)
local MissionDirectorService = require(script.Systems.MissionDirectorService)
local WeaponLoadoutService = require(script.Systems.WeaponLoadoutService)
local SurvivalLootService = require(script.Systems.SurvivalLootService)
local NightCorruptionService = require(script.Systems.NightCorruptionService)

WorldFoundationService.start()
NightCorruptionService.start()
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
SurvivalLootService.start()
AmmunitionCacheService.start()
EnemyLootService.start()
AmmunitionScarcityValidationProbeService.start()
MissionDirectorService.start()
ClassService.start()
ClassValidationProbeService.start()
WeaponLoadoutService.start()
-- Last: the cleanup/replay owner subscribes to the already-running mission's
-- terminal boundary and drives the documented stop/start order from there.
OperationLifecycleService.start()

print("[Living Kingdoms] Server bootstrap started")
