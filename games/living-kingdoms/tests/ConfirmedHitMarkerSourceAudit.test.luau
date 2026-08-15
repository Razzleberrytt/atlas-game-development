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

local function count(source: string, token: string): number
	local result = 0
	local cursor = 1
	while true do
		local index = string.find(source, token, cursor, true)
		if index == nil then
			return result
		end
		result += 1
		cursor = index + #token
	end
end

local controllerPath = "games/living-kingdoms/src/client/Controllers/CombatFeedback/ConfirmedHitMarkerController.luau"
local configPath = "games/living-kingdoms/src/shared/Config/ConfirmedHitMarkerConfig.luau"
local bootstrapPath = "games/living-kingdoms/src/client/init.client.luau"

local controllerSource = fs.readFile(controllerPath)
local configSource = fs.readFile(configPath)
local bootstrapSource = fs.readFile(bootstrapPath)

for _, required in
	{
		"PresentationMessageKindIds.ShotFired",
		"isLocalOperativeEntityId(payload.operativeEntityId)",
		"payload.didApplyDamage ~= true",
		'typeof(payload.impactWorldPosition) ~= "Vector3"',
		"camera:WorldToViewportPoint(worldPosition)",
		"not rememberShot(payload.shotId)",
		"#ARM_DEFINITIONS == 4",
		"math.min(99, confirmedChain + 1)",
		"WeaponPatternConfig.get(payload.weaponId)",
		"readSecondaryImpactCount(payload.secondaryImpacts",
		"patternDefinition.MaximumSecondaryTargets",
		"impact.targetEntityId",
		"impact.impactWorldPosition",
		"impact.damageAmount",
		"patternHitCount = 1 + secondaryImpactCount",
		"ConfirmedHitMarkerConfig.getPatternPresentation(patternModeId)",
	}
do
	assertThat(contains(controllerSource, required), "confirmed marker is missing " .. required)
end
assertThat(count(controllerSource, "RenderStepped:Connect") == 1, "marker must own exactly one frame connection")
assertThat(count(controllerSource, "OnClientEvent:Connect") == 1, "marker must own exactly one disclosure connection")
for _, forbidden in
	{
		":FireServer(",
		"RemoteFunction",
		"SetNetworkOwner",
		"TakeDamage",
		"DamageResolver",
		"EnemyDirectorService",
		"task.delay",
		"task.spawn",
		"RunProgressionService",
		"EnemyLootService",
	}
do
	assertThat(not contains(controllerSource, forbidden), "confirmed marker must not own gameplay: " .. forbidden)
end

local config = luau.load(configSource, {
	debugName = "ConfirmedHitMarkerConfig",
	injectGlobals = true,
})()
assertThat(type(config) == "table", "confirmed hit marker config did not load")
assertThat(
	config.MarkerDurationSeconds >= 0.18 and config.MarkerDurationSeconds <= 0.6,
	"marker duration escaped bounds"
)
assertThat(config.MaximumRadiusPixels + config.PatternRadiusBonusPixels <= 36, "pattern marker radius escaped budget")
assertThat(config.MaximumRememberedShotIds <= 256, "marker deduplication memory escaped bound")
assertThat(config.BrutalChainThreshold > config.HotChainThreshold, "marker escalation thresholds are not monotonic")
assertThat(config.MaximumSecondaryImpacts == 3, "pattern secondary cap drifted")
assertThat(config.getPatternPresentation("ConeCleave").Title == "BREACH CLEAVE", "shotgun punctuation title drifted")
assertThat(config.getPatternPresentation("LinePierce").Title == "LINE PIERCE", "sniper punctuation title drifted")
assertThat(config.getPatternPresentation("SingleTarget") == nil, "ordinary hits must not receive pattern punctuation")

assertThat(
	contains(bootstrapSource, "require(script.Controllers.ConfirmedHitMarkerController)"),
	"client bootstrap does not require confirmed hit marker"
)
assertThat(
	contains(bootstrapSource, "ConfirmedHitMarkerController.start()"),
	"client bootstrap does not start confirmed hit marker"
)

print(
	"ConfirmedHitMarkerSourceAudit: authoritative pattern counts, shooter scope, fixed presentation, and authority bounds passed"
)
