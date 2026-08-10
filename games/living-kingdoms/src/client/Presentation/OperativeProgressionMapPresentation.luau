--!strict

-- Patch 0.4 durable progression map presentation. This presenter owns no
-- progression truth and exposes no mutation path: it renders only the bounded
-- authored rank map plus the caller's server-derived Operative Rank snapshot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OperativeProgressionConfig = require(ReplicatedStorage.Shared.Config.OperativeProgressionConfig)

local progressionNetwork = ReplicatedStorage:WaitForChild("OperativeProgressionNetwork")
local progressionReadState = progressionNetwork:WaitForChild("ReadState") :: RemoteFunction

local Presentation = {}

local COLORS = table.freeze({
	panel = Color3.fromRGB(18, 23, 25),
	panelMuted = Color3.fromRGB(13, 17, 19),
	gold = Color3.fromRGB(224, 177, 83),
	text = Color3.fromRGB(239, 237, 224),
	muted = Color3.fromRGB(154, 164, 159),
	green = Color3.fromRGB(105, 214, 139),
	locked = Color3.fromRGB(76, 84, 81),
})

local function label(parent: Instance, text: string, position: UDim2, size: UDim2, textSize: number): TextLabel
	local created = Instance.new("TextLabel")
	created.BackgroundTransparency = 1
	created.Position = position
	created.Size = size
	created.Font = Enum.Font.GothamBold
	created.Text = text
	created.TextColor3 = COLORS.text
	created.TextSize = textSize
	created.TextXAlignment = Enum.TextXAlignment.Left
	created.Parent = parent
	return created
end

