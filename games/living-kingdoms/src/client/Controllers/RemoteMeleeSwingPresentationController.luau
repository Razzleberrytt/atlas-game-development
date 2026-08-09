--!strict

--[[
	Presentation-only co-op readability for server-confirmed melee swing attempts.
	The authoritative melee service decides whether a swing consumed cadence. This
	controller only animates the existing third-person MeleeGrip for other players;
	it owns no input, cadence, target, damage, health, inventory, or combat mode.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MeleeCombatConfig = require(ReplicatedStorage.Shared.Config.MeleeCombatConfig)
local MeleePresentationContracts = require(ReplicatedStorage.Shared.Combat.MeleePresentationContracts)
local OperativeLifeContracts = require(ReplicatedStorage.Shared.Health.OperativeLifeContracts)
local PrimaryCombatModeContracts = require(ReplicatedStorage.Shared.Combat.PrimaryCombatModeContracts)

local Controller = {}
local AttributeName = PrimaryCombatModeContracts.AttributeName
local ModeIds = PrimaryCombatModeContracts.ModeIds
local LifeStateIds = OperativeLifeContracts.OperativeLifeStateIds
local LIFE_STATE_ATTRIBUTE = "LK_P3_LifeState"
local SWING_DURATION_SECONDS = math.min(0.5, MeleeCombatConfig.OpeningWeapon.CadenceSeconds * 0.8)

local started = false
local renderConnection: RBXScriptConnection? = nil
local presentationConnection: RBXScriptConnection? = nil
local swingStartedAtByPlayer: { [Player]: number } = {}
local meleeNetwork = ReplicatedStorage:WaitForChild("MeleeNetwork")
local presentationRemote = meleeNetwork:WaitForChild("Presentation") :: RemoteEvent

local function shouldPresent(player: Player): boolean
	return player ~= Players.LocalPlayer
		and player:GetAttribute(AttributeName) == ModeIds.Melee
		and player:GetAttribute(LIFE_STATE_ATTRIBUTE) == LifeStateIds.Alive
end

local function findGrip(player: Player): Motor6D?
	local character = player.Character
	if character == nil then
		return nil
	end
	local grip = character:FindFirstChild("MeleeGrip", true)
	return if grip ~= nil and grip:IsA("Motor6D") then grip else nil
end

local function swingAmount(startedAt: number, nowClock: number): number
	local progress = (nowClock - startedAt) / SWING_DURATION_SECONDS
	if progress >= 1 then
		return 0
	end
	return math.sin(math.clamp(progress, 0, 1) * math.pi)
end

local function onPresentation(message: unknown)
	if not MeleePresentationContracts.validateSwingCommittedMessage(message) then
		return
	end
	local confirmed = message :: MeleePresentationContracts.SwingCommittedMessage
	local attacker = Players:GetPlayerByUserId(confirmed.attackerUserId)
	if attacker == nil or not shouldPresent(attacker) then
		return
	end
	swingStartedAtByPlayer[attacker] = os.clock()
end

function Controller.start()
	if started then
		return
	end
	started = true
	presentationConnection = presentationRemote.OnClientEvent:Connect(onPresentation)
	renderConnection = RunService.RenderStepped:Connect(function()
		local nowClock = os.clock()
		local expired = {}
		for player, startedAt in swingStartedAtByPlayer do
			local grip = findGrip(player)
			if grip == nil or not shouldPresent(player) then
				if grip ~= nil then
					grip.Transform = CFrame.identity
				end
				table.insert(expired, player)
				continue
			end
			local amount = swingAmount(startedAt, nowClock)
			if amount <= 0 then
				grip.Transform = CFrame.identity
				table.insert(expired, player)
			else
				grip.Transform = CFrame.Angles(math.rad(54 * amount), math.rad(-10 * amount), math.rad(-42 * amount))
			end
		end
		for _, player in expired do
			swingStartedAtByPlayer[player] = nil
		end
	end)
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	if presentationConnection ~= nil then
		presentationConnection:Disconnect()
		presentationConnection = nil
	end
	if renderConnection ~= nil then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	for player in swingStartedAtByPlayer do
		local grip = findGrip(player)
		if grip ~= nil then
			grip.Transform = CFrame.identity
		end
	end
	table.clear(swingStartedAtByPlayer)
end

return table.freeze(Controller)
