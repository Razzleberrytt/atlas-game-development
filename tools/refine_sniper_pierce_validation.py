from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    source = file_path.read_text()
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f"{path}: expected one replacement, found {count}")
    file_path.write_text(source.replace(old, new, 1))


resolver = "games/living-kingdoms/src/server/Systems/WeaponPatternResolver.luau"
replace_once(
    resolver,
    '''export type PatternImpact = {
\ttargetEntityId: string,
\tdamageMultiplier: number,
}''',
    '''export type PatternImpact = {
\ttargetEntityId: string,
\tdamageMultiplier: number,
\trequiresPierceValidation: boolean,
}''',
)
replace_once(
    resolver,
    '''local function isEligibleSecondary(fact: PatternTargetFact, primaryTargetEntityId: string): boolean
\treturn fact.entityId ~= primaryTargetEntityId
\t\tand fact.entityId ~= ""
\t\tand fact.isAlive
\t\tand fact.isTargetable
\t\tand fact.isVisible
\t\tand fact.hasLineOfSight
end''',
    '''local function isEligibleSecondary(fact: PatternTargetFact, primaryTargetEntityId: string): boolean
\treturn fact.entityId ~= primaryTargetEntityId
\t\tand fact.entityId ~= ""
\t\tand fact.isAlive
\t\tand fact.isTargetable
\t\tand fact.isVisible
end''',
)
replace_once(
    resolver,
    '''\tfor _, fact in targetFacts do
\t\tif not isEligibleSecondary(fact, primaryTargetEntityId) then
\t\t\tcontinue
\t\tend
\t\tlocal deltaX, deltaZ = horizontalDelta(operativeWorldPosition, fact.worldPosition)''',
    '''\tfor _, fact in targetFacts do
\t\tif not isEligibleSecondary(fact, primaryTargetEntityId) or not fact.hasLineOfSight then
\t\t\tcontinue
\t\tend
\t\tlocal deltaX, deltaZ = horizontalDelta(operativeWorldPosition, fact.worldPosition)''',
)
replace_once(
    resolver,
    '''\t\timpacts[index] = table.freeze({
\t\t\ttargetEntityId = ranked[index].fact.entityId,
\t\t\tdamageMultiplier = definition.SecondaryDamageMultiplier,
\t\t})''',
    '''\t\timpacts[index] = table.freeze({
\t\t\ttargetEntityId = ranked[index].fact.entityId,
\t\t\tdamageMultiplier = definition.SecondaryDamageMultiplier,
\t\t\trequiresPierceValidation = definition.ModeId == modes.LinePierce,
\t\t})''',
)

