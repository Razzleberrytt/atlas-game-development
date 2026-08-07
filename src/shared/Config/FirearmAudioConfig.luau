--!strict

--[[
	AUD-0102 client-local firearm audio set.

	Fire and reload are approved free Creator Store audio assets, verified to
	load in Studio. The empty click and completion handling cues are temporary
	derivations of the verified reload asset (replayed at raised speed) so the
	set covers fire, reload, empty, and handling today; unique
	production-approved empty and handling assets remain pending.

	These drive client-local presentation only: the server owns fire
	resolution, ammunition, and reload timing. Playback is 2D (non-positional)
	so gunfire stays audible under the fixed overhead isometric camera.
]]

local FirearmAudioConfig = {
	Version = "AUD-0102-v1",

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

	Empty = table.freeze({
		-- Temporary derivation: the verified reload asset's leading magazine
		-- click, replayed fast and quiet, stands in for a dry-fire click until a
		-- unique production-approved empty asset is sourced and mixed.
		SoundId = "rbxassetid://7058441251",
		LocalVolume = 0.4,
		PlaybackSpeed = 2.4,
		-- Dry disclosures can repeat while the operative stays empty; the click
		-- is throttled so it reads as feedback rather than noise.
		MinimumIntervalSeconds = 0.6,
	}),

	Handling = table.freeze({
		-- Temporary derivation: the verified reload asset replayed at raised
		-- speed reads as the completion rack cue until a unique
		-- production-approved handling asset is sourced and mixed.
		SoundId = "rbxassetid://7058441251",
		LocalVolume = 0.45,
		RemoteVolume = 0.26,
		PlaybackSpeed = 1.7,
	}),
}

assert(FirearmAudioConfig.FirePoolSize > 0, "fire pool must be positive")
assert(
	FirearmAudioConfig.Fire.MaxPlaybackSpeed >= FirearmAudioConfig.Fire.MinPlaybackSpeed,
	"fire playback speed range must be ordered"
)
assert(FirearmAudioConfig.Empty.PlaybackSpeed > 0, "empty click playback speed must be positive")
assert(FirearmAudioConfig.Empty.MinimumIntervalSeconds > 0, "empty click throttle must be positive")
assert(FirearmAudioConfig.Handling.PlaybackSpeed > 0, "handling playback speed must be positive")

return table.freeze(FirearmAudioConfig)
