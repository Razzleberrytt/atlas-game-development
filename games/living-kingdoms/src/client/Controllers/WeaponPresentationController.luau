--!strict

--[[
	VIS-0102 local weapon presentation owner. Every visible carbine is client-only
	presentation attached to an existing character. Only server-disclosed combat
	events may start fire, reload, empty, or recovery motion. This controller never
	fires a remote, spends ammunition, selects targets, resolves hits, changes
	health, or completes a reload.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
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
local WeaponPresentationFactory = require(script.Parent.Parent.Presentation.WeaponPresentationFactory)
local RemoteWeaponMotionPresenter = require(script.Parent.Parent.Presentation.RemoteWeaponMotionPresenter)
local WeaponShotEffectPresenter = require(script.Parent.Parent.Presentation.WeaponShotEffectPresenter)

type WeaponPresentationRig = WeaponPresentationFactory.WeaponPresentationRig

type PlayerBinding = {
	characterAddedConnection: RBXScriptConnection,
	characterRemovingConnection: RBXScriptConnection,
	weaponAttributeConnection: RBXScriptConnection,
}

type State = {
	started: boolean,
	destroyed: boolean,
	playerAddedConnection: RBXScriptConnection?,
	playerRemovingConnection: RBXScriptConnection?,
	presentationConnection: RBXScriptConnection?,
	bindings: { [Player]: PlayerBinding },
	rigs: { [Player]: WeaponPresentationRig },
	gripMotors: { [Player]: Motor6D },
	activeTweens: { [string]: Tween },
	presentedShotIds: { [string]: boolean },
	presentedShotOrder: { string },
	shotGeneration: number,
	reloadGeneration: number,
	lastLoadedRounds: number?,
	isReloading: boolean,
}

local WeaponPresentationController = {}

local MAX_PRESENTED_SHOT_IDS = 128
local MODEL_NAME = "WeaponPresentation"
local BOLT_BACK_OFFSET = CFrame.new(-0.2, 0, 0)
local MAGAZINE_OUT_OFFSET = CFrame.new(0.22, 0, -0.75) * CFrame.Angles(0, 0, math.rad(8))

local state: State = {
	started = false,
	destroyed = false,
	playerAddedConnection = nil,
	playerRemovingConnection = nil,
	presentationConnection = nil,
	bindings = {},
	rigs = {},
	gripMotors = {},
	activeTweens = {},
	presentedShotIds = {},
	presentedShotOrder = {},
	shotGeneration = 0,
	reloadGeneration = 0,
	lastLoadedRounds = nil,
	isReloading = false,
}

local combatNetwork = ReplicatedStorage:WaitForChild("CombatNetwork")
local presentationRemote = combatNetwork:WaitForChild("CombatPresentation") :: RemoteEvent

local function isNonEmptyString(value: unknown): boolean
	return type(value) == "string" and value ~= ""
end

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function isWholeNonnegative(value: unknown): boolean
	return isFiniteNumber(value) and value >= 0 and value % 1 == 0
end

local function operativeEntityIdForPlayer(player: Player): string
	return "operative.player:" .. tostring(player.UserId)
end

local function playerForOperativeEntityId(operativeEntityId: string): Player?
	for _, player in Players:GetPlayers() do
		if operativeEntityIdForPlayer(player) == operativeEntityId then
			return player
		end
	end
	return nil
end

local function cancelTween(key: string)
	local tween = state.activeTweens[key]
	if tween ~= nil then
		tween:Cancel()
		state.activeTweens[key] = nil
	end
end

local function playMotorTween(
	key: string,
	motor: Motor6D,
	durationSeconds: number,
	targetC0: CFrame,
	easingStyle: Enum.EasingStyle,
	easingDirection: Enum.EasingDirection
): Tween
	cancelTween(key)
	local tween = TweenService:Create(
		motor,
		TweenInfo.new(math.max(0.01, durationSeconds), easingStyle, easingDirection),
		{ C0 = targetC0 }
	)
	state.activeTweens[key] = tween
	tween.Completed:Once(function()
		if state.activeTweens[key] == tween then
			state.activeTweens[key] = nil
		end
	end)
	tween:Play()
	return tween
end

local function localRig(): WeaponPresentationRig?
	local localPlayer = Players.LocalPlayer
	if localPlayer == nil then
		return nil
	end
	return state.rigs[localPlayer]
end

local function destroyRig(player: Player)
	RemoteWeaponMotionPresenter.cleanupPlayer(player)
	local gripMotor = state.gripMotors[player]
	if gripMotor ~= nil then
		if gripMotor.Parent ~= nil then
			gripMotor:Destroy()
		end
		state.gripMotors[player] = nil
	end
	if player == Players.LocalPlayer then
		state.shotGeneration += 1
		state.reloadGeneration += 1
		state.isReloading = false
		cancelTween("Bolt")
		cancelTween("Magazine")
	end
	local rig = state.rigs[player]
	if rig ~= nil then
		rig.model:Destroy()
		state.rigs[player] = nil
	end
end

local function resolveRightHand(character: Model): BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local preferredName = if humanoid ~= nil and humanoid.RigType == Enum.HumanoidRigType.R6
		then "Right Arm"
		else "RightHand"
	local preferred = character:FindFirstChild(preferredName)
	if preferred == nil then
		preferred = character:WaitForChild(preferredName, 3)
	end
	if preferred ~= nil and preferred:IsA("BasePart") then
		return preferred
	end
	local fallbackName = if preferredName == "RightHand" then "Right Arm" else "RightHand"
	local fallback = character:FindFirstChild(fallbackName)
	if fallback ~= nil and fallback:IsA("BasePart") then
		return fallback
	end
	return nil
end

local function attachRig(player: Player, character: Model)
	destroyRig(player)
	if not state.started or character.Parent == nil then
		return
	end
	local hand = resolveRightHand(character)
	if hand == nil or not state.started or character.Parent == nil then
		return
	end
	local staleGrip = hand:FindFirstChild("WeaponGrip")
	if staleGrip ~= nil then
		staleGrip:Destroy()
	end
	local existing = character:FindFirstChild(MODEL_NAME)
	if existing ~= nil then
		existing:Destroy()
	end

	local weaponId = player:GetAttribute("LK_EquippedWeaponId")
	local configuredId = if isKnownWeaponId(weaponId) then weaponId else FirearmConfig.BasicFirearm.WeaponId
	local rig = WeaponPresentationFactory.create(configuredId)
	rig.root.CFrame = hand.CFrame * rig.gripC0
	rig.model.Parent = character

	local gripMotor = Instance.new("Motor6D")
	gripMotor.Name = "WeaponGrip"
	gripMotor.Part0 = hand
	gripMotor.Part1 = rig.root
	gripMotor.C0 = rig.gripC0
	gripMotor.C1 = CFrame.identity
	gripMotor.Parent = hand

	state.rigs[player] = rig
	state.gripMotors[player] = gripMotor
end

local function unbindPlayer(player: Player)
	local binding = state.bindings[player]
	if binding ~= nil then
		binding.characterAddedConnection:Disconnect()
		binding.characterRemovingConnection:Disconnect()
		binding.weaponAttributeConnection:Disconnect()
		state.bindings[player] = nil
	end
	destroyRig(player)
end

local function bindPlayer(player: Player)
	if state.bindings[player] ~= nil then
		return
	end
	local characterAddedConnection = player.CharacterAdded:Connect(function(character)
		attachRig(player, character)
	end)
	local characterRemovingConnection = player.CharacterRemoving:Connect(function()
		destroyRig(player)
	end)
	local weaponAttributeConnection = player:GetAttributeChangedSignal("LK_EquippedWeaponId"):Connect(function()
		local currentCharacter = player.Character
		if currentCharacter ~= nil then
			attachRig(player, currentCharacter)
		end
	end)
	state.bindings[player] = {
		characterAddedConnection = characterAddedConnection,
		characterRemovingConnection = characterRemovingConnection,
		weaponAttributeConnection = weaponAttributeConnection,
	}
	local character = player.Character
	if character ~= nil then
		task.defer(attachRig, player, character)
	end
end

local function rememberShot(shotId: string): boolean
	if state.presentedShotIds[shotId] then
		return false
	end
	state.presentedShotIds[shotId] = true
	table.insert(state.presentedShotOrder, shotId)
	if #state.presentedShotOrder > MAX_PRESENTED_SHOT_IDS then
		local expired = table.remove(state.presentedShotOrder, 1)
		if expired ~= nil then
			state.presentedShotIds[expired] = nil
		end
	end
	return true
end

local function resetBolt(durationSeconds: number)
	local rig = localRig()
	if rig == nil then
		return
	end
	playMotorTween(
		"Bolt",
		rig.boltMotor,
		durationSeconds,
		rig.boltRestC0,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
end

local function lockBoltOpen(durationSeconds: number)
	local rig = localRig()
	if rig == nil then
		return
	end
	playMotorTween(
		"Bolt",
		rig.boltMotor,
		durationSeconds,
		rig.boltRestC0 * BOLT_BACK_OFFSET,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
end

local function playShot(
	shotId: string,
	operativeEntityId: string,
	didApplyDamage: boolean,
	impactWorldPosition: Vector3?
)
	if not rememberShot(shotId) then
		return
	end
	local shooter = playerForOperativeEntityId(operativeEntityId)
	if shooter == nil then
		return
	end
	local rig = state.rigs[shooter]
	if rig == nil then
		return
	end
	WeaponShotEffectPresenter.present(rig, shotId, didApplyDamage, impactWorldPosition)
	if shooter ~= Players.LocalPlayer then
		RemoteWeaponMotionPresenter.presentShot(shooter, rig)
		return
	end
	state.shotGeneration += 1
	local generation = state.shotGeneration
	local backTween = playMotorTween(
		"Bolt",
		rig.boltMotor,
		0.045,
		rig.boltRestC0 * BOLT_BACK_OFFSET,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	backTween.Completed:Once(function(playbackState)
		if playbackState ~= Enum.PlaybackState.Completed or generation ~= state.shotGeneration then
			return
		end
		if state.lastLoadedRounds == 0 then
			lockBoltOpen(0.06)
		else
			resetBolt(0.065)
		end
	end)
end

local function resetMagazine(durationSeconds: number)
	local rig = localRig()
	if rig == nil then
		return
	end
	playMotorTween(
		"Magazine",
		rig.magazineMotor,
		durationSeconds,
		rig.magazineRestC0,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
end

local function playReload(operativeEntityId: string, completionServerTimestamp: number)
	local player = playerForOperativeEntityId(operativeEntityId)
	if player == nil then
		return
	end
	local rig = state.rigs[player]
	if rig == nil then
		return
	end
	if player ~= Players.LocalPlayer then
		RemoteWeaponMotionPresenter.presentReloadStarted(player, rig, completionServerTimestamp)
		return
	end
	state.reloadGeneration += 1
	local generation = state.reloadGeneration
	state.isReloading = true
	state.shotGeneration += 1
	resetBolt(0.08)
	local remaining = math.clamp(completionServerTimestamp - Workspace:GetServerTimeNow(), 0.15, 5)
	local outwardDuration = remaining * 0.36
	local holdDuration = remaining * 0.22
	local returnDuration = remaining * 0.42
	local outwardTween = playMotorTween(
		"Magazine",
		rig.magazineMotor,
		outwardDuration,
		rig.magazineRestC0 * MAGAZINE_OUT_OFFSET,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	outwardTween.Completed:Once(function(playbackState)
		if playbackState ~= Enum.PlaybackState.Completed or generation ~= state.reloadGeneration then
			return
		end
		task.delay(holdDuration, function()
			if generation ~= state.reloadGeneration or not state.isReloading then
				return
			end
			resetMagazine(returnDuration)
		end)
	end)
end

local function finishReload(operativeEntityId: string)
	local player = playerForOperativeEntityId(operativeEntityId)
	if player == nil then
		return
	end
	local rig = state.rigs[player]
	if rig == nil then
		return
	end
	if player ~= Players.LocalPlayer then
		RemoteWeaponMotionPresenter.presentReloadCompleted(player, rig)
		return
	end
	state.reloadGeneration += 1
	state.isReloading = false
	resetMagazine(0.08)
	if state.lastLoadedRounds ~= nil and state.lastLoadedRounds > 0 then
		resetBolt(0.08)
	end
end

local function interruptReload(operativeEntityId: string)
	local player = playerForOperativeEntityId(operativeEntityId)
	if player == nil then
		return
	end
	local rig = state.rigs[player]
	if rig == nil then
		return
	end
	if player ~= Players.LocalPlayer then
		RemoteWeaponMotionPresenter.presentReloadInterrupted(player, rig)
		return
	end
	state.reloadGeneration += 1
	state.isReloading = false
	resetMagazine(0.12)
	if state.lastLoadedRounds == 0 then
		lockBoltOpen(0.12)
	else
		resetBolt(0.12)
	end
end

local function presentAmmunitionPayload(payload: any): boolean
	if
		not isKnownWeaponId(payload.weaponId)
		or not isWholeNonnegative(payload.loadedRounds)
		or not isWholeNonnegative(payload.magazineCapacity)
		or payload.magazineCapacity <= 0
		or payload.loadedRounds > payload.magazineCapacity
	then
		return false
	end
	state.lastLoadedRounds = payload.loadedRounds
	if not state.isReloading then
		if payload.loadedRounds == 0 then
			lockBoltOpen(0.22)
		else
			resetBolt(0.08)
		end
	end
	return true
end

local function onPresentationMessage(message: unknown)
	if type(message) ~= "table" then
		return
	end
	local payload = message :: any
	local kindId = payload.kindId
	if kindId == CombatContracts.PresentationMessageKindIds.ShotFired then
		if
			isNonEmptyString(payload.shotId)
			and isNonEmptyString(payload.operativeEntityId)
			and isKnownWeaponId(payload.weaponId)
			and isNonEmptyString(payload.targetEntityId)
			and type(payload.didApplyDamage) == "boolean"
			and ((payload.didApplyDamage and typeof(payload.impactWorldPosition) == "Vector3") or (not payload.didApplyDamage and payload.impactWorldPosition == nil))
			and isFiniteNumber(payload.serverTimestamp)
		then
			playShot(payload.shotId, payload.operativeEntityId, payload.didApplyDamage, payload.impactWorldPosition)
		end
	elseif kindId == CombatContracts.PresentationMessageKindIds.ReloadStarted then
		if
			isNonEmptyString(payload.operativeEntityId)
			and isKnownWeaponId(payload.weaponId)
			and isFiniteNumber(payload.completionServerTimestamp)
		then
			playReload(payload.operativeEntityId, payload.completionServerTimestamp)
		end
	elseif kindId == CombatContracts.PresentationMessageKindIds.ReloadCompleted then
		if isNonEmptyString(payload.operativeEntityId) and isKnownWeaponId(payload.weaponId) then
			finishReload(payload.operativeEntityId)
		end
	elseif kindId == CombatContracts.PresentationMessageKindIds.ReloadInterrupted then
		if isNonEmptyString(payload.operativeEntityId) and isKnownWeaponId(payload.weaponId) then
			interruptReload(payload.operativeEntityId)
		end
	elseif
		kindId == CombatContracts.PresentationMessageKindIds.AmmunitionState
		or kindId == CombatContracts.PresentationMessageKindIds.AmmunitionCollected
	then
		presentAmmunitionPayload(payload)
	end
end

function WeaponPresentationController.start()
	if state.started or state.destroyed then
		return
	end
	state.started = true
	for _, player in Players:GetPlayers() do
		bindPlayer(player)
	end
	state.playerAddedConnection = Players.PlayerAdded:Connect(bindPlayer)
	state.playerRemovingConnection = Players.PlayerRemoving:Connect(unbindPlayer)
	state.presentationConnection = presentationRemote.OnClientEvent:Connect(onPresentationMessage)
end

function WeaponPresentationController.stop()
	if not state.started or state.destroyed then
		return
	end
	state.started = false
	if state.playerAddedConnection ~= nil then
		state.playerAddedConnection:Disconnect()
		state.playerAddedConnection = nil
	end
	if state.playerRemovingConnection ~= nil then
		state.playerRemovingConnection:Disconnect()
		state.playerRemovingConnection = nil
	end
	if state.presentationConnection ~= nil then
		state.presentationConnection:Disconnect()
		state.presentationConnection = nil
	end
	for player in state.bindings do
		unbindPlayer(player)
	end
	for key in state.activeTweens do
		cancelTween(key)
	end
	RemoteWeaponMotionPresenter.stop()
	table.clear(state.presentedShotIds)
	table.clear(state.presentedShotOrder)
	state.lastLoadedRounds = nil
	state.isReloading = false
end

function WeaponPresentationController.destroy()
	if state.destroyed then
		return
	end
	WeaponPresentationController.stop()
	state.destroyed = true
end

return table.freeze(WeaponPresentationController)
