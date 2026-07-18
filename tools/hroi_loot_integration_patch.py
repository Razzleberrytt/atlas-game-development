from __future__ import annotations

from pathlib import Path


def replace_once(source: str, old: str, new: str, label: str) -> str:
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one match, found {count}")
    return source.replace(old, new, 1)


life_path = Path("games/living-kingdoms/src/server/Systems/OperativeLifeService.luau")
life = life_path.read_text(encoding="utf-8")
life = replace_once(
    life,
    "local OperativeHealthResolver = require(script.Parent.OperativeHealthResolver)",
    "local OperativeHealingResolver = require(script.Parent.OperativeHealingResolver)\nlocal OperativeHealthResolver = require(script.Parent.OperativeHealthResolver)",
    "life healing resolver require",
)
life = replace_once(
    life,
    "type AuthoritativeOperativeDamage = OperativeLifeContracts.AuthoritativeOperativeDamage\ntype OperativeLifeStateSnapshot = OperativeLifeContracts.OperativeLifeStateSnapshot",
    "type AuthoritativeOperativeDamage = OperativeLifeContracts.AuthoritativeOperativeDamage\ntype AuthoritativeHealing = OperativeHealingResolver.AuthoritativeHealing\ntype OperativeLifeStateSnapshot = OperativeLifeContracts.OperativeLifeStateSnapshot",
    "life healing type",
)
life = replace_once(
    life,
    '''\tapplyAuthoritativeDamage: (
\t\toperativeEntityId: string,
\t\texpectedRevision: number,
\t\tauthoritativeDamage: AuthoritativeOperativeDamage
\t) -> CommitResult,
\tcommitAcceptedTransition:''',
    '''\tapplyAuthoritativeDamage: (
\t\toperativeEntityId: string,
\t\texpectedRevision: number,
\t\tauthoritativeDamage: AuthoritativeOperativeDamage
\t) -> CommitResult,
\tapplyAuthoritativeHealing: (
\t\toperativeEntityId: string,
\t\texpectedRevision: number,
\t\tauthoritativeHealing: AuthoritativeHealing
\t) -> CommitResult,
\tcommitAcceptedTransition:''',
    "life service healing API type",
)
life = replace_once(
    life,
    '''function OperativeLifeService.commitAcceptedTransition(
\tplayer: Player,
\texpectedRevision: number,
\tresolverResult: unknown
): CommitResult''',
    '''local function commitAcceptedTransitionInternal(
\tplayer: Player,
\texpectedRevision: number,
\tresolverResult: unknown,
\tallowHealthIncrease: boolean
): CommitResult''',
    "life internal transition commit",
)
life = replace_once(
    life,
    '''\tif
\t\tentry.snapshot.lifeStateId == lifeStateIds.Alive
\t\tand validatedSnapshot.lifeStateId == lifeStateIds.Alive
\t\tand validatedSnapshot.healthState.currentHealth > entry.snapshot.healthState.currentHealth
\tthen''',
    '''\tif
\t\tnot allowHealthIncrease
\t\tand entry.snapshot.lifeStateId == lifeStateIds.Alive
\t\tand validatedSnapshot.lifeStateId == lifeStateIds.Alive
\t\tand validatedSnapshot.healthState.currentHealth > entry.snapshot.healthState.currentHealth
\tthen''',
    "life bounded health increase gate",
)
life = replace_once(
    life,
    '''\treturn {
\t\tdidCommit = true,
\t\trejectionReason = nil,
\t\trevision = entry.revision,
\t\tsnapshot = copySnapshot(entry.snapshot),
\t}
end

function OperativeLifeService.isAlive''',
    '''\treturn {
\t\tdidCommit = true,
\t\trejectionReason = nil,
\t\trevision = entry.revision,
\t\tsnapshot = copySnapshot(entry.snapshot),
\t}
end

function OperativeLifeService.commitAcceptedTransition(
\tplayer: Player,
\texpectedRevision: number,
\tresolverResult: unknown
): CommitResult
\treturn commitAcceptedTransitionInternal(player, expectedRevision, resolverResult, false)
end

function OperativeLifeService.applyAuthoritativeHealing(
\toperativeEntityId: string,
\texpectedRevision: number,
\tauthoritativeHealing: AuthoritativeHealing
): CommitResult
\tif type(operativeEntityId) ~= "string" or operativeEntityId == "" then
\t\treturn rejected("UnknownOperative")
\tend
\tlocal player = playerByOperativeEntityId[operativeEntityId]
\tlocal entry = if player == nil then nil else entries[player]
\tif entry == nil or entry.operativeEntityId ~= operativeEntityId then
\t\treturn rejected("OperativeNotRegistered")
\tend
\tif
\t\ttype(expectedRevision) ~= "number"
\t\tor expectedRevision ~= expectedRevision
\t\tor expectedRevision % 1 ~= 0
\t\tor expectedRevision < 0
\t\tor expectedRevision ~= entry.revision
\tthen
\t\treturn rejected("StaleRevision")
\tend
\tlocal healing = authoritativeHealing :: any
\tlocal serverTimestamp = if type(healing) == "table" then healing.serverTimestamp else nil
\tlocal resolution = OperativeHealingResolver.resolve(
\t\tcopySnapshot(entry.snapshot),
\t\tauthoritativeHealing,
\t\tserverTimestamp :: any
\t)
\tif
\t\ttype(resolution) ~= "table"
\t\tor resolution.didTransition ~= true
\t\tor type(healing) ~= "table"
\t\tor type(healing.healingEventId) ~= "string"
\t\tor resolution.healingEventId ~= healing.healingEventId
\t\tor type(resolution.healedAmount) ~= "number"
\t\tor resolution.healedAmount <= 0
\tthen
\t\tlocal reason = if type(resolution) == "table" and type(resolution.rejectionReasonId) == "string"
\t\t\tthen resolution.rejectionReasonId
\t\t\telse "ResolverRejected"
\t\treturn rejected(reason)
\tend
\treturn commitAcceptedTransitionInternal(player, expectedRevision, resolution, true)
end

function OperativeLifeService.isAlive''',
    "life healing commit API",
)
life_path.write_text(life, encoding="utf-8")


