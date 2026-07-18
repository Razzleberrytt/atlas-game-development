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

local controllerPath = "games/living-kingdoms/src/client/Controllers/ConfirmedHitMarkerController.luau"
local configPath = "games/living-kingdoms/src/shared/Config/ConfirmedHitMarkerConfig.luau"
local bootstrapPath = "games/living-kingdoms/src/client/init.client.luau"

local controllerSource = fs.readFile(controllerPath)
local configSource = fs.readFile(configPath)
local bootstrapSource = fs.readFile(bootstrapPath)

assertThat(
	contains(controllerSource, "PresentationMessageKindIds.ShotFired"),
	"marker must consume accepted ShotFired disclosure"
)
assertThat(
	contains(controllerSource, "isLocalOperativeEntityId(payload.operativeEntityId)"),
	"marker must remain shooter-specific"
)
assertThat(
	contains(controllerSource, "payload.didApplyDamage ~= true"),
	"marker must reject misses and rejected damage"
)
assertThat(
	contains(controllerSource, 'typeof(payload.impactWorldPosition) ~= "Vector3"'),
	"marker must require authoritative impact position"
)
assertThat(
	contains(controllerSource, "camera:WorldToViewportPoint(worldPosition)"),
	"marker must stay anchored to the disclosed world impact"
)
assertThat(contains(controllerSource, "not rememberShot(payload.shotId)"), "marker must deduplicate accepted ShotIds")
assertThat(contains(controllerSource, "#ARM_DEFINITIONS == 4"), "marker geometry must remain exactly four fixed arms")
assertThat(
	contains(controllerSource, "math.min(99, confirmedChain + 1)"),
	"confirmed hit chain display must remain bounded"
)
assertThat(count(controllerSource, "RenderStepped:Connect") == 1, "marker must own exactly one frame connection")
assertThat(count(controllerSource, "OnClientEvent:Connect") == 1, "marker must own exactly one disclosure connection")
assertThat(not contains(controllerSource, ":FireServer("), "marker must not send gameplay intent")
assertThat(not contains(controllerSource, "RemoteFunction"), "marker must not add a request surface")
assertThat(not contains(controllerSource, "SetNetworkOwner"), "marker must not change network ownership")
assertThat(not contains(controllerSource, "TakeDamage"), "marker must not apply damage")
assertThat(not contains(controllerSource, "DamageResolver"), "marker must not resolve damage")
assertThat(
	not contains(controllerSource, "EnemyDirectorService"),
	"marker must not mutate or query authoritative enemy services"
)
assertThat(not contains(controllerSource, "task.delay"), "marker must not schedule one task per shot")
assertThat(not contains(controllerSource, "task.spawn"), "marker must not create per-shot task loops")

local config = luau.load(configSource, {
	debugName = "ConfirmedHitMarkerConfig",
	injectGlobals = true,
})()
assertThat(type(config) == "table", "confirmed hit marker config did not load")
assertThat(
	config.MarkerDurationSeconds >= 0.18 and config.MarkerDurationSeconds <= 0.6,
	"marker duration escaped bounds"
)
assertThat(config.MaximumRadiusPixels <= 36, "marker radius escaped screen-space budget")
assertThat(config.MaximumRememberedShotIds <= 256, "marker deduplication memory escaped bound")
assertThat(config.BrutalChainThreshold > config.HotChainThreshold, "marker escalation thresholds are not monotonic")

assertThat(
	contains(
		bootstrapSource,
		"local ConfirmedHitMarkerController = require(script.Controllers.ConfirmedHitMarkerController)"
	),
	"client bootstrap does not require confirmed hit marker"
)
assertThat(
	contains(bootstrapSource, "ConfirmedHitMarkerController.start()"),
	"client bootstrap does not start confirmed hit marker"
)

print(
	"ConfirmedHitMarkerSourceAudit: server-confirmed inputs, shooter scope, fixed presentation, and authority bounds passed"
)
