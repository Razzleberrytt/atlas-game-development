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

local MatchResultConfig = require(ReplicatedStorage.Shared.Config.MatchResultConfig)
local MatchResultContracts = require(ReplicatedStorage.Shared.Mission.MatchResultContracts)
local RunRpgConfig = require(ReplicatedStorage.Shared.Config.RunRpgConfig)
local RunProgressionConfig = require(ReplicatedStorage.Shared.Config.RunProgressionConfig)

type SafeMatchResultSnapshot = MatchResultContracts.SafeMatchResultSnapshot

local MatchResultController = {}

local GUI_NAME = "LK_MatchResultDebrief"

local started = false
local resultConnection: RBXScriptConnection? = nil
local screenGui: ScreenGui? = nil
local headlineLabel: TextLabel? = nil
local causeLabel: TextLabel? = nil
local eventsLabel: TextLabel? = nil
local contributionLabel: TextLabel? = nil
local buildLabel: TextLabel? = nil
local nextActionLabel: TextLabel? = nil
local hasDisplayedResult = false

local localPlayer = Players.LocalPlayer
local missionNetwork = ReplicatedStorage:WaitForChild("MissionNetwork")
local resultRemote = missionNetwork:WaitForChild("Result") :: RemoteEvent

-- Plain-language headline and explanation per authored cause. Text, never colour
-- alone, carries the outcome.
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

-- RPG-0112 display names, so the debrief explains the build in the same words the
-- HUD used rather than raw identifiers.
local RELIC_NAME_BY_ID: { [string]: string } = {}
for _, definition in RunRpgConfig.RelicCatalog do
	RELIC_NAME_BY_ID[definition.relicId] = definition.displayName
end

local UPGRADE_NAME_BY_ID: { [string]: string } = {}
for _, definition in RunProgressionConfig.UpgradeDefinitions do
	UPGRADE_NAME_BY_ID[definition.Id] = definition.Name
end

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function makeLabel(parent: Instance, name: string, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(228, 233, 226)
	label.TextStrokeColor3 = Color3.fromRGB(10, 12, 13)
	label.TextStrokeTransparency = 0.6
	label.TextSize = textSize
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true
	label.Text = ""
	label.Parent = parent
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

	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(4, 5, 6)
	backdrop.BackgroundTransparency = 0.25
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui

	local frame = Instance.new("Frame")
	frame.Name = "Debrief"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(700, 502)
	frame.BackgroundColor3 = Color3.fromRGB(13, 16, 17)
	frame.BackgroundTransparency = 0.02
	frame.BorderSizePixel = 0
	frame.Parent = gui
	addCorner(frame, 14)

	local headline = makeLabel(frame, "Headline", 30)
	headline.Font = Enum.Font.GothamBold
	headline.Position = UDim2.fromOffset(28, 24)
	headline.Size = UDim2.new(1, -56, 0, 36)
	headlineLabel = headline

	local cause = makeLabel(frame, "Cause", 16)
	cause.Position = UDim2.fromOffset(28, 66)
	cause.Size = UDim2.new(1, -56, 0, 44)
	cause.TextColor3 = Color3.fromRGB(198, 204, 195)
	causeLabel = cause

	local events = makeLabel(frame, "Events", 16)
	events.Position = UDim2.fromOffset(28, 118)
	events.Size = UDim2.new(1, -56, 0, 96)
	eventsLabel = events

	local contributions = makeLabel(frame, "Contributions", 15)
	contributions.Position = UDim2.fromOffset(28, 222)
	contributions.Size = UDim2.new(1, -56, 0, 156)
	contributionLabel = contributions

	local build = makeLabel(frame, "Build", 15)
	build.Position = UDim2.fromOffset(28, 384)
	build.Size = UDim2.new(1, -56, 0, 56)
	build.TextColor3 = Color3.fromRGB(198, 204, 195)
	buildLabel = build

	local nextAction = makeLabel(frame, "NextAction", 15)
	nextAction.Position = UDim2.fromOffset(28, 448)
	nextAction.Size = UDim2.new(1, -56, 0, 34)
	nextAction.TextColor3 = Color3.fromRGB(255, 207, 90)
	nextActionLabel = nextAction
end

local function formatDuration(durationSeconds: number): string
	local wholeSeconds = math.max(0, math.floor(durationSeconds))
	return string.format("%d:%02d", wholeSeconds // 60, wholeSeconds % 60)
end

-- RPG-0112: the relics the operative finished the run holding.
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
	cause.Text = EXPLANATION_BY_CAUSE_ID[result.causeId] or ""

	events.Text = string.format(
		"OPERATION  %s\nDuration %s  •  reached %s\nObjectives completed %d  •  waves survived %d\nThe Progenitor: %s",
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

	-- RPG-0112: the squad build the run finished with, in the same words the HUD
	-- used. Field Upgrades are squad-wide, so they read once beneath the rows.
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

	-- The next action is real: P10-0105 restarts the operation deterministically
	-- after this window. The screen still promises no reward, because none is
	-- recorded until P11.
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

	-- Listen only. A client that arrives after resolution is pushed the frozen
	-- debrief by the mission owner on join, so no request is ever needed.
	resultConnection = resultRemote.OnClientEvent:Connect(applyResult)
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
