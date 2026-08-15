--!strict

local fs = require("@lune/fs")

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local service = fs.readFile("games/living-kingdoms/src/server/Systems/CharacterProgressionService.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/server/character-progression.server.luau")
local config = fs.readFile("games/living-kingdoms/src/shared/Config/CharacterProgressionConfig.luau")

assert(contains(service, "function Service.awardXP"), "server progression must expose one XP award API")
assert(contains(service, "Resolver.awardXP"), "server service must delegate XP math to the pure resolver")
assert(contains(service, "function Service.hydratePlayer"), "future persistence must have a canonical hydration seam")
assert(contains(service, "function Service.exportPlayerState"), "future persistence must have a minimal export seam")
assert(contains(service, "function Service.connectLevelUp"), "level-up consumers need an extension hook")
assert(
	contains(service, "function Service.connectProgressionChanged"),
	"progression consumers need a general extension hook"
)
assert(contains(service, "Players.PlayerAdded:Connect"), "progression state must initialize server-side")
assert(contains(service, "Players.PlayerRemoving:Connect"), "departed player state must be released")
assert(
	contains(service, 'SetAttribute("CharacterLevel"'),
	"authoritative level must be available for presentation consumers"
)
assert(
	contains(service, 'SetAttribute("CharacterTotalXP"'),
	"authoritative XP must be available for presentation consumers"
)
assert(contains(service, "validSourceId(sourceId)"), "XP awards must require configured server attribution")

for _, sourceName in { "EnemyKill", "Assist", "Quest", "DungeonCompletion", "Event", "Exploration" } do
	assert(contains(config, sourceName .. " ="), "missing future XP attribution source " .. sourceName)
end

for _, prohibited in { "OnServerEvent", "FireServer", "RemoteEvent", "RemoteFunction" } do
	assert(
		not contains(service, prohibited),
		"progression service must not expose client mutation authority: " .. prohibited
	)
	assert(
		not contains(bootstrap, prohibited),
		"progression bootstrap must not mount client mutation authority: " .. prohibited
	)
end

assert(contains(bootstrap, "CharacterProgressionService.start()"), "bootstrap must mount the canonical server owner")

print("CharacterProgressionServiceSourceAudit: server authority, attribution, lifecycle, and extension seams passed")
