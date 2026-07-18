--!strict

--[[
	AUD-0103 client-local Exclusion Walker audio set.

	Five cues cover the recommended hostile set — alert, windup, strike, hit,
	and death — as temporary derivations of the project's two Studio-verified
	Creator Store assets (the firearm fire and reload sounds) replayed at
	shifted speeds. The walker is a mechanized rotting horror with corroded
	plating and a canister, so mechanical clicks, rattles, and thuds read
	honestly until unique production-approved organic assets are sourced and
	mixed.

	These values control cosmetic feedback only, reacting to already-replicated
	server-authored presentation attributes. They cannot establish behavior,
	damage, health, death, or any consequential gameplay fact. Playback is 2D
	(non-positional) with distance-scaled volume because the fixed overhead
	camera makes true 3D rolloff sound uniformly distant.
]]

local EnemyAudioConfig = {
	Version = "AUD-0103-v1",

	-- One bounded, reused Sound pool shared by every cue so a full 24-enemy
	-- horde can never create unbounded Sound instances.
	PoolSize = 8,

	-- The server caps living enemies at 24; corpses persist briefly through
	-- the cleanup window. This cosmetic-only ceiling covers both groups.
	MaximumTrackedEnemyModels = 64,

	-- Cues are silent beyond the far distance and reach configured volume at
	-- the near distance, measured from the current camera position like the
	-- combat-impact effects.
	FullVolumeDistanceStuds = 45,
	MaximumAudibleDistanceStuds = 140,

	-- Per-cue global minimum intervals keep a dense horde from stacking the
	-- same cue into noise; each interval spans the whole population, not one
	-- enemy.
	Alert = table.freeze({
		-- Reload asset, raised speed: the walker's targeting click when it
		-- transitions from roaming or stand-down into pursuit.
		SoundId = "rbxassetid://7058441251",
		Volume = 0.3,
		PlaybackSpeed = 1.5,
		MinimumIntervalSeconds = 0.8,
	}),

	Windup = table.freeze({
		-- Reload asset, lowered speed: the corroded-plating rattle that
		-- accompanies the pose telegraph before a strike.
		SoundId = "rbxassetid://7058441251",
		Volume = 0.42,
		PlaybackSpeed = 0.55,
		MinimumIntervalSeconds = 0.35,
	}),

	Strike = table.freeze({
		-- Fire asset, low speed: the heavy thud of a committed strike.
		SoundId = "rbxassetid://165946267",
		Volume = 0.45,
		PlaybackSpeed = 0.35,
		MinimumIntervalSeconds = 0.3,
	}),

	Hit = table.freeze({
		-- Fire asset, mid-low speed and quiet: the confirmed round striking
		-- the walker's plating.
		SoundId = "rbxassetid://165946267",
		Volume = 0.24,
		PlaybackSpeed = 0.5,
		MinimumIntervalSeconds = 0.12,
	}),

	Death = table.freeze({
		-- Fire asset, very low speed: the collapse thud when the walker dies.
		SoundId = "rbxassetid://165946267",
		Volume = 0.5,
		PlaybackSpeed = 0.25,
		MinimumIntervalSeconds = 0.25,
	}),
}

assert(
	EnemyAudioConfig.PoolSize > 0 and EnemyAudioConfig.PoolSize <= 32,
	"enemy audio pool must stay small and bounded"
)
assert(
	EnemyAudioConfig.MaximumTrackedEnemyModels >= 24 and EnemyAudioConfig.MaximumTrackedEnemyModels <= 64,
	"enemy audio must cover living enemies and bounded corpse overlap"
)
assert(
	EnemyAudioConfig.FullVolumeDistanceStuds > 0
		and EnemyAudioConfig.MaximumAudibleDistanceStuds > EnemyAudioConfig.FullVolumeDistanceStuds
		and EnemyAudioConfig.MaximumAudibleDistanceStuds <= 200,
	"enemy audio distances must be ordered and bounded"
)
for _, cueName in { "Alert", "Windup", "Strike", "Hit", "Death" } do
	local cue = (EnemyAudioConfig :: any)[cueName]
	assert(type(cue) == "table", "enemy audio cue must exist: " .. cueName)
	assert(
		type(cue.SoundId) == "string" and string.sub(cue.SoundId, 1, 13) == "rbxassetid://",
		"enemy audio cue must reference a real asset id: " .. cueName
	)
	assert(cue.Volume > 0 and cue.Volume <= 1, "enemy audio cue volume must stay bounded: " .. cueName)
	assert(cue.PlaybackSpeed > 0, "enemy audio cue playback speed must be positive: " .. cueName)
	assert(cue.MinimumIntervalSeconds > 0, "enemy audio cue throttle must be positive: " .. cueName)
end

return table.freeze(EnemyAudioConfig)
