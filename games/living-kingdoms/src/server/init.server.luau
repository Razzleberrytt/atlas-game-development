--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

--[[
	Service isolation.

	The bootstrap requires every server system and starts them in a deliberate
	order, and it used to do both bare. One service erroring during require -- or
	during start -- took every service after it with it, leaving a server that
	still accepts players while the mission, loot, class, loadout and replay
	owners behind the failure never came up, with no error naming which one broke.
	The client bootstrap already contains its controllers this way; this is the
	server counterpart. The order still carries meaning, so nothing here reorders
	or defers anything.
]]
local failedServices: { string } = {}

local function safeRequire(name: string, loader: () -> any): any?
	local ok, moduleOrError = pcall(loader)
	if ok then
		return moduleOrError
	end
	table.insert(failedServices, name)
	warn(string.format("[Server] service %s failed to load: %s", name, tostring(moduleOrError)))
	return nil
end

--[[
	The call itself stays written out at each site rather than being reached
	through a method name. Many source audits pin the exact `X.start()` token and
	their relative order to prove an owner is actually started before its
	consumers, and routing the call through a string would make those audits pass
	while proving nothing.
]]
local function safeStep(name: string, step: () -> ())
	local ok, err = pcall(step)
	if not ok then
		table.insert(failedServices, name)
		warn(string.format("[Server] service step %s failed: %s", name, tostring(err)))
	end
end

--[[
	Two owners are not containable. WorldFoundationService establishes the world
	root that later owners and several separate server scripts resolve against,
	and MatchResultService is the contribution ledger that must exist before any
	owner able to commit a fact starts. Continuing past either would produce a
	server that looks alive while committing facts no ledger recorded, so these
	abort the bootstrap loudly and by name instead of failing open.
]]
local function criticalStep(name: string, step: () -> ())
	local ok, err = pcall(step)
	if ok then
		return
	end
	table.insert(failedServices, name)
	warn(
		string.format("[Server] ordering-critical owner %s failed; aborting server bootstrap: %s", name, tostring(err))
	)
	error(string.format("[Server] server bootstrap aborted at %s", name), 0)
end

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

local AmmunitionCacheService = safeRequire("AmmunitionCacheService", function()
	return require(script.Systems.AmmunitionCacheService)
end)
local AmmunitionScarcityValidationProbeService = safeRequire("AmmunitionScarcityValidationProbeService", function()
	return require(script.Systems.AmmunitionScarcityValidationProbeService)
end)
local ClassService = safeRequire("ClassService", function()
	return require(script.Systems.ClassService)
end)
local ClassValidationProbeService = safeRequire("ClassValidationProbeService", function()
	return require(script.Systems.ClassValidationProbeService)
end)
local MovementValidationSystem = safeRequire("MovementValidationSystem", function()
	return require(script.Systems.MovementValidationSystem)
end)
local MovementStateReplicationSystem = safeRequire("MovementStateReplicationSystem", function()
	return require(script.Systems.MovementStateReplicationSystem)
end)
local EnemyDirectorService = safeRequire("EnemyDirectorService", function()
	return require(script.Systems.EnemyDirectorService)
end)
local EnemyLootService = safeRequire("EnemyLootService", function()
	return require(script.Systems.EnemyLootService)
end)
local EnemyPresentationService = safeRequire("EnemyPresentationService", function()
	return require(script.Systems.EnemyPresentationService)
end)
local EnemyValidationProbeService = safeRequire("EnemyValidationProbeService", function()
	return require(script.Systems.EnemyValidationProbeService)
end)
local HordeExperienceService = safeRequire("HordeExperienceService", function()
	return require(script.Systems.HordeExperienceService)
end)
local OperativeCombatRuntimeService = safeRequire("OperativeCombatRuntimeService", function()
	return require(script.Systems.OperativeCombatRuntimeService)
end)
local OperativeLifeDevelopmentHarness = safeRequire("OperativeLifeDevelopmentHarness", function()
	return require(script.Systems.OperativeLifeDevelopmentHarness)
end)
local OperativeLifeService = safeRequire("OperativeLifeService", function()
	return require(script.Systems.OperativeLifeService)
end)
local OperativeLifeRuntimeService = safeRequire("OperativeLifeRuntimeService", function()
	return require(script.Systems.OperativeLifeRuntimeService)
end)
local OperativeReviveSessionService = safeRequire("OperativeReviveSessionService", function()
	return require(script.Systems.OperativeReviveSessionService)
end)
local RunBuildService = safeRequire("RunBuildService", function()
	return require(script.Systems.RunBuildService)
end)
local RunProgressionService = safeRequire("RunProgressionService", function()
	return require(script.Systems.RunProgressionService)
end)
local ScreamerInterruptRewardService = safeRequire("ScreamerInterruptRewardService", function()
	return require(script.Systems.ScreamerInterruptRewardService)
end)
local SquadFailureService = safeRequire("SquadFailureService", function()
	return require(script.Systems.SquadFailureService)
end)
local PersonalFlashlightService = safeRequire("PersonalFlashlightService", function()
	return require(script.Systems.PersonalFlashlightService)
end)
local SquadPingService = safeRequire("SquadPingService", function()
	return require(script.Systems.SquadPingService)
end)
local WorldFoundationService = safeRequire("WorldFoundationService", function()
	return require(script.Systems.WorldFoundationService)
end)
local MatchResultService = safeRequire("MatchResultService", function()
	return require(script.Systems.MatchResultService)
end)
local OperationLifecycleService = safeRequire("OperationLifecycleService", function()
	return require(script.Systems.OperationLifecycleService)
end)
local MissionDirectorService = safeRequire("MissionDirectorService", function()
	return require(script.Systems.MissionDirectorService)
end)
local WeaponLoadoutService = safeRequire("WeaponLoadoutService", function()
	return require(script.Systems.WeaponLoadoutService)
end)
local SurvivalLootService = safeRequire("SurvivalLootService", function()
	return require(script.Systems.SurvivalLootService)
end)
local NightCorruptionService = safeRequire("NightCorruptionService", function()
	return require(script.Systems.NightCorruptionService)
end)

