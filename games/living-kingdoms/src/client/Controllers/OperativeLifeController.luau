--!strict

--[[
	Temporary P3 validation feedback and revive hold intent. All displayed values
	are server-owned Player attributes. The client sends only a target operative
	ID and Begin/End phase; it never reports progress or any authority fact.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

type Controller = { start: () -> (), stop: () -> () }

local Controller: Controller = {} :: Controller
local localPlayer = Players.LocalPlayer
local reviveIntentRemote =
	ReplicatedStorage:WaitForChild("OperativeLifeNetwork"):WaitForChild("ReviveIntent") :: RemoteEvent
local connections: { RBXScriptConnection } = {}
local screenGui: ScreenGui? = nil
local statusLabel: TextLabel? = nil
local heldTargetOperativeEntityId: string? = nil
local started = false

local DISCLOSED_ATTRIBUTES = {
	"LK_P3_LifeState",
	"LK_P3_CurrentHealth",
	"LK_P3_MaximumHealth",
	"LK_P3_SoloRecoveryPending",
	"LK_P3_ReviveStatus",
	"LK_P3_ReviveProgress",
	"LK_P3_SquadFailureStatus",
}

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = if character == nil then nil else character:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then root.Position else nil
end

local function nearestIncapacitatedOperativeId(): string?
	local origin = rootPosition(localPlayer)
	if origin == nil then
		return nil
	end
	local nearestId = nil
	local nearestDistance = math.huge
	for _, player in Players:GetPlayers() do
		if player ~= localPlayer and player:GetAttribute("LK_P3_LifeState") == "Incapacitated" then
			local operativeEntityId = player:GetAttribute("LK_P3_OperativeEntityId")
			local position = rootPosition(player)
			if type(operativeEntityId) == "string" and position ~= nil then
				local distance = (position - origin).Magnitude
				if distance < nearestDistance then
					nearestDistance = distance
					nearestId = operativeEntityId
				end
			end
		end
	end
	return nearestId
end

local function updateStatus()
	local label = statusLabel
	if label == nil then
		return
	end
	local lifeState = localPlayer:GetAttribute("LK_P3_LifeState") or "Registering"
	local currentHealth = localPlayer:GetAttribute("LK_P3_CurrentHealth") or 0
	local maximumHealth = localPlayer:GetAttribute("LK_P3_MaximumHealth") or 0
	local failure = localPlayer:GetAttribute("LK_P3_SquadFailureStatus") or "Viable"
	local recovery = if localPlayer:GetAttribute("LK_P3_SoloRecoveryPending") then " | solo recovery pending" else ""
	local revive = ""
	if localPlayer:GetAttribute("LK_P3_ReviveStatus") == "Active" then
		local progress = localPlayer:GetAttribute("LK_P3_ReviveProgress")
		revive = string.format(" | revive %.0f%%", (if type(progress) == "number" then progress else 0) * 100)
	end
	label.Text =
		string.format("P3 %s %d/%d | squad %s%s%s", lifeState, currentHealth, maximumHealth, failure, recovery, revive)
end

local function onInputBegan(input: InputObject, gameProcessedEvent: boolean)
	if
		gameProcessedEvent
		or input.KeyCode ~= Enum.KeyCode.E
		or UserInputService:GetFocusedTextBox() ~= nil
		or heldTargetOperativeEntityId ~= nil
	then
		return
	end
	local targetOperativeEntityId = nearestIncapacitatedOperativeId()
	if targetOperativeEntityId == nil then
		return
	end
	heldTargetOperativeEntityId = targetOperativeEntityId
	reviveIntentRemote:FireServer({ targetOperativeEntityId = targetOperativeEntityId, phase = "Begin" })
end

local function onInputEnded(input: InputObject)
	if input.KeyCode ~= Enum.KeyCode.E then
		return
	end
	local targetOperativeEntityId = heldTargetOperativeEntityId
	heldTargetOperativeEntityId = nil
	if targetOperativeEntityId ~= nil then
		reviveIntentRemote:FireServer({ targetOperativeEntityId = targetOperativeEntityId, phase = "End" })
	end
end

local function createPresentation()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TemporaryP3Validation"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 11
	local label = Instance.new("TextLabel")
	label.Name = "Status"
	label.Position = UDim2.fromOffset(16, 16)
	label.Size = UDim2.fromOffset(520, 28)
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 26)
	label.BackgroundTransparency = 0.25
	label.BorderSizePixel = 0
	label.Font = Enum.Font.Code
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
	label.TextSize = 15
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = gui
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	screenGui = gui
	statusLabel = label
	updateStatus()
end

function Controller.start()
	if started then
		return
	end
	started = true
	createPresentation()
	table.insert(connections, UserInputService.InputBegan:Connect(onInputBegan))
	table.insert(connections, UserInputService.InputEnded:Connect(onInputEnded))
	for _, attributeName in DISCLOSED_ATTRIBUTES do
		table.insert(connections, localPlayer:GetAttributeChangedSignal(attributeName):Connect(updateStatus))
	end
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	local targetOperativeEntityId = heldTargetOperativeEntityId
	heldTargetOperativeEntityId = nil
	if targetOperativeEntityId ~= nil then
		reviveIntentRemote:FireServer({ targetOperativeEntityId = targetOperativeEntityId, phase = "End" })
	end
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	if screenGui ~= nil then
		screenGui:Destroy()
		screenGui = nil
	end
	statusLabel = nil
end

return Controller
