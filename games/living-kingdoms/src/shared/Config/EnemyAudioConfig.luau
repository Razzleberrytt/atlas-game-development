--!strict

--[[
	AUD-0103 client-local hostile audio set.

	Core hostile cues plus Screamer, Bloater, and Brute warnings are temporary
	derivations of the project's two Studio-verified Creator Store assets replayed
	at shifted speeds. These values control cosmetic feedback only, reacting to
	already-replicated server-authored presentation attributes.

	Because Living Kingdoms combat is first-person, hostile cues use a small
	bounded world-emitter pool so alerts, windups, strikes, impacts, deaths, and
	special warnings carry directional information. Camera-distance volume scaling
	and 3D rolloff both remain bounded; neither can establish behavior, damage,
	health, death, or any consequential gameplay fact.
]]

local EnemyAudioConfig = {
	Version = "AUD-0103-v3-spatial-hostile-readability",

	-- One bounded, reused Sound/emitter pool shared by every cue so a full
	-- 24-enemy horde can never create unbounded presentation instances.
	PoolSize = 8,

	-- The server caps living enemies at 24; corpses persist briefly through
	-- the cleanup window. This cosmetic-only ceiling covers both groups.
	MaximumTrackedEnemyModels = 64,

	-- Cues are silent beyond the far distance and reach configured volume at
	-- the near distance. Spatial rolloff adds direction while this explicit
	-- scale preserves the existing horde-noise budget.
	FullVolumeDistanceStuds = 45,
	MaximumAudibleDistanceStuds = 140,
	SpatialEmitterSizeStuds = 5,
	SpatialRollOffMinDistanceStuds = 12,
	SpatialRollOffMaxDistanceStuds = 140,

	Alert = table.freeze({
		SoundId = "rbxassetid://7058441251",
		Volume = 0.3,
		PlaybackSpeed = 1.5,
		MinimumIntervalSeconds = 0.8,
	}),

	Windup = table.freeze({
		SoundId = "rbxassetid://7058441251",
		Volume = 0.42,
		PlaybackSpeed = 0.55,
		MinimumIntervalSeconds = 0.35,
	}),

	Strike = table.freeze({
		SoundId = "rbxassetid://165946267",
		Volume = 0.45,
		PlaybackSpeed = 0.35,
		MinimumIntervalSeconds = 0.3,
	}),

	Hit = table.freeze({
		SoundId = "rbxassetid://165946267",
		Volume = 0.24,
		PlaybackSpeed = 0.5,
		MinimumIntervalSeconds = 0.12,
	}),

	ScreamerWarning = table.freeze({
		SoundId = "rbxassetid://7058441251",
		Volume = 0.58,
		PlaybackSpeed = 0.32,
		MinimumIntervalSeconds = 0.8,
	}),

	BloaterWarning = table.freeze({
		SoundId = "rbxassetid://165946267",
		Volume = 0.6,
		PlaybackSpeed = 0.2,
		MinimumIntervalSeconds = 0.35,
	}),

	BruteWarning = table.freeze({
		SoundId = "rbxassetid://165946267",
		Volume = 0.66,
		PlaybackSpeed = 0.16,
		MinimumIntervalSeconds = 0.5,
	}),

	Death = table.freeze({
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
assert(EnemyAudioConfig.SpatialEmitterSizeStuds > 0, "enemy spatial emitter size must be positive")
assert(EnemyAudioConfig.SpatialRollOffMinDistanceStuds > 0, "enemy spatial rolloff minimum must be positive")
assert(
	EnemyAudioConfig.SpatialRollOffMaxDistanceStuds > EnemyAudioConfig.SpatialRollOffMinDistanceStuds
		and EnemyAudioConfig.SpatialRollOffMaxDistanceStuds <= EnemyAudioConfig.MaximumAudibleDistanceStuds,
	"enemy spatial rolloff range must stay ordered and within the audible budget"
)
for _, cueName in { "Alert", "Windup", "Strike", "Hit", "ScreamerWarning", "BloaterWarning", "BruteWarning", "Death" } do
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
