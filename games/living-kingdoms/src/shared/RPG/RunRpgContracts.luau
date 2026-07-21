--!strict

--[[
	RPG-0101 shared operation-bound RPG declarations. These stable IDs, intent
	shapes, and safe copied snapshots may be required on either side of the
	client/server boundary. They declare no runtime owner, remote, proc, reward,
	damage, healing, loot, elite assignment, persistence, or account power.
]]

local RunRpgContracts = {}

export type RunUpgradeId =
	"upgrade.overpressure_rounds"
	| "upgrade.hair_trigger"
	| "upgrade.echo_chamber"
	| "upgrade.cull_protocol"
	| "upgrade.pattern_amplifier"
	| "upgrade.specialist_munitions"
	| "upgrade.combat_loader"
	| "upgrade.expanded_feed"
	| "upgrade.scavenger_reach"
	| "upgrade.last_magazine"
	| "upgrade.trauma_plating"
	| "upgrade.adrenal_response"
	| "upgrade.second_pulse"
	| "upgrade.rescue_instinct"
	| "upgrade.shared_momentum"
	| "upgrade.covering_fire"
	| "upgrade.field_discipline"

export type RunUpgradeFamilyId = "Firepower" | "AmmunitionReload" | "Survival" | "CooperativeUtility"

export type EliteAffixId =
	"elite-affix.armored"
	| "elite-affix.frenzied"
	| "elite-affix.regenerator"
	| "elite-affix.volatile"
	| "elite-affix.commander"

export type RelicId =
	"relic.blood_battery"
	| "relic.grave_momentum"
	| "relic.choir_breaker"
	| "relic.last_light"
	| "relic.emergency_chamber"
	| "relic.salvagers_mark"
	| "relic.execution_protocol"
	| "relic.breach_doctrine"
	| "relic.longwatch_doctrine"
	| "relic.suppression_engine"
	| "relic.guardian_signal"
	| "relic.second_wind"

export type ModifierCategoryId =
	"Damage"
	| "Cadence"
	| "AmmunitionConservation"
	| "MagazineCapacity"
	| "ReloadDuration"
	| "MovementSpeed"
	| "Healing"
	| "TemporaryArmor"
	| "Loot"
	| "FieldXp"
	| "KillChainWindow"
	| "PatternDamage"
	| "SpecialEnemyDamage"

export type EffectTriggerId =
	"ConfirmedKill"
	| "KillChainActive"
	| "EnemySpecialWindup"
	| "LowReserveAmmunition"
	| "ReloadAccepted"
	| "EnemyBelowHealthThreshold"
	| "AmmunitionLootResolved"
	| "ShotgunSecondaryImpact"
	| "SniperSecondaryImpact"
	| "SustainedAutomaticFire"
	| "TeammateRevived"
	| "IncomingIncapacitation"

export type EffectStateId = "Inactive" | "Ready" | "Active" | "Cooldown" | "Exhausted"
export type RelicSlotStateId = "Empty" | "Equipped" | "PendingReplacement"
export type ReplacementStateId = "None" | "AwaitingChoice" | "Resolved" | "Cancelled"
export type RewardChoiceStateId = "Pending" | "Selected" | "Expired" | "Cleared"
export type ImplementationStateId = "Implemented" | "Planned"
export type RelicCompatibilityId = "Any" | "Shotgun" | "Sniper" | "Automatic" | "Cooperative"

export type RewardSourceId =
	"reward-source.elite-kill"
	| "reward-source.special-interrupt"
	| "reward-source.objective-completion"
	| "reward-source.authored-container"
	| "reward-source.horde-clear"
	| "reward-source.boss-milestone"

export type RunBuildNetworkOperationId = "Snapshot" | "RewardOffered" | "RewardResolved" | "Rejected"

export type RunRpgRejectionReasonId =
	"ServiceStopped"
	| "InvalidIntent"
	| "NotParticipant"
	| "OperationPhaseInvalid"
	| "OperationResolved"
	| "StaleOperationGeneration"
	| "StaleRevision"
	| "UnknownRelic"
	| "UnknownReward"
	| "RewardNotPending"
	| "RewardQueueFull"
	| "RelicNotOffered"
	| "RelicAlreadyEquipped"
	| "InvalidReplacementSlot"
	| "ReplacementNotRequired"
	| "SlotsFull"
	| "DuplicateRequest"
	| "RateLimited"
	| "EffectCommitRejected"

