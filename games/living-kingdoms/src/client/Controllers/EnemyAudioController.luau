--!strict

--[[
	AUD-0103 client-local Exclusion Walker audio. One frame connection reads the
	existing replicated presentation attributes and plays bounded 2D cues for
	alert (entering pursuit), attack windup, committed strike, confirmed hit,
	and death through one small reused Sound pool with per-cue global throttles
	and camera-distance volume falloff.

	The controller creates no remote, predicts nothing, reads no Humanoid
	health, and cannot move enemies, apply damage, establish death, or disclose
	anything the replicated enemy models do not already carry. Two folder
	lifecycle connections and one frame connection serve every tracked enemy;
	there are zero per-enemy connections, zero per-enemy Sounds, and zero
	delayed tasks.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local EnemyAudioConfig = require(ReplicatedStorage.Shared.Config.EnemyAudioConfig)
local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local EnemyContracts = require(ReplicatedStorage.Shared.Combat.EnemyContracts)
local EnemyPresentationContracts = require(ReplicatedStorage.Shared.Visual.EnemyPresentationContracts)

local EnemyAudioController = {}

local PresentationAttributeNames = EnemyPresentationContracts.AttributeNames
local PresentationLifeStateIds = EnemyPresentationContracts.LifeStateIds
local BehaviorStateIds = EnemyContracts.EnemyBehaviorStateIds

local ENEMY_FOLDER_NAME = "EnemyEntities"
local SOUND_HOLDER_NAME = "LivingKingdomsEnemyAudio"

local started = false
local enemyFolder: Folder? = nil
local descendantAddedConnection: RBXScriptConnection? = nil
local childRemovedConnection: RBXScriptConnection? = nil
local renderConnection: RBXScriptConnection? = nil
local soundHolder: Folder? = nil
local soundPool: { Sound } = {}
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
	wasDead: boolean,
}

local records: { [Model]: Record } = {}
local trackedCount = 0

local function readNumberAttribute(model: Model, attributeName: string): number?
	local value = model:GetAttribute(attributeName)
	return if type(value) == "number" then value else nil
end

local function readStringAttribute(model: Model, attributeName: string): string?
	local value = model:GetAttribute(attributeName)
	return if type(value) == "string" then value else nil
end

local function findEnemyModel(instance: Instance): Model?
	local folder = enemyFolder
	local current: Instance? = instance
	while current ~= nil and current ~= folder do
		if current:IsA("Model") and current:GetAttribute("EnemyArchetypeId") == EnemyConfig.Walker.ArchetypeId then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function createPresentation()
	local holder = Instance.new("Folder")
	holder.Name = SOUND_HOLDER_NAME

	for index = 1, EnemyAudioConfig.PoolSize do
		local sound = Instance.new("Sound")
		sound.Name = "EnemyCue" .. tostring(index)
		sound.Parent = holder
		table.insert(soundPool, sound)
	end

	holder.Parent = SoundService
	soundHolder = holder
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

local function playCue(cueName: string, cue: CueDefinition, record: Record)
	if #soundPool == 0 then
		return
	end
	local scale = distanceVolumeScale(record.root)
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
	sound.SoundId = cue.SoundId
	sound.Volume = math.clamp(cue.Volume * scale, 0, 1)
	sound.PlaybackSpeed = cue.PlaybackSpeed
	sound.TimePosition = 0
	sound:Play()
end

local function trackModel(model: Model)
	if
		records[model] ~= nil
		or trackedCount >= EnemyAudioConfig.MaximumTrackedEnemyModels
		or model:GetAttribute("EnemyArchetypeId") ~= EnemyConfig.Walker.ArchetypeId
	then
		return
	end

	local root = model:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local behaviorStateId = readStringAttribute(model, PresentationAttributeNames.BehaviorStateId)
	local lifeStateId = readStringAttribute(model, PresentationAttributeNames.LifeStateId)
	local windupSequence = readNumberAttribute(model, PresentationAttributeNames.WindupSequence)
	local attackSequence = readNumberAttribute(model, PresentationAttributeNames.AttackSequence)
	local hitSequence = readNumberAttribute(model, PresentationAttributeNames.HitSequence)
	if
		behaviorStateId == nil
		or lifeStateId == nil
		or windupSequence == nil
		or attackSequence == nil
		or hitSequence == nil
	then
		return
	end

	-- First sight records the replicated state silently so joining a session
	-- mid-operation cannot trigger a burst of stale cues.
	records[model] = {
		root = root,
		lastBehaviorStateId = behaviorStateId,
		lastWindupSequence = windupSequence,
		lastAttackSequence = attackSequence,
		lastHitSequence = hitSequence,
		wasDead = lifeStateId == PresentationLifeStateIds.Dead,
	}
	trackedCount += 1
end

local function untrackModel(model: Model)
	if records[model] == nil then
		return
	end
	records[model] = nil
	trackedCount = math.max(0, trackedCount - 1)
end

local function updateRecord(model: Model, record: Record)
	local behaviorStateId = readStringAttribute(model, PresentationAttributeNames.BehaviorStateId)
	local lifeStateId = readStringAttribute(model, PresentationAttributeNames.LifeStateId)
	local windupSequence = readNumberAttribute(model, PresentationAttributeNames.WindupSequence)
	local attackSequence = readNumberAttribute(model, PresentationAttributeNames.AttackSequence)
	local hitSequence = readNumberAttribute(model, PresentationAttributeNames.HitSequence)
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
		playCue("Death", EnemyAudioConfig.Death, record)
	elseif not isDead then
		if attackSequence > record.lastAttackSequence then
			playCue("Strike", EnemyAudioConfig.Strike, record)
		elseif windupSequence > record.lastWindupSequence then
			playCue("Windup", EnemyAudioConfig.Windup, record)
		elseif becamePursuing then
			playCue("Alert", EnemyAudioConfig.Alert, record)
		end
		if hitSequence > record.lastHitSequence then
			playCue("Hit", EnemyAudioConfig.Hit, record)
		end
	end

	record.lastBehaviorStateId = behaviorStateId
	record.lastWindupSequence = windupSequence
	record.lastAttackSequence = attackSequence
	record.lastHitSequence = hitSequence
	record.wasDead = isDead
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
	table.clear(soundPool)
	poolCursor = 0
	table.clear(lastCuePlayClock)
	table.clear(records)
	trackedCount = 0
	enemyFolder = nil
end

return table.freeze(EnemyAudioController)
