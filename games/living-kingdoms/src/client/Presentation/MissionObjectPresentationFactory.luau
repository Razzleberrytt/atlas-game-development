--!strict

--[[
	VIS-0105 client-only procedural mission-object fallbacks. They attach to the
	existing server-owned relay body and extraction pillar without changing
	position, size, collision, prompts, objective state, extraction state, timers,
	or outcomes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VisualAssetContracts = require(ReplicatedStorage.Shared.Visual.VisualAssetContracts)

export type RelayRig = {
	model: Model,
	visualParts: { BasePart },
	baseTransparencyByPart: { [BasePart]: number },
	screen: BasePart,
	lens: BasePart,
	label: TextLabel,
	light: PointLight,
}

export type ExtractionRig = {
	model: Model,
	visualParts: { BasePart },
	baseTransparencyByPart: { [BasePart]: number },
	beaconLens: BasePart,
	directionPanel: BasePart,
	label: TextLabel,
	light: PointLight,
}

local Factory = {}

local COLORS = table.freeze({
	structure = Color3.fromRGB(52, 59, 58),
	structureDark = Color3.fromRGB(31, 36, 36),
	panel = Color3.fromRGB(74, 84, 80),
	steel = Color3.fromRGB(111, 119, 116),
	standby = Color3.fromRGB(195, 138, 54),
	active = Color3.fromRGB(213, 70, 48),
	completed = Color3.fromRGB(75, 196, 112),
	extraction = Color3.fromRGB(247, 150, 55),
	holdout = Color3.fromRGB(255, 209, 92),
	success = Color3.fromRGB(91, 211, 132),
	failure = Color3.fromRGB(202, 67, 59),
	text = Color3.fromRGB(244, 247, 242),
})

local function configurePart(part: BasePart, name: string, color: Color3, material: Enum.Material, transparency: number)
	part.Name = name
	part.Color = color
	part.Material = material
	part.Transparency = transparency
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function weld(root: BasePart, part: BasePart)
	local constraint = Instance.new("WeldConstraint")
	constraint.Name = part.Name .. "Weld"
	constraint.Part0 = root
	constraint.Part1 = part
	constraint.Parent = part
end

local function makePart(
	model: Model,
	root: BasePart,
	visualParts: { BasePart },
	baseTransparencyByPart: { [BasePart]: number },
	name: string,
	size: Vector3,
	localCFrame: CFrame,
	color: Color3,
	material: Enum.Material,
	transparency: number?
): Part
	local part = Instance.new("Part")
	local resolvedTransparency = transparency or 0
	configurePart(part, name, color, material, resolvedTransparency)
	part.Size = size
	part.CFrame = root.CFrame * localCFrame
	part.Parent = model
	weld(root, part)
	table.insert(visualParts, part)
	baseTransparencyByPart[part] = resolvedTransparency
	return part
end

local function createSurfaceLabel(parent: BasePart, name: string): TextLabel
	local surface = Instance.new("SurfaceGui")
	surface.Name = name .. "Surface"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 42
	surface.LightInfluence = 0
	surface.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(15, 19, 19)
	label.BackgroundTransparency = 0.16
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = COLORS.text
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = surface
	return label
end

local function setVisible(visualParts: { BasePart }, baseTransparencyByPart: { [BasePart]: number }, visible: boolean)
	for _, part in visualParts do
		part.Transparency = if visible then baseTransparencyByPart[part] or 0 else 1
	end
end

function Factory.createRelay(root: BasePart): RelayRig
	local model = Instance.new("Model")
	model.Name = "RelayConsolePresentation"
	model:SetAttribute("VisualAssetKey", VisualAssetContracts.AssetKeys.ObjectiveRelayConsoleModel)
	model:SetAttribute("VisualStatus", "ProceduralFallback")
	model:SetAttribute("TruthSource", "ValidatedSafeMissionSnapshot")

	local visualParts: { BasePart } = {}
	local baseTransparencyByPart: { [BasePart]: number } = {}
	makePart(model, root, visualParts, baseTransparencyByPart, "BasePlinth", Vector3.new(4.6, 0.35, 3.6), CFrame.new(0, -2.35, 0), COLORS.structureDark, Enum.Material.Metal)
	makePart(model, root, visualParts, baseTransparencyByPart, "LeftShell", Vector3.new(0.35, 4.6, 3.3), CFrame.new(-2.15, 0, 0), COLORS.structure, Enum.Material.Metal)
	makePart(model, root, visualParts, baseTransparencyByPart, "RightShell", Vector3.new(0.35, 4.6, 3.3), CFrame.new(2.15, 0, 0), COLORS.structure, Enum.Material.Metal)
	makePart(model, root, visualParts, baseTransparencyByPart, "FrontPanel", Vector3.new(3.8, 3.8, 0.28), CFrame.new(0, -0.1, -1.64), COLORS.panel, Enum.Material.Metal)
	makePart(model, root, visualParts, baseTransparencyByPart, "TopHousing", Vector3.new(4.2, 0.55, 3.3), CFrame.new(0, 2.25, 0), COLORS.structureDark, Enum.Material.Metal)
	local screen = makePart(model, root, visualParts, baseTransparencyByPart, "RelayScreen", Vector3.new(2.35, 1.22, 0.12), CFrame.new(-0.25, 0.45, -1.84), COLORS.standby, Enum.Material.Neon, 0.05)
	local lens = makePart(model, root, visualParts, baseTransparencyByPart, "StatusLens", Vector3.new(0.55, 0.55, 0.22), CFrame.new(1.45, 1.52, -1.84), COLORS.standby, Enum.Material.Neon, 0.02)
	makePart(model, root, visualParts, baseTransparencyByPart, "LeftAntenna", Vector3.new(0.18, 1.6, 0.18), CFrame.new(-1.35, 3.15, 0.55) * CFrame.Angles(0, 0, math.rad(-8)), COLORS.steel, Enum.Material.Metal)
	makePart(model, root, visualParts, baseTransparencyByPart, "RightAntenna", Vector3.new(0.18, 1.6, 0.18), CFrame.new(-0.85, 3.15, 0.55) * CFrame.Angles(0, 0, math.rad(8)), COLORS.steel, Enum.Material.Metal)
	makePart(model, root, visualParts, baseTransparencyByPart, "CableBox", Vector3.new(0.7, 1.15, 0.5), CFrame.new(1.5, -1.25, -1.75), COLORS.structureDark, Enum.Material.Metal)
	makePart(model, root, visualParts, baseTransparencyByPart, "ScreenGuard", Vector3.new(3.45, 0.18, 0.18), CFrame.new(-0.15, 1.55, -1.96), COLORS.steel, Enum.Material.Metal)

	local label = createSurfaceLabel(screen, "RelayStateLabel")
	local light = Instance.new("PointLight")
	light.Name = "RelayStateLight"
	light.Color = COLORS.standby
	light.Brightness = 1.1
	light.Range = 16
	light.Shadows = false
	light.Parent = lens

	model.PrimaryPart = screen
	return table.freeze({
		model = model,
		visualParts = visualParts,
		baseTransparencyByPart = baseTransparencyByPart,
		screen = screen,
		lens = lens,
		label = label,
		light = light,
	})
end

function Factory.applyRelayState(rig: RelayRig, stateId: string, labelText: string)
	local visible = stateId ~= "Hidden"
	setVisible(rig.visualParts, rig.baseTransparencyByPart, visible)
	rig.label.Visible = visible
	rig.light.Enabled = visible
	if not visible then
		return
	end
	local color = if stateId == "Active"
		then COLORS.active
		elseif stateId == "Completed" then COLORS.completed
		else COLORS.standby
	rig.screen.Color = color
	rig.lens.Color = color
	rig.light.Color = color
	rig.light.Brightness = if stateId == "Active" then 2.2 elseif stateId == "Completed" then 1.8 else 0.9
	rig.label.Text = labelText
end

function Factory.createExtraction(root: BasePart): ExtractionRig
	local model = Instance.new("Model")
	model.Name = "ExtractionBeaconPresentation"
	model:SetAttribute("VisualAssetKey", VisualAssetContracts.AssetKeys.ExtractionBeaconModel)
	model:SetAttribute("VisualStatus", "ProceduralFallback")
	model:SetAttribute("TruthSource", "ValidatedSafeMissionSnapshotAndServerObjectExistence")

	local visualParts: { BasePart } = {}
	local baseTransparencyByPart: { [BasePart]: number } = {}
	makePart(model, root, visualParts, baseTransparencyByPart, "CenterBase", Vector3.new(5.4, 0.55, 5.4), CFrame.new(0, -44.35, 0), COLORS.structureDark, Enum.Material.Metal)
	makePart(model, root, visualParts, baseTransparencyByPart, "NorthPad", Vector3.new(3.4, 0.3, 5.2), CFrame.new(0, -44.7, -4.6), COLORS.panel, Enum.Material.Metal)
	makePart(model, root, visualParts, baseTransparencyByPart, "SouthPad", Vector3.new(3.4, 0.3, 5.2), CFrame.new(0, -44.7, 4.6), COLORS.panel, Enum.Material.Metal)
	makePart(model, root, visualParts, baseTransparencyByPart, "EastPad", Vector3.new(5.2, 0.3, 3.4), CFrame.new(4.6, -44.7, 0), COLORS.panel, Enum.Material.Metal)
	makePart(model, root, visualParts, baseTransparencyByPart, "WestPad", Vector3.new(5.2, 0.3, 3.4), CFrame.new(-4.6, -44.7, 0), COLORS.panel, Enum.Material.Metal)
	makePart(model, root, visualParts, baseTransparencyByPart, "LowerFinX", Vector3.new(0.28, 13, 4.4), CFrame.new(0, -35, 0), COLORS.structure, Enum.Material.Metal)
	makePart(model, root, visualParts, baseTransparencyByPart, "LowerFinZ", Vector3.new(4.4, 13, 0.28), CFrame.new(0, -35, 0), COLORS.structure, Enum.Material.Metal)
	makePart(model, root, visualParts, baseTransparencyByPart, "UpperFinX", Vector3.new(0.22, 12, 4), CFrame.new(0, 30, 0), COLORS.structure, Enum.Material.Metal)
	makePart(model, root, visualParts, baseTransparencyByPart, "UpperFinZ", Vector3.new(4, 12, 0.22), CFrame.new(0, 30, 0), COLORS.structure, Enum.Material.Metal)
	makePart(model, root, visualParts, baseTransparencyByPart, "Crown", Vector3.new(5.2, 0.55, 5.2), CFrame.new(0, 44.1, 0), COLORS.structureDark, Enum.Material.Metal)
	local beaconLens = makePart(model, root, visualParts, baseTransparencyByPart, "BeaconLens", Vector3.new(2.5, 2.5, 2.5), CFrame.new(0, 42.6, 0), COLORS.extraction, Enum.Material.Neon, 0.12)
	local directionPanel = makePart(model, root, visualParts, baseTransparencyByPart, "DirectionPanel", Vector3.new(6.2, 1.45, 0.24), CFrame.new(0, -41.6, -5.25), COLORS.extraction, Enum.Material.Neon, 0.04)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ExtractionStateBillboard"
	billboard.Adornee = beaconLens
	billboard.Size = UDim2.fromOffset(280, 54)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.MaxDistance = 1200
	billboard.Parent = model

	local label = Instance.new("TextLabel")
	label.Name = "ExtractionStateLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(15, 18, 18)
	label.BackgroundTransparency = 0.18
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = COLORS.text
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = billboard

	local light = Instance.new("PointLight")
	light.Name = "ExtractionStateLight"
	light.Color = COLORS.extraction
	light.Brightness = 2.5
	light.Range = 62
	light.Shadows = false
	light.Parent = beaconLens

	model.PrimaryPart = beaconLens
	return table.freeze({
		model = model,
		visualParts = visualParts,
		baseTransparencyByPart = baseTransparencyByPart,
		beaconLens = beaconLens,
		directionPanel = directionPanel,
		label = label,
		light = light,
	})
end

function Factory.applyExtractionState(rig: ExtractionRig, stateId: string, labelText: string)
	local visible = stateId ~= "Hidden"
	setVisible(rig.visualParts, rig.baseTransparencyByPart, visible)
	rig.label.Visible = visible
	rig.light.Enabled = visible
	if not visible then
		return
	end
	local color = if stateId == "Holdout"
		then COLORS.holdout
		elseif stateId == "Success" then COLORS.success
		elseif stateId == "Failure" then COLORS.failure
		else COLORS.extraction
	rig.beaconLens.Color = color
	rig.directionPanel.Color = color
	rig.light.Color = color
	rig.light.Brightness = if stateId == "Holdout" then 3.4 elseif stateId == "Failure" then 1.2 else 2.5
	rig.label.Text = labelText
end

return table.freeze(Factory)
