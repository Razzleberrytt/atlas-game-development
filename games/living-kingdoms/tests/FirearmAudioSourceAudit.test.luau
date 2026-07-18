--!strict

--[[
	AUD-0101 firearm audio audit. Locks the client-local, bounded, server-deferred
	shape of the firearm sound presentation so it can never grow combat authority
	or spawn unbounded Sounds under sustained automatic fire.
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

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/FirearmAudioConfig.luau"), {
	debugName = "FirearmAudioConfig",
	injectGlobals = true,
})()
local controller = fs.readFile("games/living-kingdoms/src/client/Controllers/WeaponAudioController.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")
local visualConfig = fs.readFile("games/living-kingdoms/src/shared/Config/VisualAssetConfig.luau")

-- Config: real, verified asset ids and a bounded pool.
assertThat(
	type(config.Fire.SoundId) == "string" and string.sub(config.Fire.SoundId, 1, 13) == "rbxassetid://",
	"fire sound must reference a real asset id"
)
assertThat(
	type(config.Reload.SoundId) == "string" and string.sub(config.Reload.SoundId, 1, 13) == "rbxassetid://",
	"reload sound must reference a real asset id"
)
assertThat(config.FirePoolSize > 0 and config.FirePoolSize <= 32, "fire pool must stay small and bounded")
assertThat(config.Fire.MaxPlaybackSpeed >= config.Fire.MinPlaybackSpeed, "fire playback speed scatter must be ordered")

-- Controller: reacts to the authoritative disclosure, never establishes it.
assertThat(contains(controller, "presentationRemote.OnClientEvent:Connect"), "audio must react to the shot disclosure")
assertThat(
	contains(controller, "CombatContracts.PresentationMessageKindIds.ShotFired"),
	"audio must play on accepted shots"
)
assertThat(
	contains(controller, "CombatContracts.PresentationMessageKindIds.ReloadStarted"),
	"audio must play on reload starts"
)
assertThat(contains(controller, "FirearmConfig.BasicFirearm.WeaponId"), "audio must gate on the basic firearm")
assertThat(contains(controller, "FirearmAudioConfig.FirePoolSize"), "audio must build a bounded, reused Sound pool")

-- The Sound pool is built once in createPresentation, never per message.
local _, soundConstructions = string.gsub(controller, 'Instance.new%("Sound"%)', "")
assertThat(soundConstructions == 2, "audio must construct fire and reload Sounds exactly once, not per shot")

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

-- Bootstrap starts the audio owner exactly once.
assertThat(contains(bootstrap, "WeaponAudioController.start()"), "client bootstrap must start firearm audio")
local _, startCount = string.gsub(bootstrap, "WeaponAudioController.start()", "")
assertThat(startCount == 1, "firearm audio must start exactly once")

-- Registry honestly records the audio owner and its temporary status.
assertThat(
	contains(visualConfig, "src/client/Controllers/WeaponAudioController.luau"),
	"visual asset registry must attribute firearm audio to its owner"
)

print("FirearmAudioSourceAudit: bounded client-local fire and reload audio, deferred authority, and bootstrap passed")
