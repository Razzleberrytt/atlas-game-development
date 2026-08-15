--!strict

--[[
	Presentation-only adapter between the canonical modular asset factory and the
	live Exclusion Walker shell. The authoritative enemy root, Humanoid, health,
	movement, targeting, damage, rewards, and hit validation remain untouched.

	The factory owns stable modular selection IDs. This adapter consumes those
	selections and mounts only components that preserve current combat readability:
	armor, accessories, special visual nodes, and the melee blade when selected.
	Ranged-looking weapons remain metadata-only until a ranged gameplay archetype
	exists, preventing a melee enemy from visually promising attacks it cannot use.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HordeExperienceConfig = require(ReplicatedStorage.Shared.Config.HordeExperienceConfig)
local ModularAssetFactory = require(ReplicatedStorage.Shared.Assets.ModularAssetFactory)

local Service = {}

local MODULAR_FOLDER_NAME = "ModularAssetPresentation"
local VISIBLE_MELEE_WEAPON_ID = "enemy.weapon.blade"

local ROLE_ARCHETYPES = table.freeze({
	[HordeExperienceConfig.Roles.Basic.Id] = "Grunt",
	[HordeExperienceConfig.Roles.Runner.Id] = "MeleeAttacker",
	[HordeExperienceConfig.Roles.Crawler.Id] = "Corrupted",
	[HordeExperienceConfig.Roles.Screamer.Id] = "Support",
	[HordeExperienceConfig.Roles.Bloater.Id] = "Heavy",
	[HordeExperienceConfig.Roles.Brute.Id] = "Elite",
})

local COPIED_ATTRIBUTE_NAMES = table.freeze({
	"CatalogVersion",
	"Archetype",
	"VariantSeed",
	"BodyPartId",
	"HeadPartId",
	"ArmorPartId",
	"WeaponPartId",
	"AccessoryPartId",
})

local function stableHash(text: string): number
	local hash = 17
	for index = 1, #text do
		hash = (hash * 131 + string.byte(text, index)) % 2147483647
	end
	return hash
end

local function resolveSeed(enemyModel: Model, root: BasePart): number
	local roleId = enemyModel:GetAttribute("HordeRoleId")
	local eliteAffixId = enemyModel:GetAttribute("EliteAffixId")
	local positionKey = string.format("%.1f,%.1f", root.Position.X, root.Position.Z)
	return stableHash(table.concat({ enemyModel.Name, tostring(roleId), tostring(eliteAffixId), positionKey }, "|"))
end

local function resolveArchetype(enemyModel: Model): string
	local eliteAffixId = enemyModel:GetAttribute("EliteAffixId")
	if typeof(eliteAffixId) == "string" and eliteAffixId ~= "" then
		return "Elite"
	end
	local roleId = enemyModel:GetAttribute("HordeRoleId")
	if typeof(roleId) == "string" then
		return ROLE_ARCHETYPES[roleId] or "Grunt"
	end
	return "Grunt"
end

local function findPresentationPart(presentation: Model, name: string): BasePart?
	local candidate = presentation:FindFirstChild(name, true)
	return if candidate ~= nil and candidate:IsA("BasePart") then candidate else nil
end

local function sanitizeVisualPart(part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = true
end

local function mountGeneratedPart(
	folder: Folder,
	generatedRoot: BasePart,
	liveRoot: BasePart,
	anchor: BasePart,
	sourcePart: BasePart,
	mountedName: string
): BasePart
	local rootLocalCFrame = generatedRoot.CFrame:ToObjectSpace(sourcePart.CFrame)
	sourcePart.Name = mountedName
	sanitizeVisualPart(sourcePart)
	sourcePart.CFrame = liveRoot.CFrame * rootLocalCFrame
	sourcePart.Parent = folder

	local weld = Instance.new("WeldConstraint")
	weld.Name = mountedName .. "Weld"
	weld.Part0 = anchor
	weld.Part1 = sourcePart
	weld.Parent = anchor
	return sourcePart
end

local function copySelectionMetadata(generated: Model, presentation: Model)
	for _, attributeName in COPIED_ATTRIBUTE_NAMES do
		local value = generated:GetAttribute(attributeName)
		if value ~= nil then
			presentation:SetAttribute("Modular" .. attributeName, value)
		end
	end
	presentation:SetAttribute("ModularAssetPresentationOnly", true)
end

local function moveOptionalPart(
	generated: Model,
	generatedRoot: BasePart,
	liveRoot: BasePart,
	folder: Folder,
	anchor: BasePart,
	sourceName: string,
	mountedName: string
)
	local source = generated:FindFirstChild(sourceName)
	if source ~= nil and source:IsA("BasePart") then
		mountGeneratedPart(folder, generatedRoot, liveRoot, anchor, source, mountedName)
	end
end

function Service.apply(enemyModel: Model, presentation: Model): boolean
	if presentation:FindFirstChild(MODULAR_FOLDER_NAME) ~= nil then
		return true
	end

	local liveRoot = enemyModel:FindFirstChild("HumanoidRootPart")
	local torso = findPresentationPart(presentation, "TorsoCore")
	local rightArm = findPresentationPart(presentation, "ForearmRight")
	local head = findPresentationPart(presentation, "Head")
	if liveRoot == nil or not liveRoot:IsA("BasePart") or torso == nil or rightArm == nil or head == nil then
		return false
	end

	local scratch = Instance.new("Folder")
	local archetype = resolveArchetype(enemyModel)
	local seed = resolveSeed(enemyModel, liveRoot)
	local generated = ModularAssetFactory.BuildEnemyVariant(scratch, archetype, seed)
	local generatedRoot = generated:FindFirstChild("Root")
	if generatedRoot == nil or not generatedRoot:IsA("BasePart") then
		scratch:Destroy()
		return false
	end

	local folder = Instance.new("Folder")
	folder.Name = MODULAR_FOLDER_NAME
	folder.Parent = presentation
	copySelectionMetadata(generated, presentation)

	-- Body/head selections are recorded on the existing animated shell so future
	-- authored replacements can resolve the same IDs without replacing hitboxes.
	local generatedBody = generated:FindFirstChild("Body")
	if generatedBody ~= nil and generatedBody:IsA("BasePart") then
		local visualPartId = generatedBody:GetAttribute("VisualPartId")
		if typeof(visualPartId) == "string" then
			torso:SetAttribute("ModularVisualPartId", visualPartId)
		end
	end
	local generatedHead = generated:FindFirstChild("Head")
	if generatedHead ~= nil and generatedHead:IsA("BasePart") then
		local visualPartId = generatedHead:GetAttribute("VisualPartId")
		if typeof(visualPartId) == "string" then
			head:SetAttribute("ModularVisualPartId", visualPartId)
		end
	end

	moveOptionalPart(generated, generatedRoot, liveRoot, folder, torso, "Armor", "ModularArmor")
	moveOptionalPart(generated, generatedRoot, liveRoot, folder, torso, "Accessory", "ModularAccessory")

	local weaponPartId = generated:GetAttribute("WeaponPartId")
	if weaponPartId == VISIBLE_MELEE_WEAPON_ID then
		moveOptionalPart(generated, generatedRoot, liveRoot, folder, rightArm, "Weapon", "ModularWeapon")
	else
		presentation:SetAttribute("ModularWeaponVisualSuppressed", true)
		presentation:SetAttribute("ModularWeaponSuppressionReason", "PreserveGameplayReadability")
	end

	moveOptionalPart(generated, generatedRoot, liveRoot, folder, torso, "EliteCore", "ModularEliteCore")
	for index = 1, 3 do
		moveOptionalPart(
			generated,
			generatedRoot,
			liveRoot,
			folder,
			torso,
			"CorruptionNode_" .. tostring(index),
			"ModularCorruptionNode" .. tostring(index)
		)
	end

	folder:SetAttribute("ModularArchetype", archetype)
	folder:SetAttribute("ModularVariantSeed", seed)
	folder:SetAttribute("PresentationOnly", true)

	scratch:Destroy()
	return true
end

return table.freeze(Service)