criticalStep("WorldFoundationService.start", function()
	assert(WorldFoundationService ~= nil, "WorldFoundationService failed to load")
	WorldFoundationService.start()
end)
safeStep("NightCorruptionService.start", function()
	if NightCorruptionService ~= nil then
		NightCorruptionService.start()
	end
end)
-- The contribution ledger records only already-committed facts, so it starts
-- before every owner that could commit one and before the mission can reach its
-- terminal boundary.
criticalStep("MatchResultService.start", function()
	assert(MatchResultService ~= nil, "MatchResultService failed to load")
	MatchResultService.start()
end)
safeStep("OperativeLifeService.start", function()
	if OperativeLifeService ~= nil then
		OperativeLifeService.start()
	end
end)
safeStep("SquadFailureService.start", function()
	if SquadFailureService ~= nil then
		SquadFailureService.start()
	end
end)
safeStep("PersonalFlashlightService.start", function()
	if PersonalFlashlightService ~= nil then
		PersonalFlashlightService.start()
	end
end)
safeStep("SquadPingService.start", function()
	if SquadPingService ~= nil then
		SquadPingService.start()
	end
end)
safeStep("OperativeLifeRuntimeService.start", function()
	if OperativeLifeRuntimeService ~= nil then
		OperativeLifeRuntimeService.start()
	end
end)
safeStep("OperativeReviveSessionService.start", function()
	if OperativeReviveSessionService ~= nil then
		OperativeReviveSessionService.start()
	end
end)
safeStep("OperativeLifeDevelopmentHarness.start", function()
	if OperativeLifeDevelopmentHarness ~= nil then
		OperativeLifeDevelopmentHarness.start()
	end
end)
safeStep("MovementValidationSystem.start", function()
	if MovementValidationSystem ~= nil then
		MovementValidationSystem.start()
	end
end)
safeStep("MovementStateReplicationSystem.start", function()
	if MovementStateReplicationSystem ~= nil then
		MovementStateReplicationSystem.start()
	end
end)
safeStep("EnemyDirectorService.start", function()
	if EnemyDirectorService ~= nil then
		EnemyDirectorService.start()
	end
end)
safeStep("RunBuildService.start", function()
	if RunBuildService ~= nil then
		RunBuildService.start()
	end
end)
safeStep("RunProgressionService.start", function()
	if RunProgressionService ~= nil then
		RunProgressionService.start()
	end
end)
safeStep("HordeExperienceService.start", function()
	if HordeExperienceService ~= nil then
		HordeExperienceService.start()
	end
end)
safeStep("ScreamerInterruptRewardService.start", function()
	if ScreamerInterruptRewardService ~= nil then
		ScreamerInterruptRewardService.start()
	end
end)
safeStep("EnemyPresentationService.start", function()
	if EnemyPresentationService ~= nil then
		EnemyPresentationService.start()
	end
end)
safeStep("EnemyValidationProbeService.start", function()
	if EnemyValidationProbeService ~= nil then
		EnemyValidationProbeService.start()
	end
end)
safeStep("OperativeCombatRuntimeService.start", function()
	if OperativeCombatRuntimeService ~= nil then
		OperativeCombatRuntimeService.start()
	end
end)
safeStep("SurvivalLootService.start", function()
	if SurvivalLootService ~= nil then
		SurvivalLootService.start()
	end
end)
safeStep("AmmunitionCacheService.start", function()
	if AmmunitionCacheService ~= nil then
		AmmunitionCacheService.start()
	end
end)
safeStep("EnemyLootService.start", function()
	if EnemyLootService ~= nil then
		EnemyLootService.start()
	end
end)
safeStep("AmmunitionScarcityValidationProbeService.start", function()
	if AmmunitionScarcityValidationProbeService ~= nil then
		AmmunitionScarcityValidationProbeService.start()
	end
end)
safeStep("MissionDirectorService.start", function()
	if MissionDirectorService ~= nil then
		MissionDirectorService.start()
	end
end)
safeStep("ClassService.start", function()
	if ClassService ~= nil then
		ClassService.start()
	end
end)
safeStep("ClassValidationProbeService.start", function()
	if ClassValidationProbeService ~= nil then
		ClassValidationProbeService.start()
	end
end)
safeStep("WeaponLoadoutService.start", function()
	if WeaponLoadoutService ~= nil then
		WeaponLoadoutService.start()
	end
end)
-- Last: the cleanup/replay owner subscribes to the already-running mission's
-- terminal boundary and drives the documented stop/start order from there.
safeStep("OperationLifecycleService.start", function()
	if OperationLifecycleService ~= nil then
		OperationLifecycleService.start()
	end
end)

print("[Living Kingdoms] Server bootstrap started")

--[[
	A service that failed to load or start is reported by name rather than left to
	be inferred from missing gameplay. The count is the fastest signal that
	something did not come up, and the names say which.
]]
if #failedServices > 0 then
	warn(string.format("[Server] %d service step(s) failed: %s", #failedServices, table.concat(failedServices, ", ")))
end
