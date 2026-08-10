--!strict

--[[
	Patch 0.2 elite readability.

	Client-only presentation for elites the server has already resolved and
	disclosed on the enemy model. It renders a fixed, small pool of world-space
	nameplates naming the affix and why it is dangerous, plus the disclosed armor
	remaining where the affix has armor.

	This controller creates no remote, reads no health, predicts no consequence,
	and cannot spawn, buff or damage anything. If the server never discloses an
	affix, nothing is shown — an elite is never inferred client-side.

	Bounds: one RenderStepped connection, a poll interval rather than per-frame
	attribute reads, and a fixed nameplate pool. A heavy horde cannot turn this
	into a per-enemy allocation.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EliteReadabilityConfig = require(ReplicatedStorage.Shared.Config.EliteReadabilityConfig)
local EnemyPresentationContracts = require(ReplicatedStorage.Shared.Visual.EnemyPresentationContracts)

local Controller = {}

local AttributeNames = EnemyPresentationContracts.AttributeNames
local ENEMY_FOLDER_NAME = "EnemyEntities"
local PRESENTATION_FOLDER_NAME = "LivingKingdomsEliteReadability"

type Nameplate = {
	anchor: Part,
	billboard: BillboardGui,
	title: TextLabel,
	note: TextLabel,
	model: Model?,
}

local localPlayer = Players.LocalPlayer
local started = false
local presentationFolder: Folder? = nil
local childAddedConnection: RBXScriptConnection? = nil
local childRemovedConnection: RBXScriptConnection? = nil
local renderConnection: RBXScriptConnection? = nil
local trackedModels: { [Model]: BasePart } = {}
local nameplates: { Nameplate } = {}
local pollAccumulatedSeconds = 0

local function readStringAttribute(model: Model, attributeName: string): string?
	local value = model:GetAttribute(attributeName)
	return if type(value) == "string" and value ~= "" then value else nil
end

local function readNumberAttribute(model: Model, attributeName: string): number?
	local value = model:GetAttribute(attributeName)
	return if type(value) == "number" and value == value then value else nil
end

local function trackModel(child: Instance)
	if not child:IsA("Model") then
		return
	end
	local root = child:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	trackedModels[child] = root
end

local function untrackModel(child: Instance)
	if child:IsA("Model") then
		trackedModels[child] = nil
	end
end

local function createNameplate(parent: Folder): Nameplate
	local anchor = Instance.new("Part")
	anchor.Name = "EliteNameplateAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Parent = parent

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EliteNameplate"
	billboard.Adornee = anchor
	billboard.AlwaysOnTop = false
	billboard.Size =
		UDim2.fromScale(EliteReadabilityConfig.NameplateWidthStuds, EliteReadabilityConfig.NameplateSizeStuds)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
	billboard.MaxDistance = EliteReadabilityConfig.MaximumVisibleDistanceStuds
	billboard.Enabled = false
	billboard.Parent = anchor

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.58)
	title.Font = Enum.Font.GothamBold
	title.Text = ""
	title.TextScaled = true
	title.TextStrokeTransparency = 0.4
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Parent = billboard

	local note = Instance.new("TextLabel")
	note.Name = "ThreatNote"
	note.BackgroundTransparency = 1
	note.Position = UDim2.fromScale(0, 0.58)
	note.Size = UDim2.fromScale(1, 0.42)
	note.Font = Enum.Font.GothamMedium
	note.Text = ""
	note.TextScaled = true
	note.TextStrokeTransparency = 0.6
	note.TextColor3 = Color3.fromRGB(232, 232, 232)
	note.Parent = billboard

	return {
		anchor = anchor,
		billboard = billboard,
		title = title,
		note = note,
		model = nil,
	}
end

local function releaseNameplate(plate: Nameplate)
	plate.model = nil
	plate.billboard.Enabled = false
end

local function createPresentation()
	local folder = Instance.new("Folder")
	folder.Name = PRESENTATION_FOLDER_NAME
	folder.Parent = Workspace
	presentationFolder = folder
	for _ = 1, EliteReadabilityConfig.MaximumNameplates do
		table.insert(nameplates, createNameplate(folder))
	end
end

local function viewerPosition(): Vector3?
	local character = localPlayer.Character
	local root = if character == nil then nil else character:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then root.Position else nil
end

--[[
	Collects the disclosed elites nearest the viewer, bounded by the pool size.
	Selection is by distance only; the client never ranks threat itself.
]]
local function collectVisibleElites(origin: Vector3): { { model: Model, root: BasePart, distance: number } }
	local candidates = {}
	local staleModels: { Model } = {}
	for model, root in trackedModels do
		if model.Parent == nil or root.Parent == nil then
			table.insert(staleModels, model)
			continue
		end
		if readStringAttribute(model, AttributeNames.EliteAffixId) == nil then
			continue
		end
		local distance = (root.Position - origin).Magnitude
		if distance <= EliteReadabilityConfig.MaximumVisibleDistanceStuds then
			table.insert(candidates, { model = model, root = root, distance = distance })
		end
	end
	for _, model in staleModels do
		trackedModels[model] = nil
	end
	table.sort(candidates, function(left, right)
		return left.distance < right.distance
	end)
	while #candidates > EliteReadabilityConfig.MaximumNameplates do
		table.remove(candidates)
	end
	return candidates
end

local function applyNameplate(plate: Nameplate, model: Model, root: BasePart)
	local affixId = readStringAttribute(model, AttributeNames.EliteAffixId)
	local treatment = EliteReadabilityConfig.get(affixId)
	if treatment == nil then
		releaseNameplate(plate)
		return
	end

	-- The server owns the display name; the treatment only supplies a fallback so
	-- a disclosed elite is never left unlabelled.
	local disclosedName = readStringAttribute(model, AttributeNames.EliteDisplayName)
	plate.title.Text = disclosedName or treatment.FallbackDisplayName
	plate.title.TextColor3 = treatment.AccentColor

	local armorRemaining = readNumberAttribute(model, AttributeNames.EliteArmorRemaining)
	plate.note.Text = if armorRemaining ~= nil and armorRemaining > 0
		then string.format("%s  ·  ARMOR %d", treatment.ThreatNote, math.floor(armorRemaining + 0.5))
		else treatment.ThreatNote

	plate.model = model
	plate.anchor.Position = root.Position + Vector3.new(0, EliteReadabilityConfig.NameplateHeightStuds, 0)
	plate.billboard.Enabled = true
end

local function refresh()
	local origin = viewerPosition()
	if origin == nil then
		for _, plate in nameplates do
			releaseNameplate(plate)
		end
		return
	end
	local visible = collectVisibleElites(origin)
	for index, plate in nameplates do
		local entry = visible[index]
		if entry == nil then
			releaseNameplate(plate)
		else
			applyNameplate(plate, entry.model, entry.root)
		end
	end
end

function Controller.start()
	if started then
		return
	end
	started = true
	createPresentation()

	-- Bounded wait: an unbounded WaitForChild here would halt every controller
	-- started after this one.
	local found = Workspace:WaitForChild(ENEMY_FOLDER_NAME, 10)
	if found == nil or not found:IsA("Folder") then
		warn("[EliteReadability] EnemyEntities folder unavailable; elite nameplates are inactive")
		return
	end

	-- The folder instance is cached and its children are cleared rather than the
	-- folder destroyed on replay, so this binding survives a restart.
	for _, child in found:GetChildren() do
		trackModel(child)
	end
	childAddedConnection = found.ChildAdded:Connect(trackModel)
	childRemovedConnection = found.ChildRemoved:Connect(untrackModel)

	pollAccumulatedSeconds = 0
	renderConnection = RunService.RenderStepped:Connect(function(deltaTime)
		pollAccumulatedSeconds += deltaTime
		if pollAccumulatedSeconds < EliteReadabilityConfig.PollIntervalSeconds then
			return
		end
		pollAccumulatedSeconds = 0
		refresh()
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
	table.clear(nameplates)
	table.clear(trackedModels)
	pollAccumulatedSeconds = 0
end

return table.freeze(Controller)