runtime = "games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau"
replace_once(
    runtime,
    '''local function hasClearShot(
\tplayer: Player,
\toperativePosition: Vector3,
\tfact: EnemyDirectorService.EnemyCombatFact
): boolean
\tlocal parameters = RaycastParams.new()
\tparameters.FilterType = Enum.RaycastFilterType.Exclude
\tlocal exclusions: { Instance } = {}
\tlocal character = player.Character
\tif character ~= nil then
\t\ttable.insert(exclusions, character)
\tend
\tparameters.FilterDescendantsInstances = exclusions
\tlocal direction = fact.worldPosition - operativePosition
\tlocal result = Workspace:Raycast(operativePosition, direction, parameters)
\tif result == nil then
\t\treturn true
\tend
\treturn result.Instance:IsDescendantOf(fact.model)
end''',
    '''local function hasClearShot(
\tplayer: Player,
\toperativePosition: Vector3,
\tfact: EnemyDirectorService.EnemyCombatFact
): boolean
\tlocal parameters = RaycastParams.new()
\tparameters.FilterType = Enum.RaycastFilterType.Exclude
\tlocal exclusions: { Instance } = {}
\tlocal character = player.Character
\tif character ~= nil then
\t\ttable.insert(exclusions, character)
\tend
\tparameters.FilterDescendantsInstances = exclusions
\tlocal direction = fact.worldPosition - operativePosition
\tlocal result = Workspace:Raycast(operativePosition, direction, parameters)
\tif result == nil then
\t\treturn true
\tend
\treturn result.Instance:IsDescendantOf(fact.model)
end

-- A rear candidate naturally fails the normal sight ray when the selected
-- primary is the first hit. One accepted precision shot may therefore perform
-- one additional validation ray that excludes only the operative and the
-- already-hit primary. Terrain and any other hostile still block the path.
local function hasClearPierceShot(
\tplayer: Player,
\toperativePosition: Vector3,
\tprimaryFact: EnemyDirectorService.EnemyCombatFact,
\tsecondaryFact: EnemyDirectorService.EnemyCombatFact
): boolean
\tlocal parameters = RaycastParams.new()
\tparameters.FilterType = Enum.RaycastFilterType.Exclude
\tlocal exclusions: { Instance } = { primaryFact.model }
\tlocal character = player.Character
\tif character ~= nil then
\t\ttable.insert(exclusions, character)
\tend
\tparameters.FilterDescendantsInstances = exclusions
\tlocal direction = secondaryFact.worldPosition - operativePosition
\tlocal result = Workspace:Raycast(operativePosition, direction, parameters)
\tif result == nil then
\t\treturn true
\tend
\treturn result.Instance:IsDescendantOf(secondaryFact.model)
end''',
)
replace_once(
    runtime,
    '''local function commitPatternImpacts(
\tplayerState: PlayerCombatState,
\toperativePosition: Vector3,
\tprimaryTargetEntityId: string,
\tprimaryShotId: string,
\tnowTimestamp: number
): { CombatContracts.SecondaryShotImpactPresentation }
\tlocal selectedImpacts = WeaponPatternResolver.resolve(''',
    '''local function commitPatternImpacts(
\tplayer: Player,
\tplayerState: PlayerCombatState,
\toperativePosition: Vector3,
\tprimaryTargetEntityId: string,
\tprimaryShotId: string,
\tnowTimestamp: number
): { CombatContracts.SecondaryShotImpactPresentation }
\tlocal primaryEntry = playerState.sightedByEntityId[primaryTargetEntityId]
\tif primaryEntry == nil then
\t\treturn {}
\tend
\tlocal selectedImpacts = WeaponPatternResolver.resolve(''',
)
replace_once(
    runtime,
    '''\t\tlocal healthRead = EnemyDirectorService.readHealthState(impact.targetEntityId)
\t\tif sightedEntry == nil or healthRead == nil or not healthRead.isAlive or not sightedEntry.hasLineOfSight then
\t\t\tcontinue
\t\tend
\t\tlocal derivedShotId = string.format''',
    '''\t\tlocal healthRead = EnemyDirectorService.readHealthState(impact.targetEntityId)
\t\tif sightedEntry == nil or healthRead == nil or not healthRead.isAlive then
\t\t\tcontinue
\t\tend
\t\tlocal hasPatternLineOfSight = if impact.requiresPierceValidation
\t\t\tthen hasClearPierceShot(player, operativePosition, primaryEntry.fact, sightedEntry.fact)
\t\t\telse sightedEntry.hasLineOfSight
\t\tif not hasPatternLineOfSight then
\t\t\tcontinue
\t\tend
\t\tlocal derivedShotId = string.format''',
)
replace_once(
    runtime,
    '''local function resolveAcceptedShot(
\tplayerState: PlayerCombatState,''',
    '''local function resolveAcceptedShot(
\tplayer: Player,
\tplayerState: PlayerCombatState,''',
)
replace_once(
    runtime,
    '''\tlocal secondaryImpacts = if didApplyPrimaryDamage
\t\tthen commitPatternImpacts(playerState, operativePosition, targetEntityId, shotId, nowTimestamp)
\t\telse {}''',
    '''\tlocal secondaryImpacts = if didApplyPrimaryDamage
\t\tthen commitPatternImpacts(player, playerState, operativePosition, targetEntityId, shotId, nowTimestamp)
\t\telse {}''',
)
replace_once(
    runtime,
    '''\tif fireResolution.decision.shouldFire then
\t\tresolveAcceptedShot(playerState, operativePosition, fireResolution.fireResult, nowTimestamp)''',
    '''\tif fireResolution.decision.shouldFire then
\t\tresolveAcceptedShot(player, playerState, operativePosition, fireResolution.fireResult, nowTimestamp)''',
)

