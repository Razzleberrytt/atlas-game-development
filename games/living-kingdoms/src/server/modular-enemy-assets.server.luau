--!strict

-- Bounded presentation bootstrap: one EnemyEntities connection and one deferred
-- wait per spawned model. EnemyPresentationService still owns the animated shell;
-- this script only mounts canonical modular visual components after that shell exists.

local Workspace = game:GetService("Workspace")

local ModularEnemyAssetPresentationService = require(script.Parent.Systems.ModularEnemyAssetPresentationService)

local ENEMY_FOLDER_NAME = "EnemyEntities"
local PRESENTATION_MODEL_NAME = "ExclusionWalkerPresentation"
local PRESENTATION_WAIT_SECONDS = 4
local ENEMY_FOLDER_WAIT_SECONDS = 20

local folderInstance = Workspace:WaitForChild(ENEMY_FOLDER_NAME, ENEMY_FOLDER_WAIT_SECONDS)
assert(folderInstance ~= nil, ENEMY_FOLDER_NAME .. " did not become available before the modular enemy asset timeout")
assert(folderInstance:IsA("Folder"), ENEMY_FOLDER_NAME .. " must be a Folder")
local enemyFolder = folderInstance :: Folder

local function applyWhenReady(enemyModel: Model)
	task.defer(function()
		if enemyModel.Parent == nil then
			return
		end
		local presentation = enemyModel:FindFirstChild(PRESENTATION_MODEL_NAME)
		if presentation == nil then
			presentation = enemyModel:WaitForChild(PRESENTATION_MODEL_NAME, PRESENTATION_WAIT_SECONDS)
		end
		if presentation ~= nil and presentation:IsA("Model") and enemyModel.Parent ~= nil then
			ModularEnemyAssetPresentationService.apply(enemyModel, presentation)
		end
	end)
end

for _, child in enemyFolder:GetChildren() do
	if child:IsA("Model") then
		applyWhenReady(child)
	end
end

enemyFolder.ChildAdded:Connect(function(child)
	if child:IsA("Model") then
		applyWhenReady(child)
	end
end)

print("[Living Kingdoms] Modular enemy asset presentation integration ready")
