--!strict

--[[
	RC 1.0 production-readiness accessibility baseline for client-local combat
	presentation. Every setting scales only cosmetic feedback that already reacts
	to replicated/server-confirmed facts. No level changes damage, health, death,
	targeting, XP, loot, threat, or information disclosure.

	The baseline deliberately covers more than the original shake/blood pair:
	players can also reduce flash intensity and floating combat text without
	changing gameplay truth. All settings use the same bounded three-level model
	so adding a new comfort surface is a data change plus a consumer hookup rather
	than another settings authority.
]]

local LevelIds = table.freeze({
	Full = "presentation.level.full",
	Reduced = "presentation.level.reduced",
	Off = "presentation.level.off",
})

local SettingIds = table.freeze({
	CameraShake = "presentation.setting.camera-shake",
	Blood = "presentation.setting.blood",
	FlashIntensity = "presentation.setting.flash-intensity",
	FloatingCombatText = "presentation.setting.floating-combat-text",
})

local PresentationAccessibilityConfig = {
	Version = "RC-1.0-access-v2",
	LevelIds = LevelIds,
	SettingIds = SettingIds,
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
		[SettingIds.FlashIntensity] = table.freeze({
			DisplayName = "FLASH INTENSITY",
			Scales = table.freeze({
				[LevelIds.Full] = 1,
				[LevelIds.Reduced] = 0.35,
				[LevelIds.Off] = 0,
			}),
		}),
		[SettingIds.FloatingCombatText] = table.freeze({
			DisplayName = "FLOATING COMBAT TEXT",
			Scales = table.freeze({
				[LevelIds.Full] = 1,
				[LevelIds.Reduced] = 0.55,
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
assert(PresentationAccessibilityConfig.DefaultLevelId == LevelIds.Full, "new players must start at authored presentation intensity")
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