resolver_test = "games/living-kingdoms/tests/WeaponPatternResolver.test.luau"
replace_once(
    resolver_test,
    '''for _, impact in shotgunImpacts do
\tassert(impact.damageMultiplier == 0.7, "shotgun multiplier must come from server config")
\tassert(impact.targetEntityId ~= primary.entityId, "primary cannot be duplicated as a secondary")
end''',
    '''for _, impact in shotgunImpacts do
\tassert(impact.damageMultiplier == 0.7, "shotgun multiplier must come from server config")
\tassert(not impact.requiresPierceValidation, "shotgun must use the existing sight result")
\tassert(impact.targetEntityId ~= primary.entityId, "primary cannot be duplicated as a secondary")
end''',
)
replace_once(
    resolver_test,
    '''local nearestBehind = fact("enemy.nearest-behind", 24, 1)
local fartherBehind = fact("enemy.farther-behind", 45, 0)''',
    '''local nearestBehind = fact("enemy.nearest-behind", 24, 1)
-- The normal sight ray can hit the primary first. Geometry may nominate this
-- target, but the runtime must perform the bounded post-primary validation ray.
nearestBehind.hasLineOfSight = false
local fartherBehind = fact("enemy.farther-behind", 45, 0)''',
)
replace_once(
    resolver_test,
    '''assert(sniperImpacts[1].damageMultiplier == 0.72, "sniper multiplier must come from server config")''',
    '''assert(sniperImpacts[1].damageMultiplier == 0.72, "sniper multiplier must come from server config")
assert(sniperImpacts[1].requiresPierceValidation, "precision impact must request runtime path validation")''',
)

source_audit = "games/living-kingdoms/tests/WeaponPatternSourceAudit.test.luau"
replace_once(
    source_audit,
    '''\t\t"table.sort",
\t\t"table.freeze(impacts)",''',
    '''\t\t"table.sort",
\t\t"requiresPierceValidation",
\t\t"table.freeze(impacts)",''',
)
replace_once(
    source_audit,
    '''assertThat(contains(runtime, "WeaponPatternResolver.resolve("), "runtime must resolve patterns server-side")
assertThat(contains(runtime, "buildPatternTargetFacts(playerState)"), "runtime must reuse bounded sight facts")''',
    '''assertThat(contains(runtime, "WeaponPatternResolver.resolve("), "runtime must resolve patterns server-side")
assertThat(contains(runtime, "buildPatternTargetFacts(playerState)"), "runtime must reuse bounded sight facts")
assertThat(contains(runtime, "local function hasClearPierceShot("), "runtime must validate the rear path")
assertThat(
\tcontains(runtime, "local exclusions: { Instance } = { primaryFact.model }"),
\t"rear-path validation must exclude only the already-hit primary before testing the second target"
)
local _, runtimeRaycastCount = string.gsub(runtime, "Workspace:Raycast", "")
assertThat(runtimeRaycastCount == 2, "runtime may own only the baseline sight ray and one bounded rear-path ray")''',
)

spec = "docs/specifications/authoritative-weapon-patterns.md"
replace_once(
    spec,
    '''- zero additional raycasts;
- zero new remotes;''',
    '''- no new raycast loop;
- at most one additional rear-path validation ray per accepted sniper shot, and only after a candidate is geometrically selected;
- zero new remotes;''',
)
replace_once(
    spec,
    '''The client supplies no aim vector, spread seed, secondary target, damage multiplier, impact position, penetration result, or extra ammunition request. Pattern selection consumes the same bounded server-derived sight facts and line-of-sight results already used by primary automatic targeting.''',
    '''The client supplies no aim vector, spread seed, secondary target, damage multiplier, impact position, penetration result, or extra ammunition request. Pattern selection consumes the same bounded server-derived sight facts used by primary automatic targeting. Shotgun cleave requires the existing line-of-sight result. A geometrically aligned sniper candidate receives one server ray that excludes the already-hit primary so terrain or another hostile can still block the path.''',
)

print("Refined rear-target validation with one bounded post-primary ray")
