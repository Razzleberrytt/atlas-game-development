--!strict

--[[
	Presentation-only modular decorator for the standard Exclusion Walker shell.
	It layers body proportions, war plates, horns, a carried weapon, and back
	spikes onto the existing presentation without touching the authoritative root,
	humanoid, health, damage, targeting, movement, rewards, or hit validation.

	The variant is derived deterministically from replicated enemy presentation
	facts so a small authored catalog produces many recognizable combinations with
	no per-spawn asset authoring cost.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModularAssetConfig = require(ReplicatedStorage.Shared.Config.ModularAssetConfig)

local Service = {}

local PRESENTATION_MODEL_NAME = "ExclusionWalkerPresentation"
local MODULE_FOLDER_NAME = "ModularAssets"
local BASE_SIZE_ATTRIBUTE = "HordeRoleBaseSize"

local COLORS = table.freeze({
	plate = Color3.fromRGB(56, 66, 61),
	plateDark = Color3.fromRGB(24, 30, 28),
	rust = Color3.fromRGB(115, 70, 46),
	bone = Color3.fromRGB(205, 193, 153),
	handle = Color3.fromRGB(82, 58, 41),
	weapon = Color3.fromRGB(130, 139, 136),
	weaponDark = Color3.fromRGB(69, 76, 75),
	corruption = Color3.fromRGB(154, 255, 55),
})

local function configurePart(part: Part, name: string, size: Vector3, color: Color3, material: Enum.Material)
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function makeRigidPart(
	folder: Folder,
	root: BasePart,
	anchor: BasePart,
	name: string,
	size: Vector3,
	rootLocalCFrame: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	configurePart(part, name, size, color, material)
	part.CFrame = root.CFrame * rootLocalCFrame
	part.Parent = folder
	local weld = Instance.new("WeldConstraint")
	weld.Name = name .. "Weld"
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = anchor
	return part
end

local function getPart(presentation: Model, name: string): BasePart?
	local candidate = presentation:FindFirstChild(name, true)
	return if candidate ~= nil and candidate:IsA("BasePart") then candidate else nil
end

local function scaleBasePart(part: BasePart?, scale: { number })
	if part == nil then
		return
	end
	local stored = part:GetAttribute(BASE_SIZE_ATTRIBUTE)
	local baseSize = if typeof(stored) == "Vector3" then stored else part.Size
	local modularSize = Vector3.new(baseSize.X * scale[1], baseSize.Y * scale[2], baseSize.Z * scale[3])
	part:SetAttribute(BASE_SIZE_ATTRIBUTE, modularSize)
	part.Size = modularSize
end

local function applyBodyProfile(presentation: Model, bodyId: string)
	local profile = ModularAssetConfig.getBodyProfile(bodyId)
	if profile == nil then
		return
	end
	scaleBasePart(getPart(presentation, "TorsoCore"), profile.TorsoScale)
	scaleBasePart(getPart(presentation, "RibCage"), profile.RibScale)
	scaleBasePart(getPart(presentation, "Head"), profile.HeadScale)
end

local function addWarPlates(folder: Folder, root: BasePart, torso: BasePart, warPlateId: string)
	if warPlateId == "Bare" then
		return
	end
	if warPlateId == "ScrapHarness" then
		makeRigidPart(folder, root, torso, "ModularChestBand", Vector3.new(2.55, 0.42, 0.32), CFrame.new(0, 0.92, -0.9) * CFrame.Angles(0, 0, math.rad(-9)), COLORS.rust, Enum.Material.CorrodedMetal)
		makeRigidPart(folder, root, torso, "ModularShoulderPlate", Vector3.new(1.25, 0.38, 0.95), CFrame.new(-1.18, 1.38, -0.2) * CFrame.Angles(0, 0, math.rad(-16)), COLORS.plateDark, Enum.Material.Metal)
	elseif warPlateId == "RiotPlates" then
		makeRigidPart(folder, root, torso, "ModularChestPlate", Vector3.new(2.68, 1.5, 0.34), CFrame.new(0, 0.65, -0.94) * CFrame.Angles(math.rad(-8), 0, 0), COLORS.plate, Enum.Material.DiamondPlate)
		for side = -1, 1, 2 do
			makeRigidPart(folder, root, torso, if side < 0 then "ModularPauldronLeft" else "ModularPauldronRight", Vector3.new(1.12, 0.5, 1.12), CFrame.new(side * 1.32, 1.35, -0.08) * CFrame.Angles(0, 0, math.rad(side * 14)), COLORS.plate, Enum.Material.DiamondPlate)
		end
	elseif warPlateId == "WardenPlate" then
		makeRigidPart(folder, root, torso, "ModularWardenChest", Vector3.new(2.8, 1.72, 0.42), CFrame.new(0, 0.7, -0.94) * CFrame.Angles(math.rad(-8), 0, 0), COLORS.plateDark, Enum.Material.CorrodedMetal)
		makeRigidPart(folder, root, torso, "ModularWardenCollar", Vector3.new(2.45, 0.38, 0.78), CFrame.new(0, 1.62, -0.36) * CFrame.Angles(math.rad(-12), 0, 0), COLORS.rust, Enum.Material.Metal)
		makeRigidPart(folder, root, torso, "ModularWardenBelt", Vector3.new(2.35, 0.45, 1.2), CFrame.new(0, -1.05, 0.26), COLORS.plateDark, Enum.Material.DiamondPlate)
	end
end

local function addHorns(folder: Folder, root: BasePart, head: BasePart, hornId: string)
	if hornId == "None" then
		return
	end
	local leftLength = if hornId == "Broken" then 0.62 else 1.1
	local rightLength = 1.1
	local sweep = if hornId == "Swept" then 32 else 16
	makeRigidPart(folder, root, head, "ModularHornLeft", Vector3.new(0.26, leftLength, 0.3), CFrame.new(-0.58, 2.95, -0.36) * CFrame.Angles(math.rad(-18), 0, math.rad(sweep)), COLORS.bone, Enum.Material.Slate)
	makeRigidPart(folder, root, head, "ModularHornRight", Vector3.new(0.26, rightLength, 0.3), CFrame.new(0.58, 2.95, -0.36) * CFrame.Angles(math.rad(-18), 0, math.rad(-sweep)), COLORS.bone, Enum.Material.Slate)
end

local function addBackSpikes(folder: Folder, root: BasePart, torso: BasePart, spikeId: string)
	if spikeId == "None" then
		return
	end
	local count = if spikeId == "Heavy" then 5 else 3
	for index = 1, count do
		local normalized = (index - 1) / math.max(1, count - 1)
		local y = 1.45 - normalized * 2.35
		local side = if index % 2 == 0 then -0.28 else 0.28
		local length = if spikeId == "Heavy" then 1.25 else 0.86
		makeRigidPart(folder, root, torso, "ModularBackSpike" .. tostring(index), Vector3.new(0.24, 0.24, length), CFrame.new(side, y, 1.24) * CFrame.Angles(math.rad(18), math.rad(side * 20), 0), COLORS.bone, Enum.Material.Slate)
	end
end

local function addWeapon(folder: Folder, root: BasePart, handAnchor: BasePart, weaponId: string)
	local profile = ModularAssetConfig.getWeaponProfile(weaponId)
	if profile == nil then
		return
	end
	local handleLength = profile.HandleLength
	local handle = makeRigidPart(folder, root, handAnchor, "ModularWeaponHandle", Vector3.new(0.26, handleLength, 0.26), CFrame.new(1.72, -1.72, -0.28) * CFrame.Angles(math.rad(-4), 0, math.rad(-7)), COLORS.handle, Enum.Material.Wood)
	local headY = -1.72 + handleLength * 0.52
	if profile.Silhouette == "Blade" then
		makeRigidPart(folder, root, handle, "ModularWeaponBlade", Vector3.new(profile.HeadWidth, profile.HeadLength, 0.22), CFrame.new(1.58, headY + profile.HeadLength * 0.45, -0.28) * CFrame.Angles(0, 0, math.rad(-7)), COLORS.weapon, Enum.Material.Metal)
	elseif profile.Silhouette == "Axe" then
		makeRigidPart(folder, root, handle, "ModularWeaponAxeHead", Vector3.new(profile.HeadWidth, profile.HeadLength, 0.32), CFrame.new(2.34, headY, -0.28) * CFrame.Angles(0, 0, math.rad(-7)), COLORS.weaponDark, Enum.Material.Metal)
	elseif profile.Silhouette == "Spear" then
		makeRigidPart(folder, root, handle, "ModularWeaponSpearHead", Vector3.new(profile.HeadWidth, profile.HeadLength, 0.26), CFrame.new(1.43, headY + profile.HeadLength * 0.58, -0.28) * CFrame.Angles(0, 0, math.rad(-7)), COLORS.weapon, Enum.Material.Metal)
	elseif profile.Silhouette == "Staff" then
		local crown = makeRigidPart(folder, root, handle, "ModularWeaponStaffCrown", Vector3.new(profile.HeadWidth, profile.HeadWidth, profile.HeadWidth), CFrame.new(1.38, headY + 0.52, -0.28), COLORS.weaponDark, Enum.Material.CorrodedMetal)
		crown.Shape = Enum.PartType.Ball
		local core = makeRigidPart(folder, root, crown, "ModularWeaponStaffCore", Vector3.new(0.45, 0.45, 0.45), CFrame.new(1.38, headY + 0.52, -0.74), COLORS.corruption, Enum.Material.Neon)
		core.Shape = Enum.PartType.Ball
	end
end

local function buildSeed(enemyModel: Model, root: BasePart): string
	return table.concat({
		enemyModel.Name,
		tostring(enemyModel:GetAttribute("HordeRoleId")),
		tostring(enemyModel:GetAttribute("EliteAffixId")),
		string.format("%.1f", root.Position.X),
		string.format("%.1f", root.Position.Z),
	}, "|")
end

local function decorate(enemyModel: Model): boolean
	local presentation = enemyModel:FindFirstChild(PRESENTATION_MODEL_NAME)
	if presentation == nil or not presentation:IsA("Model") then
		return false
	end
	if presentation:FindFirstChild(MODULE_FOLDER_NAME) ~= nil then
		return true
	end
	local root = enemyModel:FindFirstChild("HumanoidRootPart")
	local torso = getPart(presentation, "TorsoCore")
	local head = getPart(presentation, "Head")
	local rightArm = getPart(presentation, "ForearmRight")
	if root == nil or not root:IsA("BasePart") or torso == nil or head == nil or rightArm == nil then
		return false
	end

	local variant = ModularAssetConfig.resolveEnemyVariant(buildSeed(enemyModel, root))
	local folder = Instance.new("Folder")
	folder.Name = MODULE_FOLDER_NAME
	folder.Parent = presentation

	applyBodyProfile(presentation, variant.BodyId)
	addWarPlates(folder, root, torso, variant.WarPlateId)
	addHorns(folder, root, head, variant.HornId)
	addWeapon(folder, root, rightArm, variant.WeaponId)
	addBackSpikes(folder, root, torso, variant.BackSpikeId)

	presentation:SetAttribute("ModularAssetVersion", ModularAssetConfig.Version)
	presentation:SetAttribute("ModularBodyId", variant.BodyId)
	presentation:SetAttribute("ModularWarPlateId", variant.WarPlateId)
	presentation:SetAttribute("ModularHornId", variant.HornId)
	presentation:SetAttribute("ModularWeaponId", variant.WeaponId)
	presentation:SetAttribute("ModularBackSpikeId", variant.BackSpikeId)
	presentation:SetAttribute("ModularVariantKey", table.concat({ variant.BodyId, variant.WarPlateId, variant.HornId, variant.WeaponId, variant.BackSpikeId }, ":"))
	return true
end

function Service.applyPresentation(enemyModel: Model): boolean
	return decorate(enemyModel)
end

return table.freeze(Service)
