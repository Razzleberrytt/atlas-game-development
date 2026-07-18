--!strict

--[[
	Presentation-only escalation for the authoritative, non-rewarding horde
	streak. HordeExperienceService owns the streak and its expiry; clients may
	only render the disclosed count and deadline. No tier grants XP, loot, health,
	ammunition, damage, cadence, movement, targeting, or any other gameplay value.
]]

local FirearmAudioConfig = require(script.Parent.FirearmAudioConfig)
local HordeExperienceConfig = require(script.Parent.HordeExperienceConfig)

export type TierDefinition = {
	MinimumStreak: number,
	Title: string,
	Subtitle: string,
	Color: { number },
	PulseScale: number,
	FlashStrength: number,
	StingerVolume: number,
	StingerPlaybackSpeed: number,
}

local Tiers: { TierDefinition } = table.freeze({
	table.freeze({
		MinimumStreak = 2,
		Title = "KILL CHAIN",
		Subtitle = "KEEP MOVING",
		Color = table.freeze({ 255, 178, 82 }),
		PulseScale = 1.12,
		FlashStrength = 0.08,
		StingerVolume = 0.22,
		StingerPlaybackSpeed = 0.48,
	}),
	table.freeze({
		MinimumStreak = 4,
		Title = "SLAUGHTER",
		Subtitle = "PRESS THE HORDE",
		Color = table.freeze({ 255, 115, 62 }),
		PulseScale = 1.17,
		FlashStrength = 0.11,
		StingerVolume = 0.28,
		StingerPlaybackSpeed = 0.4,
	}),
	table.freeze({
		MinimumStreak = 7,
		Title = "MASSACRE",
		Subtitle = "NO BREATHING ROOM",
		Color = table.freeze({ 255, 65, 52 }),
		PulseScale = 1.23,
		FlashStrength = 0.14,
		StingerVolume = 0.34,
		StingerPlaybackSpeed = 0.34,
	}),
	table.freeze({
		MinimumStreak = 11,
		Title = "ANNIHILATION",
		Subtitle = "BREAK THEIR LINE",
		Color = table.freeze({ 240, 72, 164 }),
		PulseScale = 1.29,
		FlashStrength = 0.17,
		StingerVolume = 0.4,
		StingerPlaybackSpeed = 0.28,
	}),
	table.freeze({
		MinimumStreak = 16,
		Title = "APOCALYPSE",
		Subtitle = "THE HORDE IS BLEEDING",
		Color = table.freeze({ 189, 108, 255 }),
		PulseScale = 1.36,
		FlashStrength = 0.2,
		StingerVolume = 0.46,
		StingerPlaybackSpeed = 0.23,
	}),
})

local function tierForStreak(streak: unknown): (TierDefinition?, number)
	if type(streak) ~= "number" or streak ~= streak then
		return nil, 0
	end
	local chosen: TierDefinition? = nil
	local chosenIndex = 0
	for index, tier in Tiers do
		if streak >= tier.MinimumStreak then
			chosen = tier
			chosenIndex = index
		else
			break
		end
	end
	return chosen, chosenIndex
end

local Config = {
	Version = "HROI-0132-v1-massacre-crescendo",
	StreakWindowSeconds = HordeExperienceConfig.Streak.KillStreakWindowSeconds,
	MinimumVisibleStreak = 2,
	MaximumPresentedStreak = 999,
	PulseDurationSeconds = 0.34,
	FadeDurationSeconds = 0.2,
	StingerMinimumIntervalSeconds = 0.25,
	StingerSoundId = FirearmAudioConfig.Fire.SoundId,
	Tiers = Tiers,
	tierForStreak = tierForStreak,
}

assert(
	Config.StreakWindowSeconds > 0 and Config.StreakWindowSeconds <= 10,
	"streak presentation window must stay bounded"
)
assert(Config.MinimumVisibleStreak == Tiers[1].MinimumStreak, "first tier must match the visible streak floor")
assert(
	Config.MaximumPresentedStreak >= 24 and Config.MaximumPresentedStreak <= 999,
	"presented streak count must stay bounded"
)
assert(Config.PulseDurationSeconds > 0 and Config.PulseDurationSeconds <= 0.5, "streak pulse must stay brief")
assert(Config.FadeDurationSeconds > 0 and Config.FadeDurationSeconds <= 0.5, "streak fade must stay brief")
assert(Config.StingerMinimumIntervalSeconds > 0, "streak stinger requires a throttle")
assert(
	type(Config.StingerSoundId) == "string" and string.sub(Config.StingerSoundId, 1, 13) == "rbxassetid://",
	"streak stinger must reuse a verified asset"
)

local previousMinimum = 0
for _, tier in Tiers do
	assert(tier.MinimumStreak > previousMinimum, "streak tiers must be strictly ordered")
	assert(tier.MinimumStreak <= Config.MaximumPresentedStreak, "streak tier must fit the display cap")
	assert(tier.Title ~= "" and tier.Subtitle ~= "", "streak tier copy must be readable")
	assert(#tier.Color == 3, "streak tier requires an RGB tuple")
	assert(tier.PulseScale >= 1 and tier.PulseScale <= 1.5, "streak pulse scale must stay bounded")
	assert(tier.FlashStrength >= 0 and tier.FlashStrength <= 0.25, "streak flash must stay subtle")
	assert(tier.StingerVolume > 0 and tier.StingerVolume <= 0.5, "streak stinger volume must stay bounded")
	assert(tier.StingerPlaybackSpeed > 0, "streak stinger speed must stay positive")
	previousMinimum = tier.MinimumStreak
end

return table.freeze(Config)
