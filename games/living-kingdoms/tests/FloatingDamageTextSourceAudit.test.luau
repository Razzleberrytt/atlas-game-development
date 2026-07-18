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

local controllerPath = "games/living-kingdoms/src/client/Controllers/FloatingDamageTextController.luau"
local configPath = "games/living-kingdoms/src/shared/Config/FloatingDamageTextConfig.luau"
local bootstrapPath = "games/living-kingdoms/src/client/init.client.luau"
local serverPath = "games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau"
local contractsPath = "games/living-kingdoms/src/shared/Combat/CombatContracts.luau"

local controllerSource = fs.readFile(controllerPath)
local configSource = fs.readFile(configPath)
local bootstrapSource = fs.readFile(bootstrapPath)
local serverSource = fs.readFile(serverPath)
local contractsSource = fs.readFile(contractsPath)

assertThat(contains(controllerSource, "PresentationMessageKindIds.ShotFired"), "damage text must consume accepted ShotFired disclosure")
assertThat(contains(controllerSource, "isLocalOperativeEntityId(payload.operativeEntityId)"), "damage text must remain shooter-specific")
assertThat(contains(controllerSource, "payload.didApplyDamage ~= true"), "damage text must reject misses and rejected damage")
assertThat(contains(controllerSource, "typeof(payload.impactWorldPosition) ~= \"Vector3\""), "damage text must require authoritative impact position")
assertThat(contains(controllerSource, "not isWholePositiveDamage(payload.damageAmount)"), "damage text must validate the server-authored integer")
assertThat(contains(controllerSource, "camera:WorldToViewportPoint(entry.worldPosition)"), "damage text must stay anchored to the disclosed world impact")
assertThat(contains(controllerSource, "not rememberShot(payload.shotId)"), "damage text must deduplicate accepted ShotIds")
assertThat(
	contains(controllerSource, "for index = 1, FloatingDamageTextConfig.MaximumActiveEntries do"),
	"damage text must preallocate a fixed label pool"
)
assertThat(count(controllerSource, "Instance.new(\"TextLabel\")") == 1, "damage text must define one pooled label construction site")
assertThat(count(controllerSource, "RenderStepped:Connect") == 1, "damage text must own exactly one frame connection")
assertThat(count(controllerSource, "OnClientEvent:Connect") == 1, "damage text must own exactly one disclosure connection")
assertThat(not contains(controllerSource, ":FireServer("), "damage text must not send gameplay intent")
assertThat(not contains(controllerSource, "RemoteFunction"), "damage text must not add a request surface")
assertThat(not contains(controllerSource, "TakeDamage"), "damage text must not apply damage")
assertThat(not contains(controllerSource, "DamageResolver"), "damage text must not resolve damage client-side")
assertThat(not contains(controllerSource, "EnemyDirectorService"), "damage text must not query authoritative enemy state")
assertThat(not contains(controllerSource, "task.delay"), "damage text must not schedule one task per hit")
assertThat(not contains(controllerSource, "task.spawn"), "damage text must not create per-hit task loops")

assertThat(
	contains(serverSource, "damageResolution.damageEvent.damageAmount"),
	"ShotFired must disclose the exact authoritative damage event amount"
)
assertThat(
	contains(serverSource, "damageAmount = damageAmount"),
	"ShotFired payload must carry the authoritative applied amount"
)
assertThat(contains(contractsSource, "damageAmount: number?"), "shared ShotFired contract must declare optional authoritative damage")

local config = luau.load(configSource, {
	debugName = "FloatingDamageTextConfig",
	injectGlobals = true,
})()
assertThat(type(config) == "table", "floating damage text config did not load")
assertThat(config.DurationSeconds >= 0.45 and config.DurationSeconds <= 1.25, "damage text duration escaped bounds")
assertThat(config.MaximumActiveEntries <= 32, "damage text pool escaped bound")
assertThat(config.MaximumRememberedShotIds <= 256, "damage text deduplication memory escaped bound")
assertThat(config.BrutalDamageMultiplier > config.HotDamageMultiplier, "damage color thresholds are not monotonic")

assertThat(
	contains(bootstrapSource, "local FloatingDamageTextController = require(script.Controllers.FloatingDamageTextController)"),
	"client bootstrap does not require floating damage text"
)
assertThat(contains(bootstrapSource, "FloatingDamageTextController.start()"), "client bootstrap does not start floating damage text")

print("FloatingDamageTextSourceAudit: authoritative amount, shooter scope, pooled presentation, and authority bounds passed")
