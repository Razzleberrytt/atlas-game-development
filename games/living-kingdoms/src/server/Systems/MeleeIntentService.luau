--!strict

-- Narrow client-to-server bridge for the already-authoritative melee service.
-- The client supplies only a bounded request id and aim direction. Primary mode
-- is read from the server-owned player attribute before the strike is evaluated.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PrimaryCombatModeContracts = require(ReplicatedStorage.Shared.Combat.PrimaryCombatModeContracts)
local MeleeCombatService = require(script.Parent.MeleeCombatService)
local PrimaryCombatModeService = require(script.Parent.PrimaryCombatModeService)

local Service = {}
local ModeIds = PrimaryCombatModeContracts.ModeIds

local started = false
local intentConnection: RBXScriptConnection? = nil
local meleeNetwork = ReplicatedStorage:WaitForChild("MeleeNetwork")
local strikeIntent = meleeNetwork:WaitForChild("StrikeIntent") :: RemoteEvent

local function onStrikeIntent(player: Player, requestId: unknown, aimDirection: unknown, ...: unknown)
	if select("#", ...) ~= 0 or type(requestId) ~= "string" or typeof(aimDirection) ~= "Vector3" then
		return
	end
	if PrimaryCombatModeService.readMode(player) ~= ModeIds.Melee then
		return
	end
	MeleeCombatService.tryStrike(player, requestId, aimDirection)
end

function Service.start()
	if started then
		return
	end
	started = true
	intentConnection = strikeIntent.OnServerEvent:Connect(onStrikeIntent)
end

function Service.stop()
	if not started then
		return
	end
	started = false
	if intentConnection ~= nil then
		intentConnection:Disconnect()
		intentConnection = nil
	end
end

return table.freeze(Service)