export type RelicChoiceIntent = {
	requestId: string,
	operationGeneration: number,
	rewardSequence: number,
	relicId: RelicId,
}

export type RelicReplacementIntent = {
	requestId: string,
	operationGeneration: number,
	rewardSequence: number,
	relicId: RelicId,
	replaceSlotIndex: number,
}

export type SafeRelicSlotSnapshot = {
	slotIndex: number,
	slotStateId: RelicSlotStateId,
	relicId: RelicId?,
	effectStateId: EffectStateId,
	chargeCount: number,
	counterValue: number,
	cooldownEndServerTimestamp: number?,
	revision: number,
}

export type SafePendingRelicRewardSnapshot = {
	rewardSequence: number,
	sourceId: RewardSourceId,
	stateId: RewardChoiceStateId,
	offeredRelicIds: { RelicId },
	expiresAtServerTimestamp: number?,
}

export type SafeRunBuildSnapshot = {
	operationId: RunBuildNetworkOperationId,
	operationGeneration: number,
	revision: number,
	replacementStateId: ReplacementStateId,
	upgradeStacks: { [RunUpgradeId]: number },
	relicSlots: { SafeRelicSlotSnapshot },
	pendingRewards: { SafePendingRelicRewardSnapshot },
}

export type SafeRunBuildRejection = {
	operationId: RunBuildNetworkOperationId,
	operationGeneration: number,
	revision: number,
	rejectionReasonId: RunRpgRejectionReasonId,
	requestId: string?,
	rewardSequence: number?,
}

RunRpgContracts.RunUpgradeIds = table.freeze({
	OverpressureRounds = "upgrade.overpressure_rounds",
	HairTrigger = "upgrade.hair_trigger",
	EchoChamber = "upgrade.echo_chamber",
	CullProtocol = "upgrade.cull_protocol",
	PatternAmplifier = "upgrade.pattern_amplifier",
	SpecialistMunitions = "upgrade.specialist_munitions",
	CombatLoader = "upgrade.combat_loader",
	ExpandedFeed = "upgrade.expanded_feed",
	ScavengerReach = "upgrade.scavenger_reach",
	LastMagazine = "upgrade.last_magazine",
	TraumaPlating = "upgrade.trauma_plating",
	AdrenalResponse = "upgrade.adrenal_response",
	SecondPulse = "upgrade.second_pulse",
	RescueInstinct = "upgrade.rescue_instinct",
	SharedMomentum = "upgrade.shared_momentum",
	CoveringFire = "upgrade.covering_fire",
	FieldDiscipline = "upgrade.field_discipline",
})

RunRpgContracts.RunUpgradeFamilyIds = table.freeze({
	Firepower = "Firepower",
	AmmunitionReload = "AmmunitionReload",
	Survival = "Survival",
	CooperativeUtility = "CooperativeUtility",
})

RunRpgContracts.EliteAffixIds = table.freeze({
	Armored = "elite-affix.armored",
	Frenzied = "elite-affix.frenzied",
	Regenerator = "elite-affix.regenerator",
	Volatile = "elite-affix.volatile",
	Commander = "elite-affix.commander",
})

RunRpgContracts.RelicIds = table.freeze({
	BloodBattery = "relic.blood_battery",
	GraveMomentum = "relic.grave_momentum",
	ChoirBreaker = "relic.choir_breaker",
	LastLight = "relic.last_light",
	EmergencyChamber = "relic.emergency_chamber",
	SalvagersMark = "relic.salvagers_mark",
	ExecutionProtocol = "relic.execution_protocol",
	BreachDoctrine = "relic.breach_doctrine",
	LongwatchDoctrine = "relic.longwatch_doctrine",
	SuppressionEngine = "relic.suppression_engine",
	GuardianSignal = "relic.guardian_signal",
	SecondWind = "relic.second_wind",
})

