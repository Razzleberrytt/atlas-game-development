--!strict

-- Context-only survival feedback. Persistent health, objective, weapon and RPG
-- state already have canonical owners; this controller renders only short
-- server-authored pickup/home-fire messages so exploration stays readable.

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
local contextToast: TextLabel? = nil
local lastRevision = -1
local toastGeneration = 0

local function showToast(text: string)
	local toast = contextToast
	if toast == nil or text == "" then
		return
	end
	toastGeneration += 1
	local generation = toastGeneration
	toast.Text = text
	toast.Visible = true
	task.delay(2.8, function()
		if started and generation == toastGeneration and contextToast ~= nil then
			contextToast.Visible = false
		end
	end)
end

local function render(payload: unknown)
	if type(payload) ~= "table" or type((payload :: any).revision) ~= "number" then
		return
	end
	local state = payload :: any
	if state.revision < lastRevision then
		return
	end
	lastRevision = state.revision
	if type(state.eventText) == "string" then
		showToast(state.eventText)
	end
end

local function createPresentation()
	local created = Instance.new("ScreenGui")
	created.Name = "SurvivalHUD"
	created.ResetOnSpawn = false
	created.IgnoreGuiInset = true
	created.DisplayOrder = 51

	local toast = Instance.new("TextLabel")
	toast.Name = "ContextToast"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 72)
	toast.Size = UDim2.fromOffset(460, 42)
	toast.BackgroundColor3 = Color3.fromRGB(10, 13, 15)
	toast.BackgroundTransparency = 0.16
	toast.BorderSizePixel = 0
	toast.Font = Enum.Font.GothamBold
	toast.TextColor3 = Color3.fromRGB(244, 213, 139)
	toast.TextSize = 15
	toast.TextWrapped = true
	toast.Visible = false
	toast.Parent = created

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = toast
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(151, 116, 66)
	stroke.Transparency = 0.35
	stroke.Parent = toast

	created.Parent = player:WaitForChild("PlayerGui")
	gui = created
	contextToast = toast
end

function Controller.start()
	if started then
		return
	end
	started = true
	createPresentation()
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
	contextToast = nil
	lastRevision = -1
	toastGeneration = 0
end

return table.freeze(Controller)
