--!strict

--[[
	Client-only presentation for the server-owned melee mode. The local operative
	gets a simple first-person Field Hatchet viewmodel; remote melee operatives get
	a lightweight hand-attached hatchet. Presentation also follows the existing
	replicated operative life state so incapacitated/dead characters do not appear
	combat-ready. This controller owns no strike, damage, targeting, inventory,
	life-state, or combat-mode authority.
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
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MeleePresentationContracts = require(ReplicatedStorage.Shared.Combat.MeleePresentationContracts)
local PrimaryCombatModeContracts = require(ReplicatedStorage.Shared.Combat.PrimaryCombatModeContracts)
local MeleeCombatConfig = require(ReplicatedStorage.Shared.Config.MeleeCombatConfig)
local OperativeLifeContracts = require(ReplicatedStorage.Shared.Health.OperativeLifeContracts)

local Controller = {}
local AttributeName = PrimaryCombatModeContracts.AttributeName
local ModeIds = PrimaryCombatModeContracts.ModeIds
local LifeStateIds = OperativeLifeContracts.OperativeLifeStateIds
local LIFE_STATE_ATTRIBUTE = "LK_P3_LifeState"
local MODEL_NAME = "MeleePresentation"
local FIRST_PERSON_MODEL_NAME = "FirstPersonMelee"
local SWING_DURATION_SECONDS = math.min(0.5, MeleeCombatConfig.OpeningWeapon.CadenceSeconds * 0.8)
local HIT_FLASH_DURATION_SECONDS = 0.12
local IMPACT_KICK_DURATION_SECONDS = 0.11
local BLADE_IDLE_COLOR = Color3.fromRGB(116, 123, 122)
local BLADE_HIT_COLOR = Color3.fromRGB(225, 238, 220)
local BLADE_KILL_COLOR = Color3.fromRGB(255, 219, 132)

local started = false
local playerAddedConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil
local renderConnection: RBXScriptConnection? = nil
local presentationConnection: RBXScriptConnection? = nil
local modeConnections: { [Player]: RBXScriptConnection } = {}
local lifeStateConnections: { [Player]: RBXScriptConnection } = {}
local characterConnections: { [Player]: RBXScriptConnection } = {}
local remoteModels: { [Player]: Model } = {}
local localModel: Model? = nil
local localHandle: BasePart? = nil
local localBlade: BasePart? = nil
local localSwingStartedAtClock: number? = nil
local localHitConfirmedAtClock: number? = nil
local localImpactConfirmedAtClock: number? = nil
local localHitWasKill = false
local meleeNetwork = ReplicatedStorage:WaitForChild("MeleeNetwork", NETWORK_WAIT_SECONDS)
assert(meleeNetwork ~= nil, "MeleeNetwork did not become available before the client bootstrap timeout")
local presentationRemote = meleeNetwork:WaitForChild("Presentation", NETWORK_WAIT_SECONDS) :: RemoteEvent?
assert(
	presentationRemote ~= nil,
	"MeleeNetwork.Presentation did not become available before the client bootstrap timeout"
)

local function shouldPresentMelee(player: Player): boolean
	return player:GetAttribute(AttributeName) == ModeIds.Melee
		and player:GetAttribute(LIFE_STATE_ATTRIBUTE) == LifeStateIds.Alive
end

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
	local blade = makePart("Blade", Vector3.new(1.8, 1.35, 0.28), BLADE_IDLE_COLOR, Enum.Material.Metal)
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
	localHitConfirmedAtClock = nil
	localImpactConfirmedAtClock = nil
	localHitWasKill = false
end

local function createLocalModel()
	destroyLocalModel()
	local player = Players.LocalPlayer
	local camera = Workspace.CurrentCamera
	if player == nil or camera == nil or not shouldPresentMelee(player) then
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
	if not shouldPresentMelee(player) then
		return
	end
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
	local shouldPresent = shouldPresentMelee(player)
	if player == Players.LocalPlayer then
		if shouldPresent then
			if localModel == nil or localModel.Parent ~= Workspace.CurrentCamera then
				createLocalModel()
			end
		else
			destroyLocalModel()
		end
		return
	end
	if not shouldPresent then
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
	local lifeStateConnection = lifeStateConnections[player]
	if lifeStateConnection ~= nil then
		lifeStateConnection:Disconnect()
		lifeStateConnections[player] = nil
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
	lifeStateConnections[player] = player:GetAttributeChangedSignal(LIFE_STATE_ATTRIBUTE):Connect(function()
		reconcilePlayer(player)
	end)
	characterConnections[player] = player.CharacterAdded:Connect(function(character)
		if player ~= Players.LocalPlayer and shouldPresentMelee(player) then
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

local function localImpactAmount(nowClock: number): number
	local confirmedAt = localImpactConfirmedAtClock
	if confirmedAt == nil then
		return 0
	end
	local progress = (nowClock - confirmedAt) / IMPACT_KICK_DURATION_SECONDS
	if progress >= 1 then
		localImpactConfirmedAtClock = nil
		return 0
	end
	local decay = 1 - math.clamp(progress, 0, 1)
	return decay * decay
end

local function applyLocalHitFlash(blade: BasePart, nowClock: number)
	local confirmedAt = localHitConfirmedAtClock
	if confirmedAt ~= nil and nowClock - confirmedAt <= HIT_FLASH_DURATION_SECONDS then
		blade.Material = Enum.Material.Neon
		blade.Color = if localHitWasKill then BLADE_KILL_COLOR else BLADE_HIT_COLOR
		return
	end
	localHitConfirmedAtClock = nil
	localHitWasKill = false
	blade.Material = Enum.Material.Metal
	blade.Color = BLADE_IDLE_COLOR
end

local function onPresentation(message: unknown)
	if not MeleePresentationContracts.validateHitConfirmedMessage(message) then
		return
	end
	local player = Players.LocalPlayer
	if player == nil or not shouldPresentMelee(player) then
		return
	end
	local confirmed = message :: MeleePresentationContracts.HitConfirmedMessage
	local nowClock = os.clock()
	localHitConfirmedAtClock = nowClock
	localImpactConfirmedAtClock = nowClock
	localHitWasKill = confirmed.becameDead
end

function Controller.playLocalSwing()
	local player = Players.LocalPlayer
	if not started or player == nil or not shouldPresentMelee(player) then
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
	presentationConnection = presentationRemote.OnClientEvent:Connect(onPresentation)
	renderConnection = RunService.RenderStepped:Connect(function()
		local player = Players.LocalPlayer
		if player == nil or not shouldPresentMelee(player) then
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

		local nowClock = os.clock()
		local swing = localSwingAmount(nowClock)
		local impact = localImpactAmount(nowClock)
		local impactScale = if localHitWasKill then 1.25 else 1
		local x = 0.72 - 0.16 * swing + 0.04 * impact * impactScale
		local y = -0.78 + 0.1 * swing - 0.03 * impact * impactScale
		local z = -1.25 - 0.24 * swing + 0.18 * impact * impactScale
		local pitchDegrees = -8 + 58 * swing - 12 * impact * impactScale
		local yawDegrees = -12 * swing + 4 * impact * impactScale
		local rollDegrees = -20 - 52 * swing + 8 * impact * impactScale
		handle.CFrame = camera.CFrame
			* CFrame.new(x, y, z)
			* CFrame.Angles(math.rad(pitchDegrees), math.rad(yawDegrees), math.rad(rollDegrees))
		blade.CFrame = handle.CFrame * CFrame.new(0.72, 1.25, 0)
		applyLocalHitFlash(blade, nowClock)
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
	if presentationConnection ~= nil then
		presentationConnection:Disconnect()
		presentationConnection = nil
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
