--!strict

--[[
	Client-local firearm audio. This controller listens to authoritative combat
	presentation and reuses a bounded Sound set: a round-robin fire pool plus
	single reload, empty-click, and handling Sounds. Local weapon audio stays 2D
	for immediate first-person punch, while remote accepted shots are emitted from
	bounded invisible world emitters at the server-disclosed shooter's position so
	co-op gunfire carries directional information. Per-weapon profiles change only
	presentation volume and playback speed; no combat authority lives here.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--[[
	Bounded so a network folder the server has not created yet fails this one
	controller instead of stalling the whole client bootstrap. The bootstrap
	requires controllers in a deliberate order with no isolation, so an
	unbounded wait here would hold every controller after it forever.
]]
local NETWORK_WAIT_SECONDS = 20
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

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
local emitterHolder: Folder? = nil
local firePool: { Sound } = {}
local fireEmitters: { Part } = {}
local fireCursor = 0
local reloadSound: Sound? = nil
local emptySound: Sound? = nil
local handlingSound: Sound? = nil
local reloadSoundOperativeEntityId: string? = nil
local lastKnownLoadedRounds: number? = nil
local lastEmptyCueClock = -math.huge

local combatNetwork = ReplicatedStorage:WaitForChild("CombatNetwork", NETWORK_WAIT_SECONDS)
assert(combatNetwork ~= nil, "CombatNetwork did not become available before the client bootstrap timeout")
local presentationRemote = combatNetwork:WaitForChild("CombatPresentation", NETWORK_WAIT_SECONDS) :: RemoteEvent?
assert(
	presentationRemote ~= nil,
	"CombatNetwork.CombatPresentation did not become available before the client bootstrap timeout"
)

local function isNonEmptyString(value: unknown): boolean
	return type(value) == "string" and value ~= ""
end

local function isWholeNonnegative(value: unknown): boolean
	return type(value) == "number" and value == value and value >= 0 and value % 1 == 0
end

local function operativeEntityIdForPlayer(player: Player): string
	return "operative.player:" .. tostring(player.UserId)
end

local function isLocalOperative(operativeEntityId: string): boolean
	return operativeEntityId == operativeEntityIdForPlayer(localPlayer)
end

local function playerForOperativeEntityId(operativeEntityId: string): Player?
	for _, player in Players:GetPlayers() do
		if operativeEntityIdForPlayer(player) == operativeEntityId then
			return player
		end
	end
	return nil
end

local function remoteFirePosition(operativeEntityId: string): Vector3?
	local player = playerForOperativeEntityId(operativeEntityId)
	local character = if player == nil then nil else player.Character
	local root = if character == nil then nil else character:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then root.Position else nil
end

local function createPresentation()
	local holder = Instance.new("Folder")
	holder.Name = "LivingKingdomsFirearmAudio"

	local emitters = Instance.new("Folder")
	emitters.Name = "LivingKingdomsRemoteFireEmitters"
	emitters.Parent = Workspace

	for index = 1, FirearmAudioConfig.FirePoolSize do
		local sound = Instance.new("Sound")
		sound.Name = "Fire" .. tostring(index)
		sound.SoundId = FirearmAudioConfig.Fire.SoundId
		sound.Volume = FirearmAudioConfig.Fire.LocalVolume
		sound.RollOffMode = Enum.RollOffMode.Inverse
		sound.RollOffMinDistance = FirearmAudioConfig.Fire.RemoteRollOffMinDistanceStuds
		sound.RollOffMaxDistance = FirearmAudioConfig.Fire.RemoteRollOffMaxDistanceStuds
		sound.EmitterSize = FirearmAudioConfig.Fire.RemoteEmitterSizeStuds
		sound.Parent = holder
		table.insert(firePool, sound)

		local emitter = Instance.new("Part")
		emitter.Name = "FireEmitter" .. tostring(index)
		emitter.Size = Vector3.new(0.1, 0.1, 0.1)
		emitter.Transparency = 1
		emitter.Anchored = true
		emitter.CanCollide = false
		emitter.CanTouch = false
		emitter.CanQuery = false
		emitter.CastShadow = false
		emitter.CFrame = CFrame.new(0, -1000, 0)
		emitter.Parent = emitters
		table.insert(fireEmitters, emitter)
	end

	local reload = Instance.new("Sound")
	reload.Name = "Reload"
	reload.SoundId = FirearmAudioConfig.Reload.SoundId
	reload.Volume = FirearmAudioConfig.Reload.LocalVolume
	reload.Parent = holder
	reloadSound = reload

	local empty = Instance.new("Sound")
	empty.Name = "Empty"
	empty.SoundId = FirearmAudioConfig.Empty.SoundId
	empty.Volume = FirearmAudioConfig.Empty.LocalVolume
	empty.Parent = holder
	emptySound = empty

	local handling = Instance.new("Sound")
	handling.Name = "Handling"
	handling.SoundId = FirearmAudioConfig.Handling.SoundId
	handling.Volume = FirearmAudioConfig.Handling.LocalVolume
	handling.Parent = holder
	handlingSound = handling

	holder.Parent = SoundService
	soundHolder = holder
	emitterHolder = emitters
end

local function playFire(isLocal: boolean, weaponId: string, operativeEntityId: string)
	if #firePool == 0 then
		return
	end
	local profile = WeaponFeelConfig.get(weaponId)
	if profile == nil then
		return
	end
	fireCursor = (fireCursor % #firePool) + 1
	local sound = firePool[fireCursor]
	local emitter = fireEmitters[fireCursor]
	local holder = soundHolder
	local fire = FirearmAudioConfig.Fire
	local baseVolume = if isLocal then fire.LocalVolume else fire.RemoteVolume
	sound.Volume = math.clamp(baseVolume * profile.AudioVolumeMultiplier, 0, 2)
	local minimumSpeed = fire.MinPlaybackSpeed * profile.AudioPitchMinimumMultiplier
	local maximumSpeed = fire.MaxPlaybackSpeed * profile.AudioPitchMaximumMultiplier
	sound.PlaybackSpeed = minimumSpeed + math.random() * (maximumSpeed - minimumSpeed)

	local position = if isLocal then nil else remoteFirePosition(operativeEntityId)
	if position ~= nil and emitter ~= nil then
		emitter.Position = position
		sound.Parent = emitter
	elseif holder ~= nil then
		-- Fail soft to the existing non-positional presentation if the remote
		-- character has already despawned by the time its accepted shot arrives.
		sound.Parent = holder
	end
	sound.TimePosition = 0
	sound:Play()
end

local function playReload(isLocal: boolean, weaponId: string, operativeEntityId: string)
	local sound = reloadSound
	local profile = WeaponFeelConfig.get(weaponId)
	if sound == nil or profile == nil then
		return
	end
	local baseVolume = if isLocal then FirearmAudioConfig.Reload.LocalVolume else FirearmAudioConfig.Reload.RemoteVolume
	sound.Volume = math.clamp(baseVolume * profile.ReloadVolumeMultiplier, 0, 2)
	sound.PlaybackSpeed = profile.ReloadPlaybackSpeedMultiplier
	sound.TimePosition = 0
	reloadSoundOperativeEntityId = operativeEntityId
	sound:Play()
end

local function stopReloadForOperative(operativeEntityId: string)
	local sound = reloadSound
	if sound ~= nil and reloadSoundOperativeEntityId == operativeEntityId then
		sound:Stop()
		reloadSoundOperativeEntityId = nil
	end
end

local function playHandling(isLocal: boolean, weaponId: string)
	local sound = handlingSound
	local profile = WeaponFeelConfig.get(weaponId)
	if sound == nil or profile == nil then
		return
	end
	local handling = FirearmAudioConfig.Handling
	local baseVolume = if isLocal then handling.LocalVolume else handling.RemoteVolume
	sound.Volume = math.clamp(baseVolume * profile.ReloadVolumeMultiplier, 0, 2)
	sound.PlaybackSpeed = handling.PlaybackSpeed * profile.ReloadPlaybackSpeedMultiplier
	sound.TimePosition = 0
	sound:Play()
end

local function playEmptyClick(weaponId: string)
	local sound = emptySound
	local profile = WeaponFeelConfig.get(weaponId)
	if sound == nil or profile == nil then
		return
	end
	local nowClock = os.clock()
	if nowClock - lastEmptyCueClock < FirearmAudioConfig.Empty.MinimumIntervalSeconds then
		return
	end
	lastEmptyCueClock = nowClock
	local empty = FirearmAudioConfig.Empty
	sound.Volume = math.clamp(empty.LocalVolume * profile.AudioVolumeMultiplier, 0, 2)
	sound.PlaybackSpeed = empty.PlaybackSpeed
	sound.TimePosition = 0
	sound:Play()
end

local function onAmmunitionMessage(payload: any)
	if not isKnownWeaponId(payload.weaponId) or not isWholeNonnegative(payload.loadedRounds) then
		return
	end
	local previousLoadedRounds = lastKnownLoadedRounds
	lastKnownLoadedRounds = payload.loadedRounds
	if previousLoadedRounds ~= nil and previousLoadedRounds > 0 and payload.loadedRounds == 0 then
		playEmptyClick(payload.weaponId)
	end
end

local function onPresentationMessage(message: unknown)
	if type(message) ~= "table" then
		return
	end
	local payload = message :: any
	local kindId = payload.kindId
	if
		kindId == CombatContracts.PresentationMessageKindIds.AmmunitionState
		or kindId == CombatContracts.PresentationMessageKindIds.AmmunitionCollected
	then
		-- Ammunition disclosures are personal payloads about the local
		-- operative and carry no operative identity.
		onAmmunitionMessage(payload)
		return
	end
	if not isKnownWeaponId(payload.weaponId) or not isNonEmptyString(payload.operativeEntityId) then
		return
	end
	local isLocal = isLocalOperative(payload.operativeEntityId)
	if kindId == CombatContracts.PresentationMessageKindIds.ShotFired then
		if isNonEmptyString(payload.shotId) then
			playFire(isLocal, payload.weaponId, payload.operativeEntityId)
		end
	elseif kindId == CombatContracts.PresentationMessageKindIds.ReloadStarted then
		playReload(isLocal, payload.weaponId, payload.operativeEntityId)
	elseif kindId == CombatContracts.PresentationMessageKindIds.ReloadCompleted then
		stopReloadForOperative(payload.operativeEntityId)
		playHandling(isLocal, payload.weaponId)
	elseif kindId == CombatContracts.PresentationMessageKindIds.ReloadInterrupted then
		stopReloadForOperative(payload.operativeEntityId)
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
	if emitterHolder ~= nil then
		emitterHolder:Destroy()
		emitterHolder = nil
	end
	table.clear(firePool)
	table.clear(fireEmitters)
	fireCursor = 0
	reloadSound = nil
	emptySound = nil
	handlingSound = nil
	reloadSoundOperativeEntityId = nil
	lastKnownLoadedRounds = nil
	lastEmptyCueClock = -math.huge
end

return Controller
