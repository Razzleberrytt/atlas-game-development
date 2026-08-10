--!strict

--[[
	Patch 0.2 elite readability presentation constants.

	The server already resolves elite affixes and discloses them on the enemy
	model (`EnemyEliteAffixId`, `EnemyEliteDisplayName`, `EnemyEliteArmorRemaining`).
	Until now nothing presented that, so an elite was visually identical to trash
	and the player had no way to know which enemy deserved attention.

	This module is descriptive only: it maps a disclosed affix ID to a bounded
	visual treatment. It resolves no gameplay, reads no health, and grants the
	client no authority over what an elite is or does.

	Colour is never the only carrier of meaning — every treatment also has a text
	label — so the surface stays readable without colour discrimination.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunRpgContracts = require(ReplicatedStorage.Shared.RPG.RunRpgContracts)

local AffixIds = RunRpgContracts.EliteAffixIds

export type EliteTreatment = {
	AffixId: string,
	FallbackDisplayName: string,
	AccentColor: Color3,
	ThreatNote: string,
}

local function treatment(
	affixId: string,
	fallbackDisplayName: string,
	accentColor: Color3,
	threatNote: string
): EliteTreatment
	return table.freeze({
		AffixId = affixId,
		FallbackDisplayName = fallbackDisplayName,
		AccentColor = accentColor,
		ThreatNote = threatNote,
	})
end

-- One short note per affix so the nameplate says why the enemy is dangerous, not
-- merely that it is. These describe the server's existing affix behaviour; they
-- do not define it.
local Treatments: { [string]: EliteTreatment } = {
	[AffixIds.Armored] = treatment(AffixIds.Armored, "ARMORED", Color3.fromRGB(150, 170, 192), "SOAKS DAMAGE"),
	[AffixIds.Frenzied] = treatment(AffixIds.Frenzied, "FRENZIED", Color3.fromRGB(232, 92, 52), "FAST AND RELENTLESS"),
	[AffixIds.Regenerator] = treatment(
		AffixIds.Regenerator,
		"REGENERATOR",
		Color3.fromRGB(96, 204, 128),
		"HEALS IF LEFT ALONE"
	),
	[AffixIds.Volatile] = treatment(AffixIds.Volatile, "VOLATILE", Color3.fromRGB(240, 196, 64), "EXPLODES ON DEATH"),
	[AffixIds.Commander] = treatment(AffixIds.Commander, "COMMANDER", Color3.fromRGB(176, 124, 224), "EMPOWERS NEARBY"),
}

local EliteReadabilityConfig = {
	Version = 1,
	Treatments = table.freeze(Treatments),

	-- Bounds. The nameplate pool is fixed and small: elite readability must never
	-- become a per-enemy allocation or a frame-budget risk in a heavy horde.
	MaximumNameplates = 6,
	PollIntervalSeconds = 0.2,
	MaximumVisibleDistanceStuds = 180,
	NameplateHeightStuds = 5.6,
	NameplateWidthStuds = 9,
	NameplateSizeStuds = 1.9,
}

function EliteReadabilityConfig.get(affixId: unknown): EliteTreatment?
	if type(affixId) ~= "string" then
		return nil
	end
	return Treatments[affixId]
end

assert(EliteReadabilityConfig.MaximumNameplates > 0, "elite nameplate pool must be positive")
assert(EliteReadabilityConfig.PollIntervalSeconds > 0, "elite readability poll interval must be positive")
assert(EliteReadabilityConfig.MaximumVisibleDistanceStuds > 0, "elite readability distance must be positive")

-- Every affix the contracts define must have a treatment, so adding an affix
-- without a readable presentation fails here rather than shipping an unlabelled
-- elite.
for _, affixId in AffixIds do
	assert(Treatments[affixId] ~= nil, "every elite affix requires a readable treatment: " .. tostring(affixId))
end

return table.freeze(EliteReadabilityConfig)
