--!strict

--[[
	AUD-0102 firearm audio audit. Locks the client-local, bounded, server-deferred
	shape of the firearm sound presentation — fire pool, reload, empty click, and
	handling cue — so it can never grow combat authority or spawn unbounded
	instances under sustained automatic fire. Remote accepted shots additionally
	retain directional co-op readability through the bounded emitter pool.
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

local function isRealAssetId(value: unknown): boolean
	return type(value) == "string" and string.sub(value, 1, 13) == "rbxassetid://"
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/FirearmAudioConfig.luau"), {
	debugName = "FirearmAudioConfig",
	injectGlobals = true,
})()
local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/WeaponAudioController.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")
local visualConfig = fs.readFile("games/living-kingdoms/src/shared/Config/VisualAssetConfig.luau")

assertThat(isRealAssetId(config.Fire.SoundId), "fire sound must reference a real asset id")
assertThat(isRealAssetId(config.Reload.SoundId), "reload sound must reference a real asset id")
assertThat(isRealAssetId(config.Empty.SoundId), "empty click must reference a real asset id")
assertThat(isRealAssetId(config.Handling.SoundId), "handling cue must reference a real asset id")
assertThat(config.FirePoolSize > 0 and config.FirePoolSize <= 32, "fire pool must stay small and bounded")
assertThat(config.Fire.MaxPlaybackSpeed >= config.Fire.MinPlaybackSpeed, "fire playback speed scatter must be ordered")
assertThat(config.Fire.RemoteEmitterSizeStuds > 0, "remote fire emitter size must be positive")
assertThat(config.Fire.RemoteRollOffMinDistanceStuds > 0, "remote fire rolloff minimum must be positive")
assertThat(
	config.Fire.RemoteRollOffMaxDistanceStuds > config.Fire.RemoteRollOffMinDistanceStuds,
	"remote fire rolloff distances must be ordered"
)
assertThat(config.Empty.MinimumIntervalSeconds > 0, "empty click must be throttled")
assertThat(config.Empty.PlaybackSpeed > 0, "empty click playback speed must be positive")
assertThat(config.Handling.PlaybackSpeed > 0, "handling playback speed must be positive")

assertThat(contains(controller, "presentationRemote.OnClientEvent:Connect"), "audio must react to the shot disclosure")
assertThat(
	contains(controller, "CombatContracts.PresentationMessageKindIds.ShotFired"),
	"audio must play on accepted shots"
)
assertThat(
	contains(controller, "CombatContracts.PresentationMessageKindIds.ReloadStarted"),
	"audio must play on reload starts"
)
assertThat(
	contains(controller, "CombatContracts.PresentationMessageKindIds.ReloadCompleted"),
	"audio must play the handling cue on reload completion"
)
assertThat(
	contains(controller, "CombatContracts.PresentationMessageKindIds.ReloadInterrupted"),
	"audio must stop the reload sound on interruption"
)
assertThat(
	contains(controller, "CombatContracts.PresentationMessageKindIds.AmmunitionState"),
	"audio must observe the personal ammunition disclosure for the empty click"
)
assertThat(contains(controller, "stopReloadForOperative"), "an interrupted reload must stop its own reload sound")
assertThat(contains(controller, "MinimumIntervalSeconds"), "the empty click must honor the configured throttle")
assertThat(contains(controller, "isKnownWeaponId(payload.weaponId)"), "audio must gate on a configured firearm")
assertThat(contains(controller, "resolveWeaponDefinition"), "audio must retain legacy fixture compatibility")
assertThat(contains(controller, "FirearmAudioConfig.FirePoolSize"), "audio must build a bounded, reused Sound pool")

assertThat(contains(controller, "local fireEmitters: { Part } = {}"), "remote fire must use a bounded emitter pool")
assertThat(
	contains(controller, "local function playerForOperativeEntityId"),
	"remote fire position must resolve from the disclosed operative identity"
)
assertThat(
	contains(controller, 'character:FindFirstChild("HumanoidRootPart")'),
	"remote fire position must come from the replicated operative root"
)
assertThat(contains(controller, "emitter.Position = position"), "remote accepted shots must place the spatial emitter")
assertThat(contains(controller, "sound.Parent = emitter"), "remote accepted shots must become spatial audio")
assertThat(
	contains(controller, "sound.Parent = holder"),
	"local or unresolved shots must retain the safe non-positional fallback"
)
assertThat(
	contains(controller, "RemoteRollOffMaxDistanceStuds"),
	"remote fire must honor the configured bounded audible range"
)

local _, soundConstructions = string.gsub(controller, 'Instance.new%("Sound"%)', "")
assertThat(soundConstructions == 4, "audio must construct its bounded Sound set exactly once, not per shot")
local _, emitterConstructions = string.gsub(controller, 'Instance.new%("Part"%)', "")
assertThat(emitterConstructions == 1, "remote fire emitters must only be constructed by the bounded pool loop")

for _, prohibited in
	{
		"FireServer",
		"InvokeServer",
		"OnServerEvent",
		"DamageResolver",
		"FirearmHitResolver",
		"Humanoid:TakeDamage",
		"commitHealthState",
		"loadedRounds -=",
		"reserveRounds -=",
		"task.spawn",
		"task.delay",
	}
do
	assertThat(
		not contains(controller, prohibited),
		"firearm audio must remain a client-local reaction: " .. prohibited
	)
end

assertThat(contains(bootstrap, "WeaponAudioController.start()"), "client bootstrap must start firearm audio")
local _, startCount = string.gsub(bootstrap, "WeaponAudioController.start()", "")
assertThat(startCount == 1, "firearm audio must start exactly once")

assertThat(
	contains(visualConfig, "src/client/Controllers/WeaponAudioController.luau"),
	"visual asset registry must attribute firearm audio to its owner"
)

print("FirearmAudioSourceAudit: bounded local cues, spatial remote fire, deferred authority, and bootstrap passed")