progression_path = Path("games/living-kingdoms/src/server/Systems/RunProgressionService.luau")
progression = progression_path.read_text(encoding="utf-8")
progression = replace_once(
    progression,
    "local lastUpgradeRequestTimestamps: { [Player]: number } = {}",
    '''local lastUpgradeRequestTimestamps: { [Player]: number } = {}
local processedFieldIntelRewardIds: { [string]: boolean } = {}
local fieldIntelRewardOrder: { string } = {}
local MAX_PROCESSED_FIELD_INTEL_REWARDS = 64''',
    "progression intel duplicate state",
)
progression = replace_once(
    progression,
    '''local function awardConfirmedEnemyDeath()
\tlocal amount = RunProgressionConfig.FieldXpPerConfirmedEnemyDeath
\tlocal resolution = RunProgressionResolver.applyAward(level, xp, amount)
\tif not resolution.didApply then
\t\treturn
\tend
\tlevel = resolution.levelAfter
\txp = resolution.xpAfter
\ttotalXp += amount
\tsquadKills += 1
\tlastGainAmount = amount
\tlastGainSequence += 1
\tlevelsGainedLastAward = resolution.levelsGained
\tif resolution.levelsGained > 0 then
\t\tunclaimedUpgradeChoices += resolution.levelsGained
\t\tgeneratePendingChoices()
\tend
\tpublishAll()
end''',
    '''local function applyFieldXpAward(amount: number, countAsKill: boolean): boolean
\tlocal resolution = RunProgressionResolver.applyAward(level, xp, amount)
\tif not resolution.didApply then
\t\treturn false
\tend
\tlevel = resolution.levelAfter
\txp = resolution.xpAfter
\ttotalXp += amount
\tif countAsKill then
\t\tsquadKills += 1
\tend
\tlastGainAmount = amount
\tlastGainSequence += 1
\tlevelsGainedLastAward = resolution.levelsGained
\tif resolution.levelsGained > 0 then
\t\tunclaimedUpgradeChoices += resolution.levelsGained
\t\tgeneratePendingChoices()
\tend
\tpublishAll()
\treturn true
end

local function awardConfirmedEnemyDeath()
\tapplyFieldXpAward(RunProgressionConfig.FieldXpPerConfirmedEnemyDeath, true)
end''',
    "progression shared XP award helper",
)
progression = replace_once(
    progression,
    '''function RunProgressionService.readSafeSnapshot(): SafeRunProgressionSnapshot
\treturn safeSnapshot()
end''',
    '''function RunProgressionService.awardFieldIntel(rewardId: string, amount: number): boolean
\tif
\t\tnot started
\t\tor type(rewardId) ~= "string"
\t\tor rewardId == ""
\t\tor #rewardId > 240
\t\tor processedFieldIntelRewardIds[rewardId]
\t\tor type(amount) ~= "number"
\t\tor amount ~= amount
\t\tor amount % 1 ~= 0
\t\tor amount <= 0
\t\tor amount > 100
\tthen
\t\treturn false
\tend
\tprocessedFieldIntelRewardIds[rewardId] = true
\ttable.insert(fieldIntelRewardOrder, rewardId)
\tif #fieldIntelRewardOrder > MAX_PROCESSED_FIELD_INTEL_REWARDS then
\t\tlocal expired = table.remove(fieldIntelRewardOrder, 1)
\t\tif expired ~= nil then
\t\t\tprocessedFieldIntelRewardIds[expired] = nil
\t\tend
\tend
\treturn applyFieldXpAward(amount, false)
end

function RunProgressionService.readSafeSnapshot(): SafeRunProgressionSnapshot
\treturn safeSnapshot()
end''',
    "progression field intel API",
)
progression = replace_once(
    progression,
    '''\ttable.clear(lastUpgradeRequestTimestamps)
\tsyncCombatModifierAttributes()''',
    '''\ttable.clear(lastUpgradeRequestTimestamps)
\ttable.clear(processedFieldIntelRewardIds)
\ttable.clear(fieldIntelRewardOrder)
\tsyncCombatModifierAttributes()''',
    "progression intel reset",
)
progression = replace_once(
    progression,
    '''\ttable.clear(lastUpgradeRequestTimestamps)
\taccumulatedSeconds = 0''',
    '''\ttable.clear(lastUpgradeRequestTimestamps)
\ttable.clear(processedFieldIntelRewardIds)
\ttable.clear(fieldIntelRewardOrder)
\taccumulatedSeconds = 0''',
    "progression intel stop reset",
)
progression_path.write_text(progression, encoding="utf-8")


