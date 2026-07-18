--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local FIREARM_AUDIO_TOKEN = {}
local HORDE_CONFIG_TOKEN = {}

local source = fs.readFile("games/living-kingdoms/src/shared/Config/MassacreCrescendoConfig.luau")
local loader = luau.load(source, {
	debugName = "MassacreCrescendoConfig",
	environment = {
		script = {
			Parent = {
				FirearmAudioConfig = FIREARM_AUDIO_TOKEN,
				HordeExperienceConfig = HORDE_CONFIG_TOKEN,
			},
		},
		require = function(token: unknown)
			if token == FIREARM_AUDIO_TOKEN then
				return { Fire = { SoundId = "rbxassetid://165946267" } }
			end
			if token == HORDE_CONFIG_TOKEN then
				return { Streak = { KillStreakWindowSeconds = 4 } }
			end
			error("unexpected massacre crescendo dependency")
		end,
	},
	injectGlobals = true,
})
local config = loader()

assert(config.Version == "HROI-0132-v1-massacre-crescendo")
assert(config.StreakWindowSeconds == 4)
assert(config.MinimumVisibleStreak == 2)
assert(config.MaximumPresentedStreak == 999)
assert(config.PulseDurationSeconds == 0.34)
assert(config.FadeDurationSeconds == 0.2)
assert(config.StingerSoundId == "rbxassetid://165946267")
assert(#config.Tiers == 5)

local expected = {
	{ threshold = 2, title = "KILL CHAIN" },
	{ threshold = 4, title = "SLAUGHTER" },
	{ threshold = 7, title = "MASSACRE" },
	{ threshold = 11, title = "ANNIHILATION" },
	{ threshold = 16, title = "APOCALYPSE" },
}

for index, values in expected do
	local tier = config.Tiers[index]
	assert(tier.MinimumStreak == values.threshold)
	assert(tier.Title == values.title)
	assert(tier.Subtitle ~= "")
	assert(#tier.Color == 3)
	assert(tier.PulseScale >= 1 and tier.PulseScale <= 1.5)
	assert(tier.FlashStrength >= 0 and tier.FlashStrength <= 0.25)
	assert(tier.StingerVolume > 0 and tier.StingerVolume <= 0.5)
	assert(tier.StingerPlaybackSpeed > 0)
end

local tier, index = config.tierForStreak(1)
assert(tier == nil and index == 0)
tier, index = config.tierForStreak(2)
assert(tier.Title == "KILL CHAIN" and index == 1)
tier, index = config.tierForStreak(6)
assert(tier.Title == "SLAUGHTER" and index == 2)
tier, index = config.tierForStreak(7)
assert(tier.Title == "MASSACRE" and index == 3)
tier, index = config.tierForStreak(15)
assert(tier.Title == "ANNIHILATION" and index == 4)
tier, index = config.tierForStreak(999)
assert(tier.Title == "APOCALYPSE" and index == 5)
tier, index = config.tierForStreak("bad")
assert(tier == nil and index == 0)

local mutated = pcall(function()
	config.MinimumVisibleStreak = 99
end)
assert(not mutated, "crescendo config must be frozen")

print("MassacreCrescendoConfig: tiers, exact streak window, verified stinger, and bounds passed")
