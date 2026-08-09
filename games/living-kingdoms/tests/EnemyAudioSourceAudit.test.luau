--!strict

--[[
	AUD-0103 hostile audio audit. Locks the client-local, bounded, server-deferred
	shape of hostile sound presentation — one reused Sound/emitter pool, per-cue
	global throttles, camera-distance falloff, spatial direction, and silent
	first-sight tracking — so it can never grow combat authority or per-enemy
	presentation objects under horde pressure.
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

for _, cueName in {
	"Alert",
	"Windup",
	"Strike",
	"Hit",
	"ScreamerWarning",
	"BloaterWarning",
	"BruteWarning",
	"SpitterBloomWarning",
	"ProgenitorSlamWarning",
	"Death",
} do
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
assertThat(config.SpatialEmitterSizeStuds > 0, "hostile spatial emitter must have positive size")
assertThat(config.SpatialRollOffMinDistanceStuds > 0, "hostile spatial rolloff minimum must be positive")
assertThat(
	config.SpatialRollOffMaxDistanceStuds > config.SpatialRollOffMinDistanceStuds
		and config.SpatialRollOffMaxDistanceStuds <= config.MaximumAudibleDistanceStuds,
	"hostile spatial rolloff must remain bounded by the audible budget"
)

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
assertThat(
	contains(controller, "SpecialAttributeNames.Sequence"),
	"horde-special warning audio must read the server-authored telegraph sequence"
)
assertThat(contains(controller, "SpecialKindIds.ScreamerReinforcement"), "Screamer warnings must retain audio")
assertThat(contains(controller, "SpecialKindIds.BloaterDeathBurst"), "Bloater warnings must retain audio")
assertThat(contains(controller, "SpecialKindIds.BruteSecondPhase"), "Brute warnings must retain audio")
assertThat(
	contains(controller, "SpecialEncounterTelegraphConfig.discKindForArchetypeId"),
	"Spitter and boss warning audio must use the shared server/client encounter telegraph contract"
)
assertThat(
	contains(controller, "readNumberAttribute(model, record.kind.SequenceAttribute)"),
	"encounter warning audio must advance only from the replicated authoritative telegraph sequence"
)
assertThat(
	contains(controller, 'playCue("SpitterBloomWarning", EnemyAudioConfig.SpitterBloomWarning, record.root)'),
	"Corrosive Bloom must receive directional warning audio"
)
assertThat(
	contains(controller, 'playCue("ProgenitorSlamWarning", EnemyAudioConfig.ProgenitorSlamWarning, record.root)'),
	"Progenitor Slam must receive directional warning audio"
)
assertThat(contains(controller, "BehaviorStateIds.Pursuing"), "the alert cue must key on entering pursuit")
assertThat(contains(controller, "PresentationLifeStateIds.Dead"), "the death cue must key on replicated death")
assertThat(contains(controller, "MinimumIntervalSeconds"), "hostile audio must honor the per-cue throttle")
assertThat(contains(controller, "EnemyAudioConfig.PoolSize"), "hostile audio must build a bounded reused pool")
assertThat(
	contains(controller, "MaximumAudibleDistanceStuds"),
	"hostile audio must fall silent beyond the bounded distance"
)
assertThat(contains(controller, "EnemyConfig.Walker.ArchetypeId"), "ordinary hostile audio must retain walker gating")
assertThat(
	contains(controller, "trackedCount >= EnemyAudioConfig.MaximumTrackedEnemyModels"),
	"hostile and encounter audio tracking must stay bounded"
)

assertThat(contains(controller, "local emitterPool: { Part } = {}"), "hostile audio must use a bounded emitter pool")
assertThat(contains(controller, "emitter.Position = root.Position"), "each cue must originate at its enemy")
assertThat(contains(controller, "sound.Parent = emitter"), "hostile cues must use spatial sound parenting")
assertThat(contains(controller, "Enum.RollOffMode.Inverse"), "hostile cues must use bounded spatial rolloff")
assertThat(
	contains(controller, "EnemyAudioConfig.SpatialRollOffMaxDistanceStuds"),
	"hostile cues must honor the configured maximum spatial distance"
)

local _, soundConstructions = string.gsub(controller, 'Instance.new%("Sound"%)', "")
assertThat(soundConstructions == 1, "hostile audio must construct its pooled Sounds at exactly one site")
local _, emitterConstructions = string.gsub(controller, 'Instance.new%("Part"%)', "")
assertThat(emitterConstructions == 1, "hostile audio must construct its pooled emitters at exactly one site")

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

assertThat(contains(bootstrap, "EnemyAudioController.start()"), "client bootstrap must start hostile audio")
local _, startCount = string.gsub(bootstrap, "EnemyAudioController.start()", "")
assertThat(startCount == 1, "hostile audio must start exactly once")

assertThat(
	contains(visualConfig, "src/client/Controllers/EnemyAudioController.luau"),
	"visual asset registry must attribute hostile audio to its owner"
)

print("EnemyAudioSourceAudit: bounded spatial hostile and encounter warning cues remain presentation-only")
