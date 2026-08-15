--!strict

-- Hard ceilings for presentation-only Main World content. These are intentionally
-- generous enough for the current 59-model hierarchy plus readability, modular
-- prop, water/mist, and biome-VFX layers while still catching runaway decoration.
local Config = {
	Version = "environment-presentation-budget-v1",
	SettleSeconds = 2,
	Budgets = table.freeze({
		PresentationRootCount = 12,
		ModelCount = 140,
		BasePartCount = 900,
		ParticleEmitterCount = 40,
		LightCount = 24,
		BeamTrailCount = 32,
		AttachmentCount = 96,
		InteractiveCount = 0,
		ScriptCount = 0,
		CollidablePartCount = 0,
		TouchPartCount = 0,
		QueryablePartCount = 0,
	}),
}

assert(Config.SettleSeconds >= 0 and Config.SettleSeconds <= 5, "presentation budget audit must stay bounded")
assert(Config.Budgets.ModelCount >= 59, "presentation model budget must fit the deterministic hero composition")
assert(Config.Budgets.BasePartCount >= 500, "presentation part budget must retain reasonable visual headroom")
assert(Config.Budgets.InteractiveCount == 0, "presentation-only content must never own interaction authority")
assert(Config.Budgets.ScriptCount == 0, "presentation-only content must never own script authority")
assert(Config.Budgets.CollidablePartCount == 0, "presentation-only content must remain non-colliding")
assert(Config.Budgets.TouchPartCount == 0, "presentation-only content must remain non-touching")
assert(Config.Budgets.QueryablePartCount == 0, "presentation-only content must remain outside gameplay queries")

return table.freeze(Config)
