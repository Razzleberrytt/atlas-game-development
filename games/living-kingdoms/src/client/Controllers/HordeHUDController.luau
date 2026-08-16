--!strict

--[[
	Unified client presentation for the horde vertical slice. It renders only
	server-disclosed state plus client-local caches populated by existing
	controllers. Upgrade buttons send one offered ID; the server revalidates it.
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
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ChoiceInputCoordinator = require(script.Parent.ChoiceInputCoordinator)
local HordeStateEarlyListener = require(script.Parent.Parent.State.HordeStateEarlyListener)
local ActiveInputDeviceFamily = require(script.Parent.Parent.State.ActiveInputDeviceFamily)
local InputActionMapConfig = require(ReplicatedStorage.Shared.Config.InputActionMapConfig)
local InputDeviceFamilyResolver = require(ReplicatedStorage.Shared.Input.InputDeviceFamilyResolver)
local InputHintPresentationResolver = require(ReplicatedStorage.Shared.Input.InputHintPresentationResolver)

local Controller = {}
local localPlayer = Players.LocalPlayer

-- Progression is owned by RunProgressionService. The combat HUD only renders its
-- published snapshot and submits one offered upgrade ID back to it.
local progressionNetwork = ReplicatedStorage:WaitForChild("ProgressionNetwork", NETWORK_WAIT_SECONDS)
assert(progressionNetwork ~= nil, "ProgressionNetwork did not become available before the client bootstrap timeout")
local progressionStateRemote = progressionNetwork:WaitForChild("State", NETWORK_WAIT_SECONDS) :: RemoteEvent?
assert(progressionStateRemote ~= nil, "ProgressionNetwork.State did not become available before the client bootstrap timeout")
local progressionReadStateRemote = progressionNetwork:WaitForChild("ReadState", NETWORK_WAIT_SECONDS) :: RemoteFunction?
assert(
	progressionReadStateRemote ~= nil,
	"ProgressionNetwork.ReadState did not become available before the client bootstrap timeout"
)
local progressionChooseUpgradeRemote = progressionNetwork:WaitForChild("ChooseUpgrade", NETWORK_WAIT_SECONDS) :: RemoteEvent?
assert(
	progressionChooseUpgradeRemote ~= nil,
	"ProgressionNetwork.ChooseUpgrade did not become available before the client bootstrap timeout"
)

local started = false
local connections: { RBXScriptConnection } = {}
local unregisterChoiceInput: (() -> ())? = nil
local screenGui: ScreenGui? = nil
local lastRevision = -1
local lastProgressionRevision = -1
local lastEventSequence = -1
local lastProgressionGainSequence = -1
local lastSelectionSequence = -1
local lastCorruptionSequence = -1
local eventVisibleUntil = 0
local upgradeButtons: { TextButton } = {}
local upgradeChoiceIds: { [number]: string } = {}
local upgradeInputActive = false
local mouseIconWasEnabled = false

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
local runStatsPrimaryLabel: TextLabel? = nil
local runStatsSecondaryLabel: TextLabel? = nil
local ammoLabel: TextLabel? = nil
local combatStatusLabel: TextLabel? = nil
local squadLabel: TextLabel? = nil
local eventLabel: TextLabel? = nil
local extractionLabel: TextLabel? = nil
local upgradeOverlay: Frame? = nil
local upgradeTitle: TextLabel? = nil
local upgradeContainer: Frame? = nil
local playerListWasDisabled = false
local hasUpgradeChoices = false
local lastObservedLevel = -1
local levelCelebration: Frame? = nil
local levelCelebrationText: TextLabel? = nil
local controlsHint: TextLabel? = nil
local controlsHintVisibleUntil = 0
-- Retained so a mid-run device switch can re-render the offer with that device's
-- affordances rather than leaving stale keyboard text on screen.
local lastUpgradeChoices: { any } = {}

-- BA-062 device-adaptive hints. The HUD renders the canonical action map rather
-- than literal keyboard text, so a controller or touch player is never told to
-- press a key that does nothing on their device. An action with no direct binding
-- on the active family is omitted instead of being given an invented shortcut.
local CONTROL_STRIP_ENTRIES = table.freeze({
	table.freeze({ ActionId = "Move", Label = "MOVE", Separator = "" }),
	table.freeze({ ActionId = "Interact", Label = "INTERACT / PICK UP" }),
	table.freeze({ ActionId = "Reload", Label = "RELOAD" }),
	table.freeze({ ActionId = "Flashlight", Label = "FLASHLIGHT" }),
})

local function activeDeviceFamily(): string
	return ActiveInputDeviceFamily.get()
end

local function controlStripText(familyId: string): string
	local segments: { string } = {}
	for _, entry in CONTROL_STRIP_ENTRIES do
		local action = InputActionMapConfig.get(entry.ActionId)
		if action == nil then
			continue
		end
		local token = InputHintPresentationResolver.resolveText(action, familyId, {
			Separator = entry.Separator,
			MaximumTokens = if entry.Separator == "" then nil else 1,
		})
		if token ~= nil then
			table.insert(segments, string.format("%s  %s", entry.Label, token))
		end
	end
	return table.concat(segments, "  •  ")
end

--[[
	Upgrade and relic offers are chosen by direct number keys only on keyboard.
	Gamepad uses selection focus and touch uses the button itself, so those
	families get a truthful verb instead of a fabricated number shortcut.
]]
local function choiceKeyTokens(familyId: string, choiceCount: number): { string }
	local action = InputActionMapConfig.get("NumberedChoiceInput")
	if action == nil then
		return {}
	end
	return InputHintPresentationResolver.resolve(action, familyId, { MaximumTokens = choiceCount }).Tokens
end

local function choicePromptText(familyId: string, tokens: { string }): string
	if #tokens > 0 then
		return "PRESS " .. table.concat(tokens, ", ")
	end
	if familyId == InputDeviceFamilyResolver.DeviceFamilyIds.Touch then
		return "TAP ONE"
	end
	return "SELECT ONE"
end

-- The per-button index prefix and call to action only exist where a direct key
-- does; otherwise the button names the affordance the device actually has.
local function choiceButtonPrefix(tokens: { string }, choiceIndex: number): string
	local token = tokens[choiceIndex]
	return if token == nil then "" else string.format("[%s]  ", token)
end

local function choiceButtonActionText(familyId: string, tokens: { string }, choiceIndex: number): string
	local token = tokens[choiceIndex]
	if token ~= nil then
		return string.format("PRESS %s OR CLICK", token)
	end
	if familyId == InputDeviceFamilyResolver.DeviceFamilyIds.Touch then
		return "TAP TO CHOOSE"
	end
	return "SELECT TO CHOOSE"
end

local COLORS = table.freeze({
	panel = Color3.fromRGB(12, 15, 18),
	panelLow = Color3.fromRGB(20, 24, 27),
	line = Color3.fromRGB(164, 139, 91),
	text = Color3.fromRGB(242, 239, 229),
	muted = Color3.fromRGB(176, 183, 178),
	gold = Color3.fromRGB(237, 185, 77),
	danger = Color3.fromRGB(218, 58, 49),
})

local function addCorner(instance: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local function addStroke(instance: GuiObject, transparency: number, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.line
	stroke.Transparency = transparency
	stroke.Thickness = thickness
	stroke.Parent = instance
end

local function addPanelFinish(panel: Frame)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, COLORS.panelLow),
		ColorSequenceKeypoint.new(1, COLORS.panel),
	})
	gradient.Rotation = 90
	gradient.Parent = panel
	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.Position = UDim2.fromOffset(12, 0)
	accent.Size = UDim2.new(1, -24, 0, 2)
	accent.BackgroundColor3 = COLORS.line
	accent.BackgroundTransparency = 0.28
	accent.BorderSizePixel = 0
	accent.Parent = panel
end

local function createPanel(parent: Instance, name: string, position: UDim2, size: UDim2, anchor: Vector2): Frame
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.AnchorPoint = anchor
	panel.Position = position
	panel.Size = size
	panel.BackgroundColor3 = COLORS.panel
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = parent
	addCorner(panel, 10)
	addStroke(panel, 0.42, 1)
	addPanelFinish(panel)
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
	label.TextColor3 = COLORS.text
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
	track.BackgroundColor3 = Color3.fromRGB(43, 46, 47)
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	track.Parent = parent
	addCorner(track, 4)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = COLORS.danger
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
		local destination = readStringAttribute("LK_HUD_ObjectiveDestination", "")
		local progress = readNumberAttribute("LK_HUD_ObjectiveProgress", 0)
		local extractionUnlocked = localPlayer:GetAttribute("LK_HUD_ExtractionUnlocked") == true
		objective.Text = if extractionUnlocked
			then "OBJECTIVE  //  " .. text .. "  //  EXTRACT"
			elseif destination ~= "" then string.format(
				"OBJECTIVE  //  %s  //  %s  //  %d%%",
				text,
				destination,
				math.floor(progress * 100 + 0.5)
			)
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

local function showLevelCelebration(level: number)
	local flash = levelCelebration
	local title = levelCelebrationText
	if flash == nil or title == nil then
		return
	end
	title.Text = string.format("LEVEL %d!\nPOWER INCREASE AVAILABLE", level)
	flash.BackgroundTransparency = 0.2
	flash.Visible = true
	title.TextTransparency = 0
	TweenService:Create(flash, TweenInfo.new(1.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
	task.delay(1.25, function()
		if flash ~= nil then
			flash.Visible = false
		end
	end)
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
		local weaponName = readStringAttribute("LK_HUD_WeaponName", "WEAPON")
		local lightText = if localPlayer:GetAttribute("LK_HUD_FlashlightOn") == true
			then "F LIGHT ON"
			else "F LIGHT OFF"
		ammoLabel.Text =
			string.format("%s\n%02d / %02d   ·   %03d RES\n%s", weaponName, loaded, capacity, reserve, lightText)
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
		local squadPanel = squadLabel.Parent
		if squadPanel ~= nil and squadPanel:IsA("GuiObject") then
			squadPanel.Visible = #Players:GetPlayers() > 1
		end
	end
end

local function clearUpgradeButtons()
	for _, button in upgradeButtons do
		button:Destroy()
	end
	table.clear(upgradeButtons)
	table.clear(upgradeChoiceIds)
end

local function relicChoiceIsVisible(): boolean
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local runBuildHud = if playerGui == nil then nil else playerGui:FindFirstChild("LK_RunBuildHUD")
	local relicReward = if runBuildHud == nil then nil else runBuildHud:FindFirstChild("RelicReward")
	return relicReward ~= nil and relicReward:IsA("GuiObject") and relicReward.Visible
end

local function setUpgradeInputActive(active: boolean)
	if active == upgradeInputActive then
		return
	end
	upgradeInputActive = active
	if active then
		mouseIconWasEnabled = UserInputService.MouseIconEnabled
		localPlayer:SetAttribute("LK_InputModalOpen", true)
		UserInputService.MouseIconEnabled = true
		GuiService.SelectedObject = upgradeButtons[1]
	elseif not relicChoiceIsVisible() then
		localPlayer:SetAttribute("LK_InputModalOpen", nil)
		UserInputService.MouseIconEnabled = mouseIconWasEnabled
		if GuiService.SelectedObject ~= nil and table.find(upgradeButtons, GuiService.SelectedObject) ~= nil then
			GuiService.SelectedObject = nil
		end
	end
end

local function submitUpgradeChoice(choiceIndex: number)
	local upgradeId = upgradeChoiceIds[choiceIndex]
	local button = upgradeButtons[choiceIndex]
	if not upgradeInputActive or upgradeId == nil or button == nil or not button.Active then
		return
	end
	button.Active = false
	progressionChooseUpgradeRemote:FireServer(upgradeId)
end

local function renderUpgradeChoices(choices: { any })
	local overlay = upgradeOverlay
	local container = upgradeContainer
	if overlay == nil or container == nil then
		return
	end
	clearUpgradeButtons()
	if #choices == 0 then
		hasUpgradeChoices = false
		lastUpgradeChoices = {}
		overlay.Visible = false
		setUpgradeInputActive(false)
		return
	end
	hasUpgradeChoices = true
	lastUpgradeChoices = choices
	local familyId = activeDeviceFamily()
	local keyTokens = choiceKeyTokens(familyId, #choices)
	if upgradeTitle ~= nil then
		upgradeTitle.Text =
			string.format("LEVEL UP  //  CHOOSE ONE RUN UPGRADE  //  %s", choicePromptText(familyId, keyTokens))
	end
	for index, choice in choices do
		if type(choice) ~= "table" or type(choice.id) ~= "string" then
			continue
		end
		local button = Instance.new("TextButton")
		button.Name = "Choice" .. tostring(index)
		button.LayoutOrder = index
		button.Size = UDim2.new(1, -16, 0, 82)
		button.BackgroundColor3 = Color3.fromRGB(24, 20, 23)
		button.BorderSizePixel = 0
		button.AutoButtonColor = true
		button.Font = Enum.Font.GothamBold
		button.TextColor3 = Color3.fromRGB(244, 232, 215)
		button.TextSize = 13
		button.TextWrapped = true
		button.RichText = true
		local statPreview = if type(choice.statPreview) == "string" then choice.statPreview else "RUN POWER INCREASE"
		button.Text = string.format(
			'<b>%s%s</b>   <font color="#C7A85F">[%d/%d]</font>\n<font color="#F2C65D">%s</font>\n<font color="#C5CBC5">%s</font>\n<font color="#FFFFFF"><b>%s</b></font>',
			choiceButtonPrefix(keyTokens, index),
			string.upper(tostring(choice.name or choice.id)),
			tonumber(choice.stacks) or 0,
			tonumber(choice.maximumStacks) or 1,
			statPreview,
			tostring(choice.description or ""),
			choiceButtonActionText(familyId, keyTokens, index)
		)
		button.Parent = container
		addCorner(button, 7)
		addStroke(button, 0.35, 1)
		local upgradeId = choice.id
		upgradeChoiceIds[index] = upgradeId
		button.Activated:Connect(function()
			submitUpgradeChoice(index)
		end)
		table.insert(upgradeButtons, button)
	end
	setUpgradeInputActive(true)
end

local showEvent: (text: string, color: Color3) -> ()

local function applyHordeState(payload: any)
	if type(payload.revision) ~= "number" or payload.revision < lastRevision then
		return
	end
	lastRevision = payload.revision
	local threat = if type(payload.threat) == "number" then payload.threat else 0
	local corruptionTier = tonumber(payload.corruptionTier) or 0
	local corruptionIntensity = tonumber(payload.corruptionIntensity) or 0
	if threatLabel ~= nil then
		threatLabel.Text = if payload.isNight == true
			then string.format(
				"NIGHT %d  //  CORRUPTION TIER %d  //  %d%%",
				tonumber(payload.dayNumber) or 1,
				corruptionTier,
				math.floor(corruptionIntensity * 100 + 0.5)
			)
			else string.format("DAY %d  //  PREPARE  //  LIGHT THE FIRE", tonumber(payload.dayNumber) or 1)
		threatLabel.TextColor3 = if threat >= 65 then Color3.fromRGB(255, 67, 54) else Color3.fromRGB(239, 190, 92)
	end
	setBar(threatFill, threat / 100)
	local corruptionSequence = tonumber(payload.corruptionSequence) or 0
	if corruptionSequence > lastCorruptionSequence then
		if lastCorruptionSequence >= 0 then
			if corruptionTier > 0 then
				showEvent(
					string.format(
						"NIGHT DEEPENS  //  CORRUPTION TIER %d  //  +%d%% NIGHT XP",
						corruptionTier,
						corruptionTier * 8
					),
					Color3.fromRGB(194, 91, 255)
				)
			else
				showEvent("DAWN BREAKS  //  SCAVENGE, BUILD, PREPARE", Color3.fromRGB(255, 204, 102))
			end
		end
		lastCorruptionSequence = corruptionSequence
	end
	if enemyCountLabel ~= nil then
		enemyCountLabel.Text = string.format("HOSTILES  %03d", tonumber(payload.activeEnemies) or 0)
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

showEvent = function(text: string, color: Color3)
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
	if lastObservedLevel >= 0 and level > lastObservedLevel then
		showLevelCelebration(level)
	end
	lastObservedLevel = level

	local runStats = snapshot.runStats
	if type(runStats) == "table" then
		local damageBonus = tonumber(runStats.damageBonusPercent) or 0
		local fireRateBonus = tonumber(runStats.fireRateBonusPercent) or 0
		local damageReduction = tonumber(runStats.damageReductionPercent) or 0
		local reloadBonus = tonumber(runStats.reloadSpeedBonusPercent) or 0
		local ammoSave = tonumber(runStats.ammoConservationPercent) or 0
		local xpBonus = tonumber(runStats.xpBonusPercent) or 0
		if runStatsPrimaryLabel ~= nil then
			runStatsPrimaryLabel.Text =
				string.format("DMG +%d%%   RATE +%d%%   MIT %d%%", damageBonus, fireRateBonus, damageReduction)
		end
		if runStatsSecondaryLabel ~= nil then
			runStatsSecondaryLabel.Text = string.format(
				"RELOAD +%d%%   SAVE %d%%   XP +%d%%   KILLS %d",
				reloadBonus,
				ammoSave,
				xpBonus,
				tonumber(snapshot.squadKills) or 0
			)
		end
	end

	local selectionSequence = tonumber(snapshot.selectionSequence) or 0
	local selectedName = if type(snapshot.lastSelectedUpgradeName) == "string"
		then snapshot.lastSelectedUpgradeName
		else ""
	local gainSequence = tonumber(snapshot.lastGainSequence) or 0
	if selectionSequence > lastSelectionSequence and selectedName ~= "" then
		lastSelectionSequence = selectionSequence
		showEvent(string.format("FIELD UPGRADE  //  %s", string.upper(selectedName)), Color3.fromRGB(247, 198, 79))
	elseif gainSequence > lastProgressionGainSequence then
		lastProgressionGainSequence = gainSequence
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

	local hint = createLabel(
		gui,
		"FirstRunControls",
		UDim2.new(0.5, -270, 0, 72),
		UDim2.fromOffset(540, 34),
		14,
		Enum.Font.GothamBold,
		Enum.TextXAlignment.Center
	)
	hint.BackgroundColor3 = Color3.fromRGB(9, 16, 14)
	hint.BackgroundTransparency = 0.2
	hint.BorderSizePixel = 0
	hint.Text = controlStripText(activeDeviceFamily())
	hint.TextColor3 = Color3.fromRGB(245, 229, 181)
	hint.Visible = true
	addCorner(hint, 8)
	addStroke(hint, 0.55, 1)
	controlsHint = hint
	controlsHintVisibleUntil = Workspace:GetServerTimeNow() + 12

	local objectivePanel =
		createPanel(gui, "ObjectivePanel", UDim2.new(0.5, 0, 0, 12), UDim2.fromOffset(480, 50), Vector2.new(0.5, 0))
	objectiveLabel = createLabel(
		objectivePanel,
		"Objective",
		UDim2.fromOffset(18, 6),
		UDim2.new(1, -36, 0, 25),
		16,
		Enum.Font.GothamBold,
		Enum.TextXAlignment.Center
	)
	radioLabel = createLabel(
		objectivePanel,
		"Radio",
		UDim2.fromOffset(18, 30),
		UDim2.new(1, -36, 0, 18),
		11,
		Enum.Font.GothamMedium,
		Enum.TextXAlignment.Center
	)
	radioLabel.TextColor3 = COLORS.muted

	local threatPanel =
		createPanel(gui, "ThreatPanel", UDim2.new(0.5, 0, 0, 68), UDim2.fromOffset(340, 38), Vector2.new(0.5, 0))
	-- Threat remains available to ambience and diagnostics, but the permanent
	-- wave-style meter added noise without helping the player's next decision.
	threatPanel.Visible = false
	threatLabel = createLabel(
		threatPanel,
		"Threat",
		UDim2.fromOffset(14, 3),
		UDim2.new(1, -160, 0, 26),
		15,
		Enum.Font.GothamBold,
		Enum.TextXAlignment.Left
	)
	enemyCountLabel = createLabel(
		threatPanel,
		"EnemyCount",
		UDim2.new(1, -145, 0, 3),
		UDim2.fromOffset(130, 26),
		13,
		Enum.Font.GothamBold,
		Enum.TextXAlignment.Right
	)
	local _, createdThreatFill = createBar(threatPanel, "ThreatBar", UDim2.fromOffset(14, 31), UDim2.new(1, -28, 0, 7))
	createdThreatFill.BackgroundColor3 = Color3.fromRGB(207, 50, 43)
	threatFill = createdThreatFill

	local lifePanel =
		createPanel(gui, "LifePanel", UDim2.new(0, 16, 1, -16), UDim2.fromOffset(250, 106), Vector2.new(0, 1))
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
	local _, createdXpFill = createBar(lifePanel, "XPBar", UDim2.fromOffset(14, 98), UDim2.new(1, -28, 0, 5))
	createdXpFill.BackgroundColor3 = Color3.fromRGB(231, 173, 57)
	xpFill = createdXpFill
	runStatsPrimaryLabel = createLabel(
		lifePanel,
		"RunStatsPrimary",
		UDim2.fromOffset(14, 108),
		UDim2.new(1, -28, 0, 14),
		10,
		Enum.Font.Code,
		Enum.TextXAlignment.Left
	)
	runStatsPrimaryLabel.TextColor3 = COLORS.gold
	runStatsPrimaryLabel.Visible = false
	runStatsSecondaryLabel = createLabel(
		lifePanel,
		"RunStatsSecondary",
		UDim2.fromOffset(14, 123),
		UDim2.new(1, -28, 0, 14),
		9,
		Enum.Font.Code,
		Enum.TextXAlignment.Left
	)
	runStatsSecondaryLabel.TextColor3 = COLORS.muted
	runStatsSecondaryLabel.Visible = false

	local ammoPanel =
		createPanel(gui, "AmmoPanel", UDim2.new(1, -16, 1, -16), UDim2.fromOffset(214, 96), Vector2.new(1, 1))
	ammoLabel = createLabel(
		ammoPanel,
		"Ammo",
		UDim2.fromOffset(14, 8),
		UDim2.new(1, -28, 0, 66),
		18,
		Enum.Font.GothamBold,
		Enum.TextXAlignment.Right
	)
	combatStatusLabel = createLabel(
		ammoPanel,
		"CombatStatus",
		UDim2.fromOffset(14, 64),
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
	overlay.BackgroundColor3 = Color3.fromRGB(2, 4, 5)
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.ZIndex = 20
	overlay.Parent = gui
	upgradeOverlay = overlay
	local modal = createPanel(
		overlay,
		"UpgradeModal",
		UDim2.fromScale(0.5, 0.5),
		UDim2.fromOffset(470, 350),
		Vector2.new(0.5, 0.5)
	)
	modal.BackgroundTransparency = 0.02
	modal.ZIndex = 21
	upgradeTitle = createLabel(
		modal,
		"Title",
		UDim2.fromOffset(18, 12),
		UDim2.new(1, -36, 0, 42),
		18,
		Enum.Font.GothamBlack,
		Enum.TextXAlignment.Center
	)
	upgradeTitle.ZIndex = 22
	local container = Instance.new("Frame")
	container.Name = "Choices"
	container.Position = UDim2.fromOffset(14, 62)
	container.Size = UDim2.new(1, -28, 1, -76)
	container.BackgroundTransparency = 1
	container.ZIndex = 22
	container.Parent = modal
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = container
	upgradeContainer = container

	local celebration = Instance.new("Frame")
	celebration.Name = "LevelCelebration"
	celebration.Size = UDim2.fromScale(1, 1)
	celebration.BackgroundColor3 = Color3.fromRGB(255, 190, 55)
	celebration.BackgroundTransparency = 1
	celebration.BorderSizePixel = 0
	celebration.Visible = false
	celebration.ZIndex = 40
	celebration.Parent = gui
	local celebrationText = createLabel(
		celebration,
		"CelebrationText",
		UDim2.new(0.5, -300, 0.28, 0),
		UDim2.fromOffset(600, 130),
		34,
		Enum.Font.GothamBlack,
		Enum.TextXAlignment.Center
	)
	celebrationText.TextColor3 = Color3.fromRGB(255, 247, 210)
	celebrationText.TextStrokeColor3 = Color3.fromRGB(86, 39, 10)
	celebrationText.TextStrokeTransparency = 0.1
	celebrationText.TextWrapped = true
	celebrationText.ZIndex = 41
	levelCelebration = celebration
	levelCelebrationText = celebrationText

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	screenGui = gui
end

local function updateFrame()
	local serverTimestamp = Workspace:GetServerTimeNow()
	updateMissionPresentation(serverTimestamp)
	updateLifePresentation()
	updateCombatPresentation(serverTimestamp)
	updateSquadPresentation()
	local overlay = upgradeOverlay
	if overlay ~= nil then
		local relicChoiceVisible = relicChoiceIsVisible()
		overlay.Visible = hasUpgradeChoices and not relicChoiceVisible
		setUpgradeInputActive(overlay.Visible)
	end
	if controlsHint ~= nil and controlsHint.Visible and serverTimestamp > controlsHintVisibleUntil then
		controlsHint.Visible = false
	end
	if eventLabel ~= nil and eventLabel.Visible and serverTimestamp > eventVisibleUntil then
		eventLabel.Visible = false
	end
end

function Controller.start()
	if started then
		return
	end
	started = true
	-- The production squad panel already provides the useful roster facts. The
	-- default leaderboard duplicates it and obscures the right side at four
	-- players, so keep the gameplay surface clear.
	playerListWasDisabled = pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
	createPresentation()
	unregisterChoiceInput = ChoiceInputCoordinator.register("UpgradeChoice", function()
		return upgradeInputActive
	end, submitUpgradeChoice)
	table.insert(connections, HordeStateEarlyListener.subscribe(onState))
	table.insert(connections, progressionStateRemote.OnClientEvent:Connect(onProgressionState))
	table.insert(connections, RunService.RenderStepped:Connect(updateFrame))
	-- Rewrite the hints when the player switches device so a controller picked up
	-- mid-run stops showing keyboard keys. This fires only on a real family
	-- change, so window focus events do not churn the HUD.
	table.insert(
		connections,
		ActiveInputDeviceFamily.onChanged(function(familyId)
			if controlsHint ~= nil then
				controlsHint.Text = controlStripText(familyId)
			end
			if hasUpgradeChoices then
				renderUpgradeChoices(lastUpgradeChoices)
			end
		end)
	)

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
	if unregisterChoiceInput ~= nil then
		unregisterChoiceInput()
		unregisterChoiceInput = nil
	end
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	setUpgradeInputActive(false)
	clearUpgradeButtons()
	if screenGui ~= nil then
		screenGui:Destroy()
		screenGui = nil
	end
	if playerListWasDisabled then
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
		end)
		playerListWasDisabled = false
	end
	lastRevision = -1
	lastProgressionRevision = -1
	lastEventSequence = -1
	lastProgressionGainSequence = -1
	lastSelectionSequence = -1
	hasUpgradeChoices = false
	lastObservedLevel = -1
	lastCorruptionSequence = -1
	levelCelebration = nil
	levelCelebrationText = nil
	runStatsPrimaryLabel = nil
	runStatsSecondaryLabel = nil
	controlsHint = nil
	controlsHintVisibleUntil = 0
	lastUpgradeChoices = {}
end

return Controller
