--!strict

--[[
	Client-only horde reward and horror feedback layered on top of the canonical
	EnemyImpactPresentationController. The canonical impact controller owns hit
	and kill bursts/highlights; this controller adds role-aware death pools, XP
	billboards, and bounded camera shake from server-confirmed presentation facts.
	Special-role punctuation reuses those same objects and cannot establish a kill.
	It never applies damage, changes enemy state, selects targets, or reports a hit.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CombatContracts = require(ReplicatedStorage.Shared.Combat.CombatContracts)
local EnemyPresentationContracts = require(ReplicatedStorage.Shared.Visual.EnemyPresentationContracts)
local HordeConfig = require(ReplicatedStorage.Shared.Config.HordeExperienceConfig)
local HordeDeathPunctuationConfig = require(ReplicatedStorage.Shared.Config.HordeDeathPunctuationConfig)
local HordeSpecialTelegraphConfig = require(ReplicatedStorage.Shared.Config.HordeSpecialTelegraphConfig)
local PresentationAccessibilityConfig = require(ReplicatedStorage.Shared.Config.PresentationAccessibilityConfig)
local PresentationAccessibilityState = require(script.Parent.Parent.Presentation.PresentationAccessibilityState)

local Controller = {}
local lifeAttribute = EnemyPresentationContracts.AttributeNames.LifeStateId
local deadLifeState = EnemyPresentationContracts.LifeStateIds.Dead
local presentationRemote =
	ReplicatedStorage:WaitForChild("CombatNetwork"):WaitForChild("CombatPresentation") :: RemoteEvent
local punctuationKindIds = HordeDeathPunctuationConfig.KindIds
local SpecialAttributeNames = HordeSpecialTelegraphConfig.AttributeNames
local SpecialKindIds = HordeSpecialTelegraphConfig.KindIds
local SpecialStateIds = HordeSpecialTelegraphConfig.StateIds

type DeathPunctuationDefinition = HordeDeathPunctuationConfig.Definition

local started = false
local folderAddedConnection: RBXScriptConnection? = nil
local folderRemovedConnection: RBXScriptConnection? = nil
local presentationConnection: RBXScriptConnection? = nil
local renderConnection: RBXScriptConnection? = nil
local modelConnections: { [Model]: RBXScriptConnection } = {}
local processedShotIds: { [string]: boolean } = {}
local processedDeaths: { [Model]: boolean } = {}
local shakeUntil = 0
local shakeMagnitude = 0
local shakeSequence = 0

local function colorFromTuple(tuple: { number }): Color3
	return Color3.fromRGB(tuple[1], tuple[2], tuple[3])
end

local function addShake(magnitude: number, duration: number)
	-- The HROI-0104 comfort scale only attenuates this cosmetic response; it can
	-- never raise magnitude above the authored value.
	local scaled = magnitude
		* PresentationAccessibilityState.getScale(PresentationAccessibilityConfig.SettingIds.CameraShake)
	if scaled <= 0 then
		return
	end
	shakeMagnitude = math.max(shakeMagnitude, scaled)
	shakeUntil = math.max(shakeUntil, os.clock() + duration)
	shakeSequence += 1
end

local function readStringAttribute(model: Model, attributeName: string): string?
	local value = model:GetAttribute(attributeName)
	return if type(value) == "string" and value ~= "" then value else nil
end

local function readCombatEntityId(model: Model): string?
	return readStringAttribute(model, "CombatEntityId")
end

local function resolveDeathPunctuation(model: Model, roleId: unknown): DeathPunctuationDefinition?
	local kindId: string? = nil
	if roleId == HordeConfig.Roles.Screamer.Id then
		local specialKindId = readStringAttribute(model, SpecialAttributeNames.KindId)
		local specialStateId = readStringAttribute(model, SpecialAttributeNames.StateId)
		local wasInterrupted = specialKindId == SpecialKindIds.ScreamerReinforcement
			and (specialStateId == SpecialStateIds.Windup or specialStateId == SpecialStateIds.Interrupted)
		kindId = if wasInterrupted then punctuationKindIds.ScreamerInterrupted else punctuationKindIds.Screamer
	elseif roleId == HordeConfig.Roles.Bloater.Id then
		kindId = punctuationKindIds.Bloater
	elseif roleId == HordeConfig.Roles.Brute.Id then
		local entityId = readCombatEntityId(model)
		if entityId == nil then
			return nil
		end
		kindId = if string.find(entityId, HordeDeathPunctuationConfig.BruteFinalEntityMarker, 1, true) ~= nil
			then punctuationKindIds.BruteFinal
			else punctuationKindIds.BrutePhaseOne
	end
	return HordeDeathPunctuationConfig.get(kindId)
end

local function createBloodPool(position: Vector3, definition: DeathPunctuationDefinition?)
	local bloodScale = PresentationAccessibilityState.getScale(PresentationAccessibilityConfig.SettingIds.Blood)
	if bloodScale <= 0 then
		return
	end
	local diameter = bloodScale
		* (
			if definition ~= nil
				then definition.BloodDiameterStuds
				else HordeDeathPunctuationConfig.GenericBloodDiameterStuds
		)
	local colorTuple = if definition ~= nil
		then definition.BloodColor
		else HordeDeathPunctuationConfig.GenericBloodColor
	local pool = Instance.new("Part")
	pool.Name = "HordeBloodPool"
	pool.Shape = Enum.PartType.Cylinder
	pool.Size = Vector3.new(0.08, diameter, diameter)
	pool.CFrame = CFrame.new(position.X, position.Y + 0.04, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	pool.Anchored = true
	pool.CanCollide = false
	pool.CanTouch = false
	pool.CanQuery = false
	pool.Material = Enum.Material.SmoothPlastic
	pool.Color = colorFromTuple(colorTuple)
	pool.Transparency = 0.25
	pool.Parent = Workspace
	Debris:AddItem(pool, HordeConfig.Feedback.BloodLifetimeSeconds)
end

local function createKillText(model: Model, position: Vector3, definition: DeathPunctuationDefinition?)
	local attachmentPart = Instance.new("Part")
	attachmentPart.Name = "HordeKillText"
	attachmentPart.Size = Vector3.new(0.1, 0.1, 0.1)
	attachmentPart.Position = position + Vector3.new(0, 4, 0)
	attachmentPart.Anchored = true
	attachmentPart.CanCollide = false
	attachmentPart.CanTouch = false
	attachmentPart.CanQuery = false
	attachmentPart.Transparency = 1
	attachmentPart.Parent = Workspace
	local billboard = Instance.new("BillboardGui")
	billboard.AlwaysOnTop = true
	billboard.Size = if definition ~= nil then UDim2.fromOffset(270, 64) else UDim2.fromOffset(190, 44)
	billboard.StudsOffset = Vector3.new(0, 1, 0)
	billboard.Parent = attachmentPart
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = if definition ~= nil then colorFromTuple(definition.Color) else Color3.fromRGB(255, 210, 95)
	label.TextStrokeColor3 = Color3.fromRGB(20, 6, 7)
	label.TextStrokeTransparency = 0.15
	label.TextScaled = true
	label.TextWrapped = definition ~= nil
	local roleName = model:GetAttribute("HordeRoleDisplayName")
	local xp = model:GetAttribute("HordeRewardXp")
	local xpAmount = if type(xp) == "number" and xp == xp and xp > 0 then xp else nil
	local bonusXp = if definition ~= nil then definition.XpBonus or 0 else 0
	local displayedXp = if xpAmount ~= nil then xpAmount + bonusXp else nil
	label.Text = if definition ~= nil
		then string.format("%s\n+%s XP", definition.Title, tostring(displayedXp or "?"))
		else string.format("%s  +%s XP", string.upper(tostring(roleName or "INFECTED")), tostring(displayedXp or "?"))
	label.Parent = billboard
	local lifetime = if definition ~= nil
		then definition.BillboardLifetimeSeconds
		else HordeDeathPunctuationConfig.GenericBillboardLifetimeSeconds
	Debris:AddItem(attachmentPart, lifetime)
end

local function enemyRoot(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local function presentDeath(model: Model)
	if processedDeaths[model] then
		return
	end
	processedDeaths[model] = true
	local root = enemyRoot(model)
	if root == nil then
		return
	end
	local roleId = model:GetAttribute("HordeRoleId")
	local definition = resolveDeathPunctuation(model, roleId)
	createBloodPool(root.Position, definition)
	createKillText(model, root.Position, definition)
	addShake(
		if definition ~= nil then definition.ShakeMagnitude else HordeDeathPunctuationConfig.GenericShakeMagnitude,
		if definition ~= nil
			then definition.ShakeDurationSeconds
			else HordeDeathPunctuationConfig.GenericShakeDurationSeconds
	)
end

local function trackModel(instance: Instance)
	if not instance:IsA("Model") or modelConnections[instance] ~= nil then
		return
	end
	local model = instance
	if enemyRoot(model) == nil then
		return
	end
	local function update()
		if model:GetAttribute(lifeAttribute) == deadLifeState then
			presentDeath(model)
		end
	end
	modelConnections[model] = model:GetAttributeChangedSignal(lifeAttribute):Connect(update)
	update()
end

local function untrackModel(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local connection = modelConnections[instance]
	if connection ~= nil then
		connection:Disconnect()
		modelConnections[instance] = nil
	end
	processedDeaths[instance] = nil
end

local function onCombatPresentation(message: unknown)
	if type(message) ~= "table" then
		return
	end
	local payload = message :: any
	if
		payload.kindId ~= CombatContracts.PresentationMessageKindIds.ShotFired
		or payload.didApplyDamage ~= true
		or type(payload.shotId) ~= "string"
		or payload.shotId == ""
		or processedShotIds[payload.shotId]
	then
		return
	end
	processedShotIds[payload.shotId] = true
	-- The canonical impact controller owns particles/highlights. This layer adds
	-- only subtle camera response, preserving one visual impact owner.
	addShake(0.035, 0.06)
end

local function updateCameraShake()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local timestamp = os.clock()
	if timestamp >= shakeUntil then
		shakeMagnitude = 0
		return
	end
	local remaining = math.clamp((shakeUntil - timestamp) / 0.25, 0, 1)
	local phase = timestamp * 48 + shakeSequence
	local offset = Vector3.new(math.sin(phase * 1.7), math.cos(phase * 2.3), 0) * shakeMagnitude * remaining
	camera.CFrame *= CFrame.new(offset)
end

function Controller.start()
	if started then
		return
	end
	started = true
	local found = Workspace:FindFirstChild("EnemyEntities")
	if found == nil then
		found = Workspace:WaitForChild("EnemyEntities")
	end
	assert(found:IsA("Folder"), "EnemyEntities must be a Folder")
	for _, child in found:GetChildren() do
		trackModel(child)
	end
	folderAddedConnection = found.ChildAdded:Connect(trackModel)
	folderRemovedConnection = found.ChildRemoved:Connect(untrackModel)
	presentationConnection = presentationRemote.OnClientEvent:Connect(onCombatPresentation)
	renderConnection = RunService.RenderStepped:Connect(updateCameraShake)
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	for _, connection in { folderAddedConnection, folderRemovedConnection, presentationConnection, renderConnection } do
		if connection ~= nil then
			connection:Disconnect()
		end
	end
	folderAddedConnection = nil
	folderRemovedConnection = nil
	presentationConnection = nil
	renderConnection = nil
	for model, connection in modelConnections do
		connection:Disconnect()
		modelConnections[model] = nil
	end
	table.clear(processedShotIds)
	table.clear(processedDeaths)
	shakeUntil = 0
	shakeMagnitude = 0
end

return Controller
