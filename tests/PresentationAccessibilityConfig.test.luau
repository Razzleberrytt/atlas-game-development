--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local source = fs.readFile("games/living-kingdoms/src/shared/Config/PresentationAccessibilityConfig.luau")
local config = luau.load(source, {
	debugName = "PresentationAccessibilityConfig",
	injectGlobals = true,
})()

assert(config.Version == "HROI-0104-access-v1", "accessibility config version drifted")
assert(table.isfrozen(config), "accessibility config must be immutable")
assert(config.DefaultLevelId == config.LevelIds.Full, "players must start at the authored full intensity")

local levelCount = 0
for levelId, displayName in config.LevelDisplayNames do
	levelCount += 1
	assert(type(displayName) == "string" and #displayName > 0, levelId .. " requires readable level text")
end
assert(levelCount == 3, "exactly full, reduced, and off levels are authored")
assert(#config.LevelOrder == levelCount, "the cycle order must cover every level")

for _, settingId in { config.SettingIds.CameraShake, config.SettingIds.Blood } do
	local setting = config.Settings[settingId]
	assert(setting ~= nil, settingId .. " setting is missing")
	assert(#setting.DisplayName > 0, settingId .. " requires a readable name")
	assert(setting.Scales[config.LevelIds.Full] == 1, settingId .. " full must be exactly the authored intensity")
	assert(setting.Scales[config.LevelIds.Off] == 0, settingId .. " off must fully suppress the effect")
	local reduced = setting.Scales[config.LevelIds.Reduced]
	assert(reduced > 0 and reduced < 1, settingId .. " reduced must sit strictly between off and full")
	for _, levelId in config.LevelOrder do
		local scale = setting.Scales[levelId]
		assert(
			type(scale) == "number" and scale >= 0 and scale <= 1,
			settingId .. " comfort scales may only attenuate, never amplify"
		)
	end
end

-- The settings panel cycles by advancing one step through LevelOrder and
-- wrapping. Walking one full cycle from the default must visit every level
-- exactly once and return to the default.
local visited: { [string]: boolean } = {}
local currentIndex = table.find(config.LevelOrder, config.DefaultLevelId)
assert(currentIndex ~= nil, "the default level must be inside the cycle order")
for _ = 1, #config.LevelOrder do
	local levelId = config.LevelOrder[currentIndex :: number]
	assert(not visited[levelId], "the cycle repeated " .. levelId .. " before completing")
	visited[levelId] = true
	currentIndex = (currentIndex :: number) % #config.LevelOrder + 1
end
assert(config.LevelOrder[currentIndex :: number] == config.DefaultLevelId, "a full cycle must return to the default")

print("PresentationAccessibilityConfig: bounded comfort scales, full default, and complete cycle order passed")
