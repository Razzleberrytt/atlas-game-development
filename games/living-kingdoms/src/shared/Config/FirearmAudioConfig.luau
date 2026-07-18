--!strict

--[[
	AUD-0101 client-local firearm audio set for the Blackwater Support LMG.

	These are approved free Creator Store audio assets, verified to load in
	Studio. They drive client-local presentation only: the server owns fire
	resolution, ammunition, and reload timing. Playback is 2D (non-positional)
	so gunfire stays audible under the fixed overhead isometric camera.
]]

local FirearmAudioConfig = {
	Version = "AUD-0101-v1",

	-- Bounded, reused Sound pool. One fire slot is claimed per accepted shot in
	-- round-robin order so rapid automatic fire never creates unbounded Sounds.
	FirePoolSize = 12,

	Fire = table.freeze({
		SoundId = "rbxassetid://165946267",
		LocalVolume = 0.5,
		RemoteVolume = 0.3,
		-- Slight per-shot pitch scatter keeps sustained automatic fire from
		-- sounding like one looping sample.
		MinPlaybackSpeed = 0.93,
		MaxPlaybackSpeed = 1.08,
	}),

	Reload = table.freeze({
		SoundId = "rbxassetid://7058441251",
		LocalVolume = 0.55,
		RemoteVolume = 0.32,
	}),
}

assert(FirearmAudioConfig.FirePoolSize > 0, "fire pool must be positive")
assert(
	FirearmAudioConfig.Fire.MaxPlaybackSpeed >= FirearmAudioConfig.Fire.MinPlaybackSpeed,
	"fire playback speed range must be ordered"
)

return table.freeze(FirearmAudioConfig)
