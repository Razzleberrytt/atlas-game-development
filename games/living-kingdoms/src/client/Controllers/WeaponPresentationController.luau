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
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CombatContracts = require(ReplicatedStorage.Shared.Combat.CombatContracts)
local PrimaryCombatModeContracts = require(ReplicatedStorage.Shared.Combat.PrimaryCombatModeContracts)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)
local WeaponFeelConfig = require(ReplicatedStorage.Shared.Config.WeaponFeelConfig)

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

type WeaponFeelProfile = WeaponFeelConfig.WeaponFeelProfile
type WeaponPresentationRig = WeaponPresentationFactory.WeaponPresentationRig

type PlayerBinding = {
	characterAddedConnection: RBXScriptConnection,
	characterRemovingConnection: RBXScriptConnection,
	weaponAttributeConnection: RBXScriptConnection,
	combatModeAttributeConnection: RBXScriptConnection,
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
	baseGripCFrames: { [Player]: CFrame },
	viewmodelAnchor: BasePart?,
	viewmodelRenderConnection: RBXScriptConnection?,
	activeTweens: { [string]: Tween },
	presentedShotIds: { [string]: boolean },
	presentedShotOrder: { string },
	shotGeneration: number,
	reloadGeneration: number,
	lastLoadedRounds: number?,
	isReloading: boolean,
	recoilPitchDegrees: number,
	recoilYawDegrees: number,
	recoilFovDegrees: number,
	recoilRecoveryDegreesPerSecond: number,
}

local WeaponPresentationController = {}

local MAX_PRESENTED_SHOT_IDS = 128
local PRIMARY_COMBAT_MODE_ATTRIBUTE = PrimaryCombatModeContracts.AttributeName
local PrimaryCombatModeIds = PrimaryCombatModeContracts.ModeIds
local MODEL_NAME = "WeaponPresentation"
local VIEWMODEL_GRIP_CFRAME = CFrame.new(0.62, -0.72, -1.35) * CFrame.Angles(math.rad(-2), math.rad(90), math.rad(-4))

