--!strict

--[[
	Client-local session store for the HROI-0104 comfort settings. Levels live
	only on this client for this session: there is no remote, no replication,
	and no persistence, so no setting can influence another player or any
	server-owned gameplay fact. Consumers read scales at effect time and may
	subscribe to changes for immediate UI feedback.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PresentationAccessibilityConfig = require(ReplicatedStorage.Shared.Config.PresentationAccessibilityConfig)

local levelBySettingId: { [string]: string } = {}
for settingId in PresentationAccessibilityConfig.Settings do
	levelBySettingId[settingId] = PresentationAccessibilityConfig.DefaultLevelId
end

type ChangeListener = (settingId: string, levelId: string) -> ()

local listeners: { [ChangeListener]: boolean } = {}

local State = {}

function State.getLevelId(settingId: string): string
	local levelId = levelBySettingId[settingId]
	assert(levelId ~= nil, "unknown presentation setting: " .. tostring(settingId))
	return levelId
end

function State.getDisplayName(settingId: string): string
	local setting = PresentationAccessibilityConfig.Settings[settingId]
	assert(setting ~= nil, "unknown presentation setting: " .. tostring(settingId))
	return setting.DisplayName
end

function State.getLevelDisplayName(settingId: string): string
	return PresentationAccessibilityConfig.LevelDisplayNames[State.getLevelId(settingId)]
end

function State.getScale(settingId: string): number
	local setting = PresentationAccessibilityConfig.Settings[settingId]
	assert(setting ~= nil, "unknown presentation setting: " .. tostring(settingId))
	return setting.Scales[State.getLevelId(settingId)]
end

function State.cycle(settingId: string): string
	local currentLevelId = State.getLevelId(settingId)
	local order = PresentationAccessibilityConfig.LevelOrder
	local currentIndex = table.find(order, currentLevelId) or 1
	local nextLevelId = order[currentIndex % #order + 1]
	levelBySettingId[settingId] = nextLevelId
	for listener in listeners do
		listener(settingId, nextLevelId)
	end
	return nextLevelId
end

function State.onChanged(listener: ChangeListener): () -> ()
	listeners[listener] = true
	return function()
		listeners[listener] = nil
	end
end

function State.reset()
	for settingId in PresentationAccessibilityConfig.Settings do
		levelBySettingId[settingId] = PresentationAccessibilityConfig.DefaultLevelId
	end
	table.clear(listeners)
end

return table.freeze(State)
