--!strict

--[[
	Unified client presentation for the horde vertical slice. It renders only
	server-disclosed state plus client-local caches populated by existing
	controllers. Upgrade buttons send one offered ID; the server revalidates it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Controller = {}
local localPlayer = Players.LocalPlayer
local network = ReplicatedStorage:WaitForChild("HordeNetwork")
local stateRemote = network:WaitForChild("State") :: RemoteEvent

-- Progression is owned by RunProgressionService. The combat HUD only renders its
-- published snapshot and submits one offered upgrade ID back to it.
local progressionNetwork = ReplicatedStorage:WaitForChild("ProgressionNetwork")
local progressionStateRemote = progressionNetwork:WaitForChild("State") :: RemoteEvent
local progressionReadStateRemote = progressionNetwork:WaitForChild("ReadState") :: RemoteFunction
local progressionChooseUpgradeRemote = progressionNetwork:WaitForChild("ChooseUpgrade") :: RemoteEvent

local started = false
local connections: { RBXScriptConnection } = {}
local screenGui: ScreenGui? = nil
local lastRevision = -1
local lastProgressionRevision = -1
local lastEventSequence = -1
local lastProgressionGainSequence = -1
local lastSelectionSequence = -1
local eventVisibleUntil = 0
local upgradeButtons: { TextButton } = {}

local objectiveLabel: TextLabel? = nil
local radioLabel: TextLabel? = nil
local threatLabel: TextLabel? = nil
local threatFill: Frame? = nil
local enemyCountLabel: TextLabel? = nil
local healthText: TextLabel? = nil
local healthFill: Frame? = nil
local lifeStateLabel: TextLabel? = nil
local xpText: TextLabel? = nil
local xpFill: Frame? = nil
local levelLabel: TextLabel? = nil
local ammoLabel: TextLabel? = nil
local combatStatusLabel: TextLabel? = nil
local streakLabel: TextLabel? = nil
local squadLabel: TextLabel? = nil
local eventLabel: TextLabel? = nil
local extractionLabel: TextLabel? = nil
local upgradeOverlay: Frame? = nil
local upgradeTitle: TextLabel? = nil
local upgradeContainer: Frame? = nil

local function addCorner(instance: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local function addStroke(instance: GuiObject, transparency: number, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(173, 46, 42)
	stroke.Transparency = transparency
	stroke.Thickness = thickness
	stroke.Parent = instance
end

local function createPanel(parent: Instance, name: string, position: UDim2, size: UDim2, anchor: Vector2): Frame
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.AnchorPoint = anchor
	panel.Position = position
	panel.Size = size
	panel.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
	panel.BackgroundTransparency = 0.12
	panel.BorderSizePixel = 0
	panel.Parent = parent
	addCorner(panel, 8)
	addStroke(panel, 0.52, 1)
	return panel
end

local function createLabel(
	parent: Instance,
	name: string,
	position: UDim2,
	size: UDim2,
	textSize: number,
	font: Enum.Font,
	alignment: Enum.TextXAlignment
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = font
	label.Text = ""
	label.TextColor3 = Color3.fromRGB(239, 236, 226)
	label.TextSize = textSize
	label.TextXAlignment = alignment
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = true
	label.Parent = parent
	return label
end

local function createBar(parent: Instance, name: string, position: UDim2, size: UDim2): (Frame, Frame)
	local track = Instance.new("Frame")
	track.Name = name
	track.Position = position
	track.Size = size
	track.BackgroundColor3 = Color3.fromRGB(38, 36, 40)
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	track.Parent = parent
	addCorner(track, 4)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(177, 41, 41)
	fill.BorderSizePixel = 0
	fill.Parent = track
	addCorner(fill, 4)
	return track, fill
end

local function setBar(fill: Frame?, fraction: number)
	if fill ~= nil then
		fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	end
end

local function readNumberAttribute(name: string, fallback: number): number
	local value = localPlayer:GetAttribute(name)
	return if type(value) == "number" then value else fallback
end

local function readStringAttribute(name: string, fallback: string): string
	local value = localPlayer:GetAttribute(name)
	return if type(value) == "string" then value else fallback
end

local function updateMissionPresentation(serverTimestamp: number)
	local objective = objectiveLabel
	if objective ~= nil then
		local text = readStringAttribute("LK_HUD_Objective", "Regroup and survive")
		local extractionUnlocked = localPlayer:GetAttribute("LK_HUD_ExtractionUnlocked") == true
		objective.Text = if extractionUnlocked
			then "OBJECTIVE  //  " .. text .. "  //  EXTRACT"
			else "OBJECTIVE  //  " .. text
	end
	local radio = radioLabel
	if radio ~= nil then
		local text = readStringAttribute("LK_HUD_RadioText", "")
		radio.Text = text
		radio.Visible = text ~= ""
	end
	local extraction = extractionLabel
	if extraction ~= nil then
		local phase = readStringAttribute("LK_HUD_MissionPhase", "")
		local deadline = localPlayer:GetAttribute("LK_HUD_HoldoutDeadline")
		if phase == "Holdout" and type(deadline) == "number" then
			local remaining = math.max(0, deadline - serverTimestamp)
			extraction.Text = string.format("EXTRACTION  %02d:%02d", remaining // 60, math.floor(remaining % 60))
			extraction.Visible = true
		elseif phase == "Resolved" then
			local outcome = readStringAttribute("LK_HUD_Outcome", "Failure")
			extraction.Text = if outcome == "Success" then "OPERATION SURVIVED" else "SQUAD CONSUMED"
			extraction.TextColor3 = if outcome == "Success"
				then Color3.fromRGB(114, 232, 148)
				else Color3.fromRGB(255, 74, 67)
			extraction.Visible = true
		else
			extraction.Visible = false
		end
	end
end

local function updateLifePresentation()
	local currentHealth = readNumberAttribute("LK_P3_CurrentHealth", 0)
	local maximumHealth = math.max(1, readNumberAttribute("LK_P3_MaximumHealth", 100))
	local lifeState = readStringAttribute("LK_P3_LifeState", "REGISTERING")
	if healthText ~= nil then
		healthText.Text = string.format("%d / %d", currentHealth, maximumHealth)
	end
	if healthFill ~= nil then
		healthFill.BackgroundColor3 = if currentHealth / maximumHealth <= 0.25
			then Color3.fromRGB(255, 54, 47)
			else Color3.fromRGB(183, 45, 45)
	end
	setBar(healthFill, currentHealth / maximumHealth)
	if lifeStateLabel ~= nil then
		local reviveStatus = readStringAttribute("LK_P3_ReviveStatus", "")
		local reviveProgress = readNumberAttribute("LK_P3_ReviveProgress", 0)
		local suffix = if reviveStatus == "Active"
			then string.format("  //  REVIVING %.0f%%", reviveProgress * 100)
			else ""
		lifeStateLabel.Text = "LIFE  //  " .. string.upper(lifeState) .. suffix
		lifeStateLabel.TextColor3 = if lifeState == "Alive"
			then Color3.fromRGB(220, 218, 205)
			else Color3.fromRGB(255, 77, 65)
	end
end

local function updateCombatPresentation(serverTimestamp: number)
	local loaded = readNumberAttribute("LK_HUD_LoadedRounds", 0)
	local reserve = readNumberAttribute("LK_HUD_ReserveRounds", 0)
	local capacity = readNumberAttribute("LK_HUD_MagazineCapacity", 0)
	if ammoLabel ~= nil then
		ammoLabel.Text = string.format("%02d  /  %02d\nRESERVE  %03d", loaded, capacity, reserve)
		ammoLabel.TextColor3 = if loaded == 0 then Color3.fromRGB(255, 72, 60) else Color3.fromRGB(239, 236, 226)
	end
	if combatStatusLabel ~= nil then
		local status = readStringAttribute("LK_HUD_CombatStatus", "")
		local statusUntil = localPlayer:GetAttribute("LK_HUD_CombatStatusUntil")
		combatStatusLabel.Text = status
		combatStatusLabel.Visible = status ~= "" and type(statusUntil) == "number" and serverTimestamp <= statusUntil
	end
end

local function updateSquadPresentation()
	local originCharacter = localPlayer.Character
	local originRoot = if originCharacter == nil then nil else originCharacter:FindFirstChild("HumanoidRootPart")
	local lines = {}
	for _, player in Players:GetPlayers() do
		local state = player:GetAttribute("LK_P3_LifeState")
		local health = player:GetAttribute("LK_P3_CurrentHealth")
		local distanceText = ""
		if player ~= localPlayer and originRoot ~= nil and originRoot:IsA("BasePart") then
			local character = player.Character
			local root = if character == nil then nil else character:FindFirstChild("HumanoidRootPart")
			if root ~= nil and root:IsA("BasePart") then
				distanceText = string.format("  %dm", math.floor((root.Position - originRoot.Position).Magnitude))
			end
		end
		table.insert(
			lines,
			string.format(
				"%s  %s  %s%s",
				player.DisplayName,
				tostring(state or "?"),
				tostring(health or 0),
				distanceText
			)
		)
	end
	if squadLabel ~= nil then
		squadLabel.Text = table.concat(lines, "\n")
	end
end

local function clearUpgradeButtons()
	for _, button in upgradeButtons do
		button:Destroy()
	end
	table.clear(upgradeButtons)
end

local function renderUpgradeChoices(choices: { any })
	local overlay = upgradeOverlay
	local container = upgradeContainer
	if overlay == nil or container == nil then
		return
	end
	clearUpgradeButtons()
	if #choices == 0 then
		overlay.Visible = false
		return
	end
	overlay.Visible = true
	if upgradeTitle ~= nil then
		upgradeTitle.Text = "LEVEL UP  //  CHOOSE YOUR MUTATION"
	end
	for index, choice in choices do
		if type(choice) ~= "table" or type(choice.id) ~= "string" then
			continue
		end
		local button = Instance.new("TextButton")
		button.Name = "Choice" .. tostring(index)
		button.LayoutOrder = index
		button.Size = UDim2.new(1, -16, 0, 88)
		button.BackgroundColor3 = Color3.fromRGB(24, 20, 23)
		button.BorderSizePixel = 0
		button.AutoButtonColor = true
		button.Font = Enum.Font.GothamBold
		button.TextColor3 = Color3.fromRGB(244, 232, 215)
		button.TextSize = 17
		button.TextWrapped = true
		button.Text = string.format(
			"%s   [%d/%d]\n%s",
			string.upper(tostring(choice.name or choice.id)),
			tonumber(choice.stacks) or 0,
			tonumber(choice.maximumStacks) or 1,
			tostring(choice.description or "")
		)
		button.Parent = container
		addCorner(button, 7)
		addStroke(button, 0.35, 1)
		local upgradeId = choice.id
		button.Activated:Connect(function()
			button.Active = false
			progressionChooseUpgradeRemote:FireServer(upgradeId)
		end)
		table.insert(upgradeButtons, button)
	end
end

local function applyHordeState(payload: any)
	if type(payload.revision) ~= "number" or payload.revision < lastRevision then
		return
	end
	lastRevision = payload.revision
	local threat = if type(payload.threat) == "number" then payload.threat else 0
	if threatLabel ~= nil then
		threatLabel.Text =
			string.format("THREAT  //  %s  //  %03d", tostring(payload.threatLabel or "UNKNOWN"), math.floor(threat))
		threatLabel.TextColor3 = if threat >= 65 then Color3.fromRGB(255, 67, 54) else Color3.fromRGB(239, 190, 92)
	end
	setBar(threatFill, threat / 100)
	if enemyCountLabel ~= nil then
		enemyCountLabel.Text = string.format("HOSTILES  %03d", tonumber(payload.activeEnemies) or 0)
	end
	local streak = tonumber(payload.streak) or 0
	if streakLabel ~= nil then
		streakLabel.Text = if streak >= 2 then string.format("MASSACRE x%d", streak) else ""
		streakLabel.Visible = streak >= 2
	end
	local eventSequence = tonumber(payload.lastEventSequence) or 0
	if eventLabel ~= nil and eventSequence > lastEventSequence then
		lastEventSequence = eventSequence
		eventLabel.Text = tostring(payload.lastEventText or "")
		eventLabel.TextColor3 = if payload.lastEventKind == "Threat"
			then Color3.fromRGB(255, 77, 62)
			else Color3.fromRGB(214, 235, 219)
		eventLabel.Visible = eventLabel.Text ~= ""
		eventVisibleUntil = Workspace:GetServerTimeNow() + 3.5
	end
end

local function showEvent(text: string, color: Color3)
	if eventLabel == nil or text == "" then
		return
	end
	eventLabel.Text = text
	eventLabel.TextColor3 = color
	eventLabel.Visible = true
	eventVisibleUntil = Workspace:GetServerTimeNow() + 3.5
end

-- Field XP, levels, and upgrade offers come exclusively from RunProgressionService
-- through ProgressionNetwork. This renders the single XP bar and the single
-- upgrade overlay.
local function applyProgressionState(snapshot: any)
	if type(snapshot) ~= "table" then
		return
	end
	local revisionValue = snapshot.revision
	if type(revisionValue) ~= "number" or revisionValue <= lastProgressionRevision then
		return
	end
	lastProgressionRevision = revisionValue
	local level = tonumber(snapshot.level) or 1
	local xp = tonumber(snapshot.xp) or 0
	local xpForNext = tonumber(snapshot.xpForNextLevel) or 0
	if levelLabel ~= nil then
		levelLabel.Text = string.format("FIELD LEVEL %02d", level)
	end
	if xpText ~= nil then
		xpText.Text = if xpForNext <= 0 then "MAX LEVEL" else string.format("XP  %d / %d", xp, xpForNext)
	end
	setBar(xpFill, if xpForNext <= 0 then 1 else xp / xpForNext)

	local selectionSequence = tonumber(snapshot.selectionSequence) or 0
	local selectedName = if type(snapshot.lastSelectedUpgradeName) == "string"
		then snapshot.lastSelectedUpgradeName
		else ""
	local gainSequence = tonumber(snapshot.lastGainSequence) or 0
	local levelsGained = tonumber(snapshot.levelsGainedLastAward) or 0
	if selectionSequence > lastSelectionSequence and selectedName ~= "" then
		lastSelectionSequence = selectionSequence
		showEvent(string.format("SQUAD UPGRADE  //  %s", string.upper(selectedName)), Color3.fromRGB(247, 198, 79))
	elseif gainSequence > lastProgressionGainSequence then
		lastProgressionGainSequence = gainSequence
		if levelsGained > 0 then
			showEvent(string.format("FIELD LEVEL %02d — CHOOSE AN UPGRADE", level), Color3.fromRGB(247, 198, 79))
		end
	end

	renderUpgradeChoices(if type(snapshot.pendingChoices) == "table" then snapshot.pendingChoices else {})
end

local function onState(payload: unknown)
	if type(payload) ~= "table" then
		return
	end
	applyHordeState(payload :: any)
end

local function onProgressionState(snapshot: unknown)
	applyProgressionState(snapshot :: any)
end

local function createPresentation()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LivingKingdomsHordeHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local objectivePanel =
		createPanel(gui, "ObjectivePanel", UDim2.new(0.5, 0, 0, 18), UDim2.fromOffset(720, 74), Vector2.new(0.5, 0))
	objectiveLabel = createLabel(
		objectivePanel,
		"Objective",
		UDim2.fromOffset(18, 8),
		UDim2.new(1, -36, 0, 28),
		17,
		Enum.Font.GothamBold,
		Enum.TextXAlignment.Center
	)
	radioLabel = createLabel(
		objectivePanel,
		"Radio",
		UDim2.fromOffset(18, 38),
		UDim2.new(1, -36, 0, 26),
		14,
		Enum.Font.GothamMedium,
		Enum.TextXAlignment.Center
	)
	radioLabel.TextColor3 = Color3.fromRGB(199, 182, 148)

	local threatPanel =
		createPanel(gui, "ThreatPanel", UDim2.new(0.5, 0, 0, 100), UDim2.fromOffset(520, 55), Vector2.new(0.5, 0))
	threatLabel = createLabel(
		threatPanel,
		"Threat",
		UDim2.fromOffset(14, 3),
		UDim2.new(1, -160, 0, 26),
		16,
		Enum.Font.GothamBold,
		Enum.TextXAlignment.Left
	)
	enemyCountLabel = createLabel(
		threatPanel,
		"EnemyCount",
		UDim2.new(1, -145, 0, 3),
		UDim2.fromOffset(130, 26),
		14,
		Enum.Font.GothamBold,
		Enum.TextXAlignment.Right
	)
	local _, createdThreatFill = createBar(threatPanel, "ThreatBar", UDim2.fromOffset(14, 34), UDim2.new(1, -28, 0, 10))
	createdThreatFill.BackgroundColor3 = Color3.fromRGB(207, 50, 43)
	threatFill = createdThreatFill

	local lifePanel =
		createPanel(gui, "LifePanel", UDim2.new(0, 20, 1, -22), UDim2.fromOffset(330, 126), Vector2.new(0, 1))
	lifeStateLabel = createLabel(
		lifePanel,
		"LifeState",
		UDim2.fromOffset(14, 7),
		UDim2.new(1, -28, 0, 24),
		14,
		Enum.Font.GothamBold,
		Enum.TextXAlignment.Left
	)
	healthText = createLabel(
		lifePanel,
		"HealthText",
		UDim2.fromOffset(14, 34),
		UDim2.new(1, -28, 0, 25),
		20,
		Enum.Font.GothamBold,
		Enum.TextXAlignment.Left
	)
	local _, createdHealthFill = createBar(lifePanel, "HealthBar", UDim2.fromOffset(14, 64), UDim2.new(1, -28, 0, 12))
	healthFill = createdHealthFill
	levelLabel = createLabel(
		lifePanel,
		"Level",
		UDim2.fromOffset(14, 82),
		UDim2.new(1, -28, 0, 20),
		13,
		Enum.Font.GothamBold,
		Enum.TextXAlignment.Left
	)
	xpText = createLabel(
		lifePanel,
		"XPText",
		UDim2.new(1, -140, 0, 82),
		UDim2.fromOffset(126, 20),
		12,
		Enum.Font.GothamMedium,
		Enum.TextXAlignment.Right
	)
	local _, createdXpFill = createBar(lifePanel, "XPBar", UDim2.fromOffset(14, 107), UDim2.new(1, -28, 0, 7))
	createdXpFill.BackgroundColor3 = Color3.fromRGB(231, 173, 57)
	xpFill = createdXpFill

	local ammoPanel =
		createPanel(gui, "AmmoPanel", UDim2.new(1, -20, 1, -22), UDim2.fromOffset(265, 106), Vector2.new(1, 1))
	ammoLabel = createLabel(
		ammoPanel,
		"Ammo",
		UDim2.fromOffset(14, 8),
		UDim2.new(1, -28, 0, 66),
		23,
		Enum.Font.GothamBold,
		Enum.TextXAlignment.Right
	)
	combatStatusLabel = createLabel(
		ammoPanel,
		"CombatStatus",
		UDim2.fromOffset(14, 76),
		UDim2.new(1, -28, 0, 22),
		13,
		Enum.Font.GothamBold,
		Enum.TextXAlignment.Right
	)
	combatStatusLabel.TextColor3 = Color3.fromRGB(245, 184, 71)

	local squadPanel =
		createPanel(gui, "SquadPanel", UDim2.new(0, 20, 0.5, 0), UDim2.fromOffset(310, 122), Vector2.new(0, 0.5))
	createLabel(
		squadPanel,
		"Header",
		UDim2.fromOffset(12, 6),
		UDim2.new(1, -24, 0, 20),
		13,
		Enum.Font.GothamBold,
		Enum.TextXAlignment.Left
	).Text =
		"SQUAD"
	squadLabel = createLabel(
		squadPanel,
		"Squad",
		UDim2.fromOffset(12, 27),
		UDim2.new(1, -24, 1, -35),
		12,
		Enum.Font.Code,
		Enum.TextXAlignment.Left
	)
	squadLabel.TextYAlignment = Enum.TextYAlignment.Top

	streakLabel = createLabel(
		gui,
		"Streak",
		UDim2.new(0.5, -300, 0.72, 0),
		UDim2.fromOffset(600, 40),
		25,
		Enum.Font.GothamBlack,
		Enum.TextXAlignment.Center
	)
	streakLabel.TextColor3 = Color3.fromRGB(255, 94, 61)
	streakLabel.Visible = false

	eventLabel = createLabel(
		gui,
		"EventFeed",
		UDim2.new(0.5, -360, 0.79, 0),
		UDim2.fromOffset(720, 48),
		23,
		Enum.Font.GothamBold,
		Enum.TextXAlignment.Center
	)
	eventLabel.Visible = false

	extractionLabel = createLabel(
		gui,
		"Extraction",
		UDim2.new(0.5, -260, 0.18, 0),
		UDim2.fromOffset(520, 48),
		28,
		Enum.Font.GothamBlack,
		Enum.TextXAlignment.Center
	)
	extractionLabel.TextColor3 = Color3.fromRGB(255, 133, 61)
	extractionLabel.Visible = false

	local overlay = Instance.new("Frame")
	overlay.Name = "UpgradeOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(3, 2, 4)
	overlay.BackgroundTransparency = 0.22
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.ZIndex = 100
	overlay.Parent = gui
	upgradeOverlay = overlay
	local modal = createPanel(
		overlay,
		"UpgradeModal",
		UDim2.fromScale(0.5, 0.5),
		UDim2.fromOffset(620, 390),
		Vector2.new(0.5, 0.5)
	)
	modal.ZIndex = 101
	upgradeTitle = createLabel(
		modal,
		"Title",
		UDim2.fromOffset(18, 12),
		UDim2.new(1, -36, 0, 42),
		22,
		Enum.Font.GothamBlack,
		Enum.TextXAlignment.Center
	)
	upgradeTitle.ZIndex = 102
	local container = Instance.new("Frame")
	container.Name = "Choices"
	container.Position = UDim2.fromOffset(12, 65)
	container.Size = UDim2.new(1, -24, 1, -78)
	container.BackgroundTransparency = 1
	container.ZIndex = 102
	container.Parent = modal
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = container
	upgradeContainer = container

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	screenGui = gui
end

local function updateFrame()
	local serverTimestamp = Workspace:GetServerTimeNow()
	updateMissionPresentation(serverTimestamp)
	updateLifePresentation()
	updateCombatPresentation(serverTimestamp)
	updateSquadPresentation()
	if eventLabel ~= nil and eventLabel.Visible and serverTimestamp > eventVisibleUntil then
		eventLabel.Visible = false
	end
end

function Controller.start()
	if started then
		return
	end
	started = true
	createPresentation()
	table.insert(connections, stateRemote.OnClientEvent:Connect(onState))
	table.insert(connections, progressionStateRemote.OnClientEvent:Connect(onProgressionState))
	table.insert(connections, RunService.RenderStepped:Connect(updateFrame))

	-- Recover the current progression snapshot for late joins so the XP bar and
	-- any pending upgrade offer render immediately.
	local didRead, initialSnapshot = pcall(function()
		return progressionReadStateRemote:InvokeServer()
	end)
	if didRead then
		applyProgressionState(initialSnapshot :: any)
	end
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
	clearUpgradeButtons()
	if screenGui ~= nil then
		screenGui:Destroy()
		screenGui = nil
	end
	lastRevision = -1
	lastProgressionRevision = -1
	lastEventSequence = -1
	lastProgressionGainSequence = -1
	lastSelectionSequence = -1
end

return Controller
