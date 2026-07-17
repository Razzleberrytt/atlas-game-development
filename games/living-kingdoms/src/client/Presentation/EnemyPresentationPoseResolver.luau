--!strict

--[[
	VIS-0103 pure pose selection for the Exclusion Walker procedural fallback.
	Inputs are replicated presentation facts. The resolver cannot move an enemy,
	choose a target, apply damage, change health, or alter death and cleanup.
]]

local PoseIds = table.freeze({
	Idle = "Idle",
	RoamingA = "RoamingA",
	RoamingB = "RoamingB",
	PursuingA = "PursuingA",
	PursuingB = "PursuingB",
	ThreatReady = "ThreatReady",
	WindupEarlyLeft = "WindupEarlyLeft",
	WindupEarlyRight = "WindupEarlyRight",
	WindupLateLeft = "WindupLateLeft",
	WindupLateRight = "WindupLateRight",
	StrikeActiveLeft = "StrikeActiveLeft",
	StrikeActiveRight = "StrikeActiveRight",
	StrikeRecoveryLeft = "StrikeRecoveryLeft",
	StrikeRecoveryRight = "StrikeRecoveryRight",
	HitReaction = "HitReaction",
	StandDown = "StandDown",
	Dead = "Dead",
})

local SensorModes = table.freeze({
	Normal = "Normal",
	Alert = "Alert",
	Windup = "Windup",
	Strike = "Strike",
	Hit = "Hit",
	Dim = "Dim",
	Dead = "Dead",
})

local Timing = table.freeze({
	HitReactionSeconds = 0.28,
	WindupLateProgress = 0.55,
	AttackActiveSeconds = 0.16,
	AttackRecoverySeconds = 0.52,
})

export type PoseInput = {
	isDead: boolean,
	isStoodDown: boolean,
	isMoving: boolean,
	isPursuing: boolean,
	isWindingUp: boolean,
	windupSequence: number,
	windupProgress: number?,
	attackSequence: number,
	secondsSinceAttack: number?,
	secondsSinceHit: number?,
	strideIndex: number,
}

export type Pose = {
	id: string,
	torsoPitchDegrees: number,
	torsoRollDegrees: number,
	leftArmPitchDegrees: number,
	rightArmPitchDegrees: number,
	leftArmRollDegrees: number,
	rightArmRollDegrees: number,
	leftLegPitchDegrees: number,
	rightLegPitchDegrees: number,
	sensorMode: string,
}

local function pose(
	id: string,
	torsoPitchDegrees: number,
	torsoRollDegrees: number,
	leftArmPitchDegrees: number,
	rightArmPitchDegrees: number,
	leftArmRollDegrees: number,
	rightArmRollDegrees: number,
	leftLegPitchDegrees: number,
	rightLegPitchDegrees: number,
	sensorMode: string
): Pose
	return table.freeze({
		id = id,
		torsoPitchDegrees = torsoPitchDegrees,
		torsoRollDegrees = torsoRollDegrees,
		leftArmPitchDegrees = leftArmPitchDegrees,
		rightArmPitchDegrees = rightArmPitchDegrees,
		leftArmRollDegrees = leftArmRollDegrees,
		rightArmRollDegrees = rightArmRollDegrees,
		leftLegPitchDegrees = leftLegPitchDegrees,
		rightLegPitchDegrees = rightLegPitchDegrees,
		sensorMode = sensorMode,
	})
end

local IDLE = pose(PoseIds.Idle, 0, 0, 5, -5, 4, -4, 0, 0, SensorModes.Normal)
local THREAT_READY = pose(PoseIds.ThreatReady, -8, 0, -38, -38, 12, -12, 5, -5, SensorModes.Alert)
local WINDUP_EARLY_LEFT = pose(PoseIds.WindupEarlyLeft, 8, 7, 22, -54, -14, -18, -5, 5, SensorModes.Windup)
local WINDUP_EARLY_RIGHT = pose(PoseIds.WindupEarlyRight, 8, -7, -54, 22, 18, 14, 5, -5, SensorModes.Windup)
local WINDUP_LATE_LEFT = pose(PoseIds.WindupLateLeft, 15, 13, 48, -86, -25, -32, -10, 10, SensorModes.Windup)
local WINDUP_LATE_RIGHT = pose(PoseIds.WindupLateRight, 15, -13, -86, 48, 32, 25, 10, -10, SensorModes.Windup)
local STRIKE_ACTIVE_LEFT = pose(PoseIds.StrikeActiveLeft, -21, -11, -92, -24, -31, -6, 15, -15, SensorModes.Strike)
local STRIKE_ACTIVE_RIGHT = pose(PoseIds.StrikeActiveRight, -21, 11, -24, -92, 6, 31, -15, 15, SensorModes.Strike)
local STRIKE_RECOVERY_LEFT = pose(PoseIds.StrikeRecoveryLeft, 3, 6, -18, -42, 13, -16, -7, 7, SensorModes.Alert)
local STRIKE_RECOVERY_RIGHT = pose(PoseIds.StrikeRecoveryRight, 3, -6, -42, -18, 16, -13, 7, -7, SensorModes.Alert)
local HIT_REACTION = pose(PoseIds.HitReaction, 16, 9, 26, -34, -18, 20, -8, 8, SensorModes.Hit)
local STAND_DOWN = pose(PoseIds.StandDown, 19, 0, 38, 38, 12, -12, 0, 0, SensorModes.Dim)
local DEAD = pose(PoseIds.Dead, 72, 13, 66, 58, 24, -28, -18, 22, SensorModes.Dead)

local EnemyPresentationPoseResolver = {
	PoseIds = PoseIds,
	SensorModes = SensorModes,
	Timing = Timing,
}

function EnemyPresentationPoseResolver.resolve(input: PoseInput): Pose
	if input.isDead then
		return DEAD
	end

	local secondsSinceHit = input.secondsSinceHit
	if secondsSinceHit ~= nil and secondsSinceHit >= 0 and secondsSinceHit <= Timing.HitReactionSeconds then
		return HIT_REACTION
	end

	if input.isStoodDown then
		return STAND_DOWN
	end

	local windupProgress = input.windupProgress
	if input.isWindingUp and windupProgress ~= nil and windupProgress >= 0 and windupProgress <= 1 then
		local usesLeftArm = input.windupSequence % 2 == 1
		if windupProgress < Timing.WindupLateProgress then
			return if usesLeftArm then WINDUP_EARLY_LEFT else WINDUP_EARLY_RIGHT
		end
		return if usesLeftArm then WINDUP_LATE_LEFT else WINDUP_LATE_RIGHT
	end

	local secondsSinceAttack = input.secondsSinceAttack
	if secondsSinceAttack ~= nil and secondsSinceAttack >= 0 then
		local strikeUsesLeftArm = input.attackSequence % 2 == 1
		if secondsSinceAttack <= Timing.AttackActiveSeconds then
			return if strikeUsesLeftArm then STRIKE_ACTIVE_LEFT else STRIKE_ACTIVE_RIGHT
		end
		if secondsSinceAttack <= Timing.AttackRecoverySeconds then
			return if strikeUsesLeftArm then STRIKE_RECOVERY_LEFT else STRIKE_RECOVERY_RIGHT
		end
	end

	local strideIsEven = input.strideIndex % 2 == 0
	if input.isMoving and input.isPursuing then
		if strideIsEven then
			return pose(PoseIds.PursuingA, -16, -2, -34, 26, 7, -7, 24, -24, SensorModes.Alert)
		end
		return pose(PoseIds.PursuingB, -16, 2, 26, -34, 7, -7, -24, 24, SensorModes.Alert)
	end

	if input.isMoving then
		if strideIsEven then
			return pose(PoseIds.RoamingA, -6, -1, -16, 12, 5, -5, 13, -13, SensorModes.Normal)
		end
		return pose(PoseIds.RoamingB, -6, 1, 12, -16, 5, -5, -13, 13, SensorModes.Normal)
	end

	if input.isPursuing then
		return THREAT_READY
	end

	return IDLE
end

return table.freeze(EnemyPresentationPoseResolver)
