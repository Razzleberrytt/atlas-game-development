from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    source = file_path.read_text()
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f"{path}: expected one replacement, found {count}")
    file_path.write_text(source.replace(old, new, 1))


# DamageResolver: retain the existing primary override contract and add a
# separate bounded reduced-damage path for server-authored pattern impacts.
replace_once(
    "games/living-kingdoms/src/server/Systems/DamageResolver.luau",
    '''type DamageResolver = {
\tresolve: (
\t\thitResolution: FirearmHitResolution,
\t\ttargetHealthState: TargetHealthState,
\t\tserverTimestamp: number,
\t\tdamageAmountOverride: number?
\t) -> DamageResolution,
}''',
    '''type DamageResolver = {
\tresolve: (
\t\thitResolution: FirearmHitResolution,
\t\ttargetHealthState: TargetHealthState,
\t\tserverTimestamp: number,
\t\tdamageAmountOverride: number?
\t) -> DamageResolution,
\tresolvePattern: (
\t\thitResolution: FirearmHitResolution,
\t\ttargetHealthState: TargetHealthState,
\t\tserverTimestamp: number,
\t\tdamageMultiplier: number
\t) -> DamageResolution,
}''',
)
replace_once(
    "games/living-kingdoms/src/server/Systems/DamageResolver.luau",
    '''local function resolveDamageAmount(weaponId: string, override: number?, currentHealth: number): number?
\tlocal weapon = resolveWeaponDefinition(weaponId)
\tif weapon == nil then
\t\treturn nil
\tend
\tlocal configured = weapon.DamagePerHit
\tlocal requested = override
\tif requested == nil then
\t\tlocal damageMultiplier = readProgressionNumber("RunDamageMultiplier", 1)
\t\tlocal cullMultiplier = 1
\t\tlocal cullThreshold = readProgressionNumber("RunCullHealthThreshold", 0)
\t\tif currentHealth <= cullThreshold then
\t\t\tcullMultiplier = readProgressionNumber("RunCullDamageMultiplier", 1)
\t\tend
\t\trequested = math.floor(configured * damageMultiplier * cullMultiplier + 0.5)
\tend
\tif
\t\ttype(requested) ~= "number"
\t\tor requested ~= requested
\t\tor requested <= 0
\t\tor requested % 1 ~= 0
\t\tor requested < configured
\t\tor requested > configured * 3
\tthen
\t\treturn nil
\tend
\treturn requested
end''',
    '''local function resolveDamageAmount(
\tweaponId: string,
\toverride: number?,
\tcurrentHealth: number,
\tpatternMultiplier: number?
): number?
\tlocal weapon = resolveWeaponDefinition(weaponId)
\tif weapon == nil then
\t\treturn nil
\tend
\tlocal configured = weapon.DamagePerHit
\tlocal requested = override
\tif requested == nil then
\t\tlocal damageMultiplier = readProgressionNumber("RunDamageMultiplier", 1)
\t\tlocal cullMultiplier = 1
\t\tlocal cullThreshold = readProgressionNumber("RunCullHealthThreshold", 0)
\t\tif currentHealth <= cullThreshold then
\t\t\tcullMultiplier = readProgressionNumber("RunCullDamageMultiplier", 1)
\t\tend
\t\trequested = math.floor(configured * damageMultiplier * cullMultiplier + 0.5)
\tend
\tif patternMultiplier ~= nil then
\t\tif
\t\t\ttype(patternMultiplier) ~= "number"
\t\t\tor patternMultiplier ~= patternMultiplier
\t\t\tor patternMultiplier <= 0
\t\t\tor patternMultiplier > 1
\t\tthen
\t\t\treturn nil
\t\tend
\t\trequested = math.max(1, math.floor(requested * patternMultiplier + 0.5))
\tend
\tlocal minimumDamage = if patternMultiplier == nil then configured else 1
\tif
\t\ttype(requested) ~= "number"
\t\tor requested ~= requested
\t\tor requested <= 0
\t\tor requested % 1 ~= 0
\t\tor requested < minimumDamage
\t\tor requested > configured * 3
\tthen
\t\treturn nil
\tend
\treturn requested
end''',
)
replace_once(
    "games/living-kingdoms/src/server/Systems/DamageResolver.luau",
    '''function DamageResolver.resolve(
\thitResolution: FirearmHitResolution,
\ttargetHealthState: TargetHealthState,
\tserverTimestamp: number,
\tdamageAmountOverride: number?
): DamageResolution''',
    '''local function resolveInternal(
\thitResolution: FirearmHitResolution,
\ttargetHealthState: TargetHealthState,
\tserverTimestamp: number,
\tdamageAmountOverride: number?,
\tpatternMultiplier: number?
): DamageResolution''',
)
replace_once(
    "games/living-kingdoms/src/server/Systems/DamageResolver.luau",
    '''\tlocal damageAmount = resolveDamageAmount(hitResolution.weaponId, damageAmountOverride, healthBefore)''',
    '''\tlocal damageAmount = resolveDamageAmount(
\t\thitResolution.weaponId,
\t\tdamageAmountOverride,
\t\thealthBefore,
\t\tpatternMultiplier
\t)''',
)
replace_once(
    "games/living-kingdoms/src/server/Systems/DamageResolver.luau",
    '''end

return table.freeze(DamageResolver)''',
    '''end

function DamageResolver.resolve(
\thitResolution: FirearmHitResolution,
\ttargetHealthState: TargetHealthState,
\tserverTimestamp: number,
\tdamageAmountOverride: number?
): DamageResolution
\treturn resolveInternal(hitResolution, targetHealthState, serverTimestamp, damageAmountOverride, nil)
end

function DamageResolver.resolvePattern(
\thitResolution: FirearmHitResolution,
\ttargetHealthState: TargetHealthState,
\tserverTimestamp: number,
\tdamageMultiplier: number
): DamageResolution
\treturn resolveInternal(hitResolution, targetHealthState, serverTimestamp, nil, damageMultiplier)
end

return table.freeze(DamageResolver)''',
)

