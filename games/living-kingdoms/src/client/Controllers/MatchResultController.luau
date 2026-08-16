--!strict

--[[
	P10-0104 operation debrief. Renders only the server's validated
	`SafeMatchResultSnapshot`: the outcome and its cause in plain language, the key
	operation events, and the per-operative contribution facts.

	RPG-0112 adds the completed run build to the same screen: the relics each
	operative finished holding and the squad Field Upgrade stacks, named as the HUD
	named them. No XP is implied by either.

	The controller establishes nothing. It sends no request of any kind, derives no
	outcome, and refuses a payload that fails the shared validator. A client that
	arrives after resolution is pushed the same frozen snapshot on join.

	It deliberately shows **no XP, rank, or unlock** — P11 owns those. It offers no
	control either: the P10-0105 lifecycle owner restarts the operation from the
	server after the configured debrief window, so the screen states what will
	happen rather than presenting a button.
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

local MatchResultConfig = require(ReplicatedStorage.Shared.Config.MatchResultConfig)
local MatchResultContracts = require(ReplicatedStorage.Shared.Mission.MatchResultContracts)
local RunRpgConfig = require(ReplicatedStorage.Shared.Config.RunRpgConfig)
local RunProgressionConfig = require(ReplicatedStorage.Shared.Config.RunProgressionConfig)
local InterfaceTheme = require(script.Parent.Parent.UI.InterfaceTheme)

type SafeMatchResultSnapshot = MatchResultContracts.SafeMatchResultSnapshot

local MatchResultController = {}

local GUI_NAME = "LK_MatchResultDebrief"

local started = false
local resultConnection: RBXScriptConnection? = nil
local missionPhaseConnection: RBXScriptConnection? = nil
local screenGui: ScreenGui? = nil
local headlineLabel: TextLabel? = nil
local causeLabel: TextLabel? = nil
local eventsLabel: TextLabel? = nil
local contributionLabel: TextLabel? = nil
local buildLabel: TextLabel? = nil
local nextActionLabel: TextLabel? = nil
local hasDisplayedResult = false

local localPlayer = Players.LocalPlayer
local missionNetwork = ReplicatedStorage:WaitForChild("MissionNetwork", NETWORK_WAIT_SECONDS)
assert(missionNetwork ~= nil, "MissionNetwork did not become available before the client bootstrap timeout")
local resultRemote = missionNetwork:WaitForChild("Result", NETWORK_WAIT_SECONDS) :: RemoteEvent?
assert(resultRemote ~= nil, "MissionNetwork.Result did not become available before the client bootstrap timeout")

local function onMissionPhaseChanged()
	if localPlayer:GetAttribute("LK_HUD_MissionPhase") ~= "Insertion" then
		return
	end
	hasDisplayedResult = false
	if screenGui ~= nil then
		screenGui.Enabled = false
	end
end

local HEADLINE_BY_CAUSE_ID: { [string]: string } = {
	Extracted = "EXTRACTION COMPLETE",
	SquadWipe = "SQUAD LOST",
	Abandoned = "OPERATION ABANDONED",
}

local EXPLANATION_BY_CAUSE_ID: { [string]: string } = {
	Extracted = "The Progenitor is down and the bird lifted with survivors aboard.",
	SquadWipe = "Every operative went down in Blackwater. Nobody made the clearing.",
	Abandoned = "The squad left the exclusion zone before the operation resolved.",
}

local SURVIVAL_TEXT_BY_STATE_ID: { [string]: string } = {
	Alive = "extracted",
	Incapacitated = "down",
	Dead = "lost",
}

local RELIC_NAME_BY_ID: { [string]: string } = {}
for _, definition in RunRpgConfig.RelicCatalog do
	RELIC_NAME_BY_ID[definition.relicId] = definition.displayName
end

local UPGRADE_NAME_BY_ID: { [string]: string } = {}
for _, definition in RunProgressionConfig.UpgradeDefinitions do
	UPGRADE_NAME_BY_ID[definition.Id] = definition.Name
end

local function section(
	parent: Instance,
	name: string,
	order: number,
	height: number,
	options: InterfaceTheme.LabelOptions
): TextLabel
	local label = InterfaceTheme.label(parent, options)
	label.Name = name
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, height)
	return label
end

-- Information-dense debrief sections sit on quieter raised cards so the player's
-- eye can scan outcome → operation facts → squad contribution → build without
-- every line competing on one flat surface.
local function cardSection(
	parent: Instance,
	name: string,
	order: number,
	height: number,
	options: InterfaceTheme.LabelOptions
): TextLabel
	local card = Instance.new("Frame")
	card.Name = name .. "Card"
	card.LayoutOrder = order
	card.Size = UDim2.new(1, 0, 0, height)
	card.BackgroundColor3 = InterfaceTheme.Palette.PanelRaised
	card.BackgroundTransparency = InterfaceTheme.Opacity.RaisedTransparency
	card.BorderSizePixel = 0
	card.Parent = parent
	InterfaceTheme.corner(card, InterfaceTheme.Radius.Control)
	InterfaceTheme.surfaceGradient(card, InterfaceTheme.Palette.PanelHighlight, InterfaceTheme.Palette.Panel)
	InterfaceTheme.stroke(card, InterfaceTheme.Palette.Line, 0.72, InterfaceTheme.Stroke.Hairline)
	InterfaceTheme.padding(card, InterfaceTheme.Spacing.Medium)

	local label = InterfaceTheme.label(card, options)
	label.Name = name
	label.Size = UDim2.fromScale(1, 1)
	return label
end

local function createGui()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild(GUI_NAME)
	if existing ~= nil then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = GUI_NAME
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Enabled = false
	gui.Parent = playerGui
	screenGui = gui

	InterfaceTheme.backdrop(gui)

	local frame = InterfaceTheme.panel(gui, "Debrief")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(720, 540)
	InterfaceTheme.padding(frame, InterfaceTheme.Spacing.XLarge)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = frame

	headlineLabel = section(frame, "Headline", 1, 38, {
		role = "Display",
		size = InterfaceTheme.TextSize.Display,
		color = InterfaceTheme.Palette.Accent,
	})
	causeLabel = section(frame, "Cause", 2, 34, {
		role = "Body",
		size = InterfaceTheme.TextSize.Subtitle,
		color = InterfaceTheme.Palette.TextMuted,
	})
	eventsLabel = cardSection(frame, "Events", 3, 90, {
		role = "Body",
		size = InterfaceTheme.TextSize.Subtitle,
	})
	contributionLabel = cardSection(frame, "Contributions", 4, 142, { role = "Body" })
	buildLabel = cardSection(frame, "Build", 5, 58, {
		role = "Body",
		color = InterfaceTheme.Palette.TextMuted,
	})
	nextActionLabel = cardSection(frame, "NextAction", 6, 42, {
		role = "Heading",
		color = InterfaceTheme.Palette.AccentBright,
		yAlign = Enum.TextYAlignment.Center,
	})
end

local function formatDuration(durationSeconds: number): string
	local wholeSeconds = math.max(0, math.floor(durationSeconds))
	return string.format("%d:%02d", wholeSeconds // 60, wholeSeconds % 60)
end

local function formatRelics(equippedRelicIds: { string }): string
	if #equippedRelicIds == 0 then
		return "no relics"
	end
	local names = {}
	for _, relicId in equippedRelicIds do
		table.insert(names, RELIC_NAME_BY_ID[relicId] or relicId)
	end
	return table.concat(names, ", ")
end

local function formatContribution(contribution: any, isLocalOperative: boolean): string
	local survival = SURVIVAL_TEXT_BY_STATE_ID[contribution.survivalStateId] or contribution.survivalStateId
	local prefix = if isLocalOperative then "YOU" else "SQUADMATE"
	return string.format(
		"%s — %s  •  %d kills  •  %d damage  •  %d revives  •  %d objectives  •  %d class actions  •  %d boss hits",
		prefix,
		survival,
		contribution.kills,
		contribution.damageDealt,
		contribution.revivesPerformed,
		contribution.objectivesContributed,
		contribution.classActionsCommitted,
		contribution.bossExposureHits
	) .. "\n    RELICS: " .. formatRelics(contribution.equippedRelicIds)
end

local function applyResult(snapshot: unknown)
	if hasDisplayedResult or not MatchResultContracts.validateSafeMatchResultSnapshot(snapshot) then
		return
	end
	local result = snapshot :: SafeMatchResultSnapshot
	local gui = screenGui
	local headline = headlineLabel
	local cause = causeLabel
	local events = eventsLabel
	local contributions = contributionLabel
	local nextAction = nextActionLabel
	if gui == nil or headline == nil or cause == nil or events == nil or contributions == nil or nextAction == nil then
		return
	end
	hasDisplayedResult = true

	headline.Text = HEADLINE_BY_CAUSE_ID[result.causeId] or string.upper(result.outcomeId)
	headline.TextColor3 = if result.causeId == "Extracted"
		then InterfaceTheme.Palette.Accent
		else InterfaceTheme.Palette.Danger
	cause.Text = EXPLANATION_BY_CAUSE_ID[result.causeId] or ""

	events.Text = string.format(
		"OPERATION  %s\nDuration %s  •  reached %s\nObjectives completed %d  •  corruption tier reached %d\nThe Progenitor: %s",
		result.operationId,
		formatDuration(result.durationSeconds),
		result.phaseReachedId,
		result.objectivesCompleted,
		result.wavesSurvived,
		if result.bossDefeated then "defeated" else "still standing"
	)

	local localOperativeEntityId = "operative.player:" .. tostring(localPlayer.UserId)
	local lines = { "SQUAD CONTRIBUTION" }
	for _, contribution in result.contributions do
		table.insert(lines, formatContribution(contribution, contribution.operativeEntityId == localOperativeEntityId))
	end
	if #result.contributions == 0 then
		table.insert(lines, "No contribution was recorded this operation.")
	end
	contributions.Text = table.concat(lines, "\n")

	local build = buildLabel
	if build ~= nil then
		if #result.upgradeStacks == 0 then
			build.Text = "SQUAD FIELD UPGRADES\nNone taken this operation."
		else
			local upgradeLines = {}
			for _, upgrade in result.upgradeStacks do
				table.insert(
					upgradeLines,
					string.format("%s x%d", UPGRADE_NAME_BY_ID[upgrade.upgradeId] or upgrade.upgradeId, upgrade.stacks)
				)
			end
			build.Text = "SQUAD FIELD UPGRADES\n" .. table.concat(upgradeLines, "  •  ")
		end
	end

	nextAction.Text = string.format(
		"A fresh operation begins in %d seconds. No rewards are recorded yet.",
		math.floor(MatchResultConfig.ReplayDebriefSeconds)
	)
	gui.Enabled = true
end

function MatchResultController.start()
	if started then
		return
	end
	started = true
	hasDisplayedResult = false
	createGui()
	resultConnection = resultRemote.OnClientEvent:Connect(applyResult)
	missionPhaseConnection = localPlayer:GetAttributeChangedSignal("LK_HUD_MissionPhase"):Connect(onMissionPhaseChanged)
	onMissionPhaseChanged()
end

function MatchResultController.stop()
	if not started then
		return
	end
	started = false
	hasDisplayedResult = false
	if resultConnection ~= nil then
		resultConnection:Disconnect()
		resultConnection = nil
	end
	if missionPhaseConnection ~= nil then
		missionPhaseConnection:Disconnect()
		missionPhaseConnection = nil
	end
	if screenGui ~= nil then
		screenGui:Destroy()
		screenGui = nil
	end
	headlineLabel = nil
	causeLabel = nil
	eventsLabel = nil
	contributionLabel = nil
	buildLabel = nil
	nextActionLabel = nil
end

return table.freeze(MatchResultController)
