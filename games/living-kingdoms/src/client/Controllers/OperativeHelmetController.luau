--!strict

--[[
	Always-on client-local army-helmet presentation for every replicated player
	character. Each client builds the same bounded three-part helmet on every
	operative head, including before class selection and after respawn.

	The controller creates no remote, removes no avatar accessory, changes no
	Humanoid property, and cannot alter movement, collision, health, combat,
	class assignment, or mission state.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OperativeHelmetConfig = require(ReplicatedStorage.Shared.Visual.OperativeHelmetConfig)

type HelmetPartDefinition = OperativeHelmetConfig.HelmetPartDefinition

type PlayerRecord = {
	characterConnection: RBXScriptConnection,
}

local Controller = {}

local started = false
local playerRecords: { [Player]: PlayerRecord } = {}
local playerAddedConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil

local function shapeFor(shapeId: string): Enum.PartType
	if shapeId == "Ball" then
		return Enum.PartType.Ball
	end
	return Enum.PartType.Block
end

local function materialFor(materialId: string): Enum.Material
	if materialId == "Metal" then
		return Enum.Material.Metal
	end
	return Enum.Material.SmoothPlastic
end

local function colorFor(paletteId: string): Color3
	local palette = OperativeHelmetConfig.Palette[paletteId]
	if palette == nil then
		palette = OperativeHelmetConfig.Palette.Shell
	end
	return Color3.fromRGB(palette.r, palette.g, palette.b)
end

local function removeHelmet(character: Model)
	local existing = character:FindFirstChild(OperativeHelmetConfig.PresentationModelName)
	if existing ~= nil then
		existing:Destroy()
	end
end

local function resolveHead(character: Model): BasePart?
	local head = character:FindFirstChild(OperativeHelmetConfig.HeadPartName)
	if head == nil then
		head = character:WaitForChild(OperativeHelmetConfig.HeadPartName, 5)
	end
	return if head ~= nil and head:IsA("BasePart") then head else nil
end

local function createHelmetPart(head: BasePart, parent: Model, definition: HelmetPartDefinition)
	local part = Instance.new("Part")
	part.Name = definition.name
	part.Size = Vector3.new(definition.size.x, definition.size.y, definition.size.z)
	part.Shape = shapeFor(definition.shapeId)
	part.Material = materialFor(definition.materialId)
	part.Color = colorFor(definition.paletteId)
	part.Transparency = 0.02
	part.CastShadow = true
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CFrame = head.CFrame
		* CFrame.new(definition.offset.x, definition.offset.y, definition.offset.z)
		* CFrame.Angles(
			math.rad(definition.rotationDegrees.x),
			math.rad(definition.rotationDegrees.y),
			math.rad(definition.rotationDegrees.z)
		)
	part.Parent = parent

	local weld = Instance.new("WeldConstraint")
	weld.Name = definition.name .. "Weld"
	weld.Part0 = head
	weld.Part1 = part
	weld.Parent = part
end

local function applyHelmet(character: Model)
	local existing = character:FindFirstChild(OperativeHelmetConfig.PresentationModelName)
	if
		existing ~= nil
		and existing:IsA("Model")
		and existing:GetAttribute("Version") == OperativeHelmetConfig.Version
	then
		return
	end
	removeHelmet(character)

	local head = resolveHead(character)
	if head == nil or character.Parent == nil then
		return
	end

	local model = Instance.new("Model")
	model.Name = OperativeHelmetConfig.PresentationModelName
	model:SetAttribute("Version", OperativeHelmetConfig.Version)
	model:SetAttribute("VisualAssetKey", OperativeHelmetConfig.AssetKey)
	model:SetAttribute("SourceKind", "ProceduralFallback")
	model:SetAttribute("PartCount", #OperativeHelmetConfig.Parts)

	for _, definition in OperativeHelmetConfig.Parts do
		createHelmetPart(head, model, definition)
	end
	model.Parent = character
end

local function applyPlayer(player: Player)
	local character = player.Character
	if character ~= nil then
		applyHelmet(character)
	end
end

local function untrackPlayer(player: Player)
	local record = playerRecords[player]
	if record ~= nil then
		record.characterConnection:Disconnect()
		playerRecords[player] = nil
	end
	local character = player.Character
	if character ~= nil then
		removeHelmet(character)
	end
end

local function trackPlayer(player: Player)
	if playerRecords[player] ~= nil then
		return
	end
	playerRecords[player] = {
		characterConnection = player.CharacterAdded:Connect(function(character)
			applyHelmet(character)
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
