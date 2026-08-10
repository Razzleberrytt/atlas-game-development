--!strict

-- Patch 0.4 presentation for durable Operative Rank. The existing RPG menu
-- remains the UI owner; this controller mounts one bounded read-only card inside
-- its Character panel and asks only the server-owned progression read surface.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Controller = {}
local player = Players.LocalPlayer
local progressionNetwork = ReplicatedStorage:WaitForChild("OperativeProgressionNetwork")
local progressionReadState = progressionNetwork:WaitForChild("ReadState") :: RemoteFunction
local inventoryNetwork = ReplicatedStorage:WaitForChild("InventoryNetwork")
local inventoryStateRemote = inventoryNetwork:WaitForChild("State") :: RemoteEvent

local started = false
local connections: { RBXScriptConnection } = {}
local card: Frame? = nil
local rankLabel: TextLabel? = nil
local progressLabel: TextLabel? = nil

local COLORS = table.freeze({
	panel = Color3.fromRGB(18, 23, 25),
	gold = Color3.fromRGB(224, 177, 83),
	text = Color3.fromRGB(239, 237, 224),
	muted = Color3.fromRGB(154, 164, 159),
})

local function makeLabel(parent: Instance, position: UDim2, size: UDim2, textSize: number): TextLabel
	local created = Instance.new("TextLabel")
	created.BackgroundTransparency = 1
	created.Position = position
	created.Size = size
	created.Font = Enum.Font.GothamBold
	created.TextColor3 = COLORS.text
	created.TextSize = textSize
	created.TextXAlignment = Enum.TextXAlignment.Left
	created.Parent = parent
	return created
end

local function render(snapshot: any)
	local primary = rankLabel
	local secondary = progressLabel
	if primary == nil or secondary == nil then
		return
	end
	if type(snapshot) ~= "table" or snapshot.Accepted ~= true then
		primary.Text = "RANK --  //  LOADING"
		secondary.Text = "Durable expedition record unavailable"
		secondary.TextColor3 = COLORS.muted
		return
	end

	local rank = tonumber(snapshot.Rank) or 1
	local rankName = if type(snapshot.RankDisplayName) == "string" then snapshot.RankDisplayName else "Initiate"
	local completed = tonumber(snapshot.CompletedExpeditions) or 0
	primary.Text = string.format("RANK %d  //  %s", rank, string.upper(rankName))

	if snapshot.IsMaximumRank == true then
		secondary.Text = string.format("%d EXPEDITIONS CLEARED  //  MAX RANK", completed)
		secondary.TextColor3 = COLORS.gold
		return
	end

	local nextName = if type(snapshot.NextRankDisplayName) == "string"
		then snapshot.NextRankDisplayName
		else "NEXT RANK"
	local remaining = tonumber(snapshot.CompletedExpeditionsToNextRank) or 0
	secondary.Text = string.format("%d CLEARED  //  %d TO %s", completed, remaining, string.upper(nextName))
	secondary.TextColor3 = COLORS.muted
end

local function refresh()
	local ok, snapshot = pcall(function()
		return progressionReadState:InvokeServer()
	end)
	if ok then
		render(snapshot)
	else
		render(nil)
	end
end

local function mount(): Frame
	local playerGui = player:WaitForChild("PlayerGui")
	local menu = playerGui:WaitForChild("RPGMenu")
	local modal = menu:WaitForChild("Modal") :: Frame
	local characterPanel = modal:FindFirstChild("CharacterPanel", true)
	assert(characterPanel ~= nil and characterPanel:IsA("Frame"), "RPG menu CharacterPanel is required")

	local existing = characterPanel:FindFirstChild("OperativeProgressionCard")
	if existing ~= nil then
		existing:Destroy()
	end

	local created = Instance.new("Frame")
	created.Name = "OperativeProgressionCard"
	created.AnchorPoint = Vector2.new(0.5, 1)
	created.Position = UDim2.new(0.335, 0, 1, -12)
	created.Size = UDim2.fromOffset(310, 62)
	created.BackgroundColor3 = COLORS.panel
	created.BackgroundTransparency = 0.06
	created.BorderSizePixel = 0
	created.Parent = characterPanel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = created
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.gold
	stroke.Transparency = 0.25
	stroke.Parent = created

	local title = makeLabel(created, UDim2.fromOffset(10, 5), UDim2.new(1, -20, 0, 14), 9)
	title.Text = "OPERATIVE RANK  //  DURABLE"
	title.TextColor3 = COLORS.gold
	local primary = makeLabel(created, UDim2.fromOffset(10, 20), UDim2.new(1, -20, 0, 20), 14)
	primary.Text = "RANK --  //  LOADING"
	local secondary = makeLabel(created, UDim2.fromOffset(10, 41), UDim2.new(1, -20, 0, 15), 9)
	secondary.Text = "Durable expedition record unavailable"
	secondary.TextColor3 = COLORS.muted

	card = created
	rankLabel = primary
	progressLabel = secondary

	table.insert(
		connections,
		modal:GetPropertyChangedSignal("Visible"):Connect(function()
			if modal.Visible then
				refresh()
			end
		end)
	)
	return created
end

function Controller.start()
	if started then
		return
	end
	started = true
	mount()
	table.insert(
		connections,
		inventoryStateRemote.OnClientEvent:Connect(function(result)
			if type(result) == "table" and result.Accepted == true then
				refresh()
			end
		end)
	)
	refresh()
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	if card ~= nil then
		card:Destroy()
	end
	card = nil
	rankLabel = nil
	progressLabel = nil
end

return table.freeze(Controller)
