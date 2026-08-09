--!strict

--[[
	BA-051 authored encounter-beat definitions for the first outdoor route.

	The expedition bootstrap now consumes these beats as the authoritative
	Approach combat sequence through the existing EnemyDirector adapter. This does
	not activate BA-050 route geometry, teleport players, grant rewards, choose
	elite affixes, or override the canonical EliteAffixResolver / EnemyDirector
	authorities. Route traversal/geometry remains a separate prepared-data seam.
]]

local EnemyContracts = require(script.Parent.Parent.Combat.EnemyContracts)
local FirstOutdoorRouteConfig = require(script.Parent.FirstOutdoorRouteConfig)
local HordeExperienceConfig = require(script.Parent.HordeExperienceConfig)

local EnemyArchetypeIds = EnemyContracts.EnemyArchetypeIds
local EnemySpawnSourceIds = EnemyContracts.EnemySpawnSourceIds
local HordeRoles = HordeExperienceConfig.Roles
local EncounterSlotIds = FirstOutdoorRouteConfig.EncounterSlotIds

local ElitePlacementIntentIds = table.freeze({
	Ordinary = "Ordinary",
	LateRouteResolverCandidate = "LateRouteResolverCandidate",
})

local RecoveryIntentIds = table.freeze({
	BriefBreather = "BriefBreather",
	ResetBeforeDungeon = "ResetBeforeDungeon",
})

local function unit(archetypeId: string, count: number, hordeRoleId: string?)
	return table.freeze({
		ArchetypeId = archetypeId,
		Count = count,
		HordeRoleId = hordeRoleId,
	})
end

local function wave(delayAfterPreviousSeconds: number, units: { any })
	return table.freeze({
		DelayAfterPreviousSeconds = delayAfterPreviousSeconds,
		Units = table.freeze(units),
	})
end

local function beat(
	id: string,
	order: number,
	encounterSlotId: string,
	targetDurationMinimumSeconds: number,
	targetDurationMaximumSeconds: number,
	postClearRecoverySeconds: number,
	recoveryIntentId: string,
	elitePlacementIntentId: string,
	waves: { any }
)
	return table.freeze({
		Id = id,
		Order = order,
		EncounterSlotId = encounterSlotId,
		SpawnSourceId = EnemySpawnSourceIds.AuthoredWave,
		TargetDurationMinimumSeconds = targetDurationMinimumSeconds,
		TargetDurationMaximumSeconds = targetDurationMaximumSeconds,
		PostClearRecoverySeconds = postClearRecoverySeconds,
		RecoveryIntentId = recoveryIntentId,
		ElitePlacementIntentId = elitePlacementIntentId,
		Waves = table.freeze(waves),
	})
end

local FirstOutdoorEncounterBeatConfig = {
	Version = "BA-051-v2-approach-live",
	RouteId = FirstOutdoorRouteConfig.RouteId,
	RouteVersion = FirstOutdoorRouteConfig.RouteVersion,
	RuntimeConsumptionActive = true,
	RuntimeConsumptionScopeId = "ApproachCombatSequenceOnly",
	ElitePlacementIntentIds = ElitePlacementIntentIds,
	RecoveryIntentIds = RecoveryIntentIds,
	Beats = table.freeze({
		beat(
			"logging-road-contact",
			1,
			EncounterSlotIds.LoggingRoad,
			20,
			35,
			8,
			RecoveryIntentIds.BriefBreather,
			ElitePlacementIntentIds.Ordinary,
			{
				wave(0, {
					unit(EnemyArchetypeIds.ExclusionWalker, 2, HordeRoles.Basic.Id),
				}),
			}
		),
		beat(
			"campground-crossfire",
			2,
			EncounterSlotIds.Campground,
			30,
			50,
			10,
			RecoveryIntentIds.BriefBreather,
			ElitePlacementIntentIds.Ordinary,
			{
				wave(0, {
					unit(EnemyArchetypeIds.ExclusionWalker, 1, HordeRoles.Basic.Id),
					unit(EnemyArchetypeIds.ExclusionWalker, 1, HordeRoles.Runner.Id),
					unit(EnemyArchetypeIds.ExclusionWalker, 1, HordeRoles.Crawler.Id),
				}),
			}
		),
		beat(
			"military-roadblock-gate",
			3,
			EncounterSlotIds.MilitaryRoadblock,
			45,
			70,
			15,
			RecoveryIntentIds.ResetBeforeDungeon,
			ElitePlacementIntentIds.LateRouteResolverCandidate,
			{
				wave(0, {
					unit(EnemyArchetypeIds.ExclusionWalker, 1, HordeRoles.Basic.Id),
					unit(EnemyArchetypeIds.ExclusionWalker, 1, HordeRoles.Runner.Id),
				}),
				wave(5, {
					unit(EnemyArchetypeIds.ExclusionWalker, 1, HordeRoles.Basic.Id),
					unit(EnemyArchetypeIds.BlightSpitter, 1, nil),
				}),
			}
		),
	}),
}