RunRpgContracts.ModifierCategoryIds = table.freeze({
	Damage = "Damage",
	Cadence = "Cadence",
	AmmunitionConservation = "AmmunitionConservation",
	MagazineCapacity = "MagazineCapacity",
	ReloadDuration = "ReloadDuration",
	MovementSpeed = "MovementSpeed",
	Healing = "Healing",
	TemporaryArmor = "TemporaryArmor",
	Loot = "Loot",
	FieldXp = "FieldXp",
	KillChainWindow = "KillChainWindow",
	PatternDamage = "PatternDamage",
	SpecialEnemyDamage = "SpecialEnemyDamage",
})

RunRpgContracts.EffectTriggerIds = table.freeze({
	ConfirmedKill = "ConfirmedKill",
	KillChainActive = "KillChainActive",
	EnemySpecialWindup = "EnemySpecialWindup",
	LowReserveAmmunition = "LowReserveAmmunition",
	ReloadAccepted = "ReloadAccepted",
	EnemyBelowHealthThreshold = "EnemyBelowHealthThreshold",
	AmmunitionLootResolved = "AmmunitionLootResolved",
	ShotgunSecondaryImpact = "ShotgunSecondaryImpact",
	SniperSecondaryImpact = "SniperSecondaryImpact",
	SustainedAutomaticFire = "SustainedAutomaticFire",
	TeammateRevived = "TeammateRevived",
	IncomingIncapacitation = "IncomingIncapacitation",
})

RunRpgContracts.EffectStateIds = table.freeze({
	Inactive = "Inactive",
	Ready = "Ready",
	Active = "Active",
	Cooldown = "Cooldown",
	Exhausted = "Exhausted",
})

RunRpgContracts.RelicSlotStateIds = table.freeze({
	Empty = "Empty",
	Equipped = "Equipped",
	PendingReplacement = "PendingReplacement",
})

RunRpgContracts.ReplacementStateIds = table.freeze({
	None = "None",
	AwaitingChoice = "AwaitingChoice",
	Resolved = "Resolved",
	Cancelled = "Cancelled",
})

RunRpgContracts.RewardChoiceStateIds = table.freeze({
	Pending = "Pending",
	Selected = "Selected",
	Expired = "Expired",
	Cleared = "Cleared",
})

RunRpgContracts.ImplementationStateIds = table.freeze({
	Implemented = "Implemented",
	Planned = "Planned",
})

RunRpgContracts.RelicCompatibilityIds = table.freeze({
	Any = "Any",
	Shotgun = "Shotgun",
	Sniper = "Sniper",
	Automatic = "Automatic",
	Cooperative = "Cooperative",
})

RunRpgContracts.RewardSourceIds = table.freeze({
	EliteKill = "reward-source.elite-kill",
	SpecialInterrupt = "reward-source.special-interrupt",
	ObjectiveCompletion = "reward-source.objective-completion",
	AuthoredContainer = "reward-source.authored-container",
	HordeClear = "reward-source.horde-clear",
	BossMilestone = "reward-source.boss-milestone",
})

RunRpgContracts.RunBuildNetworkOperationIds = table.freeze({
	Snapshot = "Snapshot",
	RewardOffered = "RewardOffered",
	RewardResolved = "RewardResolved",
	Rejected = "Rejected",
})

RunRpgContracts.RunRpgRejectionReasonIds = table.freeze({
	ServiceStopped = "ServiceStopped",
	InvalidIntent = "InvalidIntent",
	NotParticipant = "NotParticipant",
	OperationPhaseInvalid = "OperationPhaseInvalid",
	OperationResolved = "OperationResolved",
	StaleOperationGeneration = "StaleOperationGeneration",
	StaleRevision = "StaleRevision",
	UnknownRelic = "UnknownRelic",
	UnknownReward = "UnknownReward",
	RewardNotPending = "RewardNotPending",
	RewardQueueFull = "RewardQueueFull",
	RelicNotOffered = "RelicNotOffered",
	RelicAlreadyEquipped = "RelicAlreadyEquipped",
	InvalidReplacementSlot = "InvalidReplacementSlot",
	ReplacementNotRequired = "ReplacementNotRequired",
	SlotsFull = "SlotsFull",
	DuplicateRequest = "DuplicateRequest",
	RateLimited = "RateLimited",
	EffectCommitRejected = "EffectCommitRejected",
})

