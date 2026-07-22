--!strict

--[[
	P7-0106 client-local squad class identity and action cues. The controller
	consumes the existing validated, server-safe class snapshot and adds a
	text-and-shape world label to teammates. It creates no remote or gameplay
	authority and removes every label and connection on stop.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassContracts = require(ReplicatedStorage.Shared.Classes.ClassContracts)
local ClassPresentationResolver = require(ReplicatedStorage.Shared.Classes.ClassPresentationResolver)

type MemberSnapshot = ClassContracts.ClassSquadMemberPresentationSnapshot
type PlayerRecord = {
	characterConnection: RBXScriptConnection,
	operativeIdConnection: RBXScriptConnection,
}

local Controller = {}
local localPlayer = Players.LocalPlayer
local classNetwork = ReplicatedStorage:WaitForChild("ClassNetwork")
local stateRemote = classNetwork:WaitForChild("State") :: RemoteEvent
local readStateFunction = classNetwork:WaitForChild("ReadState") :: RemoteFunction

local GUI_NAME = "ClassSquadCue"
local OPERATIVE_ID_ATTRIBUTE = "LK_P3_OperativeEntityId"

local started = false
local latestRosterRevision = -1
local membersByOperativeId: { [string]: MemberSnapshot } = {}
local playerRecords: { [Player]: PlayerRecord } = {}
local stateConnection: RBXScriptConnection? = nil
local playerAddedConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil

local CLASS_COLORS: { [string]: Color3 } = table.freeze({
	[ClassContracts.ClassIds.CombatSpecialist] = Color3.fromRGB(224, 144, 112),
	[ClassContracts.ClassIds.Medic] = Color3.fromRGB(142, 218, 205),
	[ClassContracts.ClassIds.Engineer] = Color3.fromRGB(242, 192, 103),
})

local function removeCue(character: Model)
	local existing = character:FindFirstChild(GUI_NAME)
	if existing ~= nil then
		existing:Destroy()
	end
end

local function cueAdornee(character: Model): BasePart?
	local head = character:FindFirstChild("Head")
	if head ~= nil and head:IsA("BasePart") then
		return head
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local function applyPlayer(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	if player == localPlayer then
		removeCue(character)
		return
	end
	local operativeEntityId = player:GetAttribute(OPERATIVE_ID_ATTRIBUTE)
	local member = if type(operativeEntityId) == "string" then membersByOperativeId[operativeEntityId] else nil
	if member == nil then
		removeCue(character)
		return
	end
	local identity = ClassPresentationResolver.identity(member.classId)
	local adornee = cueAdornee(character)
	if identity == nil or adornee == nil then
		removeCue(character)
		return
	end

	local existing = character:FindFirstChild(GUI_NAME)
	local gui = if existing ~= nil and existing:IsA("BillboardGui") then existing else nil
	if gui == nil then
		removeCue(character)
		gui = Instance.new("BillboardGui")
		gui.Name = GUI_NAME
		gui.AlwaysOnTop = false
		gui.LightInfluence = 0
		gui.MaxDistance = 72
		gui.Size = UDim2.fromOffset(196, 44)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)

		local backing = Instance.new("Frame")
		backing.Name = "Backing"
		backing.Size = UDim2.fromScale(1, 1)
		backing.BackgroundColor3 = Color3.fromRGB(13, 17, 20)
		backing.BackgroundTransparency = 0.18
		backing.BorderSizePixel = 0
		backing.Parent = gui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 5)
		corner.Parent = backing
		local stroke = Instance.new("UIStroke")
		stroke.Name = "ClassStroke"
		stroke.Thickness = 1.5
		stroke.Transparency = 0.18
		stroke.Parent = backing

		local identityLabel = Instance.new("TextLabel")
		identityLabel.Name = "Identity"
		identityLabel.Position = UDim2.fromOffset(7, 3)
		identityLabel.Size = UDim2.new(1, -14, 0, 18)
		identityLabel.BackgroundTransparency = 1
		identityLabel.Font = Enum.Font.GothamBold
		identityLabel.TextSize = 11
		identityLabel.TextXAlignment = Enum.TextXAlignment.Center
		identityLabel.Parent = backing

		local actionLabel = Instance.new("TextLabel")
		actionLabel.Name = "Action"
		actionLabel.Position = UDim2.fromOffset(7, 21)
		actionLabel.Size = UDim2.new(1, -14, 0, 17)
		actionLabel.BackgroundTransparency = 1
		actionLabel.Font = Enum.Font.GothamMedium
		actionLabel.TextColor3 = Color3.fromRGB(245, 245, 235)
		actionLabel.TextSize = 10
		actionLabel.TextXAlignment = Enum.TextXAlignment.Center
		actionLabel.Parent = backing

		gui.Parent = character
	end

	gui.Adornee = adornee
	local backing = gui:FindFirstChild("Backing") :: Frame?
	if backing == nil then
		return
	end
	local identityLabel = backing:FindFirstChild("Identity") :: TextLabel?
	local actionLabel = backing:FindFirstChild("Action") :: TextLabel?
	local stroke = backing:FindFirstChild("ClassStroke") :: UIStroke?
	local color = CLASS_COLORS[member.classId] or Color3.fromRGB(220, 220, 210)
	if identityLabel ~= nil then
		identityLabel.Text = identity.shapeToken .. "  " .. identity.displayName
		identityLabel.TextColor3 = color
	end
	local actionCue = ClassPresentationResolver.squadActionCue(member)
	if actionLabel ~= nil then
		actionLabel.Text = actionCue or identity.roleSummary
		actionLabel.TextTransparency = if actionCue == nil then 0.28 else 0
	end
	if stroke ~= nil then
		stroke.Color = color
		stroke.Thickness = if actionCue == nil then 1.5 else 3
	end
end

local function applyAllPlayers()
	for _, player in Players:GetPlayers() do
		applyPlayer(player)
	end
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
		operativeIdConnection = player:GetAttributeChangedSignal(OPERATIVE_ID_ATTRIBUTE):Connect(function()
			applyPlayer(player)
		end),
	}
	applyPlayer(player)
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
	table.clear(membersByOperativeId)
	for _, member in snapshot.squadMembers do
		membersByOperativeId[member.operativeEntityId] = member
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
	local tracked = {}
	for player in playerRecords do
		table.insert(tracked, player)
	end
	for _, player in tracked do
		untrackPlayer(player)
	end
	table.clear(membersByOperativeId)
	latestRosterRevision = -1
end

return Controller