supply_path = Path("games/living-kingdoms/src/server/Domain/AmmunitionSupplyResolver.luau")
supply = supply_path.read_text(encoding="utf-8")
supply = replace_once(
    supply,
    "and (candidate.sourceId == SourceIds.AuthoredCache or candidate.sourceId == SourceIds.EngineerResupply)",
    '''and (
\t\t\tcandidate.sourceId == SourceIds.AuthoredCache
\t\t\tor candidate.sourceId == SourceIds.EngineerResupply
\t\t\tor candidate.sourceId == SourceIds.EnemyDrop
\t\t)''',
    "ammunition enemy drop source validation",
)
supply_path.write_text(supply, encoding="utf-8")


bootstrap_path = Path("games/living-kingdoms/src/server/init.server.luau")
bootstrap = bootstrap_path.read_text(encoding="utf-8")
bootstrap = replace_once(
    bootstrap,
    "local EnemyValidationProbeService = require(script.Systems.EnemyValidationProbeService)\nlocal OperativeCombatRuntimeService",
    "local EnemyValidationProbeService = require(script.Systems.EnemyValidationProbeService)\nlocal LootDropService = require(script.Systems.LootDropService)\nlocal OperativeCombatRuntimeService",
    "bootstrap loot require",
)
bootstrap = replace_once(
    bootstrap,
    "AmmunitionCacheService.start()\nAmmunitionScarcityValidationProbeService.start()",
    "AmmunitionCacheService.start()\nLootDropService.start()\nAmmunitionScarcityValidationProbeService.start()",
    "bootstrap loot start",
)
bootstrap_path.write_text(bootstrap, encoding="utf-8")


life_test_path = Path("games/living-kingdoms/tests/OperativeLifeService.test.luau")
life_test = life_test_path.read_text(encoding="utf-8")
life_test = replace_once(
    life_test,
    "local HEALTH_RESOLVER_TOKEN = {}",
    "local HEALTH_RESOLVER_TOKEN = {}\nlocal HEALING_RESOLVER_TOKEN = {}",
    "life fixture healing token",
)
life_test = replace_once(
    life_test,
    '''\t\tif token == HEALTH_RESOLVER_TOKEN then
\t\t\treturn {
\t\t\t\tresolveDamage = function()
\t\t\t\t\terror("damage routing is covered by LK-0306 fixtures")
\t\t\t\tend,
\t\t\t}
\t\tend''',
    '''\t\tif token == HEALTH_RESOLVER_TOKEN then
\t\t\treturn {
\t\t\t\tresolveDamage = function()
\t\t\t\t\terror("damage routing is covered by LK-0306 fixtures")
\t\t\t\tend,
\t\t\t}
\t\tend
\t\tif token == HEALING_RESOLVER_TOKEN then
\t\t\treturn {
\t\t\t\tresolve = function()
\t\t\t\t\terror("healing routing is covered by HROI-0106 fixtures")
\t\t\t\tend,
\t\t\t}
\t\tend''',
    "life fixture healing dependency",
)
life_test = replace_once(
    life_test,
    "script = { Parent = { OperativeHealthResolver = HEALTH_RESOLVER_TOKEN } },",
    '''script = {
\t\tParent = {
\t\t\tOperativeHealingResolver = HEALING_RESOLVER_TOKEN,
\t\t\tOperativeHealthResolver = HEALTH_RESOLVER_TOKEN,
\t\t},
\t},''',
    "life fixture healing script tree",
)
life_test_path.write_text(life_test, encoding="utf-8")

print("Applied exact HROI-0106 loot integration patch")
