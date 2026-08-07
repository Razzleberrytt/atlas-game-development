--!strict

--[[
	HROI-0104 client-local combat impact for server-confirmed enemy hits and
	deaths. One frame connection reads the existing replicated presentation
	attributes and emits bounded particles plus a brief occluded highlight.

	The controller creates no remote, predicts no hit, reads no Humanoid health,
	and cannot move enemies, apply damage, establish death, award XP, create
	loot, or change cleanup. Two folder lifecycle connections and one frame
	connection serve every tracked enemy; there are zero per-enemy connections
	and zero delayed tasks.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CombatImpactPresentationConfig = require(ReplicatedStorage.Shared.Config.CombatImpactPresentationConfig)
local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)
local EnemyPresentationContracts = require(ReplicatedStorage.Shared.Visual.EnemyPresentationContracts)
local PresentationAccessibilityConfig = require(ReplicatedStorage.Shared.Config.PresentationAccessibilityConfig)
local PresentationAccessibilityState = require(script.Parent.Parent.Presentation.PresentationAccessibilityState)

local EnemyImpactPresentationController = {}

local PresentationAttributeNames = EnemyPresentationContracts.AttributeNames
local PresentationLifeStateIds = EnemyPresentationContracts.LifeStateIds

local ENEMY_FOLDER_NAME = "EnemyEntities"
local EFFECT_ATTACHMENT_NAME = "LK_LocalCombatImpactFX"
local HIT_EMITTER_NAME = "HitBurst"
local KILL_EMITTER_NAME = "KillBurst"
local HIGHLIGHT_NAME = "CombatImpactHighlight"

local HIT_FLASH_COLOR = Color3.fromRGB(255, 238, 218)
local KILL_FLASH_COLOR = Color3.fromRGB(178, 24, 31)
local BLOOD_DARK = Color3.fromRGB(92, 7, 14)
local BLOOD_MID = Color3.fromRGB(151, 13, 23)
local BLOOD_BRIGHT = Color3.fromRGB(215, 36, 43)

local PARTICLE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local started = false
local enemyFolder: Folder? = nil
local descendantAddedConnection: RBXScriptConnection? = nil
local childRemovedConnection: RBXScriptConnection? = nil
local renderConnection: RBXScriptConnection? = nil

type Record = {
	root: BasePart,
	effectAttachment: Attachment,
	hitEmitter: ParticleEmitter,
	killEmitter: ParticleEmitter,
	highlight: Highlight,
	lastHitSequence: number,
	wasDead: boolean,
	flashUntilServerTimestamp: number,
}

local records: { [Model]: Record } = {}
local trackingModels: { [Model]: boolean } = {}
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

local function configureEmitter(emitter: ParticleEmitter)
	emitter.Enabled = false
	emitter.Rate = 0
	emitter.Texture = PARTICLE_TEXTURE
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = 0.08
	emitter.LightInfluence = 0.35
	emitter.LockedToPart = false
	emitter.Orientation = Enum.ParticleOrientation.FacingCamera
	emitter.Rotation = NumberRange.new(-180, 180)
	emitter.RotSpeed = NumberRange.new(-240, 240)
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, BLOOD_BRIGHT),
		ColorSequenceKeypoint.new(0.45, BLOOD_MID),
		ColorSequenceKeypoint.new(1, BLOOD_DARK),
	})
end

local function createEffectObjects(
	model: Model,
	root: BasePart
): (Attachment, ParticleEmitter, ParticleEmitter, Highlight)
	local staleAttachment = root:FindFirstChild(EFFECT_ATTACHMENT_NAME)
	if staleAttachment ~= nil then
		staleAttachment:Destroy()
	end
	local staleHighlight = model:FindFirstChild(HIGHLIGHT_NAME)
	if staleHighlight ~= nil then
		staleHighlight:Destroy()
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = EFFECT_ATTACHMENT_NAME
	attachment.Position = Vector3.new(0, 0.35, 0)
	attachment.Parent = root

	local hitEmitter = Instance.new("ParticleEmitter")
	hitEmitter.Name = HIT_EMITTER_NAME
	configureEmitter(hitEmitter)
	hitEmitter.Lifetime = NumberRange.new(0.16, 0.30)
	hitEmitter.Speed = NumberRange.new(8, 14)
	hitEmitter.Drag = 5
	hitEmitter.Acceleration = Vector3.new(0, -30, 0)
	hitEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.34),
		NumberSequenceKeypoint.new(0.45, 0.20),
		NumberSequenceKeypoint.new(1, 0),
	})
	hitEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12),
		NumberSequenceKeypoint.new(0.75, 0.28),
		NumberSequenceKeypoint.new(1, 1),
	})
	hitEmitter.Parent = attachment

	local killEmitter = Instance.new("ParticleEmitter")
	killEmitter.Name = KILL_EMITTER_NAME
	configureEmitter(killEmitter)
	killEmitter.Lifetime = NumberRange.new(0.30, 0.52)
	killEmitter.Speed = NumberRange.new(11, 20)
	killEmitter.Drag = 4
	killEmitter.Acceleration = Vector3.new(0, -34, 0)
	killEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.52),
		NumberSequenceKeypoint.new(0.50, 0.30),
		NumberSequenceKeypoint.new(1, 0),
	})
	killEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.04),
		NumberSequenceKeypoint.new(0.72, 0.24),
		NumberSequenceKeypoint.new(1, 1),
	})
	killEmitter.Parent = attachment

	local highlight = Instance.new("Highlight")
	highlight.Name = HIGHLIGHT_NAME
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = HIT_FLASH_COLOR
	highlight.FillTransparency = 0.28
	highlight.OutlineTransparency = 1
	highlight.Enabled = false
	highlight.Parent = model

	return attachment, hitEmitter, killEmitter, highlight
