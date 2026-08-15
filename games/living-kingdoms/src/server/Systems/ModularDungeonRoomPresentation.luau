--!strict

-- Presentation-only adapter from authoritative expedition room placements to the
-- generated modular dungeon kit. The canonical room planner, graybox collision,
-- connectors, reveal barriers, encounters, and lifecycle remain authoritative.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModularAssetResolver = require(ReplicatedStorage.Shared.Assets.ModularAssetResolver)
local ModularAssetProductionCatalog = require(ReplicatedStorage.Shared.Config.ModularAssetProductionCatalog)
local RoomAssemblyContracts = require(ReplicatedStorage.Shared.Expeditions.RoomAssemblyContracts)

local Presentation = {}

local RoleIds = RoomAssemblyContracts.RoleIds
local ASSET_READY_WAIT_SECONDS = 0.75
local SHELL_NAME = "ModularDungeonShell"
local FALLBACK_STATUS = "ProceduralFallback"
local MODULAR_STATUS = "ModularGeneratedAsset"

local readinessWaitSpent = false

local ASSET_ID_BY_ROLE = table.freeze({
	[RoleIds.Entry] = "dungeon.room.empty.a",
	[RoleIds.Traversal] = "dungeon.corridor.straight.a",
	[RoleIds.Combat] = "dungeon.room.combat.a",
	[RoleIds.Elite] = "dungeon.room.combat.a",
	[RoleIds.Boss] = "dungeon.arena.boss.a",
	[RoleIds.Secret] = "dungeon.room.secret.a",
})

local catalogDungeonAssetIds: { [string]: boolean } = {}
for _, definition in ipairs(ModularAssetProductionCatalog.Dungeon.Modules) do
	catalogDungeonAssetIds[definition.id] = true
end
for roleId, assetId in pairs(ASSET_ID_BY_ROLE) do
	assert(
		catalogDungeonAssetIds[assetId] == true,
		`modular dungeon role {roleId} references unknown asset {assetId}`
	)
end

type PartSnapshot = {
	part: BasePart,
	localCFrame: CFrame,
	size: Vector3,
}

local function stripSourceIdentity(instance: Instance)
	instance:SetAttribute("AssetId", nil)
	instance:SetAttribute("PackId", nil)
	instance:SetAttribute("CatalogVersion", nil)
	instance:SetAttribute("GeneratedPrototype", nil)
end

