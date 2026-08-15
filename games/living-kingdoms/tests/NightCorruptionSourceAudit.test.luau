--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(value: unknown, message: string)
	if not value then
		error(message, 2)
	end
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/NightCorruptionConfig.luau"), {
	debugName = "NightCorruptionConfig",
	injectGlobals = true,
})()
local service = fs.readFile("games/living-kingdoms/src/server/Systems/NightCorruptionService.luau")
local lightingController = fs.readFile("games/living-kingdoms/src/server/LightingController.server.luau")
local horde = fs.readFile("games/living-kingdoms/src/server/Systems/HordeExperienceService.luau")
local hud = fs.readFile("games/living-kingdoms/src/client/Controllers/HordeHUDController.luau")
local progression = fs.readFile("games/living-kingdoms/src/server/Systems/RunProgressionService.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")

check(config.DaylightSeconds < config.CycleSeconds, "each cycle requires preparation and danger phases")
check(config.MaximumTier == 6, "night requires six readable corruption milestones")
check(string.find(service, 'network:SetAttribute("NightCorruptionTier"', 1, true), "server must publish corruption")
check(not string.find(service, "Lighting.ClockTime", 1, true), "corruption service must not own global time")
check(not string.find(service, "Lighting.FogEnd", 1, true), "corruption service must not own global fog")
check(string.find(lightingController, "Lighting.ClockTime", 1, true), "visual controller must visibly change time")
check(string.find(lightingController, "Lighting.FogEnd", 1, true), "visual controller must visibly change depth")
check(string.find(lightingController, "Lighting.FogColor", 1, true), "visual controller must own fog color")
check(string.find(lightingController, "Lighting.ColorShift_Top", 1, true), "visual controller must grade upper light")
check(string.find(lightingController, "Lighting.ColorShift_Bottom", 1, true), "visual controller must grade lower light")
check(string.find(lightingController, "Lighting.OutdoorAmbient", 1, true), "visual controller must own outdoor ambient")
check(string.find(lightingController, "EnvironmentVisualConfig", 1, true), "visual controller must use shared configuration")
check(string.find(horde, "NightCorruptionThreatBonus", 1, true), "corruption must increase ambient pressure")
check(string.find(horde, "NightCorruptionEnemySpeedMultiplier", 1, true), "corruption must strengthen enemies")
check(string.find(horde, '"night-corruption"', 1, true), "ambient spawns must not identify as waves")
check(string.find(hud, "CORRUPTION TIER", 1, true), "HUD must explain why danger is worsening")
check(string.find(progression, "NightCorruptionXpMultiplier", 1, true), "deeper night must pay more XP")
check(string.find(bootstrap, "NightCorruptionService.start()", 1, true), "night corruption must bootstrap")

print("NightCorruptionSourceAudit: gameplay corruption and centralized visual ownership passed")