local function isFinite(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isNonnegativeInteger(value: unknown): boolean
	return isFinite(value) and (value :: number) >= 0 and (value :: number) % 1 == 0
end

local function isPositiveInteger(value: unknown): boolean
	return isNonnegativeInteger(value) and (value :: number) > 0
end

local function isNonEmptyBoundedString(value: unknown, maximumLength: number): boolean
	return type(value) == "string" and value ~= "" and #value <= maximumLength
end

local function containsValue(values: { [string]: string }, candidate: unknown): boolean
	if type(candidate) ~= "string" then
		return false
	end
	for _, value in values do
		if value == candidate then
			return true
		end
	end
	return false
end

local function hasOnlyKeys(value: { [any]: any }, permittedKeys: { [string]: boolean }): boolean
	for key in value do
		if type(key) ~= "string" or permittedKeys[key] ~= true then
			return false
		end
	end
	return true
end

function RunRpgContracts.isKnownRunUpgradeId(value: unknown): boolean
	return containsValue(RunRpgContracts.RunUpgradeIds, value)
end

function RunRpgContracts.isKnownEliteAffixId(value: unknown): boolean
	return containsValue(RunRpgContracts.EliteAffixIds, value)
end

function RunRpgContracts.isKnownRelicId(value: unknown): boolean
	return containsValue(RunRpgContracts.RelicIds, value)
end

function RunRpgContracts.validateRelicChoiceIntent(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local intent = value :: { [any]: any }
	if
		not hasOnlyKeys(intent, {
			requestId = true,
			operationGeneration = true,
			rewardSequence = true,
			relicId = true,
		})
	then
		return false
	end
	return isNonEmptyBoundedString(intent.requestId, 128)
		and isPositiveInteger(intent.operationGeneration)
		and isPositiveInteger(intent.rewardSequence)
		and isNonEmptyBoundedString(intent.relicId, 96)
end

function RunRpgContracts.validateRelicReplacementIntent(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local intent = value :: { [any]: any }
	if
		not hasOnlyKeys(intent, {
			requestId = true,
			operationGeneration = true,
			rewardSequence = true,
			relicId = true,
			replaceSlotIndex = true,
		})
	then
		return false
	end
	return isNonEmptyBoundedString(intent.requestId, 128)
		and isPositiveInteger(intent.operationGeneration)
		and isPositiveInteger(intent.rewardSequence)
		and isNonEmptyBoundedString(intent.relicId, 96)
		and isPositiveInteger(intent.replaceSlotIndex)
end

local function validateRelicSlot(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local slot = value :: { [any]: any }
	if
		not hasOnlyKeys(slot, {
			slotIndex = true,
			slotStateId = true,
			relicId = true,
			effectStateId = true,
			chargeCount = true,
			counterValue = true,
			cooldownEndServerTimestamp = true,
			revision = true,
		})
	then
		return false
	end
	if
		not isPositiveInteger(slot.slotIndex)
		or not containsValue(RunRpgContracts.RelicSlotStateIds, slot.slotStateId)
		or not containsValue(RunRpgContracts.EffectStateIds, slot.effectStateId)
		or not isNonnegativeInteger(slot.chargeCount)
		or not isNonnegativeInteger(slot.counterValue)
		or (slot.cooldownEndServerTimestamp ~= nil and not isFinite(slot.cooldownEndServerTimestamp))
		or not isNonnegativeInteger(slot.revision)
	then
		return false
	end
	if slot.slotStateId == RunRpgContracts.RelicSlotStateIds.Empty then
		return slot.relicId == nil
			and slot.effectStateId == RunRpgContracts.EffectStateIds.Inactive
			and slot.chargeCount == 0
			and slot.counterValue == 0
			and slot.cooldownEndServerTimestamp == nil
	end
	return RunRpgContracts.isKnownRelicId(slot.relicId)
end

local function validatePendingReward(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local reward = value :: { [any]: any }
	if
		not hasOnlyKeys(reward, {
			rewardSequence = true,
			sourceId = true,
			stateId = true,
			offeredRelicIds = true,
			expiresAtServerTimestamp = true,
		})
	then
		return false
	end
	if
		not isPositiveInteger(reward.rewardSequence)
		or not containsValue(RunRpgContracts.RewardSourceIds, reward.sourceId)
		or not containsValue(RunRpgContracts.RewardChoiceStateIds, reward.stateId)
		or type(reward.offeredRelicIds) ~= "table"
		or (reward.expiresAtServerTimestamp ~= nil and not isFinite(reward.expiresAtServerTimestamp))
	then
		return false
	end
	local seenRelicIds = {}
	local choiceCount = 0
	for index, relicId in reward.offeredRelicIds :: { [any]: any } do
		if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or not RunRpgContracts.isKnownRelicId(relicId) then
			return false
		end
		if seenRelicIds[relicId] then
			return false
		end
		seenRelicIds[relicId] = true
		choiceCount += 1
	end
	return choiceCount >= 1 and choiceCount <= 4
end

function RunRpgContracts.validateSafeRunBuildSnapshot(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local snapshot = value :: { [any]: any }
	if
		not hasOnlyKeys(snapshot, {
			operationId = true,
			operationGeneration = true,
			revision = true,
			replacementStateId = true,
			upgradeStacks = true,
			relicSlots = true,
			pendingRewards = true,
		})
	then
		return false
	end
	if
		snapshot.operationId ~= RunRpgContracts.RunBuildNetworkOperationIds.Snapshot
		or not isPositiveInteger(snapshot.operationGeneration)
		or not isNonnegativeInteger(snapshot.revision)
		or not containsValue(RunRpgContracts.ReplacementStateIds, snapshot.replacementStateId)
		or type(snapshot.upgradeStacks) ~= "table"
		or type(snapshot.relicSlots) ~= "table"
		or type(snapshot.pendingRewards) ~= "table"
	then
		return false
	end
	for upgradeId, stackCount in snapshot.upgradeStacks :: { [any]: any } do
		if
			not RunRpgContracts.isKnownRunUpgradeId(upgradeId)
			or not isNonnegativeInteger(stackCount)
			or stackCount > 8
		then
			return false
		end
	end

	local seenSlotIndexes = {}
	local seenEquippedRelicIds = {}
	local slotCount = 0
	for index, slot in snapshot.relicSlots :: { [any]: any } do
		if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or not validateRelicSlot(slot) then
			return false
		end
		if seenSlotIndexes[slot.slotIndex] then
			return false
		end
		seenSlotIndexes[slot.slotIndex] = true
		if slot.relicId ~= nil then
			if seenEquippedRelicIds[slot.relicId] then
				return false
			end
			seenEquippedRelicIds[slot.relicId] = true
		end
		slotCount += 1
	end
	if slotCount > 8 then
		return false
	end

	local seenRewardSequences = {}
	local rewardCount = 0
	for index, reward in snapshot.pendingRewards :: { [any]: any } do
		if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or not validatePendingReward(reward) then
			return false
		end
		if seenRewardSequences[reward.rewardSequence] then
			return false
		end
		seenRewardSequences[reward.rewardSequence] = true
		rewardCount += 1
	end
	return rewardCount <= 8
end

function RunRpgContracts.validateSafeRunBuildRejection(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local rejection = value :: { [any]: any }
	if
		not hasOnlyKeys(rejection, {
			operationId = true,
			operationGeneration = true,
			revision = true,
			rejectionReasonId = true,
			requestId = true,
			rewardSequence = true,
		})
	then
		return false
	end
	return rejection.operationId == RunRpgContracts.RunBuildNetworkOperationIds.Rejected
		and isPositiveInteger(rejection.operationGeneration)
		and isNonnegativeInteger(rejection.revision)
		and containsValue(RunRpgContracts.RunRpgRejectionReasonIds, rejection.rejectionReasonId)
		and (rejection.requestId == nil or isNonEmptyBoundedString(rejection.requestId, 128))
		and (rejection.rewardSequence == nil or isPositiveInteger(rejection.rewardSequence))
end

return table.freeze(RunRpgContracts)