local function sanitizeShell(model: Model)
	stripSourceIdentity(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		stripSourceIdentity(descendant)
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		elseif
			descendant:IsA("Attachment")
			or descendant:IsA("ProximityPrompt")
			or descendant:IsA("ClickDetector")
			or descendant:IsA("Script")
			or descendant:IsA("LocalScript")
			or descendant:IsA("ModuleScript")
		then
			descendant:Destroy()
		end
	end
end

local function removeBossEndWalls(model: Model, root: BasePart)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == "ArenaWall" then
			local localPosition = root.CFrame:PointToObjectSpace(descendant.Position)
			if math.abs(localPosition.Z) > math.abs(localPosition.X) then
				descendant:Destroy()
			end
		end
	end
end

local function fitShellToPlacement(model: Model, root: BasePart, placement: any): boolean
	local size = placement.Size
	local center = placement.Center
	if
		type(size) ~= "table"
		or type(center) ~= "table"
		or type(size.x) ~= "number"
		or type(size.y) ~= "number"
		or type(size.z) ~= "number"
		or type(center.x) ~= "number"
		or type(center.z) ~= "number"
		or size.x <= 0
		or size.y <= 0
		or size.z <= 0
		or root.Size.X <= 0
		or root.Size.Z <= 0
	then
		return false
	end

	local scaleX = size.x / root.Size.X
	local scaleY = size.y / ModularAssetProductionCatalog.Dungeon.WallHeightStuds
	local scaleZ = size.z / root.Size.Z
	local targetRootCFrame = CFrame.new(center.x, 0, center.z)
	local snapshots: { PartSnapshot } = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(snapshots, {
				part = descendant,
				localCFrame = root.CFrame:ToObjectSpace(descendant.CFrame),
				size = descendant.Size,
			})
		end
	end

	for _, snapshot in ipairs(snapshots) do
		local localPosition = snapshot.localCFrame.Position
		local scaledPosition = Vector3.new(
			localPosition.X * scaleX,
			localPosition.Y * scaleY,
			localPosition.Z * scaleZ
		)
		local partScaleY = if snapshot.part == root then 1 else scaleY
		snapshot.part.Size = Vector3.new(
			snapshot.size.X * scaleX,
			snapshot.size.Y * partScaleY,
			snapshot.size.Z * scaleZ
		)
		snapshot.part.CFrame = targetRootCFrame * CFrame.new(scaledPosition) * snapshot.localCFrame.Rotation
	end
	return true
end

local function cloneAsset(assetId: string): Instance?
	local generatedRoot = ModularAssetResolver.GetGeneratedRoot(ReplicatedStorage)
	local clone = if generatedRoot ~= nil
		then ModularAssetResolver.CloneByAssetId(generatedRoot, assetId)
		else nil
	if clone ~= nil then
		return clone
	end

	if readinessWaitSpent then
		return nil
	end
	readinessWaitSpent = true
	if
		ModularAssetResolver.WaitForGeneratedAssetById(
			ReplicatedStorage,
			assetId,
			ASSET_READY_WAIT_SECONDS
		) == nil
	then
		return nil
	end

	generatedRoot = ModularAssetResolver.GetGeneratedRoot(ReplicatedStorage)
	return if generatedRoot ~= nil
		then ModularAssetResolver.CloneByAssetId(generatedRoot, assetId)
		else nil
end

local function hideAuthoritativeGrayboxVisuals(roomModel: Model)
	for _, name in ipairs({ "Floor", "WestWall", "EastWall" }) do
		local graybox = roomModel:FindFirstChild(name)
		if graybox ~= nil and graybox:IsA("BasePart") then
			graybox.Transparency = 1
			graybox.CastShadow = false
			graybox:SetAttribute("ModularVisualProxy", true)
			graybox:SetAttribute("GameplayCollisionRetained", true)
		end
	end
end

function Presentation.apply(roomModel: Model, placement: any): boolean
	if roomModel:FindFirstChild(SHELL_NAME) ~= nil then
		return true
	end

	local roleId = placement.RoleId
	local assetId = if type(roleId) == "string" then ASSET_ID_BY_ROLE[roleId] else nil
	if assetId == nil then
		roomModel:SetAttribute("ModularDungeonVisualStatus", FALLBACK_STATUS)
		return false
	end
	roomModel:SetAttribute("ModularDungeonRequestedAssetId", assetId)

	local clone = cloneAsset(assetId)
	if clone == nil or not clone:IsA("Model") then
		if clone ~= nil then
			clone:Destroy()
		end
		roomModel:SetAttribute("ModularDungeonVisualStatus", FALLBACK_STATUS)
		return false
	end
	local shell = clone :: Model
	local root = shell.PrimaryPart or shell:FindFirstChild("Root")
	if root == nil or not root:IsA("BasePart") then
		shell:Destroy()
		roomModel:SetAttribute("ModularDungeonVisualStatus", FALLBACK_STATUS)
		return false
	end
	shell.PrimaryPart = root

	if roleId == RoleIds.Boss then
		removeBossEndWalls(shell, root)
	end
	sanitizeShell(shell)
	if not fitShellToPlacement(shell, root, placement) then
		shell:Destroy()
		roomModel:SetAttribute("ModularDungeonVisualStatus", FALLBACK_STATUS)
		return false
	end

	shell.Name = SHELL_NAME
	shell:SetAttribute("SourceAssetId", assetId)
	shell:SetAttribute("PresentationOnly", true)
	shell:SetAttribute("GameplayCollisionOwnedByGraybox", true)
	shell.Parent = roomModel
	hideAuthoritativeGrayboxVisuals(roomModel)
	roomModel:SetAttribute("ModularDungeonAssetId", assetId)
	roomModel:SetAttribute("ModularDungeonVisualStatus", MODULAR_STATUS)
	return true
end

return table.freeze(Presentation)
