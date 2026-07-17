--!strict

--[[
	VIS-0104 client-local operative and starting-class silhouette fallback.
	The controller consumes the existing server-safe class roster and attaches
	massless, non-collidable equipment geometry to replicated character torsos.
	It never assigns a class, sends an intent, changes avatar movement/collision,
	activates class actions, or mutates life, weapon, ammunition, and mission state.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassContracts = require(ReplicatedStorage.Shared.Classes.ClassContracts)
local ClassSilhouetteConfig = require(ReplicatedStorage.Shared.Visual.ClassSilhouetteConfig)

type SilhouettePartDefinition = ClassSilhouetteConfig.SilhouettePartDefinition

type PlayerRecord = {
	characterConnection: RBXScriptConnection,
	operativeIdConnection: RBXScriptConnection,
}

local Controller = {}

local classNetwork = ReplicatedStorage:WaitForChild("ClassNetwork")
local stateRemote = classNetwork:WaitForChild("State") :: RemoteEvent
local readStateFunction = classNetwork:WaitForChild("ReadState") :: RemoteFunction

local PRESENTATION_MODEL_NAME = ClassSilhouetteConfig.PresentationModelName
local OPERATIVE_ID_ATTRIBUTE = ClassSilhouetteConfig.OperativeIdAttributeName

local PALETTE: { [string]: Color3 } = table.freeze({
	BaseArmor = Color3.fromRGB(49, 57, 62),
	BaseTrim = Color3.fromRGB(92, 101, 105),
	Specialist = Color3.fromRGB(126, 62, 49),
	Medic = Color3.fromRGB(86, 132, 129),
	Engineer = Color3.fromRGB(142, 104, 48),
	Signal = Color3.fromRGB(224, 183, 82),
})

local started = false
local latestRosterRevision = -1
local assignmentsByOperativeId: { [string]: string } = {}
local playerRecords: { [Player]: PlayerRecord } = {}
local stateConnection: RBXScriptConnection? = nil
local playerAddedConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil

local function shapeFor(shapeId: string): Enum.PartType
	if shapeId == "Cylinder" then
		return Enum.PartType.Cylinder
	end
	if shapeId == "Ball" then
		return Enum.PartType.Ball
	end
	return Enum.PartType.Block
end

local function materialFor(materialId: string): Enum.Material
	if materialId == "SmoothPlastic" then
		return Enum.Material.SmoothPlastic
	end
	return Enum.Material.Metal
end

local function removePresentation(character: Model)
	local existing = character:FindFirstChild(PRESENTATION_MODEL_NAME)
	if existing ~= nil then
		existing:Destroy()
	end
end

local function resolveTorso(character: Model): BasePart?
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if torso ~= nil and torso:IsA("BasePart") then
		return torso
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid")
	if not humanoid:IsA("Humanoid") then
		return nil
	end
	local torsoName = if humanoid.RigType == Enum.HumanoidRigType.R15 then "UpperTorso" else "Torso"
	local awaitedTorso = character:WaitForChild(torsoName)
	return if awaitedTorso:IsA("BasePart") then awaitedTorso else nil
end

local function createEquipmentPart(torso: BasePart, parent: Model, definition: SilhouettePartDefinition)
	local part = Instance.new("Part")
	part.Name = definition.name
	part.Size = Vector3.new(definition.size.x, definition.size.y, definition.size.z)
	part.Shape = shapeFor(definition.shapeId)
	part.Material = materialFor(definition.materialId)
	part.Color = PALETTE[definition.paletteId] or PALETTE.BaseArmor
	part.Transparency = 0.04
	part.CastShadow = true
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CFrame = torso.CFrame
		* CFrame.new(definition.offset.x, definition.offset.y, definition.offset.z)
		* CFrame.Angles(
			math.rad(definition.rotationDegrees.x),
			math.rad(definition.rotationDegrees.y),
			math.rad(definition.rotationDegrees.z)
		)
	part.Parent = parent

	local weld = Instance.new("WeldConstraint")
	weld.Name = definition.name .. "Weld"
	weld.Part0 = torso
	weld.Part1 = part
	weld.Parent = part
end

local function buildPresentation(character: Model, classId: string)
	local definition = ClassSilhouetteConfig.DefinitionsByClassId[classId]
	if definition == nil then
		removePresentation(character)
		return
	end

	local existing = character:FindFirstChild(PRESENTATION_MODEL_NAME)
	if existing ~= nil and existing:IsA("Model") and existing:GetAttribute("ClassId") == classId then
		return
	end
	removePresentation(character)

	local torso = resolveTorso(character)
	if torso == nil or character.Parent == nil then
		return
	end

	local model = Instance.new("Model")
	model.Name = PRESENTATION_MODEL_NAME
	model:SetAttribute("ClassId", classId)
	model:SetAttribute("VisualAssetKey", ClassSilhouetteConfig.AssetKey)
	model:SetAttribute("SourceKind", "ProceduralFallback")
	model:SetAttribute("SharedPartCount", #ClassSilhouetteConfig.SharedParts)
	model:SetAttribute("ClassPartCount", #definition.parts)

	for _, partDefinition in ClassSilhouetteConfig.SharedParts do
		createEquipmentPart(torso, model, partDefinition)
	end
	for _, partDefinition in definition.parts do
		createEquipmentPart(torso, model, partDefinition)
	end

	model.Parent = character
end

local function applyPlayer(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local operativeEntityId = player:GetAttribute(OPERATIVE_ID_ATTRIBUTE)
	if type(operativeEntityId) ~= "string" then
		removePresentation(character)
		return
	end
	local classId = assignmentsByOperativeId[operativeEntityId]
	if classId == nil then
		removePresentation(character)
		return
	end
	buildPresentation(character, classId)
end

local function untrackPlayer(player: Player)
	local record = playerRecords[player]
	if record ~= nil then
		record.characterConnection:Disconnect()
		record.operativeIdConnection:Disconnect()
		playerRecords[player] = nil
	end
	local character = player.Character
	if character ~= nil then
		removePresentation(character)
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
		operativeIdConnection = player:GetAttributeChangedSignal(OPERATIVE_ID_ATTRIBUTE):Connect(function()
			applyPlayer(player)
		end),
	}
	applyPlayer(player)
end

local function applyAllPlayers()
	for _, player in Players:GetPlayers() do
		applyPlayer(player)
	end
end

local function onPayload(payload: unknown)
	if not ClassContracts.validateSafeClassSelectionSnapshot(payload) then
		return
	end
	local snapshot = payload :: ClassContracts.SafeClassSelectionSnapshot
	if snapshot.rosterRevision < latestRosterRevision then
		return
	end
	latestRosterRevision = snapshot.rosterRevision
	table.clear(assignmentsByOperativeId)
	for _, member in snapshot.squadMembers do
		assignmentsByOperativeId[member.operativeEntityId] = member.classId
	end
	applyAllPlayers()
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
	stateConnection = stateRemote.OnClientEvent:Connect(onPayload)
	local succeeded, snapshot = pcall(function()
		return readStateFunction:InvokeServer()
	end)
	if succeeded then
		onPayload(snapshot)
	end
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	if stateConnection ~= nil then
		stateConnection:Disconnect()
		stateConnection = nil
	end
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
	table.clear(assignmentsByOperativeId)
	latestRosterRevision = -1
end

return Controller
