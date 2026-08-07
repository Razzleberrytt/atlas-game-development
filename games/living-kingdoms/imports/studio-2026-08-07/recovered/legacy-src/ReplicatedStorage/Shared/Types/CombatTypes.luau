-- CombatTypes: Shared type definitions for combat
local CombatTypes = {}

CombatTypes.DamageType = {
	Physical = "Physical",
	Fire = "Fire",
	Frost = "Frost",
	Lightning = "Lightning",
	Poison = "Poison",
	Shadow = "Shadow",
	Holy = "Holy",
}

CombatTypes.EnemyTier = {
	Normal = "Normal",
	Elite = "Elite",
	Boss = "Boss",
}

CombatTypes.CombatEvent = {
	Swing = "swing",
	Hit = "enemy_hit",
	PlayerHit = "player_hit",
	EnemyAttack = "enemy_attack",
	BossSpecial = "boss_special",
	BossPhase = "boss_phase",
}

return CombatTypes