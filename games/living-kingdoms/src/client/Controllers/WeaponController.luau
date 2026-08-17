--!strict

--[[
	Owns local weapon fire/reload intent origin and immediate presentation of
	server-disclosed combat events. The unified HordeHUDController renders
	ammunition and status through client-local Player attributes. This controller
	never selects legal targets, spends ammunition, resolves hits, changes health,
	or fabricates authority.
]]

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
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local CombatContracts = require(ReplicatedStorage.Shared.Combat.CombatContracts)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)

local function resolveWeaponDefinition(weaponId: unknown)
	local getter = FirearmConfig.get
	if type(getter) == "function" then
		return getter(weaponId)
	end
	local basic = FirearmConfig.BasicFirearm
	return if basic ~= nil and weaponId == basic.WeaponId then basic else nil
end

local function isKnownWeaponId(weaponId: unknown): boolean
	return resolveWeaponDefinition(weaponId) ~= nil
end

local REQUEST_COOLDOWN_SECONDS = 0.5
local COMBAT_ENTITY_ID_ATTRIBUTE = "CombatEntityId"
local FIRE_ACTION_NAME = "LK_Fire"
local RELOAD_ACTION_NAME = "LK_Reload"
local localPlayer = Players.LocalPlayer

local HUD_ATTRIBUTES = {
	"LK_HUD_LoadedRounds",
	"LK_HUD_ReserveRounds",
	"LK_HUD_MagazineCapacity",
	"LK_HUD_WeaponId",
	"LK_HUD_WeaponName",
	"LK_HUD_CombatStatus",
	"LK_HUD_CombatStatusUntil",
}

local function isLocalOperativeEntityId(value: unknown): boolean
	return value == "operative.player:" .. tostring(localPlayer.UserId)
end

type WeaponController = {
	init: () -> (),
	start: () -> (),
	stop: () -> (),
	destroy: () -> (),
}

type LifecycleState = {
	initialized: boolean,
	started: boolean,
	destroyed: boolean,
	lastReloadRequestLocalTimestamp: number,
	presentedShotIds: { [string]: boolean },
	selectedTargetEntityId: string?,
	currentWeaponId: string,
	isFiring: boolean,
	lastAimSendLocalTimestamp: number,
	inputBeganConnection: RBXScriptConnection?,
	inputEndedConnection: RBXScriptConnection?,
	renderConnection: RBXScriptConnection?,
	presentationConnection: RBXScriptConnection?,
	targetHighlight: Highlight?,
	crosshairGui: ScreenGui?,
}

local WeaponController: WeaponController = {} :: WeaponController
local state: LifecycleState = {
	initialized = false,
	started = false,
	destroyed = false,
	lastReloadRequestLocalTimestamp = -math.huge,
	presentedShotIds = {},
	selectedTargetEntityId = nil,
	currentWeaponId = FirearmConfig.BasicFirearm.WeaponId,
	isFiring = false,
	lastAimSendLocalTimestamp = -math.huge,
	inputBeganConnection = nil,
	inputEndedConnection = nil,
	renderConnection = nil,
	presentationConnection = nil,
	targetHighlight = nil,
	crosshairGui = nil,
}

local combatNetwork = assert(
	ReplicatedStorage:WaitForChild("CombatNetwork", NETWORK_WAIT_SECONDS),
	"CombatNetwork unavailable after bounded wait"
)
local fireIntentRemote = assert(
	combatNetwork:WaitForChild("FireIntent", NETWORK_WAIT_SECONDS),
	"CombatNetwork.FireIntent unavailable after bounded wait"
) :: RemoteEvent
local reloadIntentRemote = assert(
	combatNetwork:WaitForChild("ReloadIntent", NETWORK_WAIT_SECONDS),
	"CombatNetwork.ReloadIntent unavailable after bounded wait"
) :: RemoteEvent
local presentationRemote = assert(
	combatNetwork:WaitForChild("CombatPresentation", NETWORK_WAIT_SECONDS),
	"CombatNetwork.CombatPresentation unavailable after bounded wait"
) :: RemoteEvent

