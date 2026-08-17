--!strict

local fs = require("@lune/fs")

local source = fs.readFile("games/living-kingdoms/src/server/init.server.luau")

local function occurrenceCount(haystack: string, needle: string): number
	local count = 0
	local cursor = 1
	while true do
		local startIndex = string.find(haystack, needle, cursor, true)
		if startIndex == nil then
			return count
		end
		count += 1
		cursor = startIndex + #needle
	end
end

assert(
	string.find(source, "local function ensureNetwork(", 1, true) ~= nil,
	"server bootstrap must use one network builder"
)
assert(
	string.find(source, "local publishWhenComplete = false", 1, true) ~= nil,
	"network builder must distinguish new folders from existing folders"
)
assert(
	string.find(source, "publishWhenComplete = true", 1, true) ~= nil,
	"new network folders must be marked for deferred publication"
)
assert(
	occurrenceCount(source, "network.Parent = ReplicatedStorage") == 1,
	"network folders must be published through one canonical atomic path"
)

local eventLoop = string.find(source, "for _, remoteName in remoteEventNames do", 1, true)
local functionLoop = string.find(source, "for _, remoteName in remoteFunctionNames or {} do", 1, true)
local publishGate = string.find(source, "if publishWhenComplete then", 1, true)
local publish = string.find(source, "network.Parent = ReplicatedStorage", 1, true)
assert(
	eventLoop ~= nil and functionLoop ~= nil and publishGate ~= nil and publish ~= nil,
	"atomic network stages must exist"
)
assert(eventLoop < functionLoop, "RemoteEvents must be constructed before RemoteFunctions are finalized")
assert(
	functionLoop < publishGate and publishGate < publish,
	"network publication must happen only after child construction"
)

for _, contract in
	{
		'ensureNetwork("CombatNetwork", { "CombatPresentation", "FireIntent", "ReloadIntent" })',
		'ensureNetwork("RunBuildNetwork", { "State", "SubmitRelicChoice", "SubmitRelicReplacement" }, { "ReadState" })',
		'ensureNetwork("FlashlightNetwork", { "ToggleIntent", "State" })',
		'ensureNetwork("SurvivalNetwork", { "State" }, { "ReadState" })',
		'ensureNetwork("SquadPingNetwork", { "Intent", "State" })',
		'ensureNetwork("MissionNetwork", { "State", "Result" })',
		'ensureNetwork("ClassNetwork", { "SelectionIntent", "ActionIntent", "State" }, { "ReadState" })',
		'ensureNetwork("WeaponLoadoutNetwork", { "SelectionIntent", "State" }, { "ReadState" })',
		'ensureNetwork("ProgressionNetwork", { "State", "ChooseUpgrade" }, { "ReadState" })',
	}
do
	assert(string.find(source, contract, 1, true) ~= nil, "missing canonical network contract: " .. contract)
end

assert(
	string.find(source, "ensureRunBuildNetwork()", 1, true) ~= nil,
	"progression bootstrap must continue to guarantee RunBuildNetwork first"
)

print("AtomicNetworkPublicationSourceAudit: new network families publish only after required children exist")
