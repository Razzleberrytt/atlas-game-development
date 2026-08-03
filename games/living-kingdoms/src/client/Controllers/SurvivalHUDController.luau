--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Controller = {}
local player = Players.LocalPlayer
local network = ReplicatedStorage:WaitForChild("SurvivalNetwork")
local stateRemote = network:WaitForChild("State") :: RemoteEvent
local readState = network:WaitForChild("ReadState") :: RemoteFunction

local started = false
local connection: RBXScriptConnection? = nil
local gui: ScreenGui? = nil
local fireLabel: TextLabel? = nil
local packLabel: TextLabel? = nil
local goalLabel: TextLabel? = nil
local eventLabel: TextLabel? = nil
local lastRevision = -1
local eventGeneration = 0

local function render(payload: unknown)
	if type(payload) ~= "table" or type((payload :: any).revision) ~= "number" then
		return
	end
	local state = payload :: any
	if state.revision < lastRevision then
		return
	end
	lastRevision = state.revision
	if fireLabel ~= nil then
		fireLabel.Text = string.format("HOME FIRE   %d / %d", state.campfireFuel or 0, state.campfireMaximumFuel or 100)
		fireLabel.TextColor3 = if (state.campfireFuel or 0) <= 20
			then Color3.fromRGB(255, 92, 63)
			else Color3.fromRGB(255, 184, 83)
	end
	if packLabel ~= nil then
		packLabel.Text = string.format(
			"PACK   %d / %d     WOOD   %d     CHESTS   %d",
			state.inventoryUsed or 0,
			state.inventoryCapacity or 30,
			state.wood or 0,
			state.openedChests or 0
		)
	end
	if goalLabel ~= nil then
		if (state.openedChests or 0) == 0 then
			goalLabel.Text = "NEXT  //  SEARCH THE NEAREST SUPPLY CHEST"
		elseif not state.foundWeapon and (state.openedChests or 0) < 3 then
			goalLabel.Text = "NEXT  //  KEEP SEARCHING — A WEAPON IS CLOSE"
		elseif (state.wood or 0) > 0 and (state.campfireFuel or 0) < 75 then
			goalLabel.Text = "NEXT  //  RETURN HOME AND STABILIZE THE FIRE"
		else
			goalLabel.Text = "NEXT  //  LOOT, HUNT, AND KEEP THE FIRE ALIVE"
		end
	end
	if eventLabel ~= nil and type(state.eventText) == "string" and state.eventText ~= "" then
		eventGeneration += 1
		local generation = eventGeneration
		eventLabel.Text = state.eventText
		eventLabel.Visible = true
		task.delay(3.5, function()
			if started and generation == eventGeneration and eventLabel ~= nil then
				eventLabel.Visible = false
			end
		end)
	end
end

local function makeLabel(parent: Instance, name: string, y: number, height: number, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = UDim2.fromOffset(14, y)
	label.Size = UDim2.new(1, -28, 0, height)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(236, 235, 226)
	label.TextSize = size
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

function Controller.start()
	if started then
		return
	end
	started = true
	local created = Instance.new("ScreenGui")
	created.Name = "SurvivalHUD"
	created.ResetOnSpawn = false
	created.IgnoreGuiInset = true
	created.DisplayOrder = 51
	local panel = Instance.new("Frame")
	panel.Name = "SurvivalPanel"
	panel.Position = UDim2.fromOffset(16, 126)
	panel.Size = UDim2.fromOffset(270, 92)
	panel.BackgroundColor3 = Color3.fromRGB(13, 16, 18)
	panel.BackgroundTransparency = 0.12
	panel.BorderSizePixel = 0
	panel.Parent = created
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(151, 116, 66)
	stroke.Transparency = 0.3
	stroke.Parent = panel
	fireLabel = makeLabel(panel, "Fire", 5, 28, 16)
	packLabel = makeLabel(panel, "Pack", 34, 24, 11)
	goalLabel = makeLabel(panel, "Goal", 58, 29, 11)
	goalLabel.TextWrapped = true
	goalLabel.TextColor3 = Color3.fromRGB(255, 202, 105)
	eventLabel = makeLabel(created, "LootEvent", 226, 34, 16)
	eventLabel.Position = UDim2.fromOffset(16, 226)
	eventLabel.Size = UDim2.fromOffset(270, 42)
	eventLabel.TextWrapped = true
	eventLabel.TextColor3 = Color3.fromRGB(255, 202, 105)
	eventLabel.Visible = false
	created.Parent = player:WaitForChild("PlayerGui")
	gui = created
	connection = stateRemote.OnClientEvent:Connect(render)
	local ok, payload = pcall(function()
		return readState:InvokeServer()
	end)
	if ok then
		render(payload)
	end
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	if connection ~= nil then
		connection:Disconnect()
		connection = nil
	end
	if gui ~= nil then
		gui:Destroy()
		gui = nil
	end
	fireLabel = nil
	packLabel = nil
	goalLabel = nil
	eventLabel = nil
	lastRevision = -1
end

return table.freeze(Controller)