local function clearHudAttributes()
	for _, attributeName in HUD_ATTRIBUTES do
		localPlayer:SetAttribute(attributeName, nil)
	end
end

local function createCrosshair()
	if state.crosshairGui ~= nil then
		state.crosshairGui:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "FirstPersonCrosshair"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40

	local function line(name: string, size: UDim2, position: UDim2)
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Size = size
		frame.Position = position
		frame.BackgroundColor3 = Color3.fromRGB(238, 231, 210)
		frame.BorderSizePixel = 0
		frame.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(15, 17, 18)
		stroke.Thickness = 1
		stroke.Parent = frame
	end

	line("Top", UDim2.fromOffset(2, 8), UDim2.new(0.5, 0, 0.5, -9))
	line("Bottom", UDim2.fromOffset(2, 8), UDim2.new(0.5, 0, 0.5, 9))
	line("Left", UDim2.fromOffset(8, 2), UDim2.new(0.5, -9, 0.5, 0))
	line("Right", UDim2.fromOffset(8, 2), UDim2.new(0.5, 9, 0.5, 0))
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Size = UDim2.fromOffset(3, 3)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.BackgroundColor3 = Color3.fromRGB(238, 231, 210)
	dot.BorderSizePixel = 0
	dot.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot

	local playerGui = assert(
		localPlayer:WaitForChild("PlayerGui", NETWORK_WAIT_SECONDS),
		"PlayerGui unavailable after bounded wait"
	)
	gui.Parent = playerGui
	state.crosshairGui = gui
end

local function currentAimDirection(): Vector3?
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	local direction = camera.CFrame.LookVector
	return if direction.Magnitude > 0.99 then direction.Unit else nil
end

local function releaseDirectionFallback(): Vector3
	return Vector3.new(0, 0, -1)
end

local function sendFireIntent(isFiring: boolean)
	local direction = currentAimDirection()
	if direction == nil then
		if isFiring then
			return
		end
		-- Release carries no targeting authority, but the current server transport
		-- contract still validates a unit aim vector before it clears the latch.
		-- Construct the sentinel only on the missing-camera release path so module
		-- loading does not depend on a live Vector3 runtime in source-audit harnesses.
		direction = releaseDirectionFallback()
	end
	state.lastAimSendLocalTimestamp = os.clock()
	fireIntentRemote:FireServer(isFiring, direction)
end

local function setFiring(isFiring: boolean)
	if state.isFiring == isFiring then
		return
	end
	state.isFiring = isFiring
	sendFireIntent(isFiring)
end

local function setStatus(text: string, durationSeconds: number?)
	localPlayer:SetAttribute("LK_HUD_CombatStatus", text)
	localPlayer:SetAttribute(
		"LK_HUD_CombatStatusUntil",
		if text == "" then nil else Workspace:GetServerTimeNow() + (durationSeconds or 1.5)
	)
end

local function presentAmmunition(loadedRounds: number, reserveRounds: number, magazineCapacity: number)
	localPlayer:SetAttribute("LK_HUD_LoadedRounds", loadedRounds)
	localPlayer:SetAttribute("LK_HUD_ReserveRounds", reserveRounds)
	localPlayer:SetAttribute("LK_HUD_MagazineCapacity", magazineCapacity)
end

local function clearTargetPresentation()
	local targetHighlight = state.targetHighlight
	if targetHighlight ~= nil then
		targetHighlight:Destroy()
		state.targetHighlight = nil
	end
	state.selectedTargetEntityId = nil
end

local function findDisclosedTarget(entityId: string): Instance?
	local enemyFolder = Workspace:FindFirstChild("EnemyEntities")
	if enemyFolder == nil then
		return nil
	end
	for _, descendant in enemyFolder:GetDescendants() do
		if descendant:GetAttribute(COMBAT_ENTITY_ID_ATTRIBUTE) == entityId then
			return descendant
		end
	end
	return nil
end

