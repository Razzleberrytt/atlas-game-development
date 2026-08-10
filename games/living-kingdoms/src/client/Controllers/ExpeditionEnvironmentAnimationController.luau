--!strict

-- One bounded animation owner for all expedition environment fixtures. The
-- server marks decorative parts with attributes; the client animates only those
-- parts and never sends gameplay requests.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Controller = {}
local started = false
local connection: RBXScriptConnection? = nil
local workspaceChildAdded: RBXScriptConnection? = nil
local workspaceChildRemoved: RBXScriptConnection? = nil
local rootAdded: RBXScriptConnection? = nil
local rootRemoved: RBXScriptConnection? = nil
local tracked: { BasePart } = {}
local baseCFrames: { [BasePart]: CFrame } = {}
local baseTransparencies: { [BasePart]: number } = {}
local MAX_TRACKED = 96
local elapsed = 0

local function remove(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	baseCFrames[instance] = nil
	baseTransparencies[instance] = nil
	local index = table.find(tracked, instance)
	if index then
		table.remove(tracked, index)
	end
end

local function consider(instance: Instance)
	if #tracked >= MAX_TRACKED or not instance:IsA("BasePart") then
		return
	end
	if instance:GetAttribute("ExpeditionAnimated") ~= true then
		return
	end
	if baseCFrames[instance] ~= nil then
		return
	end
	table.insert(tracked, instance)
	baseCFrames[instance] = instance.CFrame
	baseTransparencies[instance] = instance.Transparency
end

local function scan(root: Instance)
	table.clear(tracked)
	table.clear(baseCFrames)
	table.clear(baseTransparencies)
	for _, descendant in root:GetDescendants() do
		consider(descendant)
	end
end

local function bindRoot(root: Instance?)
	if rootAdded then
		rootAdded:Disconnect()
		rootAdded = nil
	end
	if rootRemoved then
		rootRemoved:Disconnect()
		rootRemoved = nil
	end
	table.clear(tracked)
	table.clear(baseCFrames)
	table.clear(baseTransparencies)
	if root == nil then
		return
	end
	scan(root)
	rootAdded = root.DescendantAdded:Connect(consider)
	rootRemoved = root.DescendantRemoving:Connect(remove)
end

local function disconnectWorkspaceListeners()
	if workspaceChildAdded then
		workspaceChildAdded:Disconnect()
		workspaceChildAdded = nil
	end
	if workspaceChildRemoved then
		workspaceChildRemoved:Disconnect()
		workspaceChildRemoved = nil
	end
end

local function step(deltaTime: number)
	elapsed += deltaTime
	for index = #tracked, 1, -1 do
		local value = tracked[index]
		local base = baseCFrames[value]
		if value.Parent == nil or base == nil then
			remove(value)
			continue
		end
		local mode = value:GetAttribute("AnimationMode")
		local phase = value:GetAttribute("AnimationPhase")
		local speed = value:GetAttribute("AnimationSpeed")
		if type(phase) ~= "number" then
			phase = 0
		end
		if type(speed) ~= "number" then
			speed = 1
		end
		local wave = math.sin(elapsed * speed * math.pi * 2 + phase)

		if mode == "Flicker" then
			value.Transparency = math.clamp((baseTransparencies[value] or 0) + math.max(0, wave) * 0.12, 0, 0.35)
			local light = value:FindFirstChildOfClass("PointLight")
			if light then
				light.Brightness = 1.9 + (wave + 1) * 0.35
			end
		elseif mode == "Pulse" then
			value.Transparency = math.clamp(0.08 + (wave + 1) * 0.12, 0.05, 0.34)
		elseif mode == "Orbit" then
			value.CFrame = base * CFrame.new(0, wave * 0.65, 0) * CFrame.Angles(0, elapsed * speed, 0)
		end
	end
end

function Controller.start()
	if started then
		return
	end
	started = true
	bindRoot(Workspace:FindFirstChild("ExpeditionRooms"))
	workspaceChildAdded = Workspace.ChildAdded:Connect(function(child)
		if child.Name == "ExpeditionRooms" then
			bindRoot(child)
		end
	end)
	workspaceChildRemoved = Workspace.ChildRemoved:Connect(function(child)
		if child.Name == "ExpeditionRooms" then
			bindRoot(nil)
		end
	end)
	connection = RunService.RenderStepped:Connect(step)
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	if connection then
		connection:Disconnect()
		connection = nil
	end
	disconnectWorkspaceListeners()
	bindRoot(nil)
end

return Controller
