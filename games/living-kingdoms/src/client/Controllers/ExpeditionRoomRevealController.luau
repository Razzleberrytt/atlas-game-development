--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Controller = {}

local started = false
local heartbeat: RBXScriptConnection? = nil
local revealed: { [Instance]: boolean } = {}
local activeTweens: { Tween } = {}
local elapsed = 0

local CHECK_INTERVAL = 0.15
local REVEAL_DISTANCE = 30
local MAX_TRACKED_ROOMS = 48

local function clearTweens()
	for _, tween in activeTweens do
		tween:Cancel()
	end
	table.clear(activeTweens)
end

local function playTween(instance: Instance, info: TweenInfo, properties: { [string]: any })
	local tween = TweenService:Create(instance, info, properties)
	table.insert(activeTweens, tween)
	tween:Play()
end

local function revealRoom(room: Model)
	if revealed[room] then
		return
	end
	revealed[room] = true
	room:SetAttribute("RevealState", "Revealing")

	local roleId = room:GetAttribute("RoomRoleId")
	local duration = if roleId == "Boss" then 1.4 elseif roleId == "Elite" then 1.05 else 0.75

	for _, descendant in room:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute("ExpeditionRevealBarrier") == true then
			descendant.Transparency = descendant:GetAttribute("BaseTransparency") or 0.38
			local light = descendant:FindFirstChild("BarrierGlow")
			if light and light:IsA("PointLight") then
				light.Brightness = if roleId == "Boss" then 4.5 elseif roleId == "Elite" then 3.5 else 2.2
				playTween(light, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 })
			end
			playTween(descendant, TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				Transparency = 1,
				Size = Vector3.new(descendant.Size.X * 1.08, 0.15, descendant.Size.Z),
			})
		end
	end

	task.delay(duration, function()
		if room.Parent ~= nil then
			room:SetAttribute("RevealState", "Revealed")
		end
	end)
end

local function nearestRoom(rootPosition: Vector3): Model?
	local root = Workspace:FindFirstChild("ExpeditionRooms")
	if root == nil then
		return nil
	end

	local nearest: Model? = nil
	local nearestDistance = math.huge
	local checked = 0
	for _, child in root:GetChildren() do
		if checked >= MAX_TRACKED_ROOMS then
			break
		end
		if child:IsA("Model") and child.PrimaryPart ~= nil then
			checked += 1
			local distance = (child.PrimaryPart.Position - rootPosition).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
				nearest = child
			end
		end
	end
	if nearestDistance <= REVEAL_DISTANCE then
		return nearest
	end
	return nil
end

local function step(deltaTime: number)
	elapsed += deltaTime
	if elapsed < CHECK_INTERVAL then
		return
	end
	elapsed = 0

	local player = Players.LocalPlayer
	local character = player.Character
	local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return
	end
	local room = nearestRoom(rootPart.Position)
	if room ~= nil then
		revealRoom(room)
	end
end

function Controller.start()
	if started then
		return
	end
	started = true
	heartbeat = RunService.Heartbeat:Connect(step)
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	if heartbeat ~= nil then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	clearTweens()
	table.clear(revealed)
	elapsed = 0
end

return table.freeze(Controller)
