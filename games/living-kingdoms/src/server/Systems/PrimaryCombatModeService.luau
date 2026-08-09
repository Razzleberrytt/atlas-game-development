--!strict

-- Server-only owner of the replicated primary-combat-mode fact. There is no
-- client request surface: trusted server systems may switch modes, while clients
-- only observe the attribute to route presentation/input.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PrimaryCombatModeContracts = require(ReplicatedStorage.Shared.Combat.PrimaryCombatModeContracts)

local Service = {}
local AttributeName = PrimaryCombatModeContracts.AttributeName
local ModeIds = PrimaryCombatModeContracts.ModeIds

local started = false
local playerAddedConnection: RBXScriptConnection? = nil

local function setAttribute(player: Player, modeId: string)
	player:SetAttribute(AttributeName, modeId)
end

local function ensurePlayer(player: Player)
	local current = player:GetAttribute(AttributeName)
	if not PrimaryCombatModeContracts.isModeId(current) then
		setAttribute(player, ModeIds.Melee)
	end
end

function Service.readMode(player: Player): string
	local current = player:GetAttribute(AttributeName)
	if PrimaryCombatModeContracts.isModeId(current) then
		return current :: string
	end
	return ModeIds.Melee
end

-- Trusted server systems may need to restore a retained firearm before this
-- application's mount has started. Setting an already-validated server fact does
-- not require the lifecycle listener to be active.
function Service.setMode(player: Player, modeId: unknown): boolean
	if not PrimaryCombatModeContracts.isModeId(modeId) then
		return false
	end
	setAttribute(player, modeId :: string)
	return true
end

function Service.resetAllToMelee()
	for _, player in Players:GetPlayers() do
		setAttribute(player, ModeIds.Melee)
	end
end

function Service.start()
	if started then
		return
	end
	started = true
	for _, player in Players:GetPlayers() do
		ensurePlayer(player)
	end
	playerAddedConnection = Players.PlayerAdded:Connect(ensurePlayer)
end

function Service.stop()
	if not started then
		return
	end
	started = false
	if playerAddedConnection ~= nil then
		playerAddedConnection:Disconnect()
		playerAddedConnection = nil
	end
end

return table.freeze(Service)