end

local function trackModel(model: Model)
	if
		records[model] ~= nil
		or trackingModels[model] == true
		or trackedCount >= CombatImpactPresentationConfig.MaximumTrackedEnemyModels
		or model:GetAttribute("EnemyArchetypeId") ~= EnemyConfig.Walker.ArchetypeId
	then
		return
	end

	local root = model:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local hitSequence = readNumberAttribute(model, PresentationAttributeNames.HitSequence)
	local lifeStateId = readStringAttribute(model, PresentationAttributeNames.LifeStateId)
	if hitSequence == nil or lifeStateId == nil then
		return
	end

	trackingModels[model] = true
	local attachment, hitEmitter, killEmitter, highlight = createEffectObjects(model, root)
	records[model] = {
		root = root,
		effectAttachment = attachment,
		hitEmitter = hitEmitter,
		killEmitter = killEmitter,
		highlight = highlight,
		lastHitSequence = hitSequence,
		wasDead = lifeStateId == PresentationLifeStateIds.Dead,
		flashUntilServerTimestamp = 0,
	}
	trackedCount += 1
	trackingModels[model] = nil
end

local function untrackModel(model: Model)
	trackingModels[model] = nil
	local record = records[model]
	if record == nil then
		return
	end
	records[model] = nil
	trackedCount = math.max(0, trackedCount - 1)
	if record.highlight.Parent ~= nil then
		record.highlight:Destroy()
	end
	if record.effectAttachment.Parent ~= nil then
		record.effectAttachment:Destroy()
	end
end

local function isInsideEffectDistance(record: Record): boolean
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return false
	end
	return (camera.CFrame.Position - record.root.Position).Magnitude
		<= CombatImpactPresentationConfig.MaximumEffectDistanceStuds
end

local function scaledBloodParticleCount(authoredCount: number): number
	-- The HROI-0104 comfort scale only lowers blood-burst density. Hit and kill
	-- flash highlights stay untouched: they carry combat readability, not gore.
	local scale = PresentationAccessibilityState.getScale(PresentationAccessibilityConfig.SettingIds.Blood)
	return math.floor(authoredCount * scale + 0.5)
end

local function triggerHit(record: Record, serverTimestamp: number)
	if not isInsideEffectDistance(record) then
		return
	end
	local particleCount = scaledBloodParticleCount(CombatImpactPresentationConfig.HitParticleCount)
	if particleCount > 0 then
		record.hitEmitter:Emit(particleCount)
	end
	record.highlight.FillColor = HIT_FLASH_COLOR
	record.highlight.FillTransparency = 0.24
	record.highlight.Enabled = true
	record.flashUntilServerTimestamp = serverTimestamp + CombatImpactPresentationConfig.HitFlashSeconds
end

local function triggerKill(record: Record, serverTimestamp: number)
	if not isInsideEffectDistance(record) then
		return
	end
	local particleCount = scaledBloodParticleCount(CombatImpactPresentationConfig.KillParticleCount)
	if particleCount > 0 then
		record.killEmitter:Emit(particleCount)
	end
	record.highlight.FillColor = KILL_FLASH_COLOR
	record.highlight.FillTransparency = 0.16
	record.highlight.Enabled = true
	record.flashUntilServerTimestamp = serverTimestamp + CombatImpactPresentationConfig.KillFlashSeconds
end

local function updateRecord(model: Model, record: Record, serverTimestamp: number)
	local hitSequence = readNumberAttribute(model, PresentationAttributeNames.HitSequence)
	local lifeStateId = readStringAttribute(model, PresentationAttributeNames.LifeStateId)
	if hitSequence == nil or lifeStateId == nil then
		return
	end

	local isDead = lifeStateId == PresentationLifeStateIds.Dead
	local becameDead = isDead and not record.wasDead
	if becameDead then
		triggerKill(record, serverTimestamp)
	elseif hitSequence > record.lastHitSequence then
		triggerHit(record, serverTimestamp)
	end

	if hitSequence > record.lastHitSequence then
		record.lastHitSequence = hitSequence
	end
	record.wasDead = isDead

	if record.highlight.Enabled and serverTimestamp >= record.flashUntilServerTimestamp then
		record.highlight.Enabled = false
	end
end

function EnemyImpactPresentationController.start()
	if started then
		return
	end
	started = true

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
		local serverTimestamp = Workspace:GetServerTimeNow()
		local staleModels: { Model } = {}
		for model, record in records do
			if model.Parent == nil or record.root.Parent == nil then
				table.insert(staleModels, model)
			else
				updateRecord(model, record, serverTimestamp)
			end
		end
		for _, model in staleModels do
			untrackModel(model)
		end
	end)
end

function EnemyImpactPresentationController.stop()
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
	local trackedModels: { Model } = {}
	for model in records do
		table.insert(trackedModels, model)
	end
	for _, model in trackedModels do
		untrackModel(model)
	end
	table.clear(trackingModels)
	enemyFolder = nil
end

return table.freeze(EnemyImpactPresentationController)
