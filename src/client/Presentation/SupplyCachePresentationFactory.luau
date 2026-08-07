--!strict

--[[
	VIS-0105 client-only procedural supply-cache shell. The factory attaches
	massless, non-collidable geometry to the existing server-owned cache root and
	exposes one presentation lid motor plus a surface label. It owns no prompt,
	stock, collection, ammunition grant, position, or gameplay state.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SupplyCachePresentationConfig = require(script.Parent.SupplyCachePresentationConfig)
local VisualAssetContracts = require(ReplicatedStorage.Shared.Visual.VisualAssetContracts)

type PartDefinition = SupplyCachePresentationConfig.PartDefinition

export type SupplyCachePresentationRig = {
	model: Model,
	parts: { BasePart },
	availableColors: { [BasePart]: Color3 },
	lidMotor: Motor6D,
	lidClosedC0: CFrame,
	lidConsumedC0: CFrame,
	label: TextLabel,
	signalBand: BasePart,
	latches: { BasePart },
	emptyTray: BasePart,
}

local Factory = {}

local PALETTE: { [string]: Color3 } = table.freeze({
	Body = Color3.fromRGB(72, 84, 60),
	Panel = Color3.fromRGB(56, 65, 49),
	Rail = Color3.fromRGB(98, 104, 94),
	Latch = Color3.fromRGB(139, 145, 132),
	Signal = Color3.fromRGB(210, 160, 55),
	Interior = Color3.fromRGB(34, 38, 34),
})

local CONSUMED_COLOR = Color3.fromRGB(45, 49, 44)
local CONSUMED_RAIL_COLOR = Color3.fromRGB(76, 81, 74)

local function vector3(definition: SupplyCachePresentationConfig.VectorDefinition): Vector3
	return Vector3.new(definition.x, definition.y, definition.z)
end

local function rotation(definition: SupplyCachePresentationConfig.VectorDefinition): CFrame
	return CFrame.Angles(math.rad(definition.x), math.rad(definition.y), math.rad(definition.z))
end

local function localCFrame(
	offset: SupplyCachePresentationConfig.VectorDefinition,
	rotationDegrees: SupplyCachePresentationConfig.VectorDefinition
): CFrame
	return CFrame.new(offset.x, offset.y, offset.z) * rotation(rotationDegrees)
end

local function materialFor(materialId: string): Enum.Material
	return if materialId == "SmoothPlastic" then Enum.Material.SmoothPlastic else Enum.Material.Metal
end

local function configurePart(part: BasePart, name: string)
	part.Name = name
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function createStaticPart(root: BasePart, model: Model, definition: PartDefinition): Part
	local part = Instance.new("Part")
	configurePart(part, definition.name)
	part.Size = vector3(definition.size)
	part.Material = materialFor(definition.materialId)
	part.Color = PALETTE[definition.paletteId] or PALETTE.Body
	part.CFrame = root.CFrame * localCFrame(definition.offset, definition.rotationDegrees)
	part.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Name = definition.name .. "Weld"
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function createLid(root: BasePart, model: Model): (Part, Motor6D, CFrame, CFrame)
	local lidDefinition = SupplyCachePresentationConfig.Lid
	local lid = Instance.new("Part")
	configurePart(lid, lidDefinition.Name)
	lid.Size = vector3(lidDefinition.Size)
	lid.Material = Enum.Material.Metal
	lid.Color = PALETTE.Body
	local closedC0 = localCFrame(lidDefinition.ClosedOffset, lidDefinition.ClosedRotationDegrees)
	local consumedC0 = localCFrame(lidDefinition.ConsumedOffset, lidDefinition.ConsumedRotationDegrees)
	lid.CFrame = root.CFrame * closedC0
	lid.Parent = model

	local motor = Instance.new("Motor6D")
	motor.Name = "SupplyCacheLidMotor"
	motor.Part0 = root
	motor.Part1 = lid
	motor.C0 = closedC0
	motor.C1 = CFrame.identity
	motor.Parent = lid
	return lid, motor, closedC0, consumedC0
end

local function createLabel(frontPanel: BasePart): TextLabel
	local surface = Instance.new("SurfaceGui")
	surface.Name = "SupplyCacheLabel"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 42
	surface.LightInfluence = 0.2
	surface.AlwaysOnTop = false
	surface.Parent = frontPanel

	local label = Instance.new("TextLabel")
	label.Name = "StateLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = "RIFLE AMMO"
	label.TextColor3 = Color3.fromRGB(238, 226, 188)
	label.TextStrokeColor3 = Color3.fromRGB(18, 21, 18)
	label.TextStrokeTransparency = 0.25
	label.TextScaled = true
	label.Parent = surface
	return label
end

function Factory.create(root: BasePart): SupplyCachePresentationRig
	local model = Instance.new("Model")
	model.Name = SupplyCachePresentationConfig.PresentationModelName
	model:SetAttribute("VisualAssetKey", VisualAssetContracts.AssetKeys.SupplyAmmunitionCacheModel)
	model:SetAttribute("VisualStatus", "ProceduralFallback")
	model:SetAttribute("TruthSource", "ServerOwnedCacheRootAndConsumedMessage")

	local parts = {}
	local availableColors = {}
	local signalBand: BasePart? = nil
	local emptyTray: BasePart? = nil
	local latches: { BasePart } = {}
	local frontPanel: BasePart? = nil
	for _, definition in SupplyCachePresentationConfig.Parts do
		local part = createStaticPart(root, model, definition)
		table.insert(parts, part)
		availableColors[part] = part.Color
		if definition.name == "SupplyCacheSignalBand" then
			signalBand = part
		elseif definition.name == "SupplyCacheEmptyTray" then
			emptyTray = part
		elseif definition.name == "SupplyCacheLatchLeft" or definition.name == "SupplyCacheLatchRight" then
			table.insert(latches, part)
		elseif definition.name == "SupplyCacheFrontPanel" then
			frontPanel = part
		end
	end

	local lid, lidMotor, lidClosedC0, lidConsumedC0 = createLid(root, model)
	table.insert(parts, lid)
	availableColors[lid] = lid.Color
	assert(
		signalBand ~= nil and emptyTray ~= nil and frontPanel ~= nil and #latches == 2,
		"supply cache visual definitions incomplete"
	)
	local label = createLabel(frontPanel)
	model.Parent = root

	local rig: SupplyCachePresentationRig = {
		model = model,
		parts = parts,
		availableColors = availableColors,
		lidMotor = lidMotor,
		lidClosedC0 = lidClosedC0,
		lidConsumedC0 = lidConsumedC0,
		label = label,
		signalBand = signalBand,
		latches = latches,
		emptyTray = emptyTray,
	}
	Factory.applyState(rig, SupplyCachePresentationConfig.StateIds.Available)
	return rig
end

function Factory.applyState(rig: SupplyCachePresentationRig, stateId: string)
	local consumed = stateId == SupplyCachePresentationConfig.StateIds.Consumed
	rig.model:SetAttribute("PresentationStateId", if consumed then "Consumed" else "Available")
	rig.lidMotor.C0 = if consumed then rig.lidConsumedC0 else rig.lidClosedC0
	for _, part in rig.parts do
		local availableColor = rig.availableColors[part]
		if consumed then
			part.Color = if part.Name == "SupplyCacheLeftRail"
					or part.Name == "SupplyCacheRightRail"
					or string.find(part.Name, "Handle", 1, true) ~= nil
				then CONSUMED_RAIL_COLOR
				else CONSUMED_COLOR
		else
			part.Color = availableColor or PALETTE.Body
		end
	end
	rig.signalBand.Transparency = if consumed then 0.72 else 0.04
	for _, latch in rig.latches do
		latch.Transparency = if consumed then 0.55 else 0.02
	end
	rig.emptyTray.Transparency = if consumed then 0.08 else 1
	rig.label.Text = if consumed then "EMPTY" else "RIFLE AMMO"
	rig.label.TextColor3 = if consumed then Color3.fromRGB(171, 178, 167) else Color3.fromRGB(238, 226, 188)
end

return table.freeze(Factory)
