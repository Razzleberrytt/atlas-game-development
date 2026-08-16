--!strict

-- Local prediction and restrained cosmetic presentation for LK-0406. Neither
-- the camera-facing SpotLight nor this controller contributes gameplay facts.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--[[
	Bounded so a network folder the server has not created yet fails this one
	controller instead of stalling the whole client bootstrap. The bootstrap
	requires controllers in a deliberate order with no isolation, so an
	unbounded wait here would hold every controller after it forever.
]]
local NETWORK_WAIT_SECONDS = 20
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PersonalFlashlightConfig = require(ReplicatedStorage.Shared.Config.PersonalFlashlightConfig)
local PersonalFlashlightContracts = require(ReplicatedStorage.Shared.Lighting.PersonalFlashlightContracts)

local ACTION_NAME = "LK0406PersonalFlashlight"
local USE_REDUCED_VISUAL_INTENSITY = false

local Controller = {}
local localPlayer = Players.LocalPlayer
local flashlightNetwork = ReplicatedStorage:WaitForChild("FlashlightNetwork", NETWORK_WAIT_SECONDS)
assert(flashlightNetwork ~= nil, "FlashlightNetwork did not become available before the client bootstrap timeout")
local toggleIntentRemote = flashlightNetwork:WaitForChild("ToggleIntent", NETWORK_WAIT_SECONDS) :: RemoteEvent?
assert(
	toggleIntentRemote ~= nil,
	"FlashlightNetwork.ToggleIntent did not become available before the client bootstrap timeout"
)
local stateRemote = flashlightNetwork:WaitForChild("State", NETWORK_WAIT_SECONDS) :: RemoteEvent?
assert(stateRemote ~= nil, "FlashlightNetwork.State did not become available before the client bootstrap timeout")

local connections: { RBXScriptConnection } = {}
local started = false
local lifecycleGeneration = 0
local authoritativeRevision = 0
local expectedActive = false
-- Presentation only. The server owns which coverage profile this operative has
-- earned; this controller just renders the matching beam and never claims one.
local coverageProfileId: string = PersonalFlashlightContracts.CoverageProfileIds.Standard
local lastInputTimestamp = -math.huge
local attachment: Attachment? = nil
local spotLight: SpotLight? = nil
local lightCarrier: Part? = nil
local renderConnection: RBXScriptConnection? = nil
local screenGui: ScreenGui? = nil
local stateLabel: TextLabel? = nil

local function isAlive(): boolean
	return localPlayer:GetAttribute("LK_P3_LifeState") == "Alive"
end

local function destroyLightPresentation()
	if renderConnection ~= nil then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	if attachment ~= nil then
		attachment:Destroy()
		attachment = nil
		spotLight = nil
	elseif spotLight ~= nil then
		spotLight:Destroy()
		spotLight = nil
	end
	if lightCarrier ~= nil then
		lightCarrier:Destroy()
		lightCarrier = nil
	end
end

local function presentationConeAngleDegrees(): number
	return if coverageProfileId == PersonalFlashlightContracts.CoverageProfileIds.Focused
		then PersonalFlashlightConfig.FocusedPresentationConeAngleDegrees
		else PersonalFlashlightConfig.PresentationConeAngleDegrees
end

local function presentationRangeStuds(): number
	return if coverageProfileId == PersonalFlashlightContracts.CoverageProfileIds.Focused
		then PersonalFlashlightConfig.FocusedPresentationRangeStuds
		else PersonalFlashlightConfig.PresentationRangeStuds
end

local function applyCoverageProfile()
	local light = spotLight
	if light ~= nil then
		light.Angle = presentationConeAngleDegrees()
		light.Range = presentationRangeStuds()
	end
end

local function ensureLightPresentation()
	if attachment ~= nil then
		return
	end
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local carrier = Instance.new("Part")
	carrier.Name = "LocalFlashlightCarrier"
	carrier.Size = Vector3.new(0.1, 0.1, 0.1)
	carrier.Transparency = 1
	carrier.Anchored = true
	carrier.CanCollide = false
	carrier.CanTouch = false
	carrier.CanQuery = false
	carrier.CastShadow = false
	carrier.CFrame = camera.CFrame
	carrier.Parent = Workspace
	local createdAttachment = Instance.new("Attachment")
	createdAttachment.Name = "LocalPersonalFlashlightAttachment"
	createdAttachment.Position = Vector3.new(0.18, -0.14, -0.35)
	createdAttachment.Parent = carrier
	local createdLight = Instance.new("SpotLight")
	createdLight.Name = "LocalPersonalFlashlightBeam"
	createdLight.Angle = presentationConeAngleDegrees()
	createdLight.Range = presentationRangeStuds()
	createdLight.Brightness = PersonalFlashlightConfig.PresentationBrightness
		* (if USE_REDUCED_VISUAL_INTENSITY then PersonalFlashlightConfig.ReducedPresentationIntensityScale else 1)
	createdLight.Color = Color3.fromRGB(244, 239, 214)
	createdLight.Face = Enum.NormalId.Front
	createdLight.Shadows = true
	createdLight.Enabled = false
	createdLight.Parent = createdAttachment
	attachment = createdAttachment
	spotLight = createdLight
	lightCarrier = carrier
	renderConnection = RunService.RenderStepped:Connect(function()
		local currentCamera = Workspace.CurrentCamera
		if currentCamera ~= nil and carrier.Parent ~= nil then
			carrier.CFrame = currentCamera.CFrame
		end
	end)
end

local function updateText(active: boolean)
	local label = stateLabel
	if label ~= nil then
		label.Text = if active then "F  ·  LIGHT ON" else "F  ·  LIGHT OFF"
	end
	ContextActionService:SetTitle(ACTION_NAME, if active then "Flashlight: ON" else "Flashlight: OFF")
	local candidate = localPlayer :: any
	if type(candidate.SetAttribute) == "function" then
		candidate:SetAttribute("LK_HUD_FlashlightOn", active)
	end
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
	label.AnchorPoint = Vector2.new(1, 0)
	label.Position = UDim2.new(1, -16, 0, 126)
	label.Size = UDim2.fromOffset(142, 30)
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 26)
	label.BackgroundTransparency = 0.25
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
	label.TextSize = 13
	-- The unified ammo panel already carries the F-key light state. Keep this
	-- backing label hidden so desktop players see one clear status surface.
	label.Visible = false
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
	local accepted, stateId, revision, profileId =
		PersonalFlashlightContracts.reconcilePresentation(authoritativeRevision, payload)
	if not accepted or stateId == nil or revision == nil then
		return
	end
	authoritativeRevision = revision
	if profileId ~= nil then
		coverageProfileId = profileId
		applyCoverageProfile()
	end
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
	coverageProfileId = PersonalFlashlightContracts.CoverageProfileIds.Standard
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
