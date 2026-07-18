--!strict

--[[
	Client-only horror combat feedback. Every effect is gated by replicated,
	server-authored shot/death disclosure. It never applies damage, changes enemy
	state, selects targets, or reports a hit back to the server.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CombatContracts = require(ReplicatedStorage.Shared.Combat.CombatContracts)
local EnemyPresentationContracts = require(ReplicatedStorage.Shared.Visual.EnemyPresentationContracts)
local HordeConfig = require(ReplicatedStorage.Shared.Config.HordeExperienceConfig)

local Controller = {}
local lifeAttribute = EnemyPresentationContracts.AttributeNames.LifeStateId
local deadLifeState = EnemyPresentationContracts.LifeStateIds.Dead
local presentationRemote =
	ReplicatedStorage:WaitForChild("CombatNetwork"):WaitForChild("CombatPresentation") :: RemoteEvent

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

local function addShake(magnitude: number, duration: number)
	shakeMagnitude = math.max(shakeMagnitude, magnitude)
	shakeUntil = math.max(shakeUntil, os.clock() + duration)
	shakeSequence += 1
end

local function createEmitterPart(position: Vector3, color: Color3, count: number, size: number)
	local part = Instance.new("Part")
	part.Name = "HordeImpactEffect"
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 1
	part.Parent = Workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.25, 0.7)
	emitter.Speed = NumberRange.new(7, 18)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-180, 180)
	emitter.Drag = 5
	emitter.Acceleration = Vector3.new(0, -28, 0)
	emitter.Color = ColorSequence.new(color)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.7, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size),
		NumberSequenceKeypoint.new(1, size * 0.25),
	})
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Parent = part
	emitter:Emit(count)
	Debris:AddItem(part, 1.2)
end

local function createBloodPool(position: Vector3, isBloater: boolean)
	local pool = Instance.new("Part")
	pool.Name = "HordeBloodPool"
	pool.Shape = Enum.PartType.Cylinder
	pool.Size = Vector3.new(0.08, if isBloater then 8 else 5, if isBloater then 8 else 5)
	pool.CFrame = CFrame.new(position.X, position.Y + 0.04, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	pool.Anchored = true
	pool.CanCollide = false
	pool.CanTouch = false
	pool.CanQuery = false
	pool.Material = Enum.Material.SmoothPlastic
	pool.Color = if isBloater then Color3.fromRGB(45, 92, 32) else Color3.fromRGB(76, 4, 7)
	pool.Transparency = 0.25
	pool.Parent = Workspace
	Debris:AddItem(pool, HordeConfig.Feedback.BloodLifetimeSeconds)
end

local function createKillText(model: Model, position: Vector3)
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
	billboard.Size = UDim2.fromOffset(190, 44)
	billboard.StudsOffset = Vector3.new(0, 1, 0)
	billboard.Parent = attachmentPart
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(255, 210, 95)
	label.TextStrokeColor3 = Color3.fromRGB(20, 6, 7)
	label.TextStrokeTransparency = 0.15
	label.TextScaled = true
	local roleName = model:GetAttribute("HordeRoleDisplayName")
	local xp = model:GetAttribute("HordeRewardXp")
	label.Text = string.format("%s  +%s XP", string.upper(tostring(roleName or "INFECTED")), tostring(xp or "?"))
	label.Parent = billboard
	Debris:AddItem(attachmentPart, 1.2)
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
	local isBloater = roleId == HordeConfig.Roles.Bloater.Id
	local color = if isBloater then Color3.fromRGB(96, 186, 65) else Color3.fromRGB(126, 5, 10)
	createEmitterPart(
		root.Position + Vector3.new(0, 2, 0),
		color,
		if isBloater then 34 else 22,
		if isBloater then 1.6 else 1.05
	)
	createBloodPool(root.Position, isBloater)
	createKillText(model, root.Position)
	addShake(if roleId == HordeConfig.Roles.Brute.Id or isBloater then 0.28 else 0.1, 0.18)
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

local function validVector3(value: unknown): boolean
	return typeof(value) == "Vector3"
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
		or not validVector3(payload.impactWorldPosition)
	then
		return
	end
	processedShotIds[payload.shotId] = true
	createEmitterPart(
		payload.impactWorldPosition,
		Color3.fromRGB(138, 8, 13),
		HordeConfig.Feedback.BloodBurstParticles,
		0.65
	)
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