local state: State = {
	started = false,
	destroyed = false,
	playerAddedConnection = nil,
	playerRemovingConnection = nil,
	presentationConnection = nil,
	bindings = {},
	rigs = {},
	gripMotors = {},
	baseGripCFrames = {},
	viewmodelAnchor = nil,
	viewmodelRenderConnection = nil,
	activeTweens = {},
	presentedShotIds = {},
	presentedShotOrder = {},
	shotGeneration = 0,
	reloadGeneration = 0,
	lastLoadedRounds = nil,
	isReloading = false,
	recoilPitchDegrees = 0,
	recoilYawDegrees = 0,
	recoilFovDegrees = 0,
	recoilRecoveryDegreesPerSecond = 12,
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

local function localGripMotor(): Motor6D?
	local localPlayer = Players.LocalPlayer
	if localPlayer == nil then
		return nil
	end
	return state.gripMotors[localPlayer]
end

local function profileForRig(rig: WeaponPresentationRig): WeaponFeelProfile
	return WeaponFeelConfig.get(rig.model:GetAttribute("GameplayWeaponId")) or WeaponFeelConfig.Default
end

local function boltBackOffset(profile: WeaponFeelProfile): CFrame
	return CFrame.new(-profile.BoltTravelStuds, 0, 0)
end

local function gripKickOffset(profile: WeaponFeelProfile): CFrame
	return CFrame.new(-profile.GripKickBackStuds, 0, profile.GripKickUpStuds)
		* CFrame.Angles(0, math.rad(-profile.GripKickDegrees), 0)
end

local function magazineOutOffset(profile: WeaponFeelProfile): CFrame
	return CFrame.new(profile.MagazineOutX, 0, profile.MagazineOutZ)
		* CFrame.Angles(0, 0, math.rad(profile.MagazineRollDegrees))
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
	state.baseGripCFrames[player] = nil
	if player == Players.LocalPlayer then
		state.shotGeneration += 1
		state.reloadGeneration += 1
		state.isReloading = false
		cancelTween("Bolt")
		cancelTween("Magazine")
		cancelTween("Grip")
		if state.viewmodelAnchor ~= nil then
			state.viewmodelAnchor:Destroy()
			state.viewmodelAnchor = nil
		end
	end
	local rig = state.rigs[player]
	if rig ~= nil then
		rig.model:Destroy()
		state.rigs[player] = nil
	end
end

local function attachFirstPersonRig(player: Player, configuredId: string)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local rig = WeaponPresentationFactory.create(configuredId)
	local anchor = Instance.new("Part")
	anchor.Name = "FirstPersonWeaponAnchor"
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor.CFrame = camera.CFrame
	anchor.Parent = camera

	rig.root.CFrame = anchor.CFrame * VIEWMODEL_GRIP_CFRAME
	rig.model.Name = "FirstPersonWeapon"
	rig.model.Parent = camera
	local gripMotor = Instance.new("Motor6D")
	gripMotor.Name = "FirstPersonWeaponGrip"
	gripMotor.Part0 = anchor
	gripMotor.Part1 = rig.root
	gripMotor.C0 = VIEWMODEL_GRIP_CFRAME
	gripMotor.C1 = CFrame.identity
	gripMotor.Parent = anchor

	state.rigs[player] = rig
	state.gripMotors[player] = gripMotor
	state.baseGripCFrames[player] = VIEWMODEL_GRIP_CFRAME
	state.viewmodelAnchor = anchor
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
	if player:GetAttribute(PRIMARY_COMBAT_MODE_ATTRIBUTE) == PrimaryCombatModeIds.Melee then
		return
	end
	local weaponId = player:GetAttribute("LK_EquippedWeaponId")
	local configuredId = if isKnownWeaponId(weaponId) then weaponId else FirearmConfig.BasicFirearm.WeaponId
	if player == Players.LocalPlayer then
		attachFirstPersonRig(player, configuredId)
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
	state.baseGripCFrames[player] = rig.gripC0
end

local function unbindPlayer(player: Player)
	local binding = state.bindings[player]
	if binding ~= nil then
		binding.characterAddedConnection:Disconnect()
		binding.characterRemovingConnection:Disconnect()
		binding.weaponAttributeConnection:Disconnect()
		binding.combatModeAttributeConnection:Disconnect()
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
	local combatModeAttributeConnection = player
		:GetAttributeChangedSignal(PRIMARY_COMBAT_MODE_ATTRIBUTE)
		:Connect(function()
			local currentCharacter = player.Character
			if currentCharacter ~= nil then
				attachRig(player, currentCharacter)
			else
				destroyRig(player)
			end
		end)
	state.bindings[player] = {
		characterAddedConnection = characterAddedConnection,
		characterRemovingConnection = characterRemovingConnection,
		weaponAttributeConnection = weaponAttributeConnection,
		combatModeAttributeConnection = combatModeAttributeConnection,
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

local function resetGrip(durationSeconds: number)
	local rig = localRig()
	local gripMotor = localGripMotor()
	local localPlayer = Players.LocalPlayer
	local baseGrip = if localPlayer == nil then nil else state.baseGripCFrames[localPlayer]
	if rig == nil or gripMotor == nil or baseGrip == nil then
		return
	end
	playMotorTween("Grip", gripMotor, durationSeconds, baseGrip, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
end

local function lockBoltOpen(durationSeconds: number)
	local rig = localRig()
	if rig == nil then
		return
	end
	local profile = profileForRig(rig)
	playMotorTween(
		"Bolt",
		rig.boltMotor,
		durationSeconds,
		rig.boltRestC0 * boltBackOffset(profile),
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
end

local function playShot(
	shotId: string,
	operativeEntityId: string,
	didApplyDamage: boolean,
	impactWorldPosition: Vector3?,
	secondaryImpactWorldPositions: { Vector3 }
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
	WeaponShotEffectPresenter.present(rig, shotId, didApplyDamage, impactWorldPosition, secondaryImpactWorldPositions)
	if shooter ~= Players.LocalPlayer then
		RemoteWeaponMotionPresenter.presentShot(shooter, rig)
		return
	end
	local gripMotor = state.gripMotors[shooter]
	local baseGrip = state.baseGripCFrames[shooter]
	if gripMotor == nil or baseGrip == nil then
		return
	end
	local profile = profileForRig(rig)
	local lastByte = string.byte(shotId, #shotId) or 0
	local yawSign = if lastByte % 2 == 0 then -1 else 1
	state.recoilPitchDegrees = math.min(5.5, state.recoilPitchDegrees + profile.CameraKickDegrees)
	state.recoilYawDegrees = math.clamp(state.recoilYawDegrees + profile.CameraYawDegrees * yawSign, -1.25, 1.25)
	state.recoilFovDegrees = math.min(2.5, state.recoilFovDegrees + profile.CameraFovKickDegrees)
	state.recoilRecoveryDegreesPerSecond = profile.CameraRecoveryDegreesPerSecond
	state.shotGeneration += 1
	local generation = state.shotGeneration
	playMotorTween(
		"Grip",
		gripMotor,
		profile.ShotBackSeconds,
		baseGrip * gripKickOffset(profile),
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	local backTween = playMotorTween(
		"Bolt",
		rig.boltMotor,
		profile.ShotBackSeconds,
		rig.boltRestC0 * boltBackOffset(profile),
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	backTween.Completed:Once(function(playbackState)
		if playbackState ~= Enum.PlaybackState.Completed or generation ~= state.shotGeneration then
			return
		end
		resetGrip(profile.ShotReturnSeconds)
		if state.lastLoadedRounds == 0 then
			lockBoltOpen(profile.ShotReturnSeconds)
		else
			resetBolt(profile.ShotReturnSeconds)
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
	local profile = profileForRig(rig)
	state.reloadGeneration += 1
	local generation = state.reloadGeneration
	state.isReloading = true
	state.shotGeneration += 1
	resetBolt(0.08)
	resetGrip(0.08)
	local remaining = math.clamp(completionServerTimestamp - Workspace:GetServerTimeNow(), 0.15, 5)
	local outwardDuration = remaining * profile.ReloadOutwardFraction
	local holdDuration = remaining * profile.ReloadHoldFraction
	local returnDuration = remaining * profile.ReloadReturnFraction
	local outwardTween = playMotorTween(
		"Magazine",
		rig.magazineMotor,
		outwardDuration,
		rig.magazineRestC0 * magazineOutOffset(profile),
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
	resetGrip(0.08)
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
	resetGrip(0.12)
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

local function readSecondaryImpactPositions(value: unknown): { Vector3 }?
	if value == nil then
		return {}
	end
	if type(value) ~= "table" or #value > 3 then
		return nil
	end
	local positions = {}
	for _, impact in value :: any do
		if
			type(impact) ~= "table"
			or not isNonEmptyString(impact.targetEntityId)
			or typeof(impact.impactWorldPosition) ~= "Vector3"
			or not isWholeNonnegative(impact.damageAmount)
			or impact.damageAmount <= 0
		then
			return nil
		end
		table.insert(positions, impact.impactWorldPosition)
	end
	return positions
end

local function onPresentationMessage(message: unknown)
	if type(message) ~= "table" then
		return
	end
	local payload = message :: any
	local kindId = payload.kindId
	if kindId == CombatContracts.PresentationMessageKindIds.ShotFired then
		local secondaryImpactWorldPositions = readSecondaryImpactPositions(payload.secondaryImpacts)
		if
			isNonEmptyString(payload.shotId)
			and isNonEmptyString(payload.operativeEntityId)
			and isKnownWeaponId(payload.weaponId)
			and isNonEmptyString(payload.targetEntityId)
			and type(payload.didApplyDamage) == "boolean"
			and ((payload.didApplyDamage and typeof(payload.impactWorldPosition) == "Vector3") or (not payload.didApplyDamage and payload.impactWorldPosition == nil))
			and isFiniteNumber(payload.serverTimestamp)
			and secondaryImpactWorldPositions ~= nil
		then
			playShot(
				payload.shotId,
				payload.operativeEntityId,
				payload.didApplyDamage,
				payload.impactWorldPosition,
				secondaryImpactWorldPositions
			)
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
	state.viewmodelRenderConnection = RunService.RenderStepped:Connect(function(deltaTime)
		local anchor = state.viewmodelAnchor
		local camera = Workspace.CurrentCamera
		if anchor == nil or camera == nil then
			return
		end
		if anchor.Parent ~= camera then
			anchor.Parent = camera
		end
		local localRigValue = state.rigs[Players.LocalPlayer]
		if localRigValue ~= nil and localRigValue.model.Parent ~= camera then
			localRigValue.model.Parent = camera
		end
		anchor.CFrame = camera.CFrame
		if state.recoilPitchDegrees > 0 or math.abs(state.recoilYawDegrees) > 0.001 then
			camera.CFrame *= CFrame.Angles(math.rad(-state.recoilPitchDegrees), math.rad(state.recoilYawDegrees), 0)
		end
		camera.FieldOfView += state.recoilFovDegrees
		local recovery = state.recoilRecoveryDegreesPerSecond * math.min(deltaTime, 0.05)
		state.recoilPitchDegrees = math.max(0, state.recoilPitchDegrees - recovery)
		if state.recoilYawDegrees > 0 then
			state.recoilYawDegrees = math.max(0, state.recoilYawDegrees - recovery * 0.45)
		else
			state.recoilYawDegrees = math.min(0, state.recoilYawDegrees + recovery * 0.45)
		end
		state.recoilFovDegrees = math.max(0, state.recoilFovDegrees - recovery * 0.7)
	end)
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
	if state.viewmodelRenderConnection ~= nil then
		state.viewmodelRenderConnection:Disconnect()
		state.viewmodelRenderConnection = nil
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
	table.clear(state.baseGripCFrames)
	state.lastLoadedRounds = nil
	state.isReloading = false
	state.recoilPitchDegrees = 0
	state.recoilYawDegrees = 0
	state.recoilFovDegrees = 0
end

function WeaponPresentationController.destroy()
	if state.destroyed then
		return
	end
	WeaponPresentationController.stop()
	state.destroyed = true
end

return table.freeze(WeaponPresentationController)
