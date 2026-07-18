--!strict

--[[
	VIS-0102 presentation-only motion for non-local operative carbines. It reacts
	only to server-disclosed accepted shots and authoritative reload lifecycle
	messages. It owns no targeting, ammunition, cadence, hit, damage, health, or
	reload completion state.
]]

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local WeaponPresentationFactory = require(script.Parent.WeaponPresentationFactory)

type WeaponPresentationRig = WeaponPresentationFactory.WeaponPresentationRig

type MotionState = {
	shotGeneration: number,
	reloadGeneration: number,
	isReloading: boolean,
	activeTweens: { [string]: Tween },
}

local RemoteWeaponMotionPresenter = {}

local BOLT_BACK_OFFSET = CFrame.new(-0.2, 0, 0)
local MAGAZINE_OUT_OFFSET = CFrame.new(0.22, 0, -0.75) * CFrame.Angles(0, 0, math.rad(8))
local states: { [Player]: MotionState } = {}

local function stateFor(player: Player): MotionState
	local existing = states[player]
	if existing ~= nil then
		return existing
	end
	local created: MotionState = {
		shotGeneration = 0,
		reloadGeneration = 0,
		isReloading = false,
		activeTweens = {},
	}
	states[player] = created
	return created
end

local function cancelTween(motionState: MotionState, key: string)
	local tween = motionState.activeTweens[key]
	if tween ~= nil then
		tween:Cancel()
		motionState.activeTweens[key] = nil
	end
end

local function playMotorTween(
	motionState: MotionState,
	key: string,
	motor: Motor6D,
	durationSeconds: number,
	targetC0: CFrame,
	easingStyle: Enum.EasingStyle,
	easingDirection: Enum.EasingDirection
): Tween
	cancelTween(motionState, key)
	local tween = TweenService:Create(
		motor,
		TweenInfo.new(math.max(0.01, durationSeconds), easingStyle, easingDirection),
		{ C0 = targetC0 }
	)
	motionState.activeTweens[key] = tween
	tween.Completed:Once(function()
		if motionState.activeTweens[key] == tween then
			motionState.activeTweens[key] = nil
		end
	end)
	tween:Play()
	return tween
end

local function resetBolt(motionState: MotionState, rig: WeaponPresentationRig, durationSeconds: number)
	playMotorTween(
		motionState,
		"Bolt",
		rig.boltMotor,
		durationSeconds,
		rig.boltRestC0,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
end

local function resetMagazine(motionState: MotionState, rig: WeaponPresentationRig, durationSeconds: number)
	playMotorTween(
		motionState,
		"Magazine",
		rig.magazineMotor,
		durationSeconds,
		rig.magazineRestC0,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
end

function RemoteWeaponMotionPresenter.presentShot(player: Player, rig: WeaponPresentationRig)
	local motionState = stateFor(player)
	motionState.shotGeneration += 1
	local generation = motionState.shotGeneration
	local backTween = playMotorTween(
		motionState,
		"Bolt",
		rig.boltMotor,
		0.045,
		rig.boltRestC0 * BOLT_BACK_OFFSET,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	backTween.Completed:Once(function(playbackState)
		if
			playbackState ~= Enum.PlaybackState.Completed
			or states[player] ~= motionState
			or generation ~= motionState.shotGeneration
		then
			return
		end
		resetBolt(motionState, rig, 0.065)
	end)
end

function RemoteWeaponMotionPresenter.presentReloadStarted(
	player: Player,
	rig: WeaponPresentationRig,
	completionServerTimestamp: number
)
	local motionState = stateFor(player)
	motionState.reloadGeneration += 1
	local generation = motionState.reloadGeneration
	motionState.isReloading = true
	motionState.shotGeneration += 1
	resetBolt(motionState, rig, 0.08)
	local remaining = math.clamp(completionServerTimestamp - Workspace:GetServerTimeNow(), 0.15, 5)
	local outwardDuration = remaining * 0.36
	local holdDuration = remaining * 0.22
	local returnDuration = remaining * 0.42
	local outwardTween = playMotorTween(
		motionState,
		"Magazine",
		rig.magazineMotor,
		outwardDuration,
		rig.magazineRestC0 * MAGAZINE_OUT_OFFSET,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	outwardTween.Completed:Once(function(playbackState)
		if
			playbackState ~= Enum.PlaybackState.Completed
			or states[player] ~= motionState
			or generation ~= motionState.reloadGeneration
		then
			return
		end
		task.delay(holdDuration, function()
			if
				states[player] ~= motionState
				or generation ~= motionState.reloadGeneration
				or not motionState.isReloading
			then
				return
			end
			resetMagazine(motionState, rig, returnDuration)
		end)
	end)
end

function RemoteWeaponMotionPresenter.presentReloadCompleted(player: Player, rig: WeaponPresentationRig)
	local motionState = stateFor(player)
	motionState.reloadGeneration += 1
	motionState.isReloading = false
	resetMagazine(motionState, rig, 0.08)
	resetBolt(motionState, rig, 0.08)
end

function RemoteWeaponMotionPresenter.presentReloadInterrupted(player: Player, rig: WeaponPresentationRig)
	local motionState = stateFor(player)
	motionState.reloadGeneration += 1
	motionState.isReloading = false
	resetMagazine(motionState, rig, 0.12)
	resetBolt(motionState, rig, 0.12)
end

function RemoteWeaponMotionPresenter.cleanupPlayer(player: Player)
	local motionState = states[player]
	if motionState == nil then
		return
	end
	motionState.shotGeneration += 1
	motionState.reloadGeneration += 1
	motionState.isReloading = false
	for key in motionState.activeTweens do
		cancelTween(motionState, key)
	end
	states[player] = nil
end

function RemoteWeaponMotionPresenter.stop()
	for player in states do
		RemoteWeaponMotionPresenter.cleanupPlayer(player)
	end
end

return table.freeze(RemoteWeaponMotionPresenter)
