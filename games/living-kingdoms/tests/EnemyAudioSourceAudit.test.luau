--!strict

--[[
	AUD-0103 Exclusion Walker audio audit. Locks the client-local, bounded,
	server-deferred shape of the hostile sound presentation — one small reused
	pool, per-cue global throttles, camera-distance falloff, silent first-sight
	tracking — so it can never grow authority, per-enemy Sounds, or an unbounded
	horde cacophony.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/EnemyAudioConfig.luau"), {
	debugName = "EnemyAudioConfig",
	injectGlobals = true,
})()
local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/EnemyAudioController.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")
local visualConfig = fs.readFile("games/living-kingdoms/src/shared/Config/VisualAssetConfig.luau")

-- Config: the five recommended cues with real asset ids and bounded values.
for _, cueName in { "Alert", "Windup", "Strike", "Hit", "Death" } do
	local cue = config[cueName]
	assertThat(type(cue) == "table", "hostile audio must define the cue: " .. cueName)
	assertThat(
		type(cue.SoundId) == "string" and string.sub(cue.SoundId, 1, 13) == "rbxassetid://",
		"hostile audio cue must reference a real asset id: " .. cueName
	)
	assertThat(cue.MinimumIntervalSeconds > 0, "hostile audio cue must be throttled: " .. cueName)
	assertThat(cue.Volume > 0 and cue.Volume <= 1, "hostile audio cue volume must stay bounded: " .. cueName)
	assertThat(cue.PlaybackSpeed > 0, "hostile audio cue playback speed must be positive: " .. cueName)
end
assertThat(config.PoolSize > 0 and config.PoolSize <= 32, "hostile audio pool must stay small and bounded")
assertThat(
	config.MaximumTrackedEnemyModels >= 24 and config.MaximumTrackedEnemyModels <= 64,
	"hostile audio tracking must cover living enemies and bounded corpse overlap"
)
assertThat(
	config.MaximumAudibleDistanceStuds > config.FullVolumeDistanceStuds and config.FullVolumeDistanceStuds > 0,
	"hostile audio distances must be ordered"
)

-- Controller: reacts to replicated server-authored attributes, never
-- establishes them, and discloses nothing the enemy models do not carry.
assertThat(
	contains(controller, "PresentationAttributeNames.BehaviorStateId"),
	"hostile audio must read the replicated behavior state"
)
assertThat(
	contains(controller, "PresentationAttributeNames.LifeStateId"),
	"hostile audio must read the replicated life state"
)
assertThat(
	contains(controller, "PresentationAttributeNames.WindupSequence"),
	"hostile audio must read the replicated windup sequence"
)
assertThat(
	contains(controller, "PresentationAttributeNames.AttackSequence"),
	"hostile audio must read the replicated attack sequence"
)
assertThat(
	contains(controller, "PresentationAttributeNames.HitSequence"),
	"hostile audio must read the replicated hit sequence"
)
assertThat(contains(controller, "BehaviorStateIds.Pursuing"), "the alert cue must key on entering pursuit")
assertThat(contains(controller, "PresentationLifeStateIds.Dead"), "the death cue must key on the replicated death")
assertThat(contains(controller, "MinimumIntervalSeconds"), "hostile audio must honor the per-cue throttle")
assertThat(contains(controller, "EnemyAudioConfig.PoolSize"), "hostile audio must build a bounded, reused Sound pool")
assertThat(
	contains(controller, "MaximumAudibleDistanceStuds"),
	"hostile audio must fall silent beyond the bounded distance"
)
assertThat(
	contains(controller, "EnemyConfig.Walker.ArchetypeId"),
	"hostile audio must gate on the walker archetype"
)
assertThat(
	contains(controller, "trackedCount >= EnemyAudioConfig.MaximumTrackedEnemyModels"),
	"hostile audio tracking must stay bounded"
)

-- The Sound pool is built once in createPresentation, never per enemy or per
-- cue: exactly one construction site.
local _, soundConstructions = string.gsub(controller, 'Instance.new%("Sound"%)', "")
assertThat(soundConstructions == 1, "hostile audio must construct its pooled Sounds at exactly one site")

for _, prohibited in
	{
		"FireServer",
		"InvokeServer",
		"OnServerEvent",
		"RemoteEvent",
		"DamageResolver",
		"Humanoid:TakeDamage",
		"commitHealthState",
		"SetAttribute",
		"task.spawn",
		"task.delay",
	}
do
	assertThat(
		not contains(controller, prohibited),
		"hostile audio must remain a client-local reaction: " .. prohibited
	)
end

-- Bootstrap starts the audio owner exactly once.
assertThat(contains(bootstrap, "EnemyAudioController.start()"), "client bootstrap must start hostile audio")
local _, startCount = string.gsub(bootstrap, "EnemyAudioController.start()", "")
assertThat(startCount == 1, "hostile audio must start exactly once")

-- Registry honestly records the audio owner and its temporary status.
assertThat(
	contains(visualConfig, "src/client/Controllers/EnemyAudioController.luau"),
	"visual asset registry must attribute hostile audio to its owner"
)

print(
	"EnemyAudioSourceAudit: bounded client-local alert, windup, strike, hit, and death audio, "
		.. "deferred authority, and bootstrap passed"
)