# Shared presentation contract: one accepted shot may disclose up to three
# already committed secondary impacts without creating a new message kind.
replace_once(
    "games/living-kingdoms/src/shared/Combat/CombatContracts.luau",
    '''export type ShotFiredPresentationMessage = {
\tkindId: "ShotFired",''',
    '''export type SecondaryShotImpactPresentation = {
\ttargetEntityId: CombatEntityId,
\timpactWorldPosition: Vector3,
\tdamageAmount: number,
}

export type ShotFiredPresentationMessage = {
\tkindId: "ShotFired",''',
)
replace_once(
    "games/living-kingdoms/src/shared/Combat/CombatContracts.luau",
    '''\tdamageAmount: number?,
\tserverTimestamp: number,''',
    '''\tdamageAmount: number?,
\tsecondaryImpacts: { SecondaryShotImpactPresentation }?,
\tserverTimestamp: number,''',
)

# Runtime: consume only the existing bounded sight facts, derive secondary IDs,
# commit through the existing revision boundary, and disclose committed results.
replace_once(
    "games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau",
    '''local TargetCandidateSelector = require(script.Parent.TargetCandidateSelector)''',
    '''local TargetCandidateSelector = require(script.Parent.TargetCandidateSelector)
local WeaponPatternResolver = require(script.Parent.WeaponPatternResolver)''',
)
replace_once(
    "games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau",
    '''type FirearmTargetContext = CombatContracts.FirearmTargetContext''',
    '''type FirearmHitResolution = CombatContracts.FirearmHitResolution
type FirearmTargetContext = CombatContracts.FirearmTargetContext''',
)
replace_once(
    "games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau",
    '''local function resolveAcceptedShot(
\tplayerState: PlayerCombatState,''',
    '''local function buildPatternTargetFacts(playerState: PlayerCombatState): { WeaponPatternResolver.PatternTargetFact }
\tlocal facts = {}
\tfor _, sightedEntry in playerState.sightedByEntityId do
\t\ttable.insert(facts, {
\t\t\tentityId = sightedEntry.fact.entityId,
\t\t\tworldPosition = sightedEntry.fact.worldPosition,
\t\t\tisAlive = sightedEntry.fact.isAlive,
\t\t\tisTargetable = true,
\t\t\tisVisible = sightedEntry.distanceStuds <= EnemyConfig.Combat.GameplayVisibilityRadiusStuds,
\t\t\thasLineOfSight = sightedEntry.hasLineOfSight,
\t\t})
\tend
\treturn facts
end

local function commitPatternImpacts(
\tplayerState: PlayerCombatState,
\toperativePosition: Vector3,
\tprimaryTargetEntityId: string,
\tprimaryShotId: string,
\tnowTimestamp: number
): { CombatContracts.SecondaryShotImpactPresentation }
\tlocal selectedImpacts = WeaponPatternResolver.resolve(
\t\tplayerState.weaponState.weaponId,
\t\toperativePosition,
\t\tprimaryTargetEntityId,
\t\tbuildPatternTargetFacts(playerState)
\t)
\tlocal disclosedImpacts = {}
\tfor index, impact in selectedImpacts do
\t\tlocal sightedEntry = playerState.sightedByEntityId[impact.targetEntityId]
\t\tlocal healthRead = EnemyDirectorService.readHealthState(impact.targetEntityId)
\t\tif sightedEntry == nil or healthRead == nil or not healthRead.isAlive or not sightedEntry.hasLineOfSight then
\t\t\tcontinue
\t\tend
\t\tlocal derivedShotId = string.format(
\t\t\t"%s:pattern:%d:%s",
\t\t\tprimaryShotId,
\t\t\tindex,
\t\t\timpact.targetEntityId
\t\t)
\t\tlocal hitResolution: FirearmHitResolution = {
\t\t\tshotId = derivedShotId,
\t\t\tsourceEntityId = playerState.operativeState.entityId,
\t\t\ttargetEntityId = impact.targetEntityId,
\t\t\tweaponId = playerState.weaponState.weaponId,
\t\t\tdidHit = true,
\t\t\trejectionReasonId = nil,
\t\t}
\t\tlocal damageResolution = DamageResolver.resolvePattern(
\t\t\thitResolution,
\t\t\thealthRead.healthState,
\t\t\tnowTimestamp,
\t\t\timpact.damageMultiplier
\t\t)
\t\tlocal didCommit = EnemyDirectorService.commitHealthState(
\t\t\timpact.targetEntityId,
\t\t\thealthRead.revision,
\t\t\tdamageResolution.targetHealthStateAfter,
\t\t\tnowTimestamp
\t\t)
\t\tlocal damageEvent = damageResolution.damageEvent
\t\tif didCommit and damageResolution.didApplyDamage and damageEvent ~= nil then
\t\t\ttable.insert(disclosedImpacts, {
\t\t\t\ttargetEntityId = impact.targetEntityId,
\t\t\t\timpactWorldPosition = sightedEntry.fact.worldPosition,
\t\t\t\tdamageAmount = damageEvent.damageAmount,
\t\t\t})
\t\tend
\tend
\treturn disclosedImpacts
end

local function resolveAcceptedShot(
\tplayerState: PlayerCombatState,''',
)
replace_once(
    "games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau",
    '''\tEnemyDirectorService.commitHealthState(
\t\ttargetEntityId,
\t\thealthRead.revision,
\t\tdamageResolution.targetHealthStateAfter,
\t\tnowTimestamp
\t)
\tlocal damageAmount = if damageResolution.damageEvent == nil then nil else damageResolution.damageEvent.damageAmount
\tpresentationRemote:FireAllClients({''',
    '''\tlocal didCommitPrimary = EnemyDirectorService.commitHealthState(
\t\ttargetEntityId,
\t\thealthRead.revision,
\t\tdamageResolution.targetHealthStateAfter,
\t\tnowTimestamp
\t)
\tlocal didApplyPrimaryDamage = didCommitPrimary and damageResolution.didApplyDamage
\tlocal damageAmount = if didApplyPrimaryDamage and damageResolution.damageEvent ~= nil
\t\tthen damageResolution.damageEvent.damageAmount
\t\telse nil
\tlocal secondaryImpacts = if didApplyPrimaryDamage
\t\tthen commitPatternImpacts(playerState, operativePosition, targetEntityId, shotId, nowTimestamp)
\t\telse {}
\tpresentationRemote:FireAllClients({''',
)
replace_once(
    "games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau",
    '''\t\tdidApplyDamage = damageResolution.didApplyDamage,
\t\timpactWorldPosition = if damageResolution.didApplyDamage then fact.worldPosition else nil,
\t\tdamageAmount = damageAmount,
\t\tserverTimestamp = nowTimestamp,''',
    '''\t\tdidApplyDamage = didApplyPrimaryDamage,
\t\timpactWorldPosition = if didApplyPrimaryDamage then fact.worldPosition else nil,
\t\tdamageAmount = damageAmount,
\t\tsecondaryImpacts = if #secondaryImpacts > 0 then secondaryImpacts else nil,
\t\tserverTimestamp = nowTimestamp,''',
)

