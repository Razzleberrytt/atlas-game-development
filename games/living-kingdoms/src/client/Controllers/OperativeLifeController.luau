--!strict

--[[
	Owns only local revive hold input. Server-authored life attributes are rendered
	by HordeHUDController. The client sends a target operative ID plus Begin/End;
	it never reports progress, distance, health, completion, or authority facts.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

type Controller = { start: () -> (), stop: () -> () }

local Controller: Controller = {} :: Controller
local localPlayer = Players.LocalPlayer
local reviveIntentRemote =
	ReplicatedStorage:WaitForChild("OperativeLifeNetwork"):WaitForChild("ReviveIntent") :: RemoteEvent
local connections: { RBXScriptConnection } = {}
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

local function onInputBegan(input: InputObject, gameProcessedEvent: boolean)
	if
		gameProcessedEvent
		or input.KeyCode ~= Enum.KeyCode.E
		or UserInputService:GetFocusedTextBox() ~= nil
		or heldTargetOperativeEntityId ~= nil
	then
		return
	end
	local targetOperativeEntityId = nearestIncapacitatedOperativeId()
	if targetOperativeEntityId == nil then
		return
	end
	heldTargetOperativeEntityId = targetOperativeEntityId
	reviveIntentRemote:FireServer({ targetOperativeEntityId = targetOperativeEntityId, phase = "Begin" })
end

local function onInputEnded(input: InputObject)
	if input.KeyCode ~= Enum.KeyCode.E then
		return
	end
	local targetOperativeEntityId = heldTargetOperativeEntityId
	heldTargetOperativeEntityId = nil
	if targetOperativeEntityId ~= nil then
		reviveIntentRemote:FireServer({ targetOperativeEntityId = targetOperativeEntityId, phase = "End" })
	end
end

function Controller.start()
	if started then
		return
	end
	started = true
	table.insert(connections, UserInputService.InputBegan:Connect(onInputBegan))
	table.insert(connections, UserInputService.InputEnded:Connect(onInputEnded))
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	local targetOperativeEntityId = heldTargetOperativeEntityId
	heldTargetOperativeEntityId = nil
	if targetOperativeEntityId ~= nil then
		reviveIntentRemote:FireServer({ targetOperativeEntityId = targetOperativeEntityId, phase = "End" })
	end
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

return Controller
