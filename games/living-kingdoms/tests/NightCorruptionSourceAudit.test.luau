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
local controller = fs.readFile("games/living-kingdoms/src/server/LightingController.server.luau")
local environmentProfile = fs.readFile("games/living-kingdoms/src/server/Systems/EnvironmentProfileService.luau")
local horde = fs.readFile("games/living-kingdoms/src/server/Systems/HordeExperienceService.luau")
local hud = fs.readFile("games/living-kingdoms/src/client/Controllers/HordeHUDController.luau")
local progression = fs.readFile("games/living-kingdoms/src/server/Systems/RunProgressionService.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")

check(config.DaylightSeconds < config.CycleSeconds, "each corruption cycle requires preparation and danger phases")
check(config.MaximumTier == 6, "night requires six readable corruption milestones")
check(string.find(service, 'network:SetAttribute("NightCorruptionTier"', 1, true), "server must publish corruption")
check(not string.find(service, "EnvironmentProfileService", 1, true), "corruption state must not own global visuals")
check(string.find(controller, "EnvironmentProfileService.applyCycle", 1, true), "lighting controller must own visual cycle")
check(string.find(controller, "task.wait", 1, true), "lighting controller must use bounded scheduled updates")
check(string.find(environmentProfile, "Lighting.ClockTime", 1, true), "cycle must visibly change time")
check(string.find(environmentProfile, "Lighting.FogEnd", 1, true), "night must visibly close in")
check(string.find(horde, "NightCorruptionThreatBonus", 1, true), "corruption must increase ambient pressure")
check(string.find(horde, "NightCorruptionEnemySpeedMultiplier", 1, true), "corruption must strengthen enemies")
check(string.find(horde, '"night-corruption"', 1, true), "ambient spawns must not identify as waves")
check(string.find(hud, "CORRUPTION TIER", 1, true), "HUD must explain why danger is worsening")
check(string.find(progression, "NightCorruptionXpMultiplier", 1, true), "deeper night must pay more XP")
check(string.find(bootstrap, "NightCorruptionService.start()", 1, true), "night corruption must bootstrap")

print("NightCorruptionSourceAudit: state/visual ownership, pressure, strength, rewards, and HUD passed")
