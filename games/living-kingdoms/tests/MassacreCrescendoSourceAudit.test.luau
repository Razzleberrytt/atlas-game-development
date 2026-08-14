--!strict

local fs = require("@lune/fs")

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local function count(source: string, token: string): number
	local occurrences = 0
	local startIndex = 1
	while true do
		local found = string.find(source, token, startIndex, true)
		if found == nil then
			return occurrences
		end
		occurrences += 1
		startIndex = found + #token
	end
end

local server = fs.readFile("games/living-kingdoms/src/server/Systems/HordeExperienceService.luau")
local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/MassacreCrescendoController.luau")
local config = fs.readFile("games/living-kingdoms/src/shared/Config/MassacreCrescendoConfig.luau")
local hud = fs.readFile("games/living-kingdoms/src/client/Controllers/HordeHUDController.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")

assert(contains(server, "streakExpiresServerTimestamp"), "server must disclose the exact authoritative streak expiry")
-- The disclosed expiry must be the operative's own authoritative window, which
-- Grave Momentum (RPG-0108) may extend beyond the configured base.
assert(contains(server, "state.lastKillServerTimestamp + streakWindowSeconds(player)"))
assert(
	contains(server, "HordeConfig.Streak.KillStreakWindowSeconds + RelicModifierService.read(player)"),
	"the kill-chain window must stay derived from the configured base plus the bounded relic modifier"
)
assert(contains(server, "state.streak >= 2"), "expiry disclosure must be absent below the visible streak floor")
assert(not contains(server, "MassacreCrescendoConfig"), "server must not depend on client presentation config")

assert(contains(controller, "streakExpiresServerTimestamp"))
assert(contains(controller, "HordeStateEarlyListener.subscribe(onState)"))
assert(not contains(controller, 'WaitForChild("HordeNetwork"'), "crescendo must not own HordeNetwork transport")
assert(contains(controller, "tierForStreak"))
assert(contains(controller, "StingerMinimumIntervalSeconds"))
assert(contains(controller, "GroupTransparency"))
assert(contains(controller, "Workspace:GetServerTimeNow()"))
assert(count(controller, "OnClientEvent:Connect") == 0, "crescendo must own zero physical RemoteEvent listeners")
assert(
	count(controller, "HordeStateEarlyListener.subscribe(onState)") == 1,
	"crescendo must use one application-bridge subscription"
)
assert(count(controller, "RenderStepped:Connect") == 1, "crescendo must use one frame connection")
assert(count(controller, 'Instance.new("Sound")') == 1, "crescendo must construct one fixed stinger")
assert(count(controller, 'Instance.new("ScreenGui")') == 1, "crescendo must construct one fixed screen surface")

for _, prohibited in
	{
		"FireServer",
		"InvokeServer",
		"OnServerEvent",
		"RemoteFunction",
		"DamageResolver",
		"applyAuthoritativeDamage",
		"commitHealthState",
		"award",
		"grant",
		"spawnEnemy",
		"Raycast",
		"TweenService",
		"task.spawn",
		"task.delay",
		"SetAttribute",
		"DataStore",
	}
do
	assert(not contains(controller, prohibited), "crescendo must remain presentation-only: " .. prohibited)
end

assert(contains(config, "KILL CHAIN"))
assert(contains(config, "SLAUGHTER"))
assert(contains(config, "MASSACRE"))
assert(contains(config, "ANNIHILATION"))
assert(contains(config, "APOCALYPSE"))
assert(contains(config, "FirearmAudioConfig.Fire.SoundId"), "stinger must reuse a verified asset")
assert(contains(config, "No tier grants XP, loot, health"), "non-rewarding boundary must be explicit")

assert(not contains(hud, "MASSACRE x%d"), "legacy static streak label must be removed")
assert(not contains(hud, "streakLabel"), "the unified HUD must not retain a duplicate streak owner")
assert(not contains(bootstrap, "MassacreCrescendoController"), "kill-chain presentation must remain disabled")
assert(count(bootstrap, "MassacreCrescendoController.start()") == 0)

print("MassacreCrescendoSourceAudit: dormant bridge-only controller retained and kill-chain presentation disabled")
