--!strict

local fs = require("@lune/fs")

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local presentationPath = "games/living-kingdoms/src/client/Presentation/RewardContainerViewportPresenter.luau"
local resultControllerPath = "games/living-kingdoms/src/client/Controllers/ExpeditionResultController.luau"
local runBuildControllerPath = "games/living-kingdoms/src/client/Controllers/RunBuildHUDController.luau"
local presenter = fs.readFile(presentationPath)
local resultController = fs.readFile(resultControllerPath)
local runBuildController = fs.readFile(runBuildControllerPath)

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
		"RunRpgContracts.RewardSourceIds",
		"RewardSourceIds.BossMilestone",
		"RewardSourceIds.EliteKill",
		"RewardSourceIds.SpecialInterrupt",
		"RewardSourceIds.HordeClear",
		"resolveRunRewardAssetId",
		"renderAssetId",
		"renderRunReward",
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
assert(contains(presenter, 'descendant:IsA("ProximityPrompt")'))
assert(contains(presenter, 'descendant:IsA("Script")'))
assert(contains(resultController, "require(script.Parent.Parent.Presentation.RewardContainerViewportPresenter)"))
assert(contains(resultController, "RewardContainerViewportPresenter.create(rewardRow)"))
assert(contains(resultController, "RewardContainerViewportPresenter.render(rewardViewport, snapshot)"))
assert(contains(resultController, "layoutRewardPresentation(false)"))

assert(contains(runBuildController, "require(script.Parent.Parent.Presentation.RewardContainerViewportPresenter)"))
assert(contains(runBuildController, "RewardContainerViewportPresenter.create(panel)"))
assert(contains(runBuildController, "RewardContainerViewportPresenter.renderRunReward(rewardViewport, reward)"))
assert(contains(runBuildController, "RewardContainerViewportPresenter.clear(rewardViewport)"))
assert(contains(runBuildController, 'local reward = if type(rewards) == "table" then rewards[1] else nil'))

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
	assert(
		not contains(presenter, prohibited),
		"reward-container presenter gained authority/runtime token " .. prohibited
	)
end

print(
	"RewardContainerViewportPresenterSourceAudit: debrief + live relic chest visuals remain client-only and authority-free"
)