local function presentSelectedTarget(targetEntityId: string)
	clearTargetPresentation()
	local target = findDisclosedTarget(targetEntityId)
	if target == nil then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "DisclosedCombatTarget"
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = Color3.fromRGB(255, 181, 62)
	-- Target selection is server-owned bookkeeping, not an aim assist overlay.
	-- Keep this object invisible for compatibility with presentation cleanup.
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.fromRGB(255, 232, 160)
	highlight.OutlineTransparency = 1
	highlight.Adornee = target
	highlight.Parent = target
	state.targetHighlight = highlight
	state.selectedTargetEntityId = targetEntityId
end

local function isNonEmptyString(value: unknown): boolean
	return type(value) == "string" and value ~= ""
end

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function isWholeNonnegative(value: unknown): boolean
	return isFiniteNumber(value) and value >= 0 and value % 1 == 0
end

local function presentAmmunitionPayload(payload: any): boolean
	local definition = resolveWeaponDefinition(payload.weaponId)
	if
		definition == nil
		or not isWholeNonnegative(payload.loadedRounds)
		or not isWholeNonnegative(payload.reserveRounds)
		or not isWholeNonnegative(payload.magazineCapacity)
		or payload.magazineCapacity <= 0
		or payload.loadedRounds > payload.magazineCapacity
		or not isWholeNonnegative(payload.maximumReserveRounds)
		or payload.reserveRounds > payload.maximumReserveRounds
	then
		return false
	end
	state.currentWeaponId = definition.WeaponId
	localPlayer:SetAttribute("LK_HUD_WeaponId", definition.WeaponId)
	localPlayer:SetAttribute("LK_HUD_WeaponName", definition.ShortName)
	presentAmmunition(payload.loadedRounds, payload.reserveRounds, payload.magazineCapacity)
	return true
end

local function onPresentationMessage(message: unknown)
	if type(message) ~= "table" then
		return
	end
	local payload = message :: any
	local kindId = payload.kindId
	if kindId == CombatContracts.PresentationMessageKindIds.TargetSelected then
		if isNonEmptyString(payload.targetEntityId) and isFiniteNumber(payload.serverTimestamp) then
			presentSelectedTarget(payload.targetEntityId)
		end
	elseif kindId == CombatContracts.PresentationMessageKindIds.TargetCleared then
		if isFiniteNumber(payload.serverTimestamp) then
			clearTargetPresentation()
		end
	elseif kindId == CombatContracts.PresentationMessageKindIds.ShotFired then
		if
			isNonEmptyString(payload.shotId)
			and isLocalOperativeEntityId(payload.operativeEntityId)
			and isKnownWeaponId(payload.weaponId)
			and isNonEmptyString(payload.targetEntityId)
			and isFiniteNumber(payload.serverTimestamp)
			and not state.presentedShotIds[payload.shotId]
		then
			state.presentedShotIds[payload.shotId] = true
			if payload.didApplyDamage == true then
				setStatus("HIT CONFIRMED", 0.5)
			end
		end
	elseif kindId == CombatContracts.PresentationMessageKindIds.ReloadStarted then
		if
			isLocalOperativeEntityId(payload.operativeEntityId)
			and isKnownWeaponId(payload.weaponId)
			and isFiniteNumber(payload.completionServerTimestamp)
		then
			setStatus("RELOADING", 4)
		end
	elseif kindId == CombatContracts.PresentationMessageKindIds.ReloadCompleted then
		if isLocalOperativeEntityId(payload.operativeEntityId) and isKnownWeaponId(payload.weaponId) then
			setStatus("RELOAD COMPLETE", 1.2)
		end
	elseif kindId == CombatContracts.PresentationMessageKindIds.ReloadInterrupted then
		if isLocalOperativeEntityId(payload.operativeEntityId) and isKnownWeaponId(payload.weaponId) then
			setStatus("RELOAD INTERRUPTED", 1.8)
		end
	elseif kindId == CombatContracts.PresentationMessageKindIds.AmmunitionState then
		presentAmmunitionPayload(payload)
	elseif kindId == CombatContracts.PresentationMessageKindIds.AmmunitionCollected then
		if
			presentAmmunitionPayload(payload)
			and isWholeNonnegative(payload.grantedRounds)
			and payload.grantedRounds > 0
		then
			setStatus("+" .. tostring(payload.grantedRounds) .. " AMMUNITION", 1.8)
		end
	end
