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

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/CriticalConditionConfig.luau"), {
	debugName = "CriticalConditionConfig",
	injectGlobals = true,
})()
local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/CriticalConditionController.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")

assertThat(table.isfrozen(config), "critical condition configuration must be immutable")
assertThat(config.CriticalHealthFraction == 0.25, "critical warning threshold drifted")
assertThat(config.MortalHealthFraction == 0.1, "mortal warning threshold drifted")
assertThat(config.MortalHealthFraction < config.CriticalHealthFraction, "mortal threshold must be stricter")
assertThat(config.EdgeThicknessPixels <= 160, "critical edges must not consume the combat view")
assertThat(config.PulseTransparencyAmplitude <= 0.25, "critical pulse amplitude must remain bounded")

for _, required in {
	'local CriticalConditionConfig = require(ReplicatedStorage.Shared.Config.CriticalConditionConfig)',
	'"LK_P3_CurrentHealth"',
	'"LK_P3_MaximumHealth"',
	'"LK_P3_LifeState"',
	'lifeState ~= "Alive"',
	"CriticalConditionConfig.CriticalHealthFraction",
	"CriticalConditionConfig.MortalHealthFraction",
	"Workspace:GetServerTimeNow()",
	'Instance.new("UIGradient")',
	'"CRITICAL CONDITION  //  %d%% HEALTH"',
	'"MORTAL CONDITION  //  %d%% HEALTH"',
	"RunService.RenderStepped:Connect(updateFrame)",
	"table.clear(edgeFrames)",
} do
	assertThat(contains(controller, required), "critical condition presentation is missing " .. required)
end

assertThat(count(controller, "createEdge(gui,") == 4, "critical presentation requires exactly four bounded screen edges")
assertThat(count(controller, ":Connect(") == 1, "critical presentation requires exactly one render connection")
assertThat(contains(bootstrap, "CriticalConditionController.start()"), "client bootstrap must start critical urgency")

for _, prohibited in {
	"RemoteEvent",
	"RemoteFunction",
	"FireServer",
	"InvokeServer",
	"applyAuthoritativeDamage",
	"commitAcceptedTransition",
	"currentHealth = currentHealth -",
	"Humanoid.Health",
	"TakeDamage",
	"task.delay",
	"task.spawn",
	"task.defer",
} do
	assertThat(not contains(controller, prohibited), "critical presentation must not own gameplay through " .. prohibited)
end

print("CriticalConditionPresentation: bounded server-disclosed critical and mortal urgency passed")
