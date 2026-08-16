--!strict

-- Client-only adapter from server-authored reward facts to the shared modular
-- reward-container library. It renders presentation geometry in a ViewportFrame
-- and never sends requests, grants items, or mutates authoritative reward state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModularAssetResolver = require(ReplicatedStorage.Shared.Assets.ModularAssetResolver)
local RunRpgContracts = require(ReplicatedStorage.Shared.RPG.RunRpgContracts)

local Presenter = {}

local WORLD_NAME = "RewardContainerWorld"
local CAMERA_NAME = "RewardContainerCamera"
local COMMON_ASSET_ID = "reward.chest.common"
local RARE_ASSET_ID = "reward.chest.rare"
local BOSS_ASSET_ID = "reward.chest.boss"
local RewardSourceIds = RunRpgContracts.RewardSourceIds

local function isSecuredRewardSnapshot(snapshot: any): boolean
	return type(snapshot) == "table"
		and snapshot.OutcomeId == "Completed"
		and snapshot.RewardDispositionId == "Banked"
		and type(snapshot.Rewards) == "table"
		and #snapshot.Rewards > 0
end

function Presenter.resolveAssetId(snapshot: any): string?
	if not isSecuredRewardSnapshot(snapshot) then
		return nil
	end

	local hasRareReward = false
	for _, reward in ipairs(snapshot.Rewards) do
		if type(reward) == "table" then
			if reward.SourceId == "Boss" then
				return BOSS_ASSET_ID
			end
			if reward.Rarity == "Rare" then
				hasRareReward = true
			end
		end
	end
	return if hasRareReward then RARE_ASSET_ID else COMMON_ASSET_ID
end

function Presenter.resolveRunRewardAssetId(reward: any): string?
	if
		type(reward) ~= "table"
		or type(reward.sourceId) ~= "string"
		or type(reward.offeredRelicIds) ~= "table"
		or #reward.offeredRelicIds == 0
	then
		return nil
	end

	local sourceId = reward.sourceId
	if sourceId == RewardSourceIds.BossMilestone then
		return BOSS_ASSET_ID
	end
	if sourceId == RewardSourceIds.EliteKill or sourceId == RewardSourceIds.SpecialInterrupt then
		return RARE_ASSET_ID
	end
	if
		sourceId == RewardSourceIds.HordeClear
		or sourceId == RewardSourceIds.ObjectiveCompletion
		or sourceId == RewardSourceIds.AuthoredContainer
	then
		return COMMON_ASSET_ID
	end
	return nil
end

local function worldFor(viewport: ViewportFrame): WorldModel
	local existing = viewport:FindFirstChild(WORLD_NAME)
	if existing ~= nil and existing:IsA("WorldModel") then
		return existing
	end
	if existing ~= nil then
		existing:Destroy()
	end
	local world = Instance.new("WorldModel")
	world.Name = WORLD_NAME
	world.Parent = viewport
	return world
end

local function cameraFor(viewport: ViewportFrame): Camera
	local existing = viewport:FindFirstChild(CAMERA_NAME)
	if existing ~= nil and existing:IsA("Camera") then
		viewport.CurrentCamera = existing
		return existing
	end
	if existing ~= nil then
		existing:Destroy()
	end
	local camera = Instance.new("Camera")
	camera.Name = CAMERA_NAME
	camera.FieldOfView = 35
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return camera
end

local function sanitizeClone(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		elseif
			descendant:IsA("ProximityPrompt")
			or descendant:IsA("ClickDetector")
			or descendant:IsA("Script")
			or descendant:IsA("LocalScript")
			or descendant:IsA("ModuleScript")
		then
			descendant:Destroy()
		end
	end
end

local function frameModel(model: Model, camera: Camera)
	local boundsCFrame, boundsSize = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() - boundsCFrame.Position)

	local extent = math.max(boundsSize.X, boundsSize.Y, boundsSize.Z)
	local distance = math.max(7, extent * 1.55)
	local height = math.max(3, boundsSize.Y * 0.65)
	camera.CFrame = CFrame.lookAt(Vector3.new(distance, height, distance * 1.15), Vector3.new(0, 0, 0))
end

function Presenter.create(parent: Instance): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "RewardContainerViewport"
	viewport.BackgroundTransparency = 1
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(105, 111, 118)
	viewport.LightColor = Color3.fromRGB(235, 224, 205)
	viewport.LightDirection = Vector3.new(-0.65, -1, -0.45)
	viewport.Visible = false
	viewport.Parent = parent
	worldFor(viewport)
	cameraFor(viewport)
	return viewport
end

function Presenter.clear(viewport: ViewportFrame)
	local world = worldFor(viewport)
	world:ClearAllChildren()
	viewport:SetAttribute("RewardContainerAssetId", nil)
	viewport.Visible = false
end

function Presenter.renderAssetId(viewport: ViewportFrame, assetId: string): boolean
	Presenter.clear(viewport)
	if assetId == "" then
		return false
	end

	local generatedRoot = ModularAssetResolver.GetGeneratedRoot(ReplicatedStorage)
	if generatedRoot == nil then
		return false
	end
	local clone = ModularAssetResolver.CloneByAssetId(generatedRoot, assetId)
	if clone == nil or not clone:IsA("Model") then
		if clone ~= nil then
			clone:Destroy()
		end
		return false
	end
	local model = clone :: Model
	if model.PrimaryPart == nil then
		model:Destroy()
		return false
	end

	sanitizeClone(model)
	local world = worldFor(viewport)
	model.Name = "RewardContainerPreview"
	model:SetAttribute("PresentationOnly", true)
	model.Parent = world
	frameModel(model, cameraFor(viewport))
	viewport:SetAttribute("RewardContainerAssetId", assetId)
	viewport.Visible = true
	return true
end

function Presenter.render(viewport: ViewportFrame, snapshot: any): boolean
	local assetId = Presenter.resolveAssetId(snapshot)
	if assetId == nil then
		Presenter.clear(viewport)
		return false
	end
	return Presenter.renderAssetId(viewport, assetId)
end

function Presenter.renderRunReward(viewport: ViewportFrame, reward: any): boolean
	local assetId = Presenter.resolveRunRewardAssetId(reward)
	if assetId == nil then
		Presenter.clear(viewport)
		return false
	end
	return Presenter.renderAssetId(viewport, assetId)
end

return table.freeze(Presenter)
