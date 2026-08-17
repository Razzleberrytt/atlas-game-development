--!strict

--[[
	VIS-0104 client-local world cues for authoritative operative life state. The
	controller reads existing server-disclosed Player attributes and creates only
	massless, non-collidable marker geometry and occlusion-respecting text. It
	never sends an intent or mutates movement, health, revive, death, or ownership.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VisualAssetContracts = require(ReplicatedStorage.Shared.Visual.VisualAssetContracts)
local OperativeLifePresentationResolver = require(script.Parent.Parent.Presentation.OperativeLifePresentationResolver)

type LifePresentation = OperativeLifePresentationResolver.LifePresentation

type PlayerRecord = {
	characterConnection: RBXScriptConnection,
	attributeConnection: RBXScriptConnection,
}

local Controller = {}

local CUE_MODEL_NAME = "OperativeLifeWorldCue"
local OPERATIVE_ID_ATTRIBUTE = "LK_P3_OperativeEntityId"
local LIFE_STATE_ATTRIBUTE = "LK_P3_LifeState"
local SOLO_RECOVERY_ATTRIBUTE = "LK_P3_SoloRecoveryPending"
local REVIVE_STATUS_ATTRIBUTE = "LK_P3_ReviveStatus"
local REVIVE_PROGRESS_ATTRIBUTE = "LK_P3_ReviveProgress"
local REVIVE_TARGET_ATTRIBUTE = "LK_P3_ReviveTarget"
local BOOTSTRAP_WAIT_SECONDS = 20

local WATCHED_ATTRIBUTES: { [string]: boolean } = table.freeze({
	[OPERATIVE_ID_ATTRIBUTE] = true,
	[LIFE_STATE_ATTRIBUTE] = true,
	[SOLO_RECOVERY_ATTRIBUTE] = true,
	[REVIVE_STATUS_ATTRIBUTE] = true,
	[REVIVE_PROGRESS_ATTRIBUTE] = true,
	[REVIVE_TARGET_ATTRIBUTE] = true,
})

local CUE_COLORS: { [string]: Color3 } = table.freeze({
	Downed = Color3.fromRGB(225, 151, 61),
	Reviving = Color3.fromRGB(111, 206, 156),
	SoloRecovery = Color3.fromRGB(102, 184, 214),
	Dead = Color3.fromRGB(145, 151, 157),
})

local started = false
local playerRecords: { [Player]: PlayerRecord } = {}
local playerAddedConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil

local function removeCue(character: Model)
	local existing = character:FindFirstChild(CUE_MODEL_NAME)
	if existing ~= nil then
		existing:Destroy()
	end
end

local function resolveTorso(character: Model): BasePart?
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if torso ~= nil and torso:IsA("BasePart") then
		return torso
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		humanoid = character:WaitForChild("Humanoid", BOOTSTRAP_WAIT_SECONDS)
	end
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return nil
	end
	local torsoName = if humanoid.RigType == Enum.HumanoidRigType.R15 then "UpperTorso" else "Torso"
	local awaitedTorso = character:WaitForChild(torsoName, BOOTSTRAP_WAIT_SECONDS)
	return if awaitedTorso ~= nil and awaitedTorso:IsA("BasePart") then awaitedTorso else nil
end

local function markerColor(cueId: string): Color3
	return CUE_COLORS[cueId] or CUE_COLORS.Downed
end

local function createMarkerPart(
	torso: BasePart,
	parent: Model,
	name: string,
	size: Vector3,
	offset: Vector3,
	rotationDegrees: number,
	color: Color3
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.08
	part.CastShadow = false
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CFrame = torso.CFrame * CFrame.new(offset) * CFrame.Angles(0, 0, math.rad(rotationDegrees))
	part.Parent = parent

	local weld = Instance.new("WeldConstraint")
	weld.Name = name .. "Weld"
	weld.Part0 = torso
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function markerDefinitions(markerKindId: string): {
	name: string,
	size: Vector3,
	offset: Vector3,
	rotationDegrees: number,
}
	if markerKindId == "RecoveryChevron" then
		return {
			{
				name = "RecoveryChevronLeft",
				size = Vector3.new(0.2, 0.9, 0.14),
				offset = Vector3.new(-0.27, 2.75, -0.76),
				rotationDegrees = -38,
			},
			{
				name = "RecoveryChevronRight",
				size = Vector3.new(0.2, 0.9, 0.14),
				offset = Vector3.new(0.27, 2.75, -0.76),
				rotationDegrees = 38,
			},
		}
	end
	if markerKindId == "DeathX" then
		return {
			{
				name = "DeathSlashLeft",
				size = Vector3.new(0.22, 1.2, 0.14),
				offset = Vector3.new(0, 2.7, -0.76),
				rotationDegrees = -45,
			},
			{
				name = "DeathSlashRight",
				size = Vector3.new(0.22, 1.2, 0.14),
				offset = Vector3.new(0, 2.7, -0.76),
				rotationDegrees = 45,
			},
		}
	end
	return {
		{
			name = "RescueCrossVertical",
			size = Vector3.new(0.22, 1.2, 0.14),
			offset = Vector3.new(0, 2.7, -0.76),
			rotationDegrees = 0,
		},
		{
			name = "RescueCrossHorizontal",
			size = Vector3.new(1.2, 0.22, 0.14),
			offset = Vector3.new(0, 2.7, -0.76),
			rotationDegrees = 0,
		},
	}
end

local function createBillboard(adornee: BasePart, parent: Model): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "LifeStateBillboard"
	billboard.Adornee = adornee
	billboard.Size = UDim2.fromOffset(176, 54)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 0.9, 0)
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.MaxDistance = 90
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "CueLabel"
	label.Size = UDim2.new(1, 0, 0, 34)
	label.BackgroundColor3 = Color3.fromRGB(17, 21, 24)
	label.BackgroundTransparency = 0.22
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(245, 247, 245)
	label.TextStrokeColor3 = Color3.fromRGB(10, 12, 13)
	label.TextStrokeTransparency = 0.35
	label.TextSize = 16
	label.Parent = billboard

	local progressTrack = Instance.new("Frame")
	progressTrack.Name = "ProgressTrack"
	progressTrack.Position = UDim2.fromOffset(8, 39)
	progressTrack.Size = UDim2.new(1, -16, 0, 7)
	progressTrack.BackgroundColor3 = Color3.fromRGB(35, 42, 45)
	progressTrack.BackgroundTransparency = 0.08
	progressTrack.BorderSizePixel = 0
	progressTrack.Parent = billboard

	local progressFill = Instance.new("Frame")
	progressFill.Name = "ProgressFill"
	progressFill.Size = UDim2.fromScale(0, 1)
	progressFill.BackgroundColor3 = Color3.fromRGB(111, 206, 156)
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressTrack
	return billboard
end

local function updateCue(model: Model, result: LifePresentation)
	model:SetAttribute("CueId", result.cueId)
	model:SetAttribute("MarkerKindId", result.markerKindId)
	local billboard = model:FindFirstChild("LifeStateBillboard")
	if billboard == nil or not billboard:IsA("BillboardGui") then
		return
	end
	local label = billboard:FindFirstChild("CueLabel")
	if label ~= nil and label:IsA("TextLabel") then
		label.Text = result.labelText
	end
	local progressTrack = billboard:FindFirstChild("ProgressTrack")
	if progressTrack ~= nil and progressTrack:IsA("Frame") then
		local progress = result.normalizedProgress
		progressTrack.Visible = progress ~= nil
		local progressFill = progressTrack:FindFirstChild("ProgressFill")
		if progressFill ~= nil and progressFill:IsA("Frame") then
			progressFill.Size = UDim2.fromScale(progress or 0, 1)
		end
	end
end

local function buildCue(character: Model, result: LifePresentation)
	removeCue(character)
	local torso = resolveTorso(character)
	if torso == nil or character.Parent == nil then
		return
	end
	local model = Instance.new("Model")
	model.Name = CUE_MODEL_NAME
	model:SetAttribute("VisualAssetKey", VisualAssetContracts.AssetKeys.InterfaceLifeState)
	model:SetAttribute("SourceKind", "ProjectPlaceholder")
	model:SetAttribute("TruthSource", "ServerDisclosedPlayerAttributes")
	local color = markerColor(result.cueId)
	local firstPart = nil
	for _, definition in markerDefinitions(result.markerKindId) do
		local part = createMarkerPart(
			torso,
			model,
			definition.name,
			definition.size,
			definition.offset,
			definition.rotationDegrees,
			color
		)
		firstPart = firstPart or part
	end
	if firstPart == nil then
		return
	end
	createBillboard(firstPart, model)
	updateCue(model, result)
	model.Parent = character
end

local function resolvePlayerPresentation(player: Player): LifePresentation
	return OperativeLifePresentationResolver.resolve({
		operativeEntityId = player:GetAttribute(OPERATIVE_ID_ATTRIBUTE),
		lifeStateId = player:GetAttribute(LIFE_STATE_ATTRIBUTE),
		soloRecoveryPending = player:GetAttribute(SOLO_RECOVERY_ATTRIBUTE),
		reviveStatus = player:GetAttribute(REVIVE_STATUS_ATTRIBUTE),
		reviveProgress = player:GetAttribute(REVIVE_PROGRESS_ATTRIBUTE),
		reviveTargetOperativeEntityId = player:GetAttribute(REVIVE_TARGET_ATTRIBUTE),
	})
end

local function applyPlayer(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local result = resolvePlayerPresentation(player)
	if result.cueId == "Hidden" then
		removeCue(character)
		return
	end
	local existing = character:FindFirstChild(CUE_MODEL_NAME)
	if existing ~= nil and existing:IsA("Model") and existing:GetAttribute("MarkerKindId") == result.markerKindId then
		updateCue(existing, result)
		return
	end
	buildCue(character, result)
end

local function untrackPlayer(player: Player)
	local record = playerRecords[player]
	if record ~= nil then
		record.characterConnection:Disconnect()
		record.attributeConnection:Disconnect()
		playerRecords[player] = nil
	end
	local character = player.Character
	if character ~= nil then
		removeCue(character)
	end
end

local function trackPlayer(player: Player)
	if playerRecords[player] ~= nil then
		return
	end
	playerRecords[player] = {
		characterConnection = player.CharacterAdded:Connect(function()
			applyPlayer(player)
		end),
		attributeConnection = player.AttributeChanged:Connect(function(attributeName)
			if WATCHED_ATTRIBUTES[attributeName] then
				applyPlayer(player)
			end
		end),
	}
	applyPlayer(player)
end

function Controller.start()
	if started then
		return
	end
	started = true
	for _, player in Players:GetPlayers() do
		trackPlayer(player)
	end
	playerAddedConnection = Players.PlayerAdded:Connect(trackPlayer)
	playerRemovingConnection = Players.PlayerRemoving:Connect(untrackPlayer)
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	if playerAddedConnection ~= nil then
		playerAddedConnection:Disconnect()
		playerAddedConnection = nil
	end
	if playerRemovingConnection ~= nil then
		playerRemovingConnection:Disconnect()
		playerRemovingConnection = nil
	end
	local trackedPlayers = {}
	for player in playerRecords do
		table.insert(trackedPlayers, player)
	end
	for _, player in trackedPlayers do
		untrackPlayer(player)
	end
end

return Controller
