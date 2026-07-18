--!strict

--[[
	Client-local firearm audio. This controller listens to authoritative combat
	presentation and reuses a bounded Sound pool. Per-weapon profiles change only
	volume and playback speed so the roster reads differently without widening
	combat authority or creating per-shot instances.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local CombatContracts = require(ReplicatedStorage.Shared.Combat.CombatContracts)
local FirearmAudioConfig = require(ReplicatedStorage.Shared.Config.FirearmAudioConfig)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)
local WeaponFeelConfig = require(ReplicatedStorage.Shared.Config.WeaponFeelConfig)

local function resolveWeaponDefinition(weaponId: unknown)
	local getter = FirearmConfig.get
	if type(getter) == "function" then
		return getter(weaponId)
	end
	local basic = FirearmConfig.BasicFirearm
	return if basic ~= nil and weaponId == basic.WeaponId then basic else nil
end

local function isKnownWeaponId(weaponId: unknown): boolean
	return resolveWeaponDefinition(weaponId) ~= nil and WeaponFeelConfig.get(weaponId) ~= nil
end

local Controller = {}

local localPlayer = Players.LocalPlayer
local started = false
local connection: RBXScriptConnection? = nil
local soundHolder: Folder? = nil
local firePool: { Sound } = {}
local fireCursor = 0
local reloadSound: Sound? = nil

local combatNetwork = ReplicatedStorage:WaitForChild("CombatNetwork")
local presentationRemote = combatNetwork:WaitForChild("CombatPresentation") :: RemoteEvent

local function isNonEmptyString(value: unknown): boolean
	return type(value) == "string" and value ~= ""
end

local function isLocalOperative(operativeEntityId: string): boolean
	return operativeEntityId == "operative.player:" .. tostring(localPlayer.UserId)
end

local function createPresentation()
	local holder = Instance.new("Folder")
	holder.Name = "LivingKingdomsFirearmAudio"

	for index = 1, FirearmAudioConfig.FirePoolSize do
		local sound = Instance.new("Sound")
		sound.Name = "Fire" .. tostring(index)
		sound.SoundId = FirearmAudioConfig.Fire.SoundId
		sound.Volume = FirearmAudioConfig.Fire.LocalVolume
		sound.RollOffMode = Enum.RollOffMode.Inverse
		sound.Parent = holder
		table.insert(firePool, sound)
	end

	local reload = Instance.new("Sound")
	reload.Name = "Reload"
	reload.SoundId = FirearmAudioConfig.Reload.SoundId
	reload.Volume = FirearmAudioConfig.Reload.LocalVolume
	reload.Parent = holder
	reloadSound = reload

	holder.Parent = SoundService
	soundHolder = holder
end

local function playFire(isLocal: boolean, weaponId: string)
	if #firePool == 0 then
		return
	end
	local profile = WeaponFeelConfig.get(weaponId)
	if profile == nil then
		return
	end
	fireCursor = (fireCursor % #firePool) + 1
	local sound = firePool[fireCursor]
	local fire = FirearmAudioConfig.Fire
	local baseVolume = if isLocal then fire.LocalVolume else fire.RemoteVolume
	sound.Volume = math.clamp(baseVolume * profile.AudioVolumeMultiplier, 0, 2)
	local minimumSpeed = fire.MinPlaybackSpeed * profile.AudioPitchMinimumMultiplier
	local maximumSpeed = fire.MaxPlaybackSpeed * profile.AudioPitchMaximumMultiplier
	sound.PlaybackSpeed = minimumSpeed + math.random() * (maximumSpeed - minimumSpeed)
	sound.TimePosition = 0
	sound:Play()
end

local function playReload(isLocal: boolean, weaponId: string)
	local sound = reloadSound
	local profile = WeaponFeelConfig.get(weaponId)
	if sound == nil or profile == nil then
		return
	end
	local baseVolume = if isLocal then FirearmAudioConfig.Reload.LocalVolume else FirearmAudioConfig.Reload.RemoteVolume
	sound.Volume = math.clamp(baseVolume * profile.ReloadVolumeMultiplier, 0, 2)
	sound.PlaybackSpeed = profile.ReloadPlaybackSpeedMultiplier
	sound.TimePosition = 0
	sound:Play()
end

local function onPresentationMessage(message: unknown)
	if type(message) ~= "table" then
		return
	end
	local payload = message :: any
	if not isKnownWeaponId(payload.weaponId) or not isNonEmptyString(payload.operativeEntityId) then
		return
	end
	if payload.kindId == CombatContracts.PresentationMessageKindIds.ShotFired then
		if isNonEmptyString(payload.shotId) then
			playFire(isLocalOperative(payload.operativeEntityId), payload.weaponId)
		end
	elseif payload.kindId == CombatContracts.PresentationMessageKindIds.ReloadStarted then
		playReload(isLocalOperative(payload.operativeEntityId), payload.weaponId)
	end
end

function Controller.start()
	if started then
		return
	end
	started = true
	createPresentation()
	connection = presentationRemote.OnClientEvent:Connect(onPresentationMessage)
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	if connection ~= nil then
		connection:Disconnect()
		connection = nil
	end
	if soundHolder ~= nil then
		soundHolder:Destroy()
		soundHolder = nil
	end
	table.clear(firePool)
	fireCursor = 0
	reloadSound = nil
end

return Controller
