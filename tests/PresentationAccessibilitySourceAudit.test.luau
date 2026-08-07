--!strict

-- HROI-0104 source audit: the camera-shake and blood comfort settings remain
-- client-local presentation preference. The state store and panel own no
-- remote, no persistence, and no gameplay read; consumers may only attenuate
-- authored cosmetic intensity, never amplify it or change combat truth.
local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local state = fs.readFile("games/living-kingdoms/src/client/Presentation/PresentationAccessibilityState.luau")
local panel = fs.readFile("games/living-kingdoms/src/client/Controllers/PresentationSettingsController.luau")
local effects = fs.readFile("games/living-kingdoms/src/client/Controllers/HordeEffectsController.luau")
local impact = fs.readFile("games/living-kingdoms/src/client/Controllers/EnemyImpactPresentationController.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")

for _, token in
	{
		"PresentationAccessibilityConfig.DefaultLevelId",
		"function State.getScale",
		"function State.cycle",
		"return table.freeze(State)",
	}
do
	assertThat(contains(state, token), "accessibility state store is missing " .. token)
end

for _, forbidden in
	{
		"RemoteEvent",
		"RemoteFunction",
		"FireServer",
		"InvokeServer",
		"OnClientEvent",
		"DataStore",
		"RunService",
		"task.delay",
		"task.spawn",
		"while true",
	}
do
	assertThat(not contains(state, forbidden), "the comfort store must stay client-local and inert: " .. forbidden)
	assertThat(not contains(panel, forbidden), "the settings panel must stay client-local and inert: " .. forbidden)
end

for _, token in
	{
		"PRESENTATION COMFORT",
		"PresentationAccessibilityState.cycle(settingId)",
		"button.Activated:Connect",
		"toggleButton.Activated:Connect",
		"ResetOnSpawn = false",
		"PresentationAccessibilityState.onChanged",
		"connection:Disconnect()",
		"screenGui:Destroy()",
	}
do
	assertThat(contains(panel, token), "the settings panel is missing " .. token)
end

assertThat(
	contains(panel, "%s: %s"),
	"setting buttons must carry the full setting name and level as text, not color alone"
)

for _, token in
	{
		"PresentationAccessibilityState.getScale(PresentationAccessibilityConfig.SettingIds.CameraShake)",
		"if scaled <= 0 then",
		"if bloodScale <= 0 then",
	}
do
	assertThat(contains(effects, token), "horde effects must honor the comfort scales: " .. token)
end
assertThat(
	contains(effects, "PresentationAccessibilityConfig.SettingIds.Blood"),
	"death pools must honor the blood comfort scale"
)

for _, token in
	{
		"local function scaledBloodParticleCount",
		"scaledBloodParticleCount(CombatImpactPresentationConfig.HitParticleCount)",
		"scaledBloodParticleCount(CombatImpactPresentationConfig.KillParticleCount)",
	}
do
	assertThat(contains(impact, token), "impact bursts must honor the blood comfort scale: " .. token)
end
assertThat(
	contains(impact, "record.highlight.Enabled = true"),
	"hit and kill flash readability must survive every blood level"
)

assertThat(
	contains(bootstrap, "require(script.Controllers.PresentationSettingsController)"),
	"the bootstrap must load the settings panel"
)
assertThat(contains(bootstrap, "PresentationSettingsController.start()"), "the bootstrap must start the settings panel")

print(
	"PresentationAccessibilitySourceAudit: client-local comfort settings, attenuation-only scales, and readable text controls passed"
)
