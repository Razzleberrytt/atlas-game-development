--!strict

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Controller = {}

local started = false
local heartbeat: RBXScriptConnection? = nil
local elapsed = 0
local trackedStates: { [Model]: string } = {}
local trackedBarriers: { [BasePart]: boolean } = {}
local activeTweens: { Tween } = {}

local CHECK_INTERVAL = 0.12
local MAX_TRACKED_ROOMS = 48
local MAX_TRACKED_BARRIERS = 96

local function clearTweens()
	for _, tween in activeTweens do
		tween:Cancel()
	end
	table.clear(activeTweens)
end

local function tween(instance: Instance, duration: number, properties: { [string]: any })
	local value = TweenService:Create(instance, TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), properties)
	table.insert(activeTweens, value)
	value:Play()
end

local function barrierParts(room: Model): { BasePart }
	local result = {}
	for _, descendant in room:GetDescendants() do
		if #result >= MAX_TRACKED_BARRIERS then
			break
		end
		if descendant:IsA("BasePart") and descendant:GetAttribute("ExpeditionRevealBarrier") == true then
			table.insert(result, descendant)
		end
	end
	return result
end

local function roleBrightness(room: Model): number
	local roleId = room:GetAttribute("RoomRoleId")
	if roleId == "Boss" then
		return 5.2
	elseif roleId == "Elite" then
		return 4.2
	end
	return 3.1
end

local function applyLocked(room: Model)
	for _, barrier in barrierParts(room) do
		trackedBarriers[barrier] = true
		barrier.Transparency = 0.16
		local light = barrier:FindFirstChild("BarrierGlow")
		if light and light:IsA("PointLight") then
			light.Brightness = roleBrightness(room)
		end
	end
end

local function applyCleared(room: Model)
	for _, barrier in barrierParts(room) do
		trackedBarriers[barrier] = nil
		local light = barrier:FindFirstChild("BarrierGlow")
		if light and light:IsA("PointLight") then
			tween(light, 0.45, { Brightness = 0 })
		end
		tween(barrier, 0.6, {
			Transparency = 1,
			Size = Vector3.new(barrier.Size.X * 1.12, 0.12, barrier.Size.Z),
		})
	end
end

local function applyDormant(room: Model)
	for _, barrier in barrierParts(room) do
		trackedBarriers[barrier] = nil
	end
end

local function updateStates()
	local root = Workspace:FindFirstChild("ExpeditionRooms")
	if root == nil then
		table.clear(trackedStates)
		table.clear(trackedBarriers)
		return
	end

	local checked = 0
	for _, child in root:GetChildren() do
		if checked >= MAX_TRACKED_ROOMS then
			break
		end
		if child:IsA("Model") then
			checked += 1
			local nextState = child:GetAttribute("BarrierState")
			if type(nextState) ~= "string" then
				nextState = "Dormant"
			end
			if trackedStates[child] ~= nextState then
				trackedStates[child] = nextState
				if nextState == "Locked" then
					applyLocked(child)
				elseif nextState == "Cleared" then
					applyCleared(child)
				else
					applyDormant(child)
				end
			end
		end
	end
end

local function step(deltaTime: number)
	elapsed += deltaTime
	if elapsed >= CHECK_INTERVAL then
		elapsed = 0
		updateStates()
	end

	local now = Workspace:GetServerTimeNow()
	for barrier in trackedBarriers do
		if barrier.Parent == nil then
			trackedBarriers[barrier] = nil
			continue
		end
		local light = barrier:FindFirstChild("BarrierGlow")
		if light and light:IsA("PointLight") then
			local base = 3.2
			light.Brightness = base + math.sin(now * 5.5 + barrier.Position.X * 0.03) * 0.9
		end
		barrier.Transparency = 0.14 + (math.sin(now * 4.2 + barrier.Position.Z * 0.02) + 1) * 0.035
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
	table.clear(trackedStates)
	table.clear(trackedBarriers)
	elapsed = 0
end

return table.freeze(Controller)
