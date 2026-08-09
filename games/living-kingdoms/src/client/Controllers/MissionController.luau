--!strict

--[[
	Receives only the server-disclosed safe mission snapshot and exposes a small
	client-local presentation cache through LocalPlayer attributes. The unified
	HordeHUDController owns rendering. No attribute is returned to the server or
	used as gameplay authority.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MissionContracts = require(ReplicatedStorage.Shared.Mission.MissionContracts)

type SafeMissionSnapshot = MissionContracts.SafeMissionSnapshot
type Controller = { start: () -> (), stop: () -> () }

local RADIO_VISIBLE_SECONDS = 6
local Controller: Controller = {} :: Controller
local localPlayer = Players.LocalPlayer
local stateRemote = ReplicatedStorage:WaitForChild("MissionNetwork"):WaitForChild("State") :: RemoteEvent
local started = false
local connections: { RBXScriptConnection } = {}
local latestSnapshot: SafeMissionSnapshot? = nil
local displayedRadioTimestamp: number? = nil

local ATTRIBUTE_NAMES = {
	"LK_HUD_MissionPhase",
	"LK_HUD_Objective",
	"LK_HUD_ObjectiveDestination",
	"LK_HUD_ObjectiveProgress",
	"LK_HUD_ObjectiveDecaying",
	"LK_HUD_ObjectiveOptional",
	"LK_HUD_ExtractionUnlocked",
	"LK_HUD_FloodlightsRestored",
	"LK_HUD_HoldoutDeadline",
	"LK_HUD_Outcome",
	"LK_HUD_RadioText",
	"LK_HUD_RadioTimestamp",
}

local function clearAttributes()
	for _, attributeName in ATTRIBUTE_NAMES do
		localPlayer:SetAttribute(attributeName, nil)
	end
end

-- The current objective the squad is working, from the server-owned chain. Nil
-- when the required chain is complete and no optional objective is active.
local function activeObjective(snapshot: SafeMissionSnapshot): MissionContracts.SafeObjectiveSnapshot?
	local activeId = snapshot.activeObjectiveId
	if activeId == nil then
		return nil
	end
	for _, objective in snapshot.objectives do
		if objective.objectiveId == activeId then
			return objective
		end
	end
	return nil
end

local function applySnapshot(snapshot: SafeMissionSnapshot)
	localPlayer:SetAttribute("LK_HUD_MissionPhase", snapshot.phaseId)
	localPlayer:SetAttribute("LK_HUD_Objective", snapshot.objectiveText)
	localPlayer:SetAttribute("LK_HUD_ExtractionUnlocked", snapshot.extractionUnlocked)
	localPlayer:SetAttribute("LK_HUD_FloodlightsRestored", snapshot.floodlightsRestored)
	localPlayer:SetAttribute("LK_HUD_HoldoutDeadline", snapshot.holdoutDeadlineServerTimestamp)
	localPlayer:SetAttribute("LK_HUD_Outcome", snapshot.outcomeId)
	local objective = activeObjective(snapshot)
	if objective ~= nil then
		-- P4-permitted route guidance: the destination and local progress only.
		localPlayer:SetAttribute("LK_HUD_ObjectiveDestination", objective.destinationDisplayName)
		localPlayer:SetAttribute("LK_HUD_ObjectiveProgress", objective.progressRatio)
		localPlayer:SetAttribute("LK_HUD_ObjectiveDecaying", objective.decaying)
		localPlayer:SetAttribute("LK_HUD_ObjectiveOptional", objective.isOptional)
	else
		localPlayer:SetAttribute("LK_HUD_ObjectiveDestination", nil)
		localPlayer:SetAttribute("LK_HUD_ObjectiveProgress", nil)
		localPlayer:SetAttribute("LK_HUD_ObjectiveDecaying", nil)
		localPlayer:SetAttribute("LK_HUD_ObjectiveOptional", nil)
	end
	local transmission = snapshot.radio
	if transmission ~= nil and transmission.serverTimestamp ~= displayedRadioTimestamp then
		displayedRadioTimestamp = transmission.serverTimestamp
		localPlayer:SetAttribute("LK_HUD_RadioText", transmission.text)
		localPlayer:SetAttribute("LK_HUD_RadioTimestamp", transmission.serverTimestamp)
	end
end

local function onSnapshot(payload: unknown)
	if not MissionContracts.validateSafeMissionSnapshot(payload) then
		return
	end
	local snapshot = payload :: SafeMissionSnapshot
	local previous = latestSnapshot
	if previous ~= nil and snapshot.operationId == previous.operationId and snapshot.revision <= previous.revision then
		return
	end
	latestSnapshot = snapshot
	applySnapshot(snapshot)
end

local function updateRadioLifetime()
	local timestamp = displayedRadioTimestamp
	if timestamp ~= nil and Workspace:GetServerTimeNow() - timestamp > RADIO_VISIBLE_SECONDS then
		displayedRadioTimestamp = nil
		localPlayer:SetAttribute("LK_HUD_RadioText", "")
		localPlayer:SetAttribute("LK_HUD_RadioTimestamp", nil)
	end
end

function Controller.start()
	if started then
		return
	end
	started = true
	clearAttributes()
	table.insert(connections, stateRemote.OnClientEvent:Connect(onSnapshot))
	table.insert(connections, RunService.Heartbeat:Connect(updateRadioLifetime))
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
	latestSnapshot = nil
	displayedRadioTimestamp = nil
	clearAttributes()
end

return Controller