assert(FirstOutdoorEncounterBeatConfig.RuntimeConsumptionActive == true, "BA-051 approach combat must remain live")
assert(
	FirstOutdoorEncounterBeatConfig.RuntimeConsumptionScopeId == "ApproachCombatSequenceOnly",
	"BA-051 live scope must not imply route-geometry activation"
)
assert(FirstOutdoorRouteConfig.RuntimeConsumptionActive == false, "BA-051 cannot activate the BA-050 route geometry")
assert(#FirstOutdoorEncounterBeatConfig.Beats == 3, "the first outdoor route requires exactly three encounter beats")

local expectedEncounterSlotIds = table.freeze({
	EncounterSlotIds.LoggingRoad,
	EncounterSlotIds.Campground,
	EncounterSlotIds.MilitaryRoadblock,
})
local knownEnemyArchetypeIds = {}
for _, archetypeId in EnemyArchetypeIds do
	knownEnemyArchetypeIds[archetypeId] = true
end
local knownHordeRoleIds = {}
for _, role in HordeRoles do
	knownHordeRoleIds[role.Id] = true
end

local resolverCandidateCount = 0
for index, authoredBeat in FirstOutdoorEncounterBeatConfig.Beats do
	assert(authoredBeat.Order == index, "outdoor encounter beat orders must remain contiguous")
	assert(
		authoredBeat.EncounterSlotId == expectedEncounterSlotIds[index],
		"outdoor encounter beat must preserve the BA-050 slot order"
	)
	assert(
		authoredBeat.SpawnSourceId == EnemySpawnSourceIds.AuthoredWave,
		"outdoor encounter beats must use the canonical authored-wave spawn source"
	)
	assert(
		authoredBeat.TargetDurationMinimumSeconds > 0
			and authoredBeat.TargetDurationMaximumSeconds >= authoredBeat.TargetDurationMinimumSeconds,
		"outdoor encounter target duration must be a positive bounded range"
	)
	assert(authoredBeat.PostClearRecoverySeconds >= 0, "outdoor encounter recovery target cannot be negative")
	assert(#authoredBeat.Waves >= 1, "outdoor encounter beats require at least one authored wave")

	if authoredBeat.ElitePlacementIntentId == ElitePlacementIntentIds.LateRouteResolverCandidate then
		resolverCandidateCount += 1
		assert(
			index == #FirstOutdoorEncounterBeatConfig.Beats,
			"only the final outdoor beat may carry elite-candidate intent"
		)
	else
		assert(
			authoredBeat.ElitePlacementIntentId == ElitePlacementIntentIds.Ordinary,
			"unknown outdoor elite placement intent"
		)
	end

	for waveIndex, authoredWave in authoredBeat.Waves do
		if waveIndex == 1 then
			assert(
				authoredWave.DelayAfterPreviousSeconds == 0,
				"the first authored wave cannot require a prior-wave delay"
			)
		else
			assert(
				authoredWave.DelayAfterPreviousSeconds > 0,
				"follow-up authored waves require a positive pacing delay"
			)
		end
		assert(#authoredWave.Units >= 1, "outdoor authored waves cannot be empty")

		local wavePopulation = 0
		for _, authoredUnit in authoredWave.Units do
			assert(
				knownEnemyArchetypeIds[authoredUnit.ArchetypeId] == true,
				"unknown enemy archetype in outdoor encounter content"
			)
			assert(
				authoredUnit.ArchetypeId ~= EnemyArchetypeIds.Progenitor,
				"outdoor route cannot author the dungeon boss"
			)
			assert(
				authoredUnit.Count >= 1 and authoredUnit.Count % 1 == 0,
				"outdoor authored enemy counts must be positive integers"
			)
			wavePopulation += authoredUnit.Count
			if authoredUnit.ArchetypeId == EnemyArchetypeIds.ExclusionWalker then
				assert(
					authoredUnit.HordeRoleId ~= nil and knownHordeRoleIds[authoredUnit.HordeRoleId] == true,
					"outdoor walkers must reference a canonical horde role"
				)
			else
				assert(authoredUnit.HordeRoleId == nil, "special outdoor archetypes cannot borrow a walker horde role")
			end
		end
		assert(wavePopulation <= 3, "first-route authored waves must stay readable for solo onboarding")
	end
end

assert(resolverCandidateCount == 1, "the outdoor approach requires exactly one late-route elite-candidate beat")
assert(
	FirstOutdoorEncounterBeatConfig.Beats[1].TargetDurationMaximumSeconds
		< FirstOutdoorEncounterBeatConfig.Beats[3].TargetDurationMaximumSeconds,
	"outdoor encounter pacing must escalate toward the dungeon"
)
assert(
	FirstOutdoorEncounterBeatConfig.Beats[3].RecoveryIntentId == RecoveryIntentIds.ResetBeforeDungeon,
	"the final roadblock must preserve a recovery window before First Descent"
)
assert(
	FirstOutdoorEncounterBeatConfig.Beats[3].PostClearRecoverySeconds
		> FirstOutdoorEncounterBeatConfig.Beats[2].PostClearRecoverySeconds,
	"the final pre-dungeon recovery target must be the longest outdoor breather"
)

return table.freeze(FirstOutdoorEncounterBeatConfig)
