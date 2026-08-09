--!strict

-- Accessible, visual-only presentation for server-approved LK-0407 snapshots.
-- Local ray/forward selection is only a candidate; it grants no authority.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local InputActionMapConfig = require(ReplicatedStorage.Shared.Config.InputActionMapConfig)
local SquadPingConfig = require(ReplicatedStorage.Shared.Config.SquadPingConfig)
local InputBindingHintResolver = require(ReplicatedStorage.Shared.Input.InputBindingHintResolver)
local InputDeviceFamilyResolver = require(ReplicatedStorage.Shared.Input.InputDeviceFamilyResolver)
local SquadPingContracts = require(ReplicatedStorage.Shared.Navigation.SquadPingContracts)

local ACTION_NAME = "LK0407SquadPing"

type Marker = {
	part: Part,
	expiresAtServerTimestamp: number,
}

local Controller = {}
local localPlayer = Players.LocalPlayer
local network = ReplicatedStorage:WaitForChild("SquadPingNetwork")
local intentRemote = network:WaitForChild("Intent") :: RemoteEvent
local stateRemote = network:WaitForChild("State") :: RemoteEvent

local connections: { RBXScriptConnection } = {}
local markersByPingId: { [string]: Marker } = {}
local started = false
local authoritativeRevision = 0
local statusGui: ScreenGui? = nil
local statusLabel: TextLabel? = nil
local readyStatusText = "PING READY"

local DISPLAY_TOKENS = table.freeze({
	MouseButton3 = "MMB",
	DPadUp = "↑",
})

local function isAlive(): boolean
	return localPlayer:GetAttribute("LK_P3_LifeState") == "Alive"
end

local function rootPart(): BasePart?
	local character = localPlayer.Character
	local root = if character == nil then nil else character:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local function destroyMarker(pingId: string)
	local marker = markersByPingId[pingId]
	if marker ~= nil then
		marker.part:Destroy()
		markersByPingId[pingId] = nil
	end
end

local function clearMarkers()
	for pingId in markersByPingId do
		destroyMarker(pingId)
	end
end

local function createMarker(ping: any): Marker
	local part = Instance.new("Part")
	part.Name = "SquadLocationPing_" .. ping.pingId
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Position = ping.position

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Marker"
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = SquadPingConfig.MaximumDistanceStuds + 24
	billboard.Size = UDim2.fromOffset(116, 54)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "LocationLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(18, 24, 34)
	label.BackgroundTransparency = 0.12
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Text = "◇  LOCATION\nSQUAD PING"
	label.TextColor3 = Color3.fromRGB(238, 246, 255)
	label.TextSize = 15
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.35
	label.Parent = billboard

	part.Parent = Workspace
	return { part = part, expiresAtServerTimestamp = ping.expiresAtServerTimestamp }
end

local function presentSnapshot(pings: { any })
	local retained = {}
	for _, ping in pings do
		retained[ping.pingId] = true
		local marker = markersByPingId[ping.pingId]
		if marker == nil then
			markersByPingId[ping.pingId] = createMarker(ping)
		else
			marker.part.Position = ping.position
			marker.expiresAtServerTimestamp = ping.expiresAtServerTimestamp
		end
	end
	for pingId in markersByPingId do
		if not retained[pingId] then
			destroyMarker(pingId)
		end
	end
end

local function setStatus(text: string)
	if statusLabel ~= nil then
		statusLabel.Text = text
	end
end

local function displayToken(token: string): string
	return DISPLAY_TOKENS[token] or token
end

local function deviceFamily(inputType: Enum.UserInputType): string?
	local resolution = InputDeviceFamilyResolver.resolve(inputType.Name)
	if resolution.DeviceFamilyId ~= nil then
		return resolution.DeviceFamilyId
	end
	if inputType == Enum.UserInputType.None and UserInputService.KeyboardEnabled then
		return InputDeviceFamilyResolver.DeviceFamilyIds.KeyboardPointer
	end
	return nil
end

local function readyStatusFor(inputType: Enum.UserInputType): string
	local familyId = deviceFamily(inputType)
	local action = InputActionMapConfig.get("SquadPing")
	if familyId == nil or action == nil then
		return "PING READY"
	end
	local hint = InputBindingHintResolver.resolve(action, familyId)
	if hint.ResolutionId ~= InputBindingHintResolver.ResolutionIds.Available or hint.BindingToken == nil then
		return "PING READY"
	end
	if familyId == InputDeviceFamilyResolver.DeviceFamilyIds.Touch then
		return "PING READY"
	end
	local primary = displayToken(hint.BindingToken)
	if familyId == InputDeviceFamilyResolver.DeviceFamilyIds.KeyboardPointer then
		local mouseToken = action.MouseInputTypeNames[1]
		if mouseToken ~= nil then
			return string.format("PING  •  %s / %s", primary, displayToken(mouseToken))
		end
	end
	return "PING  •  " .. primary
