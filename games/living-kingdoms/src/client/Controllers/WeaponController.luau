--!strict

--[[
	Owns local reload input and immediate presentation of server-disclosed combat
	events. The unified HordeHUDController renders ammunition and status through
	client-local Player attributes. This controller never selects legal targets,
	spends ammunition, resolves hits, changes health, or fabricates authority.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
	inputBeganConnection: RBXScriptConnection?,
	presentationConnection: RBXScriptConnection?,
	targetHighlight: Highlight?,
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
	inputBeganConnection = nil,
	presentationConnection = nil,
	targetHighlight = nil,
}

local combatNetwork = ReplicatedStorage:WaitForChild("CombatNetwork")
local reloadIntentRemote = combatNetwork:WaitForChild("ReloadIntent") :: RemoteEvent
local presentationRemote = combatNetwork:WaitForChild("CombatPresentation") :: RemoteEvent

local function clearHudAttributes()
	for _, attributeName in HUD_ATTRIBUTES do
		localPlayer:SetAttribute(attributeName, nil)
	end
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
	highlight.FillTransparency = 0.82
	highlight.OutlineColor = Color3.fromRGB(255, 232, 160)
	highlight.OutlineTransparency = 0
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
	The one client reload path, cooldown-guarded. Both the keyboard (R) and the
	mobile reload button call it, so there is a single request surface and one
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

local function onInputBegan(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent or input.KeyCode ~= Enum.KeyCode.R or UserInputService:GetFocusedTextBox() ~= nil then
		return
	end
	WeaponController.requestReload()
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
	clearHudAttributes()
	state.inputBeganConnection = UserInputService.InputBegan:Connect(onInputBegan)
	state.presentationConnection = presentationRemote.OnClientEvent:Connect(onPresentationMessage)
end

function WeaponController.stop()
	if not state.started or state.destroyed then
		return
	end
	if state.inputBeganConnection ~= nil then
		state.inputBeganConnection:Disconnect()
		state.inputBeganConnection = nil
	end
	if state.presentationConnection ~= nil then
		state.presentationConnection:Disconnect()
		state.presentationConnection = nil
	end
	clearTargetPresentation()
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
