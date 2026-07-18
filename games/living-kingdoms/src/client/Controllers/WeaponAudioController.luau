--!strict

--[[
	AUD-0101 client-local firearm audio. This controller listens to the same
	authoritative CombatPresentation disclosure the visual effects use and plays
	a bounded, reused pool of 2D Sounds for accepted shots and reload starts.

	It creates no remote, requests no fire, resolves no hit, spends no
	ammunition, and never reaches the server. It only reacts to messages the
	server already decided to broadcast.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local CombatContracts = require(ReplicatedStorage.Shared.Combat.CombatContracts)
local FirearmAudioConfig = require(ReplicatedStorage.Shared.Config.FirearmAudioConfig)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)

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

local function playFire(isLocal: boolean)
	if #firePool == 0 then
		return
	end
	fireCursor = (fireCursor % #firePool) + 1
	local sound = firePool[fireCursor]
	local fire = FirearmAudioConfig.Fire
	sound.Volume = if isLocal then fire.LocalVolume else fire.RemoteVolume
	sound.PlaybackSpeed = fire.MinPlaybackSpeed + math.random() * (fire.MaxPlaybackSpeed - fire.MinPlaybackSpeed)
	sound.TimePosition = 0
	sound:Play()
end

local function playReload(isLocal: boolean)
	local sound = reloadSound
	if sound == nil then
		return
	end
	sound.Volume = if isLocal then FirearmAudioConfig.Reload.LocalVolume else FirearmAudioConfig.Reload.RemoteVolume
	sound.TimePosition = 0
	sound:Play()
end

local function onPresentationMessage(message: unknown)
	if type(message) ~= "table" then
		return
	end
	local payload = message :: any
	if payload.weaponId ~= FirearmConfig.BasicFirearm.WeaponId or not isNonEmptyString(payload.operativeEntityId) then
		return
	end
	if payload.kindId == CombatContracts.PresentationMessageKindIds.ShotFired then
		if isNonEmptyString(payload.shotId) then
			playFire(isLocalOperative(payload.operativeEntityId))
		end
	elseif payload.kindId == CombatContracts.PresentationMessageKindIds.ReloadStarted then
		playReload(isLocalOperative(payload.operativeEntityId))
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
