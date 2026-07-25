--!strict

-- Local prediction and restrained cosmetic presentation for LK-0406. Neither
-- the camera-facing SpotLight nor this controller contributes gameplay facts.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PersonalFlashlightConfig = require(ReplicatedStorage.Shared.Config.PersonalFlashlightConfig)
local PersonalFlashlightContracts = require(ReplicatedStorage.Shared.Lighting.PersonalFlashlightContracts)

local ACTION_NAME = "LK0406PersonalFlashlight"
local USE_REDUCED_VISUAL_INTENSITY = false

local Controller = {}
local localPlayer = Players.LocalPlayer
local flashlightNetwork = ReplicatedStorage:WaitForChild("FlashlightNetwork")
local toggleIntentRemote = flashlightNetwork:WaitForChild("ToggleIntent") :: RemoteEvent
local stateRemote = flashlightNetwork:WaitForChild("State") :: RemoteEvent

local connections: { RBXScriptConnection } = {}
local started = false
local lifecycleGeneration = 0
local authoritativeRevision = 0
local expectedActive = false
local lastInputTimestamp = -math.huge
local attachment: Attachment? = nil
local spotLight: SpotLight? = nil
local screenGui: ScreenGui? = nil
local stateLabel: TextLabel? = nil

local function isAlive(): boolean
	return localPlayer:GetAttribute("LK_P3_LifeState") == "Alive"
end

local function destroyLightPresentation()
	if attachment ~= nil then
		attachment:Destroy()
		attachment = nil
		spotLight = nil
	elseif spotLight ~= nil then
		spotLight:Destroy()
		spotLight = nil
	end
end

local function ensureLightPresentation()
	if attachment ~= nil then
		return
	end
	local character = localPlayer.Character
	local head = if character == nil then nil else character:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local createdAttachment = Instance.new("Attachment")
	createdAttachment.Name = "LocalPersonalFlashlightAttachment"
	createdAttachment.Position = Vector3.new(0, 0, -0.35)
	createdAttachment.Parent = head
	local createdLight = Instance.new("SpotLight")
	createdLight.Name = "LocalPersonalFlashlightBeam"
	createdLight.Angle = PersonalFlashlightConfig.ConeAngleDegrees
	createdLight.Range = PersonalFlashlightConfig.RangeStuds
	createdLight.Brightness = PersonalFlashlightConfig.PresentationBrightness
		* (if USE_REDUCED_VISUAL_INTENSITY then PersonalFlashlightConfig.ReducedPresentationIntensityScale else 1)
	createdLight.Color = Color3.fromRGB(244, 239, 214)
	createdLight.Face = Enum.NormalId.Front
	createdLight.Shadows = false
	createdLight.Enabled = false
	createdLight.Parent = createdAttachment
	attachment = createdAttachment
	spotLight = createdLight
end

local function updateText(active: boolean)
	local label = stateLabel
	if label ~= nil then
		label.Text = if active then "Flashlight ON" else "Flashlight OFF"
	end
	ContextActionService:SetTitle(ACTION_NAME, if active then "Flashlight: ON" else "Flashlight: OFF")
end

local function present(active: boolean)
	if active and isAlive() then
		ensureLightPresentation()
	end
	local light = spotLight
	if light ~= nil then
		light.Enabled = active and isAlive()
	end
	updateText(active and isAlive())
end

local function createStatusPresentation()
	local gui = Instance.new("ScreenGui")
	gui.Name = "PersonalFlashlightPresentation"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 9
	local label = Instance.new("TextLabel")
	label.Name = "State"
	label.AnchorPoint = Vector2.new(1, 1)
	label.Position = UDim2.new(1, -18, 1, -18)
	label.Size = UDim2.fromOffset(150, 28)
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 26)
	label.BackgroundTransparency = 0.25
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
	label.TextSize = 15
	label.Parent = gui
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	screenGui = gui
	stateLabel = label
	updateText(false)
end

local function onAction(_actionName: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if not started or not isAlive() then
		present(false)
		return Enum.ContextActionResult.Sink
	end
	local now = os.clock()
	if now - lastInputTimestamp < PersonalFlashlightConfig.ToggleCooldownSeconds then
		return Enum.ContextActionResult.Sink
	end
	lastInputTimestamp = now
	expectedActive = not expectedActive
	present(expectedActive)
	toggleIntentRemote:FireServer(expectedActive)
	return Enum.ContextActionResult.Sink
end

local function onState(payload: unknown)
	local accepted, stateId, revision =
		PersonalFlashlightContracts.reconcilePresentation(authoritativeRevision, payload)
	if not accepted or stateId == nil or revision == nil then
		return
	end
	authoritativeRevision = revision
	expectedActive = stateId == PersonalFlashlightContracts.StateIds.Active
	present(expectedActive)
end

local function onLifeChanged()
	if not isAlive() then
		expectedActive = false
		present(false)
	end
end

function Controller.start()
	if started then
		return
	end
	started = true
	lifecycleGeneration += 1
	authoritativeRevision = 0
	expectedActive = false
	lastInputTimestamp = -math.huge
	ContextActionService:BindAction(
		ACTION_NAME,
		onAction,
		true,
		Enum.KeyCode[PersonalFlashlightConfig.KeyboardKeyCodeName],
		Enum.KeyCode[PersonalFlashlightConfig.GamepadKeyCodeName]
	)
	createStatusPresentation()
	table.insert(connections, stateRemote.OnClientEvent:Connect(onState))
	table.insert(connections, localPlayer:GetAttributeChangedSignal("LK_P3_LifeState"):Connect(onLifeChanged))
	table.insert(
		connections,
		localPlayer.CharacterAdded:Connect(function()
			local generation = lifecycleGeneration
			task.defer(function()
				if started and generation == lifecycleGeneration then
					destroyLightPresentation()
					present(expectedActive)
				end
			end)
		end)
	)
	table.insert(
		connections,
		localPlayer.CharacterRemoving:Connect(function()
			destroyLightPresentation()
			present(false)
		end)
	)
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	lifecycleGeneration += 1
	ContextActionService:UnbindAction(ACTION_NAME)
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	expectedActive = false
	present(false)
	destroyLightPresentation()
	if screenGui ~= nil then
		screenGui:Destroy()
		screenGui = nil
	end
	stateLabel = nil
end

return Controller
