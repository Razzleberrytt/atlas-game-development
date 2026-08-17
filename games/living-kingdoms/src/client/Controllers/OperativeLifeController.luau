--!strict

--[[
	Owns only local revive hold input. Server-authored life attributes are rendered
	by HordeHUDController. The client sends a target operative ID plus Begin/End;
	it never reports progress, distance, health, completion, or authority facts.

	Input is a ContextActionService hold binding, so the same handler serves the
	keyboard (V), gamepad D-pad Down, and an auto-created touch button. V stays
	distinct from the engine-default E interaction key used by ProximityPrompt.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

type Controller = { start: () -> (), stop: () -> () }

local ACTION_NAME = "LK_Revive"
local NETWORK_WAIT_SECONDS = 20

local Controller: Controller = {} :: Controller
local localPlayer = Players.LocalPlayer
local operativeLifeNetwork = ReplicatedStorage:WaitForChild("OperativeLifeNetwork", NETWORK_WAIT_SECONDS)
assert(operativeLifeNetwork ~= nil, "OperativeLifeNetwork did not become available before the client bootstrap timeout")
local reviveIntentRemote = operativeLifeNetwork:WaitForChild("ReviveIntent", NETWORK_WAIT_SECONDS) :: RemoteEvent?
assert(
	reviveIntentRemote ~= nil,
	"OperativeLifeNetwork.ReviveIntent did not become available before the client bootstrap timeout"
)
local heldTargetOperativeEntityId: string? = nil
local started = false

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = if character == nil then nil else character:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then root.Position else nil
end

local function nearestIncapacitatedOperativeId(): string?
	local origin = rootPosition(localPlayer)
	if origin == nil then
		return nil
	end
	local nearestId = nil
	local nearestDistance = math.huge
	for _, player in Players:GetPlayers() do
		if player ~= localPlayer and player:GetAttribute("LK_P3_LifeState") == "Incapacitated" then
			local operativeEntityId = player:GetAttribute("LK_P3_OperativeEntityId")
			local position = rootPosition(player)
			if type(operativeEntityId) == "string" and position ~= nil then
				local distance = (position - origin).Magnitude
				if distance < nearestDistance then
					nearestDistance = distance
					nearestId = operativeEntityId
				end
			end
		end
	end
	return nearestId
end

local function beginReviveHold()
	if UserInputService:GetFocusedTextBox() ~= nil or heldTargetOperativeEntityId ~= nil then
		return
	end
	local targetOperativeEntityId = nearestIncapacitatedOperativeId()
	if targetOperativeEntityId == nil then
		return
	end
	heldTargetOperativeEntityId = targetOperativeEntityId
	reviveIntentRemote:FireServer({ targetOperativeEntityId = targetOperativeEntityId, phase = "Begin" })
end

local function endReviveHold()
	local targetOperativeEntityId = heldTargetOperativeEntityId
	heldTargetOperativeEntityId = nil
	if targetOperativeEntityId ~= nil then
		reviveIntentRemote:FireServer({ targetOperativeEntityId = targetOperativeEntityId, phase = "End" })
	end
end

-- Begin the hold on press, end it on release; the server owns the hold duration
-- and every other revive fact. Pass so unrelated input layers are not blocked.
local function onReviveAction(_actionName: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin then
		beginReviveHold()
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		endReviveHold()
	end
	return Enum.ContextActionResult.Pass
end

function Controller.start()
	if started then
		return
	end
	started = true
	-- `true` creates the mobile touch button. Held: Begin on press, End on release.
	ContextActionService:BindAction(ACTION_NAME, onReviveAction, true, Enum.KeyCode.V, Enum.KeyCode.DPadDown)
	ContextActionService:SetTitle(ACTION_NAME, "Revive")
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	endReviveHold()
	ContextActionService:UnbindAction(ACTION_NAME)
end

return Controller
