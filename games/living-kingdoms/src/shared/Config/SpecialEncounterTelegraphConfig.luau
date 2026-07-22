--!strict

--[[
	P9-0105 shared server/client contract for the special-enemy and boss
	telegraphs. The server owns when each dangerous action begins and commits and
	discloses it through the bounded replicated model attributes declared in
	EnemyPresentationContracts. Clients may only present the disclosed center,
	radius, sequence, and commit timestamp — never predict a consequence, read
	health, or legalise a hit.

	Two ground-disc telegraphs (the Blight Spitter Corrosive Bloom and the
	Progenitor Slam) plus the boss phase/vulnerability status share one client
	controller and one fixed presentation pool.
]]

local EnemyContracts = require(script.Parent.Parent.Combat.EnemyContracts)
local EnemyConfig = require(script.Parent.EnemyConfig)
local EnemyPresentationContracts = require(script.Parent.Parent.Visual.EnemyPresentationContracts)

local Attr = EnemyPresentationContracts.AttributeNames

export type DiscTelegraphKind = {
	Id: string,
	ArchetypeId: string,
	SequenceAttribute: string,
	StartedAttribute: string,
	CommitAttribute: string,
	CenterXAttribute: string,
	CenterZAttribute: string,
	RadiusAttribute: string,
	WarningLabel: string,
	CommitLabel: string,
	Color: { number },
	PulseCount: number,
	-- True for the bloom: after the burst commits, the ground stays denied for the
	-- authoritative lingering lifetime; false for the one-shot Slam.
	HasLinger: boolean,
}

local Bloom: DiscTelegraphKind = table.freeze({
	Id = "SpitterBloom",
	ArchetypeId = EnemyContracts.EnemyArchetypeIds.BlightSpitter,
	SequenceAttribute = Attr.SpitterBloomChargeSequence,
	StartedAttribute = Attr.SpitterBloomChargeStartedServerTimestamp,
	CommitAttribute = Attr.SpitterBloomCommitServerTimestamp,
	CenterXAttribute = Attr.SpitterBloomCenterX,
	CenterZAttribute = Attr.SpitterBloomCenterZ,
	RadiusAttribute = Attr.SpitterBloomRadiusStuds,
	WarningLabel = "CORROSIVE BLOOM",
	CommitLabel = "TOXIC GROUND",
	Color = table.freeze({ 120, 232, 76 }),
	PulseCount = 3,
	HasLinger = true,
})

local Slam: DiscTelegraphKind = table.freeze({
	Id = "ProgenitorSlam",
	ArchetypeId = EnemyContracts.EnemyArchetypeIds.Progenitor,
	SequenceAttribute = Attr.BossSlamSequence,
	StartedAttribute = Attr.BossSlamStartedServerTimestamp,
	CommitAttribute = Attr.BossSlamCommitServerTimestamp,
	CenterXAttribute = Attr.BossSlamCenterX,
	CenterZAttribute = Attr.BossSlamCenterZ,
	RadiusAttribute = Attr.BossSlamRadiusStuds,
	WarningLabel = "PROGENITOR SLAM",
	CommitLabel = "IMPACT",
	Color = table.freeze({ 255, 96, 48 }),
	PulseCount = 3,
	HasLinger = false,
})

-- The always-visible boss status: phase name plus an unmistakable armored /
-- exposed indicator so players learn when their fire lands.
local BossStatus = table.freeze({
	ArchetypeId = EnemyContracts.EnemyArchetypeIds.Progenitor,
	PhaseAttribute = Attr.BossPhaseId,
	VulnerableAttribute = Attr.BossIsVulnerable,
	VulnerableLabel = "EXPOSED — FIRE",
	ArmoredLabel = "ARMORED",
	PhaseLabels = table.freeze({
		Carapace = "CARAPACE",
		Brood = "BROOD",
		Collapse = "COLLAPSE",
		Defeated = "DOWN",
	}),
	VulnerableColor = table.freeze({ 132, 255, 132 }),
	ArmoredColor = table.freeze({ 224, 150, 128 }),
})

local DiscKinds = table.freeze({ Bloom, Slam })

local DiscKindByArchetypeId = table.freeze({
	[Bloom.ArchetypeId] = Bloom,
	[Slam.ArchetypeId] = Slam,
})

local function discKindForArchetypeId(archetypeId: unknown): DiscTelegraphKind?
	return if type(archetypeId) == "string" then DiscKindByArchetypeId[archetypeId] else nil
end

local Config = {
	Version = "P9-0105-v1",
	DiscKinds = DiscKinds,
	Bloom = Bloom,
	Slam = Slam,
	BossStatus = BossStatus,
	DiscKindByArchetypeId = DiscKindByArchetypeId,
	discKindForArchetypeId = discKindForArchetypeId,
	MaximumTrackedEnemyModels = 128,
	MaximumActiveTelegraphs = 12,
	PollIntervalSeconds = 0.05,
	CommitHoldSeconds = 0.28,
}

local seenAttributeNames = {}
for _, kind in DiscKinds do
	for _, attributeName in
		{
			kind.SequenceAttribute,
			kind.StartedAttribute,
			kind.CommitAttribute,
			kind.CenterXAttribute,
			kind.CenterZAttribute,
			kind.RadiusAttribute,
		}
	do
		assert(type(attributeName) == "string" and attributeName ~= "", "telegraph attribute names must be non-empty")
		assert(not seenAttributeNames[attributeName], "telegraph attribute names must be unique: " .. attributeName)
		seenAttributeNames[attributeName] = true
	end
	assert(type(kind.ArchetypeId) == "string" and kind.ArchetypeId ~= "", "a telegraph kind requires an archetype")
	assert(kind.WarningLabel ~= "" and kind.CommitLabel ~= "", "telegraph labels must be present (not color-only)")
	assert(#kind.Color == 3, "telegraph colors require RGB tuples")
	assert(kind.PulseCount >= 1 and kind.PulseCount <= 4, "telegraph pulse count must stay bounded")
end

assert(#BossStatus.VulnerableColor == 3 and #BossStatus.ArmoredColor == 3, "boss status colors require RGB tuples")
assert(
	BossStatus.VulnerableLabel ~= "" and BossStatus.ArmoredLabel ~= "",
	"boss status must carry text, not color alone"
)
for _, phaseLabel in BossStatus.PhaseLabels do
	assert(phaseLabel ~= "", "every boss phase needs a readable label")
end

assert(
	Config.MaximumTrackedEnemyModels >= EnemyConfig.Population.AbsoluteMaximumConcurrent,
	"telegraph tracking must cover the enemy cap"
)
assert(Config.MaximumTrackedEnemyModels <= 128, "telegraph tracking must stay bounded")
assert(Config.MaximumActiveTelegraphs > 0 and Config.MaximumActiveTelegraphs <= 24, "active telegraphs require a cap")
assert(Config.PollIntervalSeconds > 0 and Config.PollIntervalSeconds <= 0.1, "telegraph polling must stay bounded")
assert(Config.CommitHoldSeconds > 0 and Config.CommitHoldSeconds <= 0.5, "commit flash must stay brief")

return table.freeze(Config)
