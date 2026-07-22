--!strict

--[[
	P9-0105 client-only presentation for the special-enemy and boss telegraphs.
	One RenderStepped connection polls bounded replicated model attributes and
	animates a fixed pool of world-space ground discs plus one boss status label.
	It renders the Blight Spitter Corrosive Bloom (with a lingering toxic-ground
	footprint), the Progenitor Slam, and the boss phase / armored-vs-exposed
	indicator.

	The controller creates no remote, predicts no consequence, reads no health,
	and cannot spawn enemies or apply damage. Discs are centred on the server's
	disclosed landing position (not a client guess) and appear only once the server
	has committed to the action, so nothing is disclosed early and no hit is
	client-legalised. Cues are redundant across world position, shape, a numeric
	countdown, text, and animation — never color alone.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SpecialEncounterTelegraphConfig = require(ReplicatedStorage.Shared.Config.SpecialEncounterTelegraphConfig)
local SpecialEnemyConfig = require(ReplicatedStorage.Shared.Config.SpecialEnemyConfig)

local Controller = {}

local ENEMY_FOLDER_NAME = "EnemyEntities"
local PRESENTATION_FOLDER_NAME = "LivingKingdomsSpecialEncounterTelegraphs"
local BossStatusConfig = SpecialEncounterTelegraphConfig.BossStatus
local BLOOM_LINGER_SECONDS = SpecialEnemyConfig.Bloom.Lingering.LifetimeSeconds

type DiscTelegraphKind = SpecialEncounterTelegraphConfig.DiscTelegraphKind

type ModelRecord = {
	root: BasePart,
	kind: DiscTelegraphKind,
	lastSequence: number,
	isBoss: boolean,
}

type TelegraphSlot = {
	ring: Part,
	anchor: Part,
	label: TextLabel,
	active: boolean,
	kind: DiscTelegraphKind?,
	center: Vector3,
	radiusStuds: number,
	startServerTimestamp: number,
	commitServerTimestamp: number,
	lingerEndServerTimestamp: number,
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
local bossStatusAnchor: Part? = nil
local bossStatusLabel: TextLabel? = nil
local bossStatusModel: Model? = nil
local bossStatusRoot: BasePart? = nil

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
	slot.kind = nil
	slot.startServerTimestamp = 0
	slot.commitServerTimestamp = 0
	slot.lingerEndServerTimestamp = 0
	slot.ring.Transparency = 1
	slot.anchor.Transparency = 1
	slot.label.Visible = false
end

local function createSlot(parent: Folder, index: number): TelegraphSlot
	local ring = Instance.new("Part")
	ring.Name = "EncounterDisc" .. tostring(index)
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
	anchor.Name = "EncounterLabelAnchor" .. tostring(index)
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Parent = parent

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EncounterBillboard"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(248, 46)
	billboard.MaxDistance = 220
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Name = "EncounterText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(16, 12, 10)
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
		kind = nil,
		center = Vector3.zero,
		radiusStuds = 0,
		startServerTimestamp = 0,
		commitServerTimestamp = 0,
		lingerEndServerTimestamp = 0,
	}
	deactivateSlot(slot)
	return slot
end

local function createBossStatus(parent: Folder)
	local anchor = Instance.new("Part")
	anchor.Name = "BossStatusAnchor"
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Parent = parent

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BossStatusBillboard"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(268, 40)
	billboard.MaxDistance = 320
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Name = "BossStatusText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(14, 12, 12)
	label.BackgroundTransparency = 0.2
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

	bossStatusAnchor = anchor
	bossStatusLabel = label
end

local function createPresentation()
	local folder = Instance.new("Folder")
	folder.Name = PRESENTATION_FOLDER_NAME
	for index = 1, SpecialEncounterTelegraphConfig.MaximumActiveTelegraphs do
		table.insert(slots, createSlot(folder, index))
	end
	createBossStatus(folder)
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

local function activateTelegraph(model: Model, kind: DiscTelegraphKind, serverTimestamp: number)
	local commitServerTimestamp = readNumberAttribute(model, kind.CommitAttribute)
	local startServerTimestamp = readNumberAttribute(model, kind.StartedAttribute)
	local centerX = readNumberAttribute(model, kind.CenterXAttribute)
	local centerZ = readNumberAttribute(model, kind.CenterZAttribute)
	local radiusStuds = readNumberAttribute(model, kind.RadiusAttribute)
	if
		commitServerTimestamp == nil
		or startServerTimestamp == nil
		or centerX == nil
		or centerZ == nil
		or radiusStuds == nil
		or radiusStuds <= 0
		or commitServerTimestamp <= startServerTimestamp
		or commitServerTimestamp < serverTimestamp - SpecialEncounterTelegraphConfig.CommitHoldSeconds
	then
		return
	end
	local slot = chooseSlot()
	slot.active = true
	slot.kind = kind
	slot.center = Vector3.new(centerX, 0, centerZ)
	slot.radiusStuds = radiusStuds
	slot.startServerTimestamp = startServerTimestamp
	slot.commitServerTimestamp = commitServerTimestamp
	slot.lingerEndServerTimestamp = if kind.HasLinger then commitServerTimestamp + BLOOM_LINGER_SECONDS else 0
	slot.ring.Color = colorFromTuple(kind.Color)
	slot.label.TextColor3 = slot.ring.Color
	slot.label.Visible = true
end

local function readAndPresent(model: Model, record: ModelRecord, serverTimestamp: number)
	local sequence = readNumberAttribute(model, record.kind.SequenceAttribute)
	if sequence == nil or sequence <= record.lastSequence then
		return
	end
	record.lastSequence = sequence
	activateTelegraph(model, record.kind, serverTimestamp)
end

local function groundHeight(center: Vector3, root: BasePart?): number
	if root ~= nil and root.Parent ~= nil then
		return root.Position.Y - root.Size.Y * 0.5
	end
	return center.Y
end

local function trackModel(instance: Instance)
	if not instance:IsA("Model") or records[instance] ~= nil then
		return
	end
	local kind = SpecialEncounterTelegraphConfig.discKindForArchetypeId(instance:GetAttribute("EnemyArchetypeId"))
	if kind == nil or trackedCount >= SpecialEncounterTelegraphConfig.MaximumTrackedEnemyModels then
		return
	end
	local root = instance:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local isBoss = kind.ArchetypeId == BossStatusConfig.ArchetypeId
	records[instance] = {
		root = root,
		kind = kind,
		lastSequence = readNumberAttribute(instance, kind.SequenceAttribute) or 0,
		isBoss = isBoss,
	}
	trackedCount += 1
	if isBoss then
		bossStatusModel = instance
		bossStatusRoot = root
	end
end

local function untrackModel(instance: Instance)
	if not instance:IsA("Model") or records[instance] == nil then
		return
	end
	if instance == bossStatusModel then
		bossStatusModel = nil
		bossStatusRoot = nil
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
	local kind = slot.kind
	if kind == nil then
		deactivateSlot(slot)
		return
	end

	local afterCommit = serverTimestamp - slot.commitServerTimestamp
	local radiusScale: number
	local transparency: number
	if afterCommit < 0 then
		local duration = math.max(0.01, slot.commitServerTimestamp - slot.startServerTimestamp)
		local progress = math.clamp((serverTimestamp - slot.startServerTimestamp) / duration, 0, 1)
		local pulse = math.sin(progress * math.pi * kind.PulseCount) ^ 2
		radiusScale = 0.35 + progress * 0.65
		transparency = 0.76 - pulse * 0.2
		slot.label.Text = string.format("%s  %.1f", kind.WarningLabel, math.max(0, -afterCommit))
	elseif kind.HasLinger and serverTimestamp < slot.lingerEndServerTimestamp then
		-- The committed bloom leaves denied ground for its authoritative lifetime.
		local remaining = slot.lingerEndServerTimestamp - serverTimestamp
		radiusScale = 1
		transparency = 0.58 + 0.08 * math.sin(serverTimestamp * 6) ^ 2
		slot.label.Text = string.format("%s  %.0f", kind.CommitLabel, math.max(0, remaining))
	else
		local commitProgress = math.clamp(afterCommit / SpecialEncounterTelegraphConfig.CommitHoldSeconds, 0, 1)
		radiusScale = 1 + commitProgress * 0.18
		transparency = 0.42 + commitProgress * 0.56
		slot.label.Text = kind.CommitLabel
		if commitProgress >= 1 and not kind.HasLinger then
			deactivateSlot(slot)
			return
		end
		if kind.HasLinger and serverTimestamp >= slot.lingerEndServerTimestamp then
			deactivateSlot(slot)
			return
		end
	end

	local center = slot.center
	local height =
		groundHeight(center, if slot.kind == SpecialEncounterTelegraphConfig.Slam then bossStatusRoot else nil)
	local diameter = slot.radiusStuds * 2 * radiusScale
	slot.ring.Size = Vector3.new(0.06, diameter, diameter)
	slot.ring.Transparency = transparency
	slot.ring.CFrame = CFrame.new(center.X, height + 0.08, center.Z) * CFrame.Angles(0, 0, math.rad(90))
	slot.anchor.Position = Vector3.new(center.X, height + 5.6, center.Z)
end

local function updateBossStatus()
	local anchor = bossStatusAnchor
	local label = bossStatusLabel
	local model = bossStatusModel
	local root = bossStatusRoot
	if anchor == nil or label == nil then
		return
	end
	if model == nil or model.Parent == nil or root == nil or root.Parent == nil then
		label.Visible = false
		return
	end
	local phaseId = readStringAttribute(model, BossStatusConfig.PhaseAttribute)
	local phaseLabel = if phaseId ~= nil then BossStatusConfig.PhaseLabels[phaseId] else nil
	local isVulnerable = model:GetAttribute(BossStatusConfig.VulnerableAttribute) == true
	local stateLabel = if isVulnerable then BossStatusConfig.VulnerableLabel else BossStatusConfig.ArmoredLabel
	label.Text = string.format("%s  •  %s", phaseLabel or "PROGENITOR", stateLabel)
	label.TextColor3 =
		colorFromTuple(if isVulnerable then BossStatusConfig.VulnerableColor else BossStatusConfig.ArmoredColor)
	label.Visible = true
	anchor.Position = root.Position + Vector3.new(0, root.Size.Y * 0.5 + 4, 0)
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
		if pollAccumulatedSeconds >= SpecialEncounterTelegraphConfig.PollIntervalSeconds then
			pollAccumulatedSeconds = 0
			pollModels(serverTimestamp)
		end
		for _, slot in slots do
			updateSlot(slot, serverTimestamp)
		end
		updateBossStatus()
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
	bossStatusAnchor = nil
	bossStatusLabel = nil
	bossStatusModel = nil
	bossStatusRoot = nil
end

return table.freeze(Controller)
