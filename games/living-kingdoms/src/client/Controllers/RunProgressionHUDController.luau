--!strict

--[[
	Read-only Field XP presentation bridge. The canonical server progression
	snapshot remains the only XP/level truth. This controller creates no separate
	GUI; it writes client-local attributes consumed by HordeHUDController and
	sends no reward, kill, XP, level, or upgrade mutation.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RunProgressionConfig = require(ReplicatedStorage.Shared.Config.RunProgressionConfig)

local RunProgressionHUDController = {}
local localPlayer = Players.LocalPlayer

local started = false
local stateConnection: RBXScriptConnection? = nil
local renderConnection: RBXScriptConnection? = nil
local lastRevision = -1
local lastGainSequence = 0
local gainExpiresAtServerTimestamp = 0

local progressionNetwork = ReplicatedStorage:WaitForChild("ProgressionNetwork")
local stateRemote = progressionNetwork:WaitForChild("State") :: RemoteEvent
local readStateRemote = progressionNetwork:WaitForChild("ReadState") :: RemoteFunction

local attributeNames = {
	"LK_HUD_FieldLevel",
	"LK_HUD_FieldXp",
	"LK_HUD_FieldXpForNext",
	"LK_HUD_FieldTotalXp",
	"LK_HUD_FieldKills",
	"LK_HUD_FieldGainText",
	"LK_HUD_FieldGainSequence",
	"LK_HUD_FieldGainUntil",
}

local function clearAttributes()
	for _, attributeName in attributeNames do
		localPlayer:SetAttribute(attributeName, nil)
	end
end

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function applySnapshot(snapshot: unknown)
	if type(snapshot) ~= "table" then
		return
	end
	local revision = snapshot.revision
	local level = snapshot.level
	local xp = snapshot.xp
	local xpForNextLevel = snapshot.xpForNextLevel
	local totalXp = snapshot.totalXp
	local squadKills = snapshot.squadKills
	local gainAmount = snapshot.lastGainAmount
	local gainSequence = snapshot.lastGainSequence
	local levelsGained = snapshot.levelsGainedLastAward
	if
		not isFiniteNumber(revision)
		or revision <= lastRevision
		or not isFiniteNumber(level)
		or not isFiniteNumber(xp)
		or not isFiniteNumber(xpForNextLevel)
		or not isFiniteNumber(totalXp)
		or not isFiniteNumber(squadKills)
		or not isFiniteNumber(gainAmount)
		or not isFiniteNumber(gainSequence)
		or not isFiniteNumber(levelsGained)
	then
		return
	end
	lastRevision = revision
	localPlayer:SetAttribute("LK_HUD_FieldLevel", level)
	localPlayer:SetAttribute("LK_HUD_FieldXp", xp)
	localPlayer:SetAttribute("LK_HUD_FieldXpForNext", xpForNextLevel)
	localPlayer:SetAttribute("LK_HUD_FieldTotalXp", totalXp)
	localPlayer:SetAttribute("LK_HUD_FieldKills", squadKills)

	if gainSequence > lastGainSequence and gainAmount > 0 then
		lastGainSequence = gainSequence
		local gainText = if levelsGained > 0
			then string.format("LEVEL UP!  FIELD LEVEL %d", level)
			else string.format("+%d FIELD XP", gainAmount)
		gainExpiresAtServerTimestamp = Workspace:GetServerTimeNow() + RunProgressionConfig.GainDisplaySeconds
		localPlayer:SetAttribute("LK_HUD_FieldGainText", gainText)
		localPlayer:SetAttribute("LK_HUD_FieldGainSequence", gainSequence)
		localPlayer:SetAttribute("LK_HUD_FieldGainUntil", gainExpiresAtServerTimestamp)
	end
end

function RunProgressionHUDController.start()
	if started then
		return
	end
	started = true
	lastRevision = -1
	lastGainSequence = 0
	gainExpiresAtServerTimestamp = 0
	clearAttributes()

	stateConnection = stateRemote.OnClientEvent:Connect(applySnapshot)
	renderConnection = RunService.RenderStepped:Connect(function()
		if gainExpiresAtServerTimestamp <= 0 then
			return
		end
		if Workspace:GetServerTimeNow() < gainExpiresAtServerTimestamp then
			return
		end
		gainExpiresAtServerTimestamp = 0
		localPlayer:SetAttribute("LK_HUD_FieldGainText", "")
		localPlayer:SetAttribute("LK_HUD_FieldGainUntil", nil)
	end)

	local didRead, initialSnapshot = pcall(function()
		return readStateRemote:InvokeServer()
	end)
	if didRead then
		applySnapshot(initialSnapshot)
	end
end

function RunProgressionHUDController.stop()
	if not started then
		return
	end
	started = false
	if stateConnection ~= nil then
		stateConnection:Disconnect()
		stateConnection = nil
	end
	if renderConnection ~= nil then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	lastRevision = -1
	lastGainSequence = 0
	gainExpiresAtServerTimestamp = 0
	clearAttributes()
end

return table.freeze(RunProgressionHUDController)
