--!strict

--[[
	Client-only presentation for server-authored horde special warnings. One
	RenderStepped connection polls bounded replicated model attributes and animates
	a fixed pool of world-space discs and text labels. The controller creates no
	remote, predicts no consequence, reads no health, and cannot spawn enemies or
	apply damage.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local HordeSpecialTelegraphConfig = require(ReplicatedStorage.Shared.Config.HordeSpecialTelegraphConfig)

local Controller = {}

local AttributeNames = HordeSpecialTelegraphConfig.AttributeNames
local StateIds = HordeSpecialTelegraphConfig.StateIds
local ENEMY_FOLDER_NAME = "EnemyEntities"
local PRESENTATION_FOLDER_NAME = "LivingKingdomsHordeSpecialTelegraphs"

type ModelRecord = {
	root: BasePart,
	lastSequence: number,
}

type TelegraphSlot = {
	ring: Part,
	anchor: Part,
	label: TextLabel,
	active: boolean,
	model: Model?,
	root: BasePart?,
	kindId: string?,
	startServerTimestamp: number,
	commitServerTimestamp: number,
}

local started = false
local presentationFolder: Folder? = nil
local childAddedConnection: RBXScriptConnection? = nil
local childRemovedConnection: RBXScriptConnection? = nil
local renderConnection: RBXScriptConnection? = nil
local records: { [Model]: ModelRecord } = {}
local slots: { TelegraphSlot } = {}
local trackedCount = 0
local pollAccumulatedSeconds = 0

local function readNumberAttribute(model: Model, attributeName: string): number?
	local value = model:GetAttribute(attributeName)
	return if type(value) == "number" and value == value then value else nil
end

local function readStringAttribute(model: Model, attributeName: string): string?
	local value = model:GetAttribute(attributeName)
	return if type(value) == "string" and value ~= "" then value else nil
end

local function colorFromTuple(tuple: { number }): Color3
	return Color3.fromRGB(tuple[1], tuple[2], tuple[3])
end

local function deactivateSlot(slot: TelegraphSlot)
	slot.active = false
	slot.model = nil
	slot.root = nil
	slot.kindId = nil
	slot.startServerTimestamp = 0
	slot.commitServerTimestamp = 0
	slot.ring.Transparency = 1
	slot.anchor.Transparency = 1
	slot.label.Visible = false
end

local function createSlot(parent: Folder, index: number): TelegraphSlot
	local ring = Instance.new("Part")
	ring.Name = "WarningDisc" .. tostring(index)
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.06, 1, 1)
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanTouch = false
	ring.CanQuery = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Transparency = 1
	ring.Parent = parent

	local anchor = Instance.new("Part")
	anchor.Name = "WarningLabelAnchor" .. tostring(index)
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Parent = parent

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WarningBillboard"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(240, 46)
	billboard.MaxDistance = 180
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Name = "WarningText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(18, 10, 12)
	label.BackgroundTransparency = 0.18
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.1
	label.TextScaled = true
	label.Visible = false
	label.Parent = billboard

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Transparency = 0.08
	stroke.Parent = label

	local slot: TelegraphSlot = {
		ring = ring,
		anchor = anchor,
		label = label,
		active = false,
		model = nil,
		root = nil,
		kindId = nil,
		startServerTimestamp = 0,
		commitServerTimestamp = 0,
	}
	deactivateSlot(slot)
	return slot
end

local function createPresentation()
	local folder = Instance.new("Folder")
	folder.Name = PRESENTATION_FOLDER_NAME
	for index = 1, HordeSpecialTelegraphConfig.MaximumActiveTelegraphs do
		table.insert(slots, createSlot(folder, index))
	end
	folder.Parent = Workspace
	presentationFolder = folder
end

local function chooseSlot(): TelegraphSlot
	local earliest: TelegraphSlot? = nil
	for _, slot in slots do
		if not slot.active then
			return slot
		end
		if earliest == nil or slot.commitServerTimestamp < earliest.commitServerTimestamp then
			earliest = slot
		end
	end
	assert(earliest ~= nil, "telegraph pool must contain at least one slot")
	deactivateSlot(earliest)
	return earliest
end

local function activateTelegraph(model: Model, root: BasePart, kindId: string, commitServerTimestamp: number)
	local definition = HordeSpecialTelegraphConfig.get(kindId)
	if definition == nil then
		return
	end
	local slot = chooseSlot()
	slot.active = true
	slot.model = model
	slot.root = root
	slot.kindId = kindId
	slot.startServerTimestamp = commitServerTimestamp - definition.WindupSeconds
	slot.commitServerTimestamp = commitServerTimestamp
	slot.ring.Color = colorFromTuple(definition.Color)
	slot.label.TextColor3 = slot.ring.Color
	slot.label.Visible = true
end

local function readAndPresent(model: Model, record: ModelRecord, serverTimestamp: number)
	local sequence = readNumberAttribute(model, AttributeNames.Sequence)
	if sequence == nil or sequence <= record.lastSequence then
		return
	end
	record.lastSequence = sequence
	local stateId = readStringAttribute(model, AttributeNames.StateId)
	local kindId = readStringAttribute(model, AttributeNames.KindId)
	local commitServerTimestamp = readNumberAttribute(model, AttributeNames.CommitServerTimestamp)
	if
		stateId ~= StateIds.Windup
		or kindId == nil
		or commitServerTimestamp == nil
		or commitServerTimestamp < serverTimestamp - HordeSpecialTelegraphConfig.CommitHoldSeconds
	then
		return
	end
	activateTelegraph(model, record.root, kindId, commitServerTimestamp)
end

local function trackModel(instance: Instance)
	if
		not instance:IsA("Model")
		or records[instance] ~= nil
		or trackedCount >= HordeSpecialTelegraphConfig.MaximumTrackedEnemyModels
		or instance:GetAttribute("EnemyArchetypeId") ~= EnemyConfig.Walker.ArchetypeId
	then
		return
	end
	local root = instance:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local sequence = readNumberAttribute(instance, AttributeNames.Sequence) or 0
	local record: ModelRecord = { root = root, lastSequence = sequence }
	records[instance] = record
	trackedCount += 1

	local stateId = readStringAttribute(instance, AttributeNames.StateId)
	local kindId = readStringAttribute(instance, AttributeNames.KindId)
	local commitServerTimestamp = readNumberAttribute(instance, AttributeNames.CommitServerTimestamp)
	local serverTimestamp = Workspace:GetServerTimeNow()
	if
		sequence > 0
		and stateId == StateIds.Windup
		and kindId ~= nil
		and commitServerTimestamp ~= nil
		and commitServerTimestamp > serverTimestamp
	then
		activateTelegraph(instance, root, kindId, commitServerTimestamp)
	end
end

local function untrackModel(instance: Instance)
	if not instance:IsA("Model") or records[instance] == nil then
		return
	end
	records[instance] = nil
	trackedCount = math.max(0, trackedCount - 1)
end

local function pollModels(serverTimestamp: number)
	local staleModels: { Model } = {}
	for model, record in records do
		if model.Parent == nil or record.root.Parent == nil then
			table.insert(staleModels, model)
		else
			readAndPresent(model, record, serverTimestamp)
		end
	end
	for _, model in staleModels do
		untrackModel(model)
	end
end

local function updateSlot(slot: TelegraphSlot, serverTimestamp: number)
	if not slot.active then
		return
	end
	local model = slot.model
	local root = slot.root
	local kindId = slot.kindId
	local definition = HordeSpecialTelegraphConfig.get(kindId)
	if model == nil or model.Parent == nil or root == nil or root.Parent == nil or definition == nil then
		deactivateSlot(slot)
		return
	end

	if
		serverTimestamp < slot.commitServerTimestamp - HordeSpecialTelegraphConfig.PollIntervalSeconds
		and readStringAttribute(model, AttributeNames.StateId) ~= StateIds.Windup
	then
		deactivateSlot(slot)
		return
	end

	local center = root.Position
	local duration = math.max(0.01, slot.commitServerTimestamp - slot.startServerTimestamp)
	local progress = math.clamp((serverTimestamp - slot.startServerTimestamp) / duration, 0, 1)
	local afterCommit = serverTimestamp - slot.commitServerTimestamp
	local radiusScale: number
	local transparency: number
	if afterCommit < 0 then
		local pulse = math.sin(progress * math.pi * definition.PulseCount) ^ 2
		radiusScale = 0.35 + progress * 0.65
		transparency = 0.76 - pulse * 0.2
		slot.label.Text = string.format("%s  %.1f", definition.WarningLabel, math.max(0, -afterCommit))
	else
		local commitProgress = math.clamp(afterCommit / HordeSpecialTelegraphConfig.CommitHoldSeconds, 0, 1)
		radiusScale = 1 + commitProgress * 0.18
		transparency = 0.42 + commitProgress * 0.56
		slot.label.Text = definition.CommitLabel
		if commitProgress >= 1 then
			deactivateSlot(slot)
			return
		end
	end

	local diameter = definition.RadiusStuds * 2 * radiusScale
	slot.ring.Size = Vector3.new(0.06, diameter, diameter)
	slot.ring.Transparency = transparency
	slot.ring.CFrame = CFrame.new(center.X, center.Y + 0.08, center.Z) * CFrame.Angles(0, 0, math.rad(90))
	slot.anchor.Position = center + Vector3.new(0, 6.4, 0)
end

function Controller.start()
	if started then
		return
	end
	started = true
	createPresentation()
	local found = Workspace:WaitForChild(ENEMY_FOLDER_NAME)
	assert(found:IsA("Folder"), "EnemyEntities must be a Folder")
	for _, child in found:GetChildren() do
		trackModel(child)
	end
	childAddedConnection = found.ChildAdded:Connect(trackModel)
	childRemovedConnection = found.ChildRemoved:Connect(untrackModel)
	pollAccumulatedSeconds = 0
	renderConnection = RunService.RenderStepped:Connect(function(deltaTime)
		local serverTimestamp = Workspace:GetServerTimeNow()
		pollAccumulatedSeconds += deltaTime
		if pollAccumulatedSeconds >= HordeSpecialTelegraphConfig.PollIntervalSeconds then
			pollAccumulatedSeconds = 0
			pollModels(serverTimestamp)
		end
		for _, slot in slots do
			updateSlot(slot, serverTimestamp)
		end
	end)
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	for _, connection in { childAddedConnection, childRemovedConnection, renderConnection } do
		if connection ~= nil then
			connection:Disconnect()
		end
	end
	childAddedConnection = nil
	childRemovedConnection = nil
	renderConnection = nil
	if presentationFolder ~= nil then
		presentationFolder:Destroy()
		presentationFolder = nil
	end
	table.clear(records)
	table.clear(slots)
	trackedCount = 0
	pollAccumulatedSeconds = 0
end

return table.freeze(Controller)
