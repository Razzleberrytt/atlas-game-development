--!strict

--[[
	HROI-0104 accessibility levels for client-local combat presentation. Camera
	shake and blood intensity are personal comfort settings: every level scales
	only cosmetic feedback that already reacts to replicated server-confirmed
	facts. No level can change damage, health, death, targeting, XP, loot,
	threat, or any other consequential gameplay fact, and no level reveals
	information a full-intensity client would not receive.
]]

local LevelIds = table.freeze({
	Full = "presentation.level.full",
	Reduced = "presentation.level.reduced",
	Off = "presentation.level.off",
})

local SettingIds = table.freeze({
	CameraShake = "presentation.setting.camera-shake",
	Blood = "presentation.setting.blood",
})

local PresentationAccessibilityConfig = {
	Version = "HROI-0104-access-v1",
	LevelIds = LevelIds,
	SettingIds = SettingIds,
	-- Cycle order for the settings panel: each activation advances one step and
	-- wraps, so every level is reachable from every other with at most two taps.
	LevelOrder = table.freeze({ LevelIds.Full, LevelIds.Reduced, LevelIds.Off }),
	LevelDisplayNames = table.freeze({
		[LevelIds.Full] = "FULL",
		[LevelIds.Reduced] = "REDUCED",
		[LevelIds.Off] = "OFF",
	}),
	DefaultLevelId = LevelIds.Full,
	Settings = table.freeze({
		[SettingIds.CameraShake] = table.freeze({
			DisplayName = "CAMERA SHAKE",
			Scales = table.freeze({
				[LevelIds.Full] = 1,
				[LevelIds.Reduced] = 0.4,
				[LevelIds.Off] = 0,
			}),
		}),
		[SettingIds.Blood] = table.freeze({
			DisplayName = "BLOOD",
			Scales = table.freeze({
				[LevelIds.Full] = 1,
				[LevelIds.Reduced] = 0.45,
				[LevelIds.Off] = 0,
			}),
		}),
	}),
}

local levelCount = 0
for _ in PresentationAccessibilityConfig.LevelDisplayNames do
	levelCount += 1
end
assert(#PresentationAccessibilityConfig.LevelOrder == levelCount, "the cycle order must cover every level exactly once")
local seenLevels: { [string]: boolean } = {}
for _, levelId in PresentationAccessibilityConfig.LevelOrder do
	assert(PresentationAccessibilityConfig.LevelDisplayNames[levelId] ~= nil, "ordered levels require display names")
	assert(not seenLevels[levelId], "the cycle order cannot repeat a level")
	seenLevels[levelId] = true
end
assert(
	PresentationAccessibilityConfig.LevelDisplayNames[PresentationAccessibilityConfig.DefaultLevelId] ~= nil,
	"the default level must be a known level"
)
assert(
	PresentationAccessibilityConfig.DefaultLevelId == LevelIds.Full,
	"new players must start at full intensity so reviews judge the authored presentation"
)
for settingId, setting in PresentationAccessibilityConfig.Settings do
	assert(#setting.DisplayName > 0, settingId .. " requires a readable display name")
	assert(setting.Scales[LevelIds.Full] == 1, settingId .. " full intensity must be exactly the authored presentation")
	assert(setting.Scales[LevelIds.Off] == 0, settingId .. " off must suppress the effect entirely")
	local reduced = setting.Scales[LevelIds.Reduced]
	assert(reduced > 0 and reduced < 1, settingId .. " reduced must sit strictly between off and full")
	for levelId in PresentationAccessibilityConfig.LevelDisplayNames do
		local scale = setting.Scales[levelId]
		assert(type(scale) == "number" and scale >= 0 and scale <= 1, settingId .. " scales must stay within [0, 1]")
	end
end

return table.freeze(PresentationAccessibilityConfig)
