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
