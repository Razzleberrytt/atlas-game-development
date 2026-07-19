--!strict

--[[
	Shared server/client contract for the three existing horde-role special
	telegraphs. The server owns when a warning begins and when its consequence
	commits. Clients may only present the replicated kind, sequence, state, and
	commit timestamp.
]]

local EnemyConfig = require(script.Parent.EnemyConfig)
local HordeExperienceConfig = require(script.Parent.HordeExperienceConfig)

export type TelegraphDefinition = {
	KindId: string,
	WarningLabel: string,
	CommitLabel: string,
	WindupSeconds: number,
	RadiusStuds: number,
	PulseCount: number,
	Color: { number },
}

local AttributeNames = table.freeze({
	KindId = "HordeSpecialKindId",
	Sequence = "HordeSpecialSequence",
	StateId = "HordeSpecialStateId",
	CommitServerTimestamp = "HordeSpecialCommitServerTimestamp",
})

local StateIds = table.freeze({
	Idle = "Idle",
	Windup = "Windup",
	Interrupted = "Interrupted",
	Committed = "Committed",
})

local KindIds = table.freeze({
	ScreamerReinforcement = "ScreamerReinforcement",
	BloaterDeathBurst = "BloaterDeathBurst",
	BruteSecondPhase = "BruteSecondPhase",
})

local ScreamerReinforcement: TelegraphDefinition = table.freeze({
	KindId = KindIds.ScreamerReinforcement,
	WarningLabel = "SCREAMER SUMMONING",
	CommitLabel = "REINFORCEMENTS",
	WindupSeconds = 1.25,
	RadiusStuds = 9,
	PulseCount = 3,
	Color = table.freeze({ 255, 220, 60 }),
})

local BloaterDeathBurst: TelegraphDefinition = table.freeze({
	KindId = KindIds.BloaterDeathBurst,
	WarningLabel = "BLOATER BURST",
	CommitLabel = "BURST",
	WindupSeconds = 0.85,
	RadiusStuds = HordeExperienceConfig.Roles.Bloater.DeathBurstRadiusStuds,
	PulseCount = 2,
	Color = table.freeze({ 112, 232, 76 }),
})

local BruteSecondPhase: TelegraphDefinition = table.freeze({
	KindId = KindIds.BruteSecondPhase,
	WarningLabel = "BRUTE REANIMATING",
	CommitLabel = "PHASE II",
	WindupSeconds = 0.9,
	RadiusStuds = 12,
	PulseCount = 2,
	Color = table.freeze({ 255, 56, 56 }),
})

local DefinitionsByKindId = table.freeze({
	[ScreamerReinforcement.KindId] = ScreamerReinforcement,
	[BloaterDeathBurst.KindId] = BloaterDeathBurst,
	[BruteSecondPhase.KindId] = BruteSecondPhase,
})

local function get(kindId: unknown): TelegraphDefinition?
	return if type(kindId) == "string" then DefinitionsByKindId[kindId] else nil
end

local Config = {
	Version = "HROI-0138-v1-screamer-interrupt-confirmation",
	AttributeNames = AttributeNames,
	StateIds = StateIds,
	KindIds = KindIds,
	ScreamerReinforcement = ScreamerReinforcement,
	BloaterDeathBurst = BloaterDeathBurst,
	BruteSecondPhase = BruteSecondPhase,
	DefinitionsByKindId = DefinitionsByKindId,
	MaximumTrackedEnemyModels = 128,
	MaximumActiveTelegraphs = 16,
	PollIntervalSeconds = 0.05,
	CommitHoldSeconds = 0.28,
	get = get,
}

local seenAttributeNames = {}
for _, attributeName in AttributeNames do
	assert(not seenAttributeNames[attributeName], "special telegraph attribute names must be unique")
	seenAttributeNames[attributeName] = true
end

for kindId, definition in DefinitionsByKindId do
	assert(definition.KindId == kindId, "special telegraph definition identity must match its key")
	assert(
		definition.WindupSeconds >= 0.6 and definition.WindupSeconds <= 1.5,
		"special windups must stay readable and bounded"
	)
	assert(definition.RadiusStuds > 0 and definition.RadiusStuds <= 24, "special telegraph radius must stay bounded")
	assert(definition.PulseCount >= 1 and definition.PulseCount <= 4, "special telegraph pulse count must stay bounded")
	assert(#definition.Color == 3, "special telegraph colors require RGB tuples")
end

assert(
	BloaterDeathBurst.RadiusStuds == HordeExperienceConfig.Roles.Bloater.DeathBurstRadiusStuds,
	"the Bloater warning must disclose the exact authoritative damage radius"
)
assert(
	math.max(BloaterDeathBurst.WindupSeconds, BruteSecondPhase.WindupSeconds) < EnemyConfig.Cleanup.CorpseCleanupSeconds,
	"corpse specials must commit before authoritative cleanup"
)
assert(
	Config.MaximumTrackedEnemyModels >= EnemyConfig.Population.AbsoluteMaximumConcurrent,
	"telegraph tracking must cover the enemy cap"
)
assert(Config.MaximumTrackedEnemyModels <= 128, "telegraph tracking must stay bounded")
assert(
	Config.MaximumActiveTelegraphs > 0 and Config.MaximumActiveTelegraphs <= 24,
	"active telegraphs require a strict cap"
)
assert(
	Config.PollIntervalSeconds > 0 and Config.PollIntervalSeconds <= 0.1,
	"telegraph polling must stay responsive and bounded"
)
assert(Config.CommitHoldSeconds > 0 and Config.CommitHoldSeconds <= 0.5, "commit flash must stay brief")

return table.freeze(Config)
