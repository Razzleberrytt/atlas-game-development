--!strict

-- Presentation-only visual identities for enemy archetypes that sit outside the
-- standard Exclusion Walker / horde-role shell. Keeping these keys separate
-- lets procedural fallbacks graduate to imported rigs later without changing
-- combat archetype IDs or the authoritative EnemyDirector ownership boundary.

return table.freeze({
	BlightSpitterModel = "visual.enemy.blight-spitter.model",
	ProgenitorBossModel = "visual.enemy.progenitor-boss.model",
})