local function decorate(target: GuiObject, color: Color3, transparency: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = target
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = transparency or 0.3
	stroke.Parent = target
end

local function clear(panel: ScrollingFrame)
	for _, child in panel:GetChildren() do
		child:Destroy()
	end
end

local function readSnapshot(): any
	local ok, snapshot = pcall(function()
		return progressionReadState:InvokeServer()
	end)
	if not ok or type(snapshot) ~= "table" or snapshot.Accepted ~= true then
		return nil
	end
	return snapshot
end

local function rankStatus(rank: any, snapshot: any): (string, Color3, Color3)
	if snapshot == nil then
		return "STATUS UNAVAILABLE", COLORS.muted, COLORS.panelMuted
	end
	local currentRank = tonumber(snapshot.Rank) or 1
	if rank.Rank < currentRank then
		return "EARNED", COLORS.green, COLORS.panel
	elseif rank.Rank == currentRank then
		return "CURRENT", COLORS.gold, Color3.fromRGB(43, 36, 22)
	elseif rank.Rank == currentRank + 1 then
		local remaining = tonumber(snapshot.CompletedExpeditionsToNextRank) or 0
		return string.format("NEXT  //  %d CLEARS TO GO", remaining), COLORS.gold, COLORS.panel
	end
	return "LOCKED", COLORS.locked, COLORS.panelMuted
end

local function unlocksForRank(rankOrdinal: number): { any }
	local unlocks = {}
	for _, unlock in OperativeProgressionConfig.Unlocks do
		if unlock.RequiredRank == rankOrdinal then
			table.insert(unlocks, unlock)
		end
	end
	return unlocks
end

local function milestoneCard(parent: Instance, rank: any, snapshot: any, y: number): number
	local statusText, statusColor, backgroundColor = rankStatus(rank, snapshot)
	local unlocks = unlocksForRank(rank.Rank)
	local cardHeight = if #unlocks > 0 then 110 + (#unlocks - 1) * 26 else 78
	local card = Instance.new("Frame")
	card.Name = "Rank" .. tostring(rank.Rank)
	card.Position = UDim2.fromOffset(8, y)
	card.Size = UDim2.new(1, -16, 0, cardHeight)
	card.BackgroundColor3 = backgroundColor
	card.BorderSizePixel = 0
	card.Parent = parent
	decorate(card, statusColor, if statusText == "LOCKED" then 0.6 else 0.2)

	local ordinal =
		label(card, string.format("RANK %d", rank.Rank), UDim2.fromOffset(12, 9), UDim2.fromOffset(70, 20), 10)
	ordinal.TextColor3 = statusColor
	local name = label(card, string.upper(rank.DisplayName), UDim2.fromOffset(84, 7), UDim2.new(1, -96, 0, 23), 14)
	name.TextColor3 = if statusText == "LOCKED" then COLORS.muted else COLORS.text
	local requirement = label(
		card,
		string.format("%d COMPLETED EXPEDITIONS", rank.RequiredCompletedExpeditions),
		UDim2.fromOffset(12, 36),
		UDim2.new(0.58, -12, 0, 20),
		9
	)
	requirement.TextColor3 = COLORS.muted
	local status = label(card, statusText, UDim2.new(0.58, 0, 0, 36), UDim2.new(0.42, -12, 0, 20), 9)
	status.TextXAlignment = Enum.TextXAlignment.Right
	status.TextColor3 = statusColor

	if #unlocks == 0 then
		local note = label(
			card,
			if rank.Rank == 1 then "OPERATIVE RECORD ESTABLISHED" else "DURABLE MILESTONE",
			UDim2.fromOffset(12, 55),
			UDim2.new(1, -24, 0, 15),
			8
		)
		note.TextColor3 = COLORS.locked
	else
		local unlockHeading = label(card, "RANK UNLOCKS", UDim2.fromOffset(12, 58), UDim2.new(1, -24, 0, 15), 8)
		unlockHeading.TextColor3 = statusColor
		for index, unlock in unlocks do
			local unlockLabel = label(
				card,
				string.format("%s  //  %s", string.upper(unlock.DisplayName), unlock.Description),
				UDim2.fromOffset(12, 74 + (index - 1) * 26),
				UDim2.new(1, -24, 0, 24),
				8
			)
			unlockLabel.TextWrapped = true
			unlockLabel.TextColor3 = if statusText == "LOCKED" then COLORS.muted else COLORS.text
		end
	end

	return cardHeight
end

function Presentation.rebuild(panel: ScrollingFrame)
	clear(panel)
	local snapshot = readSnapshot()
	local completed = if snapshot ~= nil then tonumber(snapshot.CompletedExpeditions) or 0 else 0
	local currentRank = if snapshot ~= nil then tonumber(snapshot.Rank) or 1 else 1
	local currentName = if snapshot ~= nil and type(snapshot.RankDisplayName) == "string"
		then snapshot.RankDisplayName
		else "Unavailable"

	local heading =
		label(panel, "OPERATIVE PROGRESSION  //  DURABLE", UDim2.fromOffset(8, 2), UDim2.new(1, -16, 0, 28), 14)
	heading.TextColor3 = COLORS.gold
	local summary = label(
		panel,
		string.format("RANK %d  //  %s  //  %d LIFETIME CLEARS", currentRank, string.upper(currentName), completed),
		UDim2.fromOffset(8, 29),
		UDim2.new(1, -16, 0, 22),
		10
	)
	summary.TextColor3 = if snapshot ~= nil then COLORS.text else COLORS.muted
	local explanation = label(
		panel,
		"Completed expeditions advance this personal record. Temporary Field XP and run upgrades reset each run.",
		UDim2.fromOffset(8, 51),
		UDim2.new(1, -16, 0, 30),
		9
	)
	explanation.TextWrapped = true
	explanation.TextColor3 = COLORS.muted

	local y = 88
	for _, rank in OperativeProgressionConfig.Ranks do
		local cardHeight = milestoneCard(panel, rank, snapshot, y)
		y += cardHeight + 10
	end
	panel.CanvasSize = UDim2.fromOffset(0, y + 8)
end

return table.freeze(Presentation)
