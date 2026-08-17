--!strict

-- Narrow client-to-server bridge for the already-authoritative melee service.
-- The client supplies only a bounded request id and aim direction. Primary mode
-- is read from the server-owned player attribute before the strike is evaluated.
-- Only already-committed successful damage is disclosed back to the attacker as
-- presentation; rejected/missed swings remain silent and grant no client state.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NETWORK_WAIT_SECONDS = 20

local MeleePresentationContracts = require(ReplicatedStorage.Shared.Combat.MeleePresentationContracts)
local PrimaryCombatModeContracts = require(ReplicatedStorage.Shared.Combat.PrimaryCombatModeContracts)
local MeleeCombatService = require(script.Parent.MeleeCombatService)
local PrimaryCombatModeService = require(script.Parent.PrimaryCombatModeService)

local Service = {}
local ModeIds = PrimaryCombatModeContracts.ModeIds
local MessageKindIds = MeleePresentationContracts.MessageKindIds

local started = false
local intentConnection: RBXScriptConnection? = nil
local meleeNetwork = ReplicatedStorage:WaitForChild("MeleeNetwork", NETWORK_WAIT_SECONDS)
assert(meleeNetwork ~= nil, "MeleeNetwork did not become available before the server bootstrap timeout")
local strikeIntent = meleeNetwork:WaitForChild("StrikeIntent", NETWORK_WAIT_SECONDS) :: RemoteEvent?
assert(strikeIntent ~= nil, "meleeNetwork.StrikeIntent did not become available before the server bootstrap timeout")
local presentationRemote = meleeNetwork:WaitForChild("Presentation", NETWORK_WAIT_SECONDS) :: RemoteEvent?
assert(
	presentationRemote ~= nil,
	"meleeNetwork.Presentation did not become available before the server bootstrap timeout"
)

local function onStrikeIntent(player: Player, requestId: unknown, aimDirection: unknown, ...: unknown)
	if select("#", ...) ~= 0 or type(requestId) ~= "string" or typeof(aimDirection) ~= "Vector3" then
		return
	end
	if PrimaryCombatModeService.readMode(player) ~= ModeIds.Melee then
		return
	end
	local result = MeleeCombatService.tryStrike(player, requestId, aimDirection)
	if result.swingAccepted == true and result.strikeId ~= nil then
		presentationRemote:FireAllClients({
			kindId = MessageKindIds.SwingCommitted,
			attackerUserId = player.UserId,
			strikeId = result.strikeId,
			serverTimestamp = result.serverTimestamp,
		})
	end
	if
		result.accepted ~= true
		or result.strikeId == nil
		or result.targetEntityId == nil
		or result.damageAmount <= 0
	then
		return
	end
	presentationRemote:FireClient(player, {
		kindId = MessageKindIds.HitConfirmed,
		strikeId = result.strikeId,
		targetEntityId = result.targetEntityId,
		damageAmount = result.damageAmount,
		becameDead = result.becameDead,
		serverTimestamp = result.serverTimestamp,
	})
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