# Client presentation: validate a maximum of three authoritative secondary
# positions, then draw extra paths/impacts without replaying flash, casing,
# recoil, or audio.
replace_once(
    "games/living-kingdoms/src/client/Presentation/WeaponShotEffectPresenter.luau",
    '''\t\tdidApplyDamage: boolean,
\t\timpactWorldPosition: Vector3?
\t) -> (),''',
    '''\t\tdidApplyDamage: boolean,
\t\timpactWorldPosition: Vector3?,
\t\tsecondaryImpactWorldPositions: { Vector3 }
\t) -> (),''',
)
replace_once(
    "games/living-kingdoms/src/client/Presentation/WeaponShotEffectPresenter.luau",
    '''\tdidApplyDamage: boolean,
\timpactWorldPosition: Vector3?
)''',
    '''\tdidApplyDamage: boolean,
\timpactWorldPosition: Vector3?,
\tsecondaryImpactWorldPositions: { Vector3 }
)''',
)
replace_once(
    "games/living-kingdoms/src/client/Presentation/WeaponShotEffectPresenter.luau",
    '''\tif didApplyDamage and impactWorldPosition ~= nil then
\t\tspawnDamageTracer(rig, shotId, impactWorldPosition, profile)
\t\tspawnDamageImpact(impactWorldPosition, profile)
\tend
end''',
    '''\tif didApplyDamage and impactWorldPosition ~= nil then
\t\tspawnDamageTracer(rig, shotId, impactWorldPosition, profile)
\t\tspawnDamageImpact(impactWorldPosition, profile)
\tend
\tfor index, secondaryPosition in secondaryImpactWorldPositions do
\t\tif index > 3 then
\t\t\tbreak
\t\tend
\t\tspawnDamageTracer(rig, shotId .. ":pattern:" .. tostring(index), secondaryPosition, profile)
\t\tspawnDamageImpact(secondaryPosition, profile)
\tend
end''',
)
replace_once(
    "games/living-kingdoms/src/client/Controllers/WeaponPresentationController.luau",
    '''\tdidApplyDamage: boolean,
\timpactWorldPosition: Vector3?
)''',
    '''\tdidApplyDamage: boolean,
\timpactWorldPosition: Vector3?,
\tsecondaryImpactWorldPositions: { Vector3 }
)''',
)
replace_once(
    "games/living-kingdoms/src/client/Controllers/WeaponPresentationController.luau",
    '''\tWeaponShotEffectPresenter.present(rig, shotId, didApplyDamage, impactWorldPosition)''',
    '''\tWeaponShotEffectPresenter.present(
\t\trig,
\t\tshotId,
\t\tdidApplyDamage,
\t\timpactWorldPosition,
\t\tsecondaryImpactWorldPositions
\t)''',
)
replace_once(
    "games/living-kingdoms/src/client/Controllers/WeaponPresentationController.luau",
    '''local function onPresentationMessage(message: unknown)''',
    '''local function readSecondaryImpactPositions(value: unknown): { Vector3 }?
\tif value == nil then
\t\treturn {}
\tend
\tif type(value) ~= "table" or #value > 3 then
\t\treturn nil
\tend
\tlocal positions = {}
\tfor _, impact in value :: any do
\t\tif
\t\t\ttype(impact) ~= "table"
\t\t\tor not isNonEmptyString(impact.targetEntityId)
\t\t\tor typeof(impact.impactWorldPosition) ~= "Vector3"
\t\t\tor not isWholeNonnegative(impact.damageAmount)
\t\t\tor impact.damageAmount <= 0
\t\tthen
\t\t\treturn nil
\t\tend
\t\ttable.insert(positions, impact.impactWorldPosition)
\tend
\treturn positions
end

local function onPresentationMessage(message: unknown)''',
)
replace_once(
    "games/living-kingdoms/src/client/Controllers/WeaponPresentationController.luau",
    '''\tif kindId == CombatContracts.PresentationMessageKindIds.ShotFired then
\t\tif''',
    '''\tif kindId == CombatContracts.PresentationMessageKindIds.ShotFired then
\t\tlocal secondaryImpactWorldPositions = readSecondaryImpactPositions(payload.secondaryImpacts)
\t\tif''',
)
replace_once(
    "games/living-kingdoms/src/client/Controllers/WeaponPresentationController.luau",
    '''\t\t\tand isFiniteNumber(payload.serverTimestamp)
\t\tthen
\t\t\tplayShot(payload.shotId, payload.operativeEntityId, payload.didApplyDamage, payload.impactWorldPosition)''',
    '''\t\t\tand isFiniteNumber(payload.serverTimestamp)
\t\t\tand secondaryImpactWorldPositions ~= nil
\t\tthen
\t\t\tplayShot(
\t\t\t\tpayload.shotId,
\t\t\t\tpayload.operativeEntityId,
\t\t\t\tpayload.didApplyDamage,
\t\t\t\tpayload.impactWorldPosition,
\t\t\t\tsecondaryImpactWorldPositions
\t\t\t)''',
)

print("Applied authoritative shotgun cone and sniper line-pierce integration")
