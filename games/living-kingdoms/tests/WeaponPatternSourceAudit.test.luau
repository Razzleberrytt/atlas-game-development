--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local FIREARM_TOKEN = {}
local firearmConfig = {
	BasicFirearm = { WeaponId = "weapon.basic", RangeStuds = 80 },
	LightMachineGun = { WeaponId = "weapon.lmg", RangeStuds = 92 },
	BreachShotgun = { WeaponId = "weapon.shotgun", RangeStuds = 38 },
	SniperRifle = { WeaponId = "weapon.sniper", RangeStuds = 165 },
	ServicePistol = { WeaponId = "weapon.pistol", RangeStuds = 66 },
	SubmachineGun = { WeaponId = "weapon.smg", RangeStuds = 54 },
	SelectableWeaponIds = {
		"weapon.lmg",
		"weapon.shotgun",
		"weapon.sniper",
		"weapon.pistol",
		"weapon.smg",
	},
}

local configSource = fs.readFile("games/living-kingdoms/src/shared/Config/WeaponPatternConfig.luau")
local config = luau.load(configSource, {
	debugName = "WeaponPatternConfig",
	environment = {
		script = { Parent = { FirearmConfig = FIREARM_TOKEN } },
		require = function(token: unknown)
			assert(token == FIREARM_TOKEN, "unexpected config module")
			return firearmConfig
		end,
	},
	injectGlobals = true,
})()

assertThat(config.BreachShotgun.ModeId == config.ModeIds.ConeCleave, "shotgun must own cone cleave")
assertThat(config.BreachShotgun.MaximumSecondaryTargets == 3, "shotgun cleave must remain capped at three")
assertThat(config.BreachShotgun.ConeHalfAngleDegrees <= 30, "shotgun cone must remain tightly bounded")
assertThat(
	config.BreachShotgun.MaximumSecondaryRangeStuds <= firearmConfig.BreachShotgun.RangeStuds,
	"shotgun secondary range cannot exceed weapon range"
)
assertThat(config.SniperRifle.ModeId == config.ModeIds.LinePierce, "sniper must own line pierce")
assertThat(config.SniperRifle.MaximumSecondaryTargets == 1, "sniper may pierce only one secondary")
assertThat(config.SniperRifle.PierceHalfWidthStuds <= 4, "sniper line width must remain narrow")
for _, weaponId in firearmConfig.SelectableWeaponIds do
	assertThat(config.get(weaponId) ~= nil, "every selectable weapon requires a pattern definition")
end

local resolver = fs.readFile("games/living-kingdoms/src/server/Systems/WeaponPatternResolver.luau")
local damage = fs.readFile("games/living-kingdoms/src/server/Systems/DamageResolver.luau")
local runtime = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau")
local contracts = fs.readFile("games/living-kingdoms/src/shared/Combat/CombatContracts.luau")
local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/WeaponPresentationController.luau")
local presenter = fs.readFile("games/living-kingdoms/src/client/Presentation/WeaponShotEffectPresenter.luau")

for _, token in {
	"MaximumSecondaryTargets",
	"hasLineOfSight",
	"ConeCleave",
	"LinePierce",
	"table.sort",
	"table.freeze(impacts)",
} do
	assertThat(contains(resolver, token), "pattern resolver missing bounded deterministic token: " .. token)
end
for _, prohibited in {
	"Workspace",
	"Raycast(",
	"FireServer",
	"OnServerEvent",
	"DamageResolver",
	"commitHealthState",
	"loadedRounds",
	"math.random",
} do
	assertThat(not contains(resolver, prohibited), "pure pattern resolver must not contain " .. prohibited)
end

assertThat(contains(damage, "function DamageResolver.resolvePattern"), "damage resolver must expose a pattern-only path")
assertThat(contains(damage, "patternMultiplier > 1"), "pattern damage cannot exceed primary scale")
assertThat(
	contains(damage, "local minimumDamage = if patternMultiplier == nil then configured else 1"),
	"primary override floor must remain intact"
)
assertThat(contains(runtime, "WeaponPatternResolver.resolve("), "runtime must resolve patterns server-side")
assertThat(contains(runtime, "buildPatternTargetFacts(playerState)"), "runtime must reuse bounded sight facts")
assertThat(contains(runtime, "DamageResolver.resolvePattern("), "secondary damage must use dedicated resolver path")
assertThat(contains(runtime, '"%s:pattern:%d:%s"'), "secondary impacts require derived unique shot identities")
assertThat(contains(runtime, "didCommit and damageResolution.didApplyDamage"), "only committed secondary damage may disclose")
assertThat(contains(runtime, "secondaryImpacts = if #secondaryImpacts > 0"), "shot disclosure must omit empty secondary lists")

assertThat(contains(contracts, "export type SecondaryShotImpactPresentation"), "shared contract must type secondary impacts")
assertThat(
	contains(contracts, "secondaryImpacts: { SecondaryShotImpactPresentation }?"),
	"secondary disclosure must remain optional"
)
assertThat(contains(controller, "#value > 3"), "client must reject unbounded secondary impact lists")
assertThat(contains(controller, "readSecondaryImpactPositions"), "client must validate secondary disclosures")
assertThat(contains(presenter, "if index > 3 then"), "effect presenter must cap secondary paths")

local _, flashCalls = string.gsub(presenter, "presentMuzzleFlash%(rig, profile%)", "")
local _, casingCalls = string.gsub(presenter, "spawnCasing%(rig, shotId, profile%)", "")
assertThat(flashCalls == 1, "one accepted trigger must create exactly one muzzle flash")
assertThat(casingCalls == 1, "one accepted trigger must eject exactly one casing or shell")

for _, prohibited in {
	"FireServer",
	"InvokeServer",
	"Humanoid:TakeDamage",
	".Touched:Connect",
} do
	assertThat(not contains(controller .. presenter, prohibited), "pattern presentation must remain client-local: " .. prohibited)
end

print("WeaponPatternSourceAudit: bounded server patterns, reduced damage path, revision commits, and one-trigger presentation passed")
