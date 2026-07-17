--!strict

--[[
	Replicated, presentation-only disclosure names for server-owned enemies.
	These attributes describe already-committed gameplay truth. They do not
	request attacks, select targets, apply damage, change health, or own death.
]]

local AttributeNames = table.freeze({
	BehaviorStateId = "EnemyPresentationBehaviorStateId",
	LifeStateId = "EnemyPresentationLifeStateId",
	AttackSequence = "EnemyPresentationAttackSequence",
	AttackServerTimestamp = "EnemyPresentationAttackServerTimestamp",
	HitSequence = "EnemyPresentationHitSequence",
	HitServerTimestamp = "EnemyPresentationHitServerTimestamp",
})

local LifeStateIds = table.freeze({
	Alive = "Alive",
	Dead = "Dead",
})

return table.freeze({
	AttributeNames = AttributeNames,
	LifeStateIds = LifeStateIds,
})
