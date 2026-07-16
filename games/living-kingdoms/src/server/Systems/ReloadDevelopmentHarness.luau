--!strict

--[[
	Studio-only LK-0206 integration harness. It owns isolated prototype reload
	state so reload input and presentation remotes can be exercised before a
	production combat runtime owner exists. It never discovers targets, fires,
	resolves hits, applies damage, or runs outside Studio.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CombatContracts = require(ReplicatedStorage.Shared.Combat.CombatContracts)
local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)
local ReloadResolver = require(script.Parent.ReloadResolver)

type OperativeReloadState = CombatContracts.OperativeReloadState
type WeaponReadinessState = CombatContracts.WeaponReadinessState
type PlayerReloadState = {
	operativeState: OperativeReloadState,
	weaponState: WeaponReadinessState,
	lastRequestServerTimestamp: number,
}

type ReloadDevelopmentHarness = {
	start: () -> (),
	stop: () -> (),
}

local SERVER_REQUEST_COOLDOWN_SECONDS = 0.25
local ReloadDevelopmentHarness: ReloadDevelopmentHarness = {} :: ReloadDevelopmentHarness
local started = false
local reloadIntentConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil
local playerStates: { [Player]: PlayerReloadState } = {}

local combatNetwork = ReplicatedStorage:WaitForChild("CombatNetwork")
local reloadIntentRemote = combatNetwork:WaitForChild("ReloadIntent") :: RemoteEvent
local presentationRemote = combatNetwork:WaitForChild("CombatPresentation") :: RemoteEvent

local function createPlayerState(player: Player): PlayerReloadState
	local weaponId = FirearmConfig.BasicFirearm.WeaponId
	return {
		operativeState = {
			entityId = "operative.player:" .. tostring(player.UserId),
			combatStateId = CombatContracts.OperativeCombatStateIds.Ready,
			equippedWeaponId = weaponId,
		},
		weaponState = {
			weaponId = weaponId,
			readinessStateId = CombatContracts.WeaponReadinessStateIds.Ready,
			ammunition = {
				weaponId = weaponId,
				loadedRounds = math.max(0, FirearmConfig.BasicFirearm.MagazineCapacity - 4),
				reserveRounds = FirearmConfig.BasicFirearm.PrototypeInitialReserveRounds,
				magazineCapacity = FirearmConfig.BasicFirearm.MagazineCapacity,
			},
			cadence = {
				weaponId = weaponId,
				lastFireServerTimestamp = nil,
				nextAllowedFireServerTimestamp = 0,
			},
			reloadState = nil,
		},
		lastRequestServerTimestamp = -math.huge,
	}
end

local function getPlayerState(player: Player): PlayerReloadState
	local playerState = playerStates[player]
	if playerState == nil then
		playerState = createPlayerState(player)
		playerStates[player] = playerState
	end

	return playerState
end

local function completeReload(player: Player, expectedCompletionTimestamp: number)
	local playerState = playerStates[player]
	if playerState == nil then
		return
	end

	local reloadState = playerState.weaponState.reloadState
	if reloadState == nil or reloadState.completionServerTimestamp ~= expectedCompletionTimestamp then
		return
	end

	local resolution =
		ReloadResolver.complete(playerState.operativeState, playerState.weaponState, Workspace:GetServerTimeNow())
	playerState.operativeState = resolution.operativeStateAfter
	playerState.weaponState = resolution.weaponStateAfter
	if resolution.didComplete then
		presentationRemote:FireClient(player, {
			kindId = CombatContracts.PresentationMessageKindIds.ReloadCompleted,
			weaponId = FirearmConfig.BasicFirearm.WeaponId,
		})
	elseif resolution.wasInterrupted then
		presentationRemote:FireClient(player, {
			kindId = CombatContracts.PresentationMessageKindIds.ReloadInterrupted,
			weaponId = FirearmConfig.BasicFirearm.WeaponId,
		})
	end
end

local function onReloadIntent(player: Player, weaponId: unknown, ...: unknown)
	if select("#", ...) ~= 0 or type(weaponId) ~= "string" then
		return
	end

	local playerState = getPlayerState(player)
	if weaponId ~= playerState.operativeState.equippedWeaponId then
		return
	end

	local serverTimestamp = Workspace:GetServerTimeNow()
	if serverTimestamp - playerState.lastRequestServerTimestamp < SERVER_REQUEST_COOLDOWN_SECONDS then
		return
	end
	playerState.lastRequestServerTimestamp = serverTimestamp

	local resolution = ReloadResolver.begin(playerState.operativeState, playerState.weaponState, serverTimestamp)
	playerState.operativeState = resolution.operativeStateAfter
	playerState.weaponState = resolution.weaponStateAfter
	if not resolution.didBegin then
		return
	end

	local reloadState = resolution.weaponStateAfter.reloadState
	assert(reloadState ~= nil, "accepted reload must include authoritative timing")
	presentationRemote:FireClient(player, {
		kindId = CombatContracts.PresentationMessageKindIds.ReloadStarted,
		weaponId = FirearmConfig.BasicFirearm.WeaponId,
		completionServerTimestamp = reloadState.completionServerTimestamp,
	})

	task.delay(FirearmConfig.BasicFirearm.ReloadDurationSeconds, function()
		completeReload(player, reloadState.completionServerTimestamp)
	end)
end

function ReloadDevelopmentHarness.start()
	if started or not RunService:IsStudio() then
		return
	end

	started = true
	for _, player in Players:GetPlayers() do
		playerStates[player] = createPlayerState(player)
	end
	reloadIntentConnection = reloadIntentRemote.OnServerEvent:Connect(onReloadIntent)
	playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		playerStates[player] = nil
	end)
end

function ReloadDevelopmentHarness.stop()
	if not started then
		return
	end

	local currentReloadIntentConnection = reloadIntentConnection
	if currentReloadIntentConnection ~= nil then
		currentReloadIntentConnection:Disconnect()
		reloadIntentConnection = nil
	end
	local currentPlayerRemovingConnection = playerRemovingConnection
	if currentPlayerRemovingConnection ~= nil then
		currentPlayerRemovingConnection:Disconnect()
		playerRemovingConnection = nil
	end
	table.clear(playerStates)
	started = false
end

return ReloadDevelopmentHarness