end

--[[
	The one client reload path, cooldown-guarded. Keyboard R, gamepad R1 and the
	mobile reload button all call it, so there is a single request surface and one
	cooldown. Returns whether the intent was sent.
]]
function WeaponController.requestReload(): boolean
	if not state.started or state.destroyed then
		return false
	end
	local timestamp = os.clock()
	if timestamp - state.lastReloadRequestLocalTimestamp < REQUEST_COOLDOWN_SECONDS then
		return false
	end
	state.lastReloadRequestLocalTimestamp = timestamp
	reloadIntentRemote:FireServer(state.currentWeaponId)
	return true
end

local function onFireAction(_actionName: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if not state.started or state.destroyed then
		return Enum.ContextActionResult.Pass
	end
	if inputState == Enum.UserInputState.Begin then
		if UserInputService:GetFocusedTextBox() ~= nil then
			return Enum.ContextActionResult.Pass
		end
		setFiring(true)
		return Enum.ContextActionResult.Sink
	end
	if inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		setFiring(false)
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

local function onReloadAction(_actionName: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if not state.started or state.destroyed or inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if UserInputService:GetFocusedTextBox() ~= nil then
		return Enum.ContextActionResult.Pass
	end
	WeaponController.requestReload()
	return Enum.ContextActionResult.Sink
end

local function onInputBegan(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent or UserInputService:GetFocusedTextBox() ~= nil then
		return
	end
	if input.KeyCode ~= Enum.KeyCode.R then
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			setFiring(true)
		end
		return
	end
	WeaponController.requestReload()
end

local function onInputEnded(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		setFiring(false)
	end
end

function WeaponController.init()
	if state.initialized or state.destroyed then
		return
	end
	state.initialized = true
end

function WeaponController.start()
	if state.started or state.destroyed then
		return
	end
	WeaponController.init()
	state.started = true
	state.lastReloadRequestLocalTimestamp = -math.huge
	state.lastAimSendLocalTimestamp = -math.huge
	state.isFiring = false
	clearHudAttributes()
	createCrosshair()
	ContextActionService:BindAction(FIRE_ACTION_NAME, onFireAction, true, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle(FIRE_ACTION_NAME, "Fire")
	ContextActionService:BindAction(RELOAD_ACTION_NAME, onReloadAction, false, Enum.KeyCode.ButtonR1)
	state.inputBeganConnection = UserInputService.InputBegan:Connect(onInputBegan)
	state.inputEndedConnection = UserInputService.InputEnded:Connect(onInputEnded)
	state.renderConnection = RunService.RenderStepped:Connect(function()
		if state.isFiring and os.clock() - state.lastAimSendLocalTimestamp >= 0.1 then
			sendFireIntent(true)
		end
	end)
	state.presentationConnection = presentationRemote.OnClientEvent:Connect(onPresentationMessage)
end

function WeaponController.stop()
	if not state.started or state.destroyed then
		return
	end
	ContextActionService:UnbindAction(FIRE_ACTION_NAME)
	ContextActionService:UnbindAction(RELOAD_ACTION_NAME)
	if state.inputBeganConnection ~= nil then
		state.inputBeganConnection:Disconnect()
		state.inputBeganConnection = nil
	end
	if state.inputEndedConnection ~= nil then
		state.inputEndedConnection:Disconnect()
		state.inputEndedConnection = nil
	end
	if state.renderConnection ~= nil then
		state.renderConnection:Disconnect()
		state.renderConnection = nil
	end
	setFiring(false)
	if state.presentationConnection ~= nil then
		state.presentationConnection:Disconnect()
		state.presentationConnection = nil
	end
	clearTargetPresentation()
	if state.crosshairGui ~= nil then
		state.crosshairGui:Destroy()
		state.crosshairGui = nil
	end
	clearHudAttributes()
	table.clear(state.presentedShotIds)
	state.started = false
end

function WeaponController.destroy()
	if state.destroyed then
		return
	end
	WeaponController.stop()
	state.initialized = false
	state.destroyed = true
end

return WeaponController