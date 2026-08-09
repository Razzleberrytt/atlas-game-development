--!strict

-- BA-062 C4 source audit. One client coordinator must own numbered keyboard
-- detection while the two HUDs keep their existing semantic submit functions.
local fs = require("@lune/fs")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "BA-062 choice input coordinator assertion failed", 2)
	end
end

local root = "games/living-kingdoms/src/client/Controllers/"
local coordinator = fs.readFile(root .. "ChoiceInputCoordinator.luau")
local hordeHud = fs.readFile(root .. "HordeHUDController.luau")
local runBuildHud = fs.readFile(root .. "RunBuildHUDController.luau")

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local _, listenerCount = string.gsub(coordinator, "UserInputService%.InputBegan:Connect", "")
assert(listenerCount == 1, "the coordinator must own exactly one raw InputBegan listener")

for _, keyName in { "One", "Two", "Three", "KeypadOne", "KeypadTwo", "KeypadThree" } do
	assert(contains(coordinator, `Enum.KeyCode.{keyName}`), `missing numbered key mapping: {keyName}`)
end
assert(contains(coordinator, "gameProcessedEvent"), "processed input must be ignored")
assert(contains(coordinator, "ChoiceInputConflictResolver.resolve(activeOwnerIds())"), "routing must use fail-closed resolver")
assert(contains(coordinator, "resolution.DispatchAllowed ~= true"), "non-dispatch resolutions must stop routing")
assert(contains(coordinator, "resolution.OwnerId"), "accepted resolution must identify one owner")
assert(contains(coordinator, "registration.dispatchChoice(choiceIndex)"), "accepted input must dispatch through registration")
assert(contains(coordinator, "inputConnection:Disconnect()"), "the shared listener must disconnect when unused")

assert(contains(hordeHud, 'ChoiceInputCoordinator.register("UpgradeChoice"'))
assert(contains(hordeHud, "return upgradeInputActive"))
assert(contains(hordeHud, "submitUpgradeChoice"), "upgrade semantics must stay in HordeHUDController")
assert(contains(hordeHud, "progressionChooseUpgradeRemote:FireServer(upgradeId)"), "upgrade remote path must remain unchanged")

assert(contains(runBuildHud, 'ChoiceInputCoordinator.register("RelicChoice"'))
assert(contains(runBuildHud, "return choiceInputActive"))
assert(contains(runBuildHud, "submitChoice(selectionIndex)"), "relic choice semantics must stay in RunBuildHUDController")
assert(contains(runBuildHud, "submitReplacement(selectionIndex)"), "replacement number selection must stay supported")
assert(contains(runBuildHud, "submitChoiceRemote:FireServer"), "relic choice remote path must remain unchanged")
assert(contains(runBuildHud, "submitReplacementRemote:FireServer"), "replacement remote path must remain unchanged")

for _, source in { hordeHud, runBuildHud } do
	assert(not contains(source, "UserInputService.InputBegan:Connect"), "HUDs must not retain duplicate numbered listeners")
	assert(not contains(source, "Enum.KeyCode.One"), "HUDs must not directly detect numbered keys")
	assert(contains(source, "unregisterChoiceInput()"), "HUD registration must be released on teardown")
	assert(contains(source, ".Activated:Connect"), "GUI click/tap activation must remain available")
end

for _, forbidden in { "FireServer", "InvokeServer", "RemoteEvent", "RemoteFunction", "Instance.new", "DataStore" } do
	assert(not contains(coordinator, forbidden), `coordinator must remain input-only: {forbidden}`)
end

print("BA-062 ChoiceInputCoordinator: one fail-closed numbered listener routes existing HUD submit paths")
