--!strict

--[[
	AUD-0103 client-local hostile audio. One frame connection reads existing
	replicated presentation attributes and plays bounded spatial cues for ordinary
	hostile actions, horde-role specials, Blight Spitter Corrosive Bloom, and the
	Progenitor Slam through one small reused Sound/emitter pool.

	The controller creates no remote, predicts nothing, reads no Humanoid health,
	and cannot move enemies, apply damage, establish death, or establish telegraph
	timing. Two folder lifecycle connections and one frame connection serve every
	tracked enemy; there are zero per-enemy connections, zero per-enemy Sounds,
	and zero delayed tasks.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EnemyAudioConfig = require(ReplicatedStorage.Shared.Config.EnemyAudioConfig)
local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local HordeSpecialTelegraphConfig = require(ReplicatedStorage.Shared.Config.HordeSpecialTelegraphConfig)
local SpecialEncounterTelegraphConfig = require(ReplicatedStorage.Shared.Config.SpecialEncounterTelegraphConfig)
local EnemyContracts = require(ReplicatedStorage.Shared.Combat.EnemyContracts)
local EnemyPresentationContracts = require(ReplicatedStorage.Shared.Visual.EnemyPresentationContracts)

local EnemyAudioController = {}

local PresentationAttributeNames = EnemyPresentationContracts.AttributeNames
local PresentationLifeStateIds = EnemyPresentationContracts.LifeStateIds
local BehaviorStateIds = EnemyContracts.EnemyBehaviorStateIds
local SpecialAttributeNames = HordeSpecialTelegraphConfig.AttributeNames
local SpecialKindIds = HordeSpecialTelegraphConfig.KindIds

local ENEMY_FOLDER_NAME = "EnemyEntities"
local SOUND_HOLDER_NAME = "LivingKingdomsEnemyAudio"
local EMITTER_HOLDER_NAME = "LivingKingdomsEnemyAudioEmitters"

local started = false
local enemyFolder: Folder? = nil
local descendantAddedConnection: RBXScriptConnection? = nil
local childRemovedConnection: RBXScriptConnection? = nil
local renderConnection: RBXScriptConnection? = nil
local soundHolder: Folder? = nil
local emitterHolder: Folder? = nil
local soundPool: { Sound } = {}
local emitterPool: { Part } = {}
local poolCursor = 0
local lastCuePlayClock: { [string]: number } = {}

type CueDefinition = {
	SoundId: string,
	Volume: number,
	PlaybackSpeed: number,
	MinimumIntervalSeconds: number,
}

type Record = {
	root: BasePart,
	lastBehaviorStateId: string,
	lastWindupSequence: number,
	lastAttackSequence: number,
	lastHitSequence: number,
	lastSpecialSequence: number,
	wasDead: boolean,
}

type EncounterRecord = {
	root: BasePart,
	kind: SpecialEncounterTelegraphConfig.DiscTelegraphKind,
	lastSequence: number,
}

local records: { [Model]: Record } = {}
local encounterRecords: { [Model]: EncounterRecord } = {}
local trackedCount = 0

local function readNumberAttribute(model: Model, attributeName: string): number?
	local value = model:GetAttribute(attributeName)
	return if type(value) == "number" then value else nil
end

local function readStringAttribute(model: Model, attributeName: string): string?
	local value = model:GetAttribute(attributeName)
	return if type(value) == "string" then value else nil
end

local function isRelevantEnemyModel(model: Model): boolean
	local archetypeId = model:GetAttribute("EnemyArchetypeId")
	return archetypeId == EnemyConfig.Walker.ArchetypeId
		or SpecialEncounterTelegraphConfig.discKindForArchetypeId(archetypeId) ~= nil
end

local function findEnemyModel(instance: Instance): Model?
	local folder = enemyFolder
	local current: Instance? = instance
	while current ~= nil and current ~= folder do
		if current:IsA("Model") and isRelevantEnemyModel(current) then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function createPresentation()
	local holder = Instance.new("Folder")
	holder.Name = SOUND_HOLDER_NAME
	holder.Parent = Workspace

	local emitters = Instance.new("Folder")
	emitters.Name = EMITTER_HOLDER_NAME
	emitters.Parent = Workspace

	for index = 1, EnemyAudioConfig.PoolSize do
		local emitter = Instance.new("Part")
		emitter.Name = "EnemyCueEmitter" .. tostring(index)
		emitter.Size = Vector3.new(0.1, 0.1, 0.1)
		emitter.Transparency = 1
		emitter.Anchored = true
		emitter.CanCollide = false
		emitter.CanTouch = false
		emitter.CanQuery = false
		emitter.CastShadow = false
		emitter.CFrame = CFrame.new(0, -1000, 0)
		emitter.Parent = emitters
		table.insert(emitterPool, emitter)

		local sound = Instance.new("Sound")
		sound.Name = "EnemyCue" .. tostring(index)
		sound.RollOffMode = Enum.RollOffMode.Inverse
		sound.RollOffMinDistance = EnemyAudioConfig.SpatialRollOffMinDistanceStuds
		sound.RollOffMaxDistance = EnemyAudioConfig.SpatialRollOffMaxDistanceStuds
		sound.EmitterSize = EnemyAudioConfig.SpatialEmitterSizeStuds
		sound.Parent = emitter
		table.insert(soundPool, sound)
	end

	soundHolder = holder
	emitterHolder = emitters
end

local function distanceVolumeScale(root: BasePart): number
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return 0
	end
	local distance = (camera.CFrame.Position - root.Position).Magnitude
	if distance >= EnemyAudioConfig.MaximumAudibleDistanceStuds then
		return 0
	end
	if distance <= EnemyAudioConfig.FullVolumeDistanceStuds then
		return 1
	end
	return 1
		- (distance - EnemyAudioConfig.FullVolumeDistanceStuds)
			/ (EnemyAudioConfig.MaximumAudibleDistanceStuds - EnemyAudioConfig.FullVolumeDistanceStuds)
end

local function playCue(cueName: string, cue: CueDefinition, root: BasePart)
	if #soundPool == 0 then
		return
	end
	local scale = distanceVolumeScale(root)
	if scale <= 0 then
		return
	end
	local nowClock = os.clock()
	local lastPlayClock = lastCuePlayClock[cueName]
	if lastPlayClock ~= nil and nowClock - lastPlayClock < cue.MinimumIntervalSeconds then
		return
	end
	lastCuePlayClock[cueName] = nowClock
	poolCursor = (poolCursor % #soundPool) + 1
	local sound = soundPool[poolCursor]
	local emitter = emitterPool[poolCursor]
	if emitter == nil then
		return
	end
	emitter.Position = root.Position
	sound.SoundId = cue.SoundId
	sound.Volume = math.clamp(cue.Volume * scale, 0, 1)
	sound.PlaybackSpeed = cue.PlaybackSpeed
	sound.TimePosition = 0
	sound:Play()
end

local function trackWalker(model: Model, root: BasePart)
	if model:GetAttribute("EnemyArchetypeId") ~= EnemyConfig.Walker.ArchetypeId or records[model] ~= nil then
		return
	end
	local behaviorStateId = readStringAttribute(model, PresentationAttributeNames.BehaviorStateId)
	local lifeStateId = readStringAttribute(model, PresentationAttributeNames.LifeStateId)
	local windupSequence = readNumberAttribute(model, PresentationAttributeNames.WindupSequence)
	local attackSequence = readNumberAttribute(model, PresentationAttributeNames.AttackSequence)
	local hitSequence = readNumberAttribute(model, PresentationAttributeNames.HitSequence)
	local specialSequence = readNumberAttribute(model, SpecialAttributeNames.Sequence) or 0
	if
		behaviorStateId == nil
		or lifeStateId == nil
		or windupSequence == nil
		or attackSequence == nil
		or hitSequence == nil
	then
		return
	end

	records[model] = {
		root = root,
		lastBehaviorStateId = behaviorStateId,
		lastWindupSequence = windupSequence,
		lastAttackSequence = attackSequence,
		lastHitSequence = hitSequence,
		lastSpecialSequence = specialSequence,
		wasDead = lifeStateId == PresentationLifeStateIds.Dead,
	}
end

local function trackEncounterTelegraph(model: Model, root: BasePart)
	if encounterRecords[model] ~= nil then
		return
	end
	local kind = SpecialEncounterTelegraphConfig.discKindForArchetypeId(model:GetAttribute("EnemyArchetypeId"))
	if kind == nil then
		return
	end
	local sequence = readNumberAttribute(model, kind.SequenceAttribute)
	if sequence == nil then
		return
	end
	encounterRecords[model] = {
		root = root,
		kind = kind,
		lastSequence = sequence,
	}
end

local function trackModel(model: Model)
	if trackedCount >= EnemyAudioConfig.MaximumTrackedEnemyModels or not isRelevantEnemyModel(model) then
		return
	end
	if records[model] ~= nil or encounterRecords[model] ~= nil then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end

	trackWalker(model, root)
	trackEncounterTelegraph(model, root)
	if records[model] ~= nil or encounterRecords[model] ~= nil then
		trackedCount += 1
	end
end

local function untrackModel(model: Model)
	local wasTracked = records[model] ~= nil or encounterRecords[model] ~= nil
	records[model] = nil
	encounterRecords[model] = nil
	if wasTracked then
		trackedCount = math.max(0, trackedCount - 1)
	end
end

local function updateRecord(model: Model, record: Record)
	local behaviorStateId = readStringAttribute(model, PresentationAttributeNames.BehaviorStateId)
	local lifeStateId = readStringAttribute(model, PresentationAttributeNames.LifeStateId)
	local windupSequence = readNumberAttribute(model, PresentationAttributeNames.WindupSequence)
	local attackSequence = readNumberAttribute(model, PresentationAttributeNames.AttackSequence)
	local hitSequence = readNumberAttribute(model, PresentationAttributeNames.HitSequence)
	local specialSequence = readNumberAttribute(model, SpecialAttributeNames.Sequence) or record.lastSpecialSequence
	local specialKindId = readStringAttribute(model, SpecialAttributeNames.KindId)
	if
		behaviorStateId == nil
		or lifeStateId == nil
		or windupSequence == nil
		or attackSequence == nil
		or hitSequence == nil
	then
		return
	end

	local isDead = lifeStateId == PresentationLifeStateIds.Dead
	local becameDead = isDead and not record.wasDead
	local becamePursuing = behaviorStateId == BehaviorStateIds.Pursuing
		and (
			record.lastBehaviorStateId == BehaviorStateIds.Roaming
			or record.lastBehaviorStateId == BehaviorStateIds.StandDown
		)

	if becameDead then
		playCue("Death", EnemyAudioConfig.Death, record.root)
	elseif not isDead then
		if attackSequence > record.lastAttackSequence then
			playCue("Strike", EnemyAudioConfig.Strike, record.root)
		elseif windupSequence > record.lastWindupSequence then
			playCue("Windup", EnemyAudioConfig.Windup, record.root)
		elseif becamePursuing then
			playCue("Alert", EnemyAudioConfig.Alert, record.root)
		end
		if hitSequence > record.lastHitSequence then
			playCue("Hit", EnemyAudioConfig.Hit, record.root)
		end
	end

	if specialSequence > record.lastSpecialSequence then
		if specialKindId == SpecialKindIds.ScreamerReinforcement then
			playCue("ScreamerWarning", EnemyAudioConfig.ScreamerWarning, record.root)
		elseif specialKindId == SpecialKindIds.BloaterDeathBurst then
			playCue("BloaterWarning", EnemyAudioConfig.BloaterWarning, record.root)
		elseif specialKindId == SpecialKindIds.BruteSecondPhase then
			playCue("BruteWarning", EnemyAudioConfig.BruteWarning, record.root)
		end
	end

	record.lastBehaviorStateId = behaviorStateId
	record.lastWindupSequence = windupSequence
	record.lastAttackSequence = attackSequence
	record.lastHitSequence = hitSequence
	record.lastSpecialSequence = specialSequence
	record.wasDead = isDead
end

local function updateEncounterRecord(model: Model, record: EncounterRecord)
	local sequence = readNumberAttribute(model, record.kind.SequenceAttribute)
	if sequence == nil or sequence <= record.lastSequence then
		return
	end
	record.lastSequence = sequence
	if record.kind.Id == SpecialEncounterTelegraphConfig.Bloom.Id then
		playCue("SpitterBloomWarning", EnemyAudioConfig.SpitterBloomWarning, record.root)
	elseif record.kind.Id == SpecialEncounterTelegraphConfig.Slam.Id then
		playCue("ProgenitorSlamWarning", EnemyAudioConfig.ProgenitorSlamWarning, record.root)
	end
end

function EnemyAudioController.start()
	if started then
		return
	end
	started = true
	createPresentation()

	local folder = Workspace:WaitForChild(ENEMY_FOLDER_NAME)
	assert(folder:IsA("Folder"), "EnemyEntities must be a Folder")
	enemyFolder = folder
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			trackModel(child)
		end
	end

	descendantAddedConnection = folder.DescendantAdded:Connect(function(descendant)
		local model = findEnemyModel(descendant)
		if model ~= nil then
			trackModel(model)
		end
	end)
	childRemovedConnection = folder.ChildRemoved:Connect(function(child)
		if child:IsA("Model") then
			untrackModel(child)
		end
	end)
	renderConnection = RunService.RenderStepped:Connect(function()
		local staleModels: { Model } = {}
		for model, record in records do
			if model.Parent == nil or record.root.Parent == nil then
				table.insert(staleModels, model)
			else
				updateRecord(model, record)
			end
		end
		for model, record in encounterRecords do
			if model.Parent == nil or record.root.Parent == nil then
				table.insert(staleModels, model)
			else
				updateEncounterRecord(model, record)
			end
		end
		for _, model in staleModels do
			untrackModel(model)
		end
	end)
end

function EnemyAudioController.stop()
	if not started then
		return
	end
	started = false
	if descendantAddedConnection ~= nil then
		descendantAddedConnection:Disconnect()
		descendantAddedConnection = nil
	end
	if childRemovedConnection ~= nil then
		childRemovedConnection:Disconnect()
		childRemovedConnection = nil
	end
	if renderConnection ~= nil then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	if soundHolder ~= nil then
		soundHolder:Destroy()
		soundHolder = nil
	end
	if emitterHolder ~= nil then
		emitterHolder:Destroy()
		emitterHolder = nil
	end
	table.clear(soundPool)
	table.clear(emitterPool)
	poolCursor = 0
	table.clear(lastCuePlayClock)
	table.clear(records)
	table.clear(encounterRecords)
	trackedCount = 0
	enemyFolder = nil
end

return table.freeze(EnemyAudioController)
