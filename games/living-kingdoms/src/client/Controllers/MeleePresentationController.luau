--!strict

--[[
	Client-only presentation for the server-owned melee mode. The local operative
	gets a simple first-person Field Hatchet viewmodel; remote melee operatives get
	a lightweight hand-attached hatchet. This controller owns no strike, damage,
	targeting, inventory, or combat-mode authority.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PrimaryCombatModeContracts = require(ReplicatedStorage.Shared.Combat.PrimaryCombatModeContracts)
local MeleeCombatConfig = require(ReplicatedStorage.Shared.Config.MeleeCombatConfig)

local Controller = {}
local AttributeName = PrimaryCombatModeContracts.AttributeName
local ModeIds = PrimaryCombatModeContracts.ModeIds
local MODEL_NAME = "MeleePresentation"
local FIRST_PERSON_MODEL_NAME = "FirstPersonMelee"
local SWING_DURATION_SECONDS = math.min(0.5, MeleeCombatConfig.OpeningWeapon.CadenceSeconds * 0.8)

local started = false
local playerAddedConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil
local renderConnection: RBXScriptConnection? = nil
local modeConnections: { [Player]: RBXScriptConnection } = {}
local characterConnections: { [Player]: RBXScriptConnection } = {}
local remoteModels: { [Player]: Model } = {}
local localModel: Model? = nil
local localHandle: BasePart? = nil
local localBlade: BasePart? = nil
local localSwingStartedAtClock: number? = nil

local function makePart(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function createHatchetModel(name: string, anchored: boolean): (Model, Part, Part)
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("GameplayWeaponId", MeleeCombatConfig.OpeningWeapon.WeaponId)
	local handle = makePart("Handle", Vector3.new(0.42, 3.7, 0.42), Color3.fromRGB(91, 58, 35), Enum.Material.Wood)
	handle.Anchored = anchored
	handle.Parent = model
	local blade = makePart("Blade", Vector3.new(1.8, 1.35, 0.28), Color3.fromRGB(116, 123, 122), Enum.Material.Metal)
	blade.Anchored = anchored
	blade.Parent = model
	model.PrimaryPart = handle
	return model, handle, blade
end

local function resolveRightHand(character: Model): BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local preferredName = if humanoid ~= nil and humanoid.RigType == Enum.HumanoidRigType.R6
		then "Right Arm"
		else "RightHand"
	local hand = character:FindFirstChild(preferredName)
	if hand ~= nil and hand:IsA("BasePart") then
		return hand
	end
	local fallback = character:FindFirstChild(if preferredName == "RightHand" then "Right Arm" else "RightHand")
	return if fallback ~= nil and fallback:IsA("BasePart") then fallback else nil
end

local function destroyRemoteModel(player: Player)
	local model = remoteModels[player]
	if model ~= nil then
		model:Destroy()
		remoteModels[player] = nil
	end
end

local function destroyLocalModel()
	if localModel ~= nil then
		localModel:Destroy()
	end
	localModel = nil
	localHandle = nil
	localBlade = nil
	localSwingStartedAtClock = nil
end

local function createLocalModel()
	destroyLocalModel()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local model, handle, blade = createHatchetModel(FIRST_PERSON_MODEL_NAME, true)
	model.Parent = camera
	localModel = model
	localHandle = handle
	localBlade = blade
end

local function createRemoteModel(player: Player, character: Model)
	destroyRemoteModel(player)
	local hand = resolveRightHand(character)
	if hand == nil then
		return
	end
	local model, handle, blade = createHatchetModel(MODEL_NAME, false)
	handle.CFrame = hand.CFrame * CFrame.new(0, -1.15, -0.15) * CFrame.Angles(0, 0, math.rad(18))
	blade.CFrame = handle.CFrame * CFrame.new(0.72, 1.25, 0)
	model.Parent = character

	local bladeWeld = Instance.new("WeldConstraint")
	bladeWeld.Part0 = handle
	bladeWeld.Part1 = blade
	bladeWeld.Parent = handle
	local grip = Instance.new("Motor6D")
	grip.Name = "MeleeGrip"
	grip.Part0 = hand
	grip.Part1 = handle
	grip.C0 = CFrame.new(0, -1.15, -0.15) * CFrame.Angles(0, 0, math.rad(18))
	grip.C1 = CFrame.identity
	grip.Parent = hand
	remoteModels[player] = model
end

local function reconcilePlayer(player: Player)
	local isMelee = player:GetAttribute(AttributeName) == ModeIds.Melee
	if player == Players.LocalPlayer then
		if isMelee then
			if localModel == nil or localModel.Parent ~= Workspace.CurrentCamera then
				createLocalModel()
			end
		else
			destroyLocalModel()
		end
		return
	end
	if not isMelee then
		destroyRemoteModel(player)
		return
	end
	local character = player.Character
	if character ~= nil and remoteModels[player] == nil then
		createRemoteModel(player, character)
	end
end

local function unbindPlayer(player: Player)
	local modeConnection = modeConnections[player]
	if modeConnection ~= nil then
		modeConnection:Disconnect()
		modeConnections[player] = nil
	end
	local characterConnection = characterConnections[player]
	if characterConnection ~= nil then
		characterConnection:Disconnect()
		characterConnections[player] = nil
	end
	if player == Players.LocalPlayer then
		destroyLocalModel()
	else
		destroyRemoteModel(player)
	end
end

local function bindPlayer(player: Player)
	if modeConnections[player] ~= nil then
		return
	end
	modeConnections[player] = player:GetAttributeChangedSignal(AttributeName):Connect(function()
		reconcilePlayer(player)
	end)
	characterConnections[player] = player.CharacterAdded:Connect(function(character)
		if player ~= Players.LocalPlayer and player:GetAttribute(AttributeName) == ModeIds.Melee then
			task.defer(createRemoteModel, player, character)
		end
	end)
	reconcilePlayer(player)
end

local function localSwingAmount(nowClock: number): number
	local startedAt = localSwingStartedAtClock
	if startedAt == nil then
		return 0
	end
	local progress = (nowClock - startedAt) / SWING_DURATION_SECONDS
	if progress >= 1 then
		localSwingStartedAtClock = nil
		return 0
	end
	return math.sin(math.clamp(progress, 0, 1) * math.pi)
end

function Controller.playLocalSwing()
	local player = Players.LocalPlayer
	if not started or player == nil or player:GetAttribute(AttributeName) ~= ModeIds.Melee then
		return
	end
	if localModel == nil or localModel.Parent ~= Workspace.CurrentCamera then
		createLocalModel()
	end
	localSwingStartedAtClock = os.clock()
end

function Controller.start()
	if started then
		return
	end
	started = true
	for _, player in Players:GetPlayers() do
		bindPlayer(player)
	end
	playerAddedConnection = Players.PlayerAdded:Connect(bindPlayer)
	playerRemovingConnection = Players.PlayerRemoving:Connect(unbindPlayer)
	renderConnection = RunService.RenderStepped:Connect(function()
		local player = Players.LocalPlayer
		if player == nil or player:GetAttribute(AttributeName) ~= ModeIds.Melee then
			return
		end
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end
		if localModel == nil or localModel.Parent ~= camera or localHandle == nil or localBlade == nil then
			createLocalModel()
		end
		local handle = localHandle
		local blade = localBlade
		if handle == nil or blade == nil then
			return
		end

		local swing = localSwingAmount(os.clock())
		local x = 0.72 - 0.16 * swing
		local y = -0.78 + 0.1 * swing
		local z = -1.25 - 0.24 * swing
		local pitchDegrees = -8 + 58 * swing
		local yawDegrees = -12 * swing
		local rollDegrees = -20 - 52 * swing
		handle.CFrame = camera.CFrame
			* CFrame.new(x, y, z)
			* CFrame.Angles(math.rad(pitchDegrees), math.rad(yawDegrees), math.rad(rollDegrees))
		blade.CFrame = handle.CFrame * CFrame.new(0.72, 1.25, 0)
	end)
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	if playerAddedConnection ~= nil then
		playerAddedConnection:Disconnect()
		playerAddedConnection = nil
	end
	if playerRemovingConnection ~= nil then
		playerRemovingConnection:Disconnect()
		playerRemovingConnection = nil
	end
	if renderConnection ~= nil then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	local players = {}
	for player in modeConnections do
		table.insert(players, player)
	end
	for _, player in players do
		unbindPlayer(player)
	end
	destroyLocalModel()
end

return table.freeze(Controller)
