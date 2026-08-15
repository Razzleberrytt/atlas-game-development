--!strict

local fs = require("@lune/fs")

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local presentationPath = "games/living-kingdoms/src/client/Presentation/RewardContainerViewportPresenter.luau"
local controllerPath = "games/living-kingdoms/src/client/Controllers/ExpeditionResultController.luau"
local presenter = fs.readFile(presentationPath)
local controller = fs.readFile(controllerPath)

for _, token in
	{
		"ModularAssetResolver",
		"GetGeneratedRoot",
		"CloneByAssetId",
		'"reward.chest.common"',
		'"reward.chest.rare"',
		'"reward.chest.boss"',
		'OutcomeId == "Completed"',
		'RewardDispositionId == "Banked"',
		'Instance.new("ViewportFrame")',
		'Instance.new("WorldModel")',
		"GetBoundingBox",
		"CurrentCamera",
		"PresentationOnly",
	}
do
	assert(contains(presenter, token), "reward-container presenter missing contract token " .. token)
end

assert(contains(presenter, 'if reward.SourceId == "Boss" then'))
assert(contains(presenter, 'if reward.Rarity == "Rare" then'))
assert(contains(presenter, "descendant:IsA(\"ProximityPrompt\")"))
assert(contains(presenter, "descendant:IsA(\"Script\")"))
assert(contains(controller, "require(script.Parent.Parent.Presentation.RewardContainerViewportPresenter)"))
assert(contains(controller, "RewardContainerViewportPresenter.create(rewardRow)"))
assert(contains(controller, "RewardContainerViewportPresenter.render(rewardViewport, snapshot)"))
assert(contains(controller, "layoutRewardPresentation(false)"))

for _, prohibited in
	{
		"FireServer",
		"InvokeServer",
		"OnServerEvent",
		"RemoteEvent",
		"RemoteFunction",
		"applyReward",
		"claimReward",
		"DataStore",
		"RunService",
		"RenderStepped",
		"Heartbeat",
	}
do
	assert(not contains(presenter, prohibited), "reward-container presenter gained authority/runtime token " .. prohibited)
end

print("RewardContainerViewportPresenterSourceAudit: modular debrief reward visuals remain client-only and authority-free")
