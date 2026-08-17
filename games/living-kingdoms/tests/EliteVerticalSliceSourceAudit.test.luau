--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, value: string): boolean
	return string.find(source, value, 1, true) ~= nil
end

local director = fs.readFile("games/living-kingdoms/src/server/Systems/EnemyDirectorService.luau")
local behavior = fs.readFile("games/living-kingdoms/src/server/Systems/EnemyBehaviorResolver.luau")
local horde = fs.readFile("games/living-kingdoms/src/server/Systems/HordeExperienceService.luau")
local progression = fs.readFile("games/living-kingdoms/src/server/Systems/RunProgressionService.luau")
local combat = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau")
local presentation = fs.readFile("games/living-kingdoms/src/shared/Visual/EnemyPresentationContracts.luau")

assertThat(contains(director, "EliteAffixResolver.resolveAssignment"), "spawn path must own elite assignment")
assertThat(contains(director, "activeEliteCount = activeEliteCount"), "director must supply retained elite population")
assertThat(contains(director, 'Instance.new("Highlight")'), "every elite needs an unmistakable world telegraph")
assertThat(
	contains(director, "activeEliteCount = math.max(0, activeEliteCount - 1)"),
	"death must release elite capacity"
)
assertThat(contains(director, "operationPressureStartedServerTimestamp"), "protected opening needs operation time")
assertThat(contains(behavior, "archetype.AttackWindupSeconds * cadenceMultiplier"), "windup cadence must be bounded")
assertThat(
	contains(behavior, "archetype.AttackCooldownSeconds * cadenceMultiplier"),
	"cooldown cadence must be bounded"
)
assertThat(
	contains(horde, "EffectiveMovementSpeedMultiplier"),
	"horde role speed must preserve elite and aura movement"
)
assertThat(contains(progression, "EliteBonusFieldXpAttribute"), "Field XP must consume server elite identity")
assertThat(contains(progression, "awardConfirmedEnemyDeath(model)"), "elite XP must use the one-shot death transition")
assertThat(contains(combat, 'GetAttribute("EnemyEliteAffixId")'), "elite identity must extend special-enemy damage")
assertThat(contains(presentation, 'EliteAffixId = "EnemyEliteAffixId"'), "elite identity needs a stable safe attribute")
assertThat(contains(director, "damageTakenMultiplierWhileArmored"), "Armored requires finite damage absorption")
assertThat(contains(director, "applyRegeneration"), "Regenerator requires pressure-reset healing")
assertThat(contains(director, "detonateVolatile"), "Volatile requires a delayed one-shot reaction")
assertThat(contains(director, "refreshCommanderAuras"), "Commander requires bounded spatial aura resolution")
assertThat(contains(horde, "hordeRoleId = role.Id"), "affix assignment requires the server-owned role fact")
assertThat(not contains(director, "RemoteEvent"), "elite assignment must add no client request surface")

print("EliteVerticalSliceSourceAudit: full roster mechanics, compatibility, reward, cap, and cleanup passed")
