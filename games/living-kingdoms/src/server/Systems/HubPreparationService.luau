--!strict

-- Builds the source-managed forward-operations preparation shell. This service
-- owns only static presentation and ProximityPrompt access points. It does not
-- own inventory, progression, class/loadout selection, or expedition launch.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubPreparationConfig = require(ReplicatedStorage.Shared.Config.HubPreparationConfig)
local WorldContentConfig = require(ReplicatedStorage.Shared.Config.WorldContentConfig)
local WorldFoundationConfig = require(ReplicatedStorage.Shared.Config.WorldFoundationConfig)

-- WorldFoundationService creates the world root before this service starts, so
-- the wait normally resolves at once. It stays bounded because an unbounded
-- WaitForChild in a start() yields forever rather than erroring, which no
-- failure containment can interrupt.
local WORLD_WAIT_SECONDS = 20

local HubPreparationService = {}

local started = false
local root: Folder? = nil

local function anchorPosition(): Vector3
	for _, landmark in WorldFoundationConfig.Landmarks do
		if landmark.id == HubPreparationConfig.AnchorLandmarkId then
			return Vector3.new(landmark.x, 0, landmark.z)
		end
	end
	error("HubPreparationConfig anchor landmark is not defined by WorldFoundationConfig")
end

local function decorateStation(part: Part, displayName: string)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "StationLabel"
	gui.Face = Enum.NormalId.Top
	gui.AlwaysOnTop = false
	gui.PixelsPerStud = 36
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = string.upper(displayName)
	label.TextColor3 = Color3.fromRGB(235, 230, 207)
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = gui
end

local function buildControlsBoard(parent: Instance, origin: Vector3)
	local board = Instance.new("Part")
	board.Name = "FieldMenuBoard"
	board.Size = Vector3.new(30, 7, 1)
	board.Position = origin + Vector3.new(0, 4, 26)
	board.Anchored = true
	board.CanCollide = true
	board.CanTouch = false
	board.Material = Enum.Material.WoodPlanks
	board.Color = Color3.fromRGB(66, 55, 43)
	board:SetAttribute("LK_PresentationOnly", true)
	board.Parent = parent

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Controls"
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 48
	gui.Parent = board

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = HubPreparationConfig.ControlsBoardText
	label.TextColor3 = Color3.fromRGB(235, 230, 207)
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = gui
end

local function buildStation(parent: Instance, origin: Vector3, definition: any)
	local descriptor = WorldContentConfig.ById[definition.contentId]
	assert(descriptor ~= nil and descriptor.active, "hub station must reference active world content")

	local part = Instance.new("Part")
	part.Name = definition.actionId
	part.Size = Vector3.new(9, 1.2, 6)
	part.Position = origin + Vector3.new(definition.x, definition.y, definition.z)
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = false
	part.Material = if definition.actionId == "OpenExpedition" then Enum.Material.Metal else Enum.Material.WoodPlanks
	part.Color = if definition.actionId == "OpenExpedition"
		then Color3.fromRGB(63, 87, 98)
		else Color3.fromRGB(83, 68, 50)
	part:SetAttribute("LK_WorldContentId", definition.contentId)
	part:SetAttribute("LK_HubAction", definition.actionId)
	part:SetAttribute("LK_PresentationOnly", true)
	part.Parent = parent
	decorateStation(part, definition.displayName)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = definition.promptText
	prompt.ObjectText = definition.displayName
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = HubPreparationConfig.PromptMaxDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
end

function HubPreparationService.start()
	if started then
		return
	end
	started = true

	local worldRoot = Workspace:WaitForChild(WorldFoundationConfig.WorldRootName, WORLD_WAIT_SECONDS)
	assert(
		worldRoot ~= nil,
		WorldFoundationConfig.WorldRootName .. " did not become available before the hub preparation start timeout"
	)
	local existing = worldRoot:FindFirstChild(HubPreparationConfig.RootName)
	if existing ~= nil then
		existing:Destroy()
	end

	local createdRoot = Instance.new("Folder")
	createdRoot.Name = HubPreparationConfig.RootName
	createdRoot:SetAttribute("LK_WorldContentId", HubPreparationConfig.ZoneContentId)
	createdRoot:SetAttribute("LK_PresentationOnly", true)
	createdRoot.Parent = worldRoot
	root = createdRoot

	local origin = anchorPosition()
	buildControlsBoard(createdRoot, origin)
	for _, station in HubPreparationConfig.Stations do
		buildStation(createdRoot, origin, station)
	end
end

function HubPreparationService.stop()
	if not started then
		return
	end
	started = false
	if root ~= nil then
		root:Destroy()
		root = nil
	end
end

return table.freeze(HubPreparationService)