end

local function updateReadyStatus(inputType: Enum.UserInputType)
	readyStatusText = readyStatusFor(inputType)
	setStatus(readyStatusText)
end

local function candidatePosition(inputObject: InputObject): Vector3?
	local root = rootPart()
	if root == nil then
		return nil
	end
	if inputObject.UserInputType == Enum.UserInputType.MouseButton3 then
		local camera = Workspace.CurrentCamera
		if camera ~= nil then
			local mouse = UserInputService:GetMouseLocation()
			local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
			if math.abs(ray.Direction.Y) > 0.0001 then
				local distance = (root.Position.Y - ray.Origin.Y) / ray.Direction.Y
				if distance > 0 then
					local point = ray.Origin + ray.Direction * distance
					local offset = point - root.Position
					if offset.Magnitude > SquadPingConfig.MaximumDistanceStuds then
						point = root.Position + offset.Unit * SquadPingConfig.MaximumDistanceStuds
					end
					return point
				end
			end
		end
	end
	local forward = root.CFrame.LookVector
	local flat = Vector3.new(forward.X, 0, forward.Z)
	if flat.Magnitude < 0.0001 then
		flat = Vector3.new(0, 0, -1)
	else
		flat = flat.Unit
	end
	return root.Position + flat * SquadPingConfig.DefaultForwardDistanceStuds
end

local function onAction(
	_actionName: string,
	inputState: Enum.UserInputState,
	inputObject: InputObject
): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if UserInputService:GetFocusedTextBox() ~= nil then
		return Enum.ContextActionResult.Pass
	end
	if not started or not isAlive() then
		setStatus("PING UNAVAILABLE")
		return Enum.ContextActionResult.Sink
	end
	local candidate = candidatePosition(inputObject)
	if candidate == nil then
		setStatus("PING UNAVAILABLE")
		return Enum.ContextActionResult.Sink
	end
	setStatus("PING SENT")
	intentRemote:FireServer({
		categoryId = SquadPingContracts.CategoryIds.Location,
		candidatePosition = candidate,
	})
	return Enum.ContextActionResult.Sink
end

local function onState(payload: unknown)
	if type(payload) == "table" and (payload :: any).operationId == SquadPingContracts.StateOperationIds.Rejected then
		if SquadPingContracts.validateSafeSnapshot(payload) then
			setStatus("PING BLOCKED")
		end
		return
	end
	local accepted, pings, acceptedRevision = SquadPingContracts.reconcileSnapshot(authoritativeRevision, payload)
	if not accepted or pings == nil or acceptedRevision == nil then
		return
	end
	authoritativeRevision = acceptedRevision
	presentSnapshot(pings)
	setStatus(readyStatusText)
end

local function createStatusPresentation()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SquadPingPresentation"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8
	local label = Instance.new("TextLabel")
	label.Name = "Instructions"
	label.AnchorPoint = Vector2.new(1, 1)
	label.Position = UDim2.new(1, -18, 1, -52)
	label.Size = UDim2.fromOffset(190, 28)
	label.BackgroundColor3 = Color3.fromRGB(18, 24, 34)
	label.BackgroundTransparency = 0.2
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(238, 246, 255)
	label.TextSize = 14
	label.Parent = gui
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	statusGui = gui
	statusLabel = label
	updateReadyStatus(UserInputService:GetLastInputType())
end

function Controller.start()
	if started then
		return
	end
	started = true
	authoritativeRevision = 0
	ContextActionService:BindAction(
		ACTION_NAME,
		onAction,
		true,
		Enum.KeyCode[SquadPingConfig.KeyboardKeyCodeName],
		Enum.KeyCode[SquadPingConfig.GamepadKeyCodeName],
		Enum.UserInputType.MouseButton3
	)
	ContextActionService:SetTitle(ACTION_NAME, "◇ Ping")
	createStatusPresentation()
	table.insert(connections, UserInputService.LastInputTypeChanged:Connect(updateReadyStatus))
	table.insert(connections, stateRemote.OnClientEvent:Connect(onState))
	table.insert(connections, localPlayer.CharacterRemoving:Connect(clearMarkers))
	table.insert(
		connections,
		localPlayer:GetAttributeChangedSignal("LK_P3_LifeState"):Connect(function()
			if not isAlive() then
				setStatus("PING UNAVAILABLE")
			end
		end)
	)
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function()
			local now = Workspace:GetServerTimeNow()
			for pingId, marker in markersByPingId do
				if marker.expiresAtServerTimestamp <= now then
					destroyMarker(pingId)
				end
			end
		end)
	)
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	ContextActionService:UnbindAction(ACTION_NAME)
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	clearMarkers()
	if statusGui ~= nil then
		statusGui:Destroy()
		statusGui = nil
	end
	statusLabel = nil
	readyStatusText = "PING READY"
	authoritativeRevision = 0
end

return Controller
