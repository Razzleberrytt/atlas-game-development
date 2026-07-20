--!strict

--[[
	Replicated, presentation-only disclosure names for server-owned enemies.
	These attributes describe authoritative state, windup intent, and committed
	events. They do not request attacks, select targets, apply damage, change
	health, or own death.
]]

local AttributeNames = table.freeze({
	BehaviorStateId = "EnemyPresentationBehaviorStateId",
	LifeStateId = "EnemyPresentationLifeStateId",
	WindupSequence = "EnemyPresentationWindupSequence",
	WindupStartedServerTimestamp = "EnemyPresentationWindupStartedServerTimestamp",
	WindupCommitServerTimestamp = "EnemyPresentationWindupCommitServerTimestamp",
	AttackSequence = "EnemyPresentationAttackSequence",
	AttackServerTimestamp = "EnemyPresentationAttackServerTimestamp",
	HitSequence = "EnemyPresentationHitSequence",
	HitServerTimestamp = "EnemyPresentationHitServerTimestamp",
	EliteAffixId = "EnemyEliteAffixId",
	EliteDisplayName = "EnemyEliteDisplayName",
	EliteMovementSpeedMultiplier = "EnemyEliteMovementSpeedMultiplier",
	EliteAttackCadenceMultiplier = "EnemyEliteAttackCadenceMultiplier",
	EliteBonusFieldXp = "EnemyEliteBonusFieldXp",
})

local LifeStateIds = table.freeze({
	Alive = "Alive",
	Dead = "Dead",
})

return table.freeze({
	AttributeNames = AttributeNames,
	LifeStateIds = LifeStateIds,
})
