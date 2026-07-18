--!strict

--[[
	HROI-0104 bounded client-local combat-impact presentation. These values
	control only cosmetic feedback after replicated server-confirmed enemy hits
	and deaths. They cannot establish damage, health, death, XP, loot, or any
	other consequential gameplay fact.
]]

local CombatImpactPresentationConfig = {
	Version = "HROI-0104-v1",
	-- The server caps living enemies at 24, but recently killed models remain
	-- replicated through the corpse-cleanup window. This cosmetic-only record
	-- ceiling covers both groups without increasing gameplay population.
	MaximumTrackedEnemyModels = 64,
	MaximumEffectDistanceStuds = 140,
	HitParticleCount = 7,
	KillParticleCount = 22,
	HitFlashSeconds = 0.08,
	KillFlashSeconds = 0.18,
}

assert(
	CombatImpactPresentationConfig.MaximumTrackedEnemyModels >= 24
		and CombatImpactPresentationConfig.MaximumTrackedEnemyModels <= 64,
	"impact presentation must cover living enemies and bounded corpse overlap"
)
assert(
	CombatImpactPresentationConfig.MaximumEffectDistanceStuds > 0
		and CombatImpactPresentationConfig.MaximumEffectDistanceStuds <= 200,
	"impact effects require a bounded camera distance"
)
assert(
	CombatImpactPresentationConfig.HitParticleCount > 0 and CombatImpactPresentationConfig.HitParticleCount <= 12,
	"hit bursts must remain small and readable"
)
assert(
	CombatImpactPresentationConfig.KillParticleCount > CombatImpactPresentationConfig.HitParticleCount
		and CombatImpactPresentationConfig.KillParticleCount <= 32,
	"kill bursts must be stronger than hit bursts while remaining bounded"
)
assert(
	CombatImpactPresentationConfig.HitFlashSeconds > 0 and CombatImpactPresentationConfig.HitFlashSeconds <= 0.15,
	"hit flash must remain brief"
)
assert(
	CombatImpactPresentationConfig.KillFlashSeconds > CombatImpactPresentationConfig.HitFlashSeconds
		and CombatImpactPresentationConfig.KillFlashSeconds <= 0.3,
	"kill flash must be distinct and bounded"
)

return table.freeze(CombatImpactPresentationConfig)
