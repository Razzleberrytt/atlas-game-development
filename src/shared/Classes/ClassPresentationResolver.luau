--!strict

--[[
	P7-0106 pure class-presentation vocabulary. It converts only server-safe
	class snapshots into redundant text/shape cues; it never derives gameplay
	facts, discovers targets, or owns action timing.
]]

local ClassContracts = require(script.Parent.ClassContracts)

local ClassIds = ClassContracts.ClassIds
local ActionIds = ClassContracts.ClassActionIds
local ActionStateIds = ClassContracts.ClassActionStateIds
local ResourceIds = ClassContracts.ClassResourceIds

local Resolver = {}

export type IdentityPresentation = {
	displayName: string,
	shapeToken: string,
	roleSummary: string,
}

local IDENTITIES: { [string]: IdentityPresentation } = table.freeze({
	[ClassIds.CombatSpecialist] = table.freeze({
		displayName = "COMBAT SPECIALIST",
		shapeToken = "[SHIELD]",
		roleSummary = "HOLDS THE FIRING LINE",
	}),
	[ClassIds.Medic] = table.freeze({
		displayName = "MEDIC",
		shapeToken = "[CROSS]",
		roleSummary = "PRESERVES OPERATIVE HEALTH",
	}),
	[ClassIds.Engineer] = table.freeze({
		displayName = "ENGINEER",
		shapeToken = "[TOOL]",
		roleSummary = "EXTENDS AMMUNITION RESERVES",
	}),
})

local ACTION_LABELS: { [string]: string } = table.freeze({
	[ActionIds.Brace] = "BRACING — SAFE FIRE WINDOW",
	[ActionIds.FieldTreatment] = "TREATING TEAMMATE",
	[ActionIds.ReviveAssistance] = "ASSISTING REVIVE",
	[ActionIds.FieldResupply] = "RESUPPLYING OPERATIVE",
})

local REJECTION_LABELS: { [string]: string } = table.freeze({
	ServiceStopped = "CLASS SERVICE UNAVAILABLE",
	InvalidIntent = "ACTION REQUEST INVALID",
	UnknownClass = "CLASS UNAVAILABLE",
	UnknownAction = "ACTION UNAVAILABLE",
	UnknownTarget = "TARGET UNKNOWN",
	NotParticipant = "NOT IN THIS OPERATION",
	OperationPhaseInvalid = "ACTION UNAVAILABLE IN THIS PHASE",
	OperationResolved = "OPERATION COMPLETE",
	SelectionClosed = "CLASS SELECTION LOCKED",
	ClassLocked = "CLASS ASSIGNMENT LOCKED",
	ClassUnavailable = "CLASS UNAVAILABLE",
	WrongAssignedClass = "ACTION BELONGS TO ANOTHER CLASS",
	ActorNotAlive = "ACTION REQUIRES ALIVE STATE",
	ActionAlreadyActive = "ACTION ALREADY ACTIVE",
	ActionOnCooldown = "ACTION RECHARGING",
	InsufficientResource = "NO CLASS CHARGES REMAIN",
	InvalidTarget = "NO VALID TARGET",
	SelfTargetNotAllowed = "CHOOSE A TEAMMATE",
	TargetNotAlive = "TARGET IS NOT ALIVE",
	TargetNotIncapacitated = "TARGET DOES NOT NEED REVIVAL",
	TargetNotInjured = "TARGET HEALTH IS FULL",
	IncompatibleWeapon = "TARGET WEAPON CANNOT USE THIS SUPPLY",
	NoCapacity = "TARGET AMMUNITION RESERVE IS FULL",
	OutOfRange = "TARGET OUT OF RANGE",
	NoLineOfSight = "TARGET PATH BLOCKED",
	MovementInterrupted = "ACTION INTERRUPTED — MOVED",
	DamageInterrupted = "ACTION INTERRUPTED — HIT",
	ReloadInterrupted = "BRACE INTERRUPTED — RELOADED",
	ActionCancelled = "ACTION CANCELLED",
	ActionCompleted = "ACTION COMPLETE",
	StaleRevision = "ACTION STATE CHANGED — TRY AGAIN",
	DuplicateRequest = "ACTION REQUEST ALREADY HANDLED",
	RateLimited = "ACTION INPUT TOO FAST",
	EffectCommitRejected = "ACTION COULD NOT COMMIT",
})

function Resolver.identity(classId: string): IdentityPresentation?
	return IDENTITIES[classId]
end

function Resolver.actionLabel(actionId: string?): string?
	if actionId == nil then
		return nil
	end
	return ACTION_LABELS[actionId]
end

function Resolver.rejectionLabel(reasonId: string?): string?
	if reasonId == nil then
		return nil
	end
	return REJECTION_LABELS[reasonId] or "ACTION UNAVAILABLE"
end

function Resolver.resourceLabel(classId: string, resources: { ClassContracts.AuthoritativeClassResourceState }): string
	local expectedResourceId = if classId == ClassIds.Medic
		then ResourceIds.MedicalCharge
		else if classId == ClassIds.Engineer then ResourceIds.ResupplyCharge else nil
	if expectedResourceId == nil then
		return "BRACE • COOLDOWN LIMITED"
	end
	for _, resource in resources do
		if resource.resourceId == expectedResourceId then
			local noun = if classId == ClassIds.Medic then "MEDICAL CHARGES" else "RESUPPLY CHARGES"
			return string.format("%s  %d / %d", noun, resource.currentAmount, resource.maximumAmount)
		end
	end
	return if classId == ClassIds.Medic then "MEDICAL CHARGES  0 / 0" else "RESUPPLY CHARGES  0 / 0"
end

function Resolver.ownerStatus(
	classId: string,
	state: ClassContracts.AuthoritativeClassActionState,
	serverTimestamp: number
): string
	local actionName = if classId == ClassIds.Medic
		then "FIELD TREATMENT"
		else if classId == ClassIds.Engineer then "FIELD RESUPPLY" else "BRACE"
	if state.actionStateId == ActionStateIds.Active then
		local remaining = math.max(0, (state.completionServerTimestamp or serverTimestamp) - serverTimestamp)
		return string.format("%s ACTIVE  %.1fs  •  Q TO CANCEL", actionName, remaining)
	elseif state.actionStateId == ActionStateIds.Cooldown then
		local remaining = math.max(0, (state.cooldownEndServerTimestamp or serverTimestamp) - serverTimestamp)
		local reason = Resolver.rejectionLabel(state.statusReasonId)
		if reason ~= nil and state.statusReasonId ~= "ActionCompleted" then
			return string.format("%s  •  READY IN %.1fs", reason, remaining)
		end
		return string.format("%s RECHARGING  •  READY IN %.1fs", actionName, remaining)
	end
	return actionName .. " READY  •  Q / GAMEPAD X"
end

function Resolver.squadActionCue(member: ClassContracts.ClassSquadMemberPresentationSnapshot): string?
	if member.actionStateId ~= ActionStateIds.Active then
		return nil
	end
	return Resolver.actionLabel(member.actionId)
end

return table.freeze(Resolver)
