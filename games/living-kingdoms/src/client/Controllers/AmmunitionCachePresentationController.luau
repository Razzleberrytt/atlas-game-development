--!strict

-- Presents only server-disclosed per-operative cache depletion. Local prompt
-- and visual changes never mutate the server-owned cache or collection history.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Contracts = require(ReplicatedStorage.Shared.Combat.AmmunitionCachePresentationContracts)

local SUPPLY_CACHE_ID_ATTRIBUTE = "SupplyCacheId"
local COLLECT_PROMPT_NAME = "CollectPrompt"
local CONSUMED_HIGHLIGHT_NAME = "ConsumedCacheHighlight"

local Controller = {}
local started = false
local presentationConnection: RBXScriptConnection? = nil
local presentedCacheIds: { [string]: boolean } = {}

local combatNetwork = ReplicatedStorage:WaitForChild("CombatNetwork")
local presentationRemote = combatNetwork:WaitForChild("CombatPresentation") :: RemoteEvent

local function isNonEmptyString(value: unknown): boolean
	return type(value) == "string" and value ~= ""
end

local function findCachePart(cacheId: string): BasePart?
	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute(SUPPLY_CACHE_ID_ATTRIBUTE) == cacheId then
			return descendant
		end
	end
	return nil
end

local function presentConsumedCache(cacheId: string)
	if presentedCacheIds[cacheId] then
		return
	end
	local cachePart = findCachePart(cacheId)
	if cachePart == nil then
		return
	end
	local prompt = cachePart:FindFirstChild(COLLECT_PROMPT_NAME)
	if prompt ~= nil and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = false
	end
	cachePart.Color = Color3.fromRGB(48, 51, 47)
	cachePart.Material = Enum.Material.SmoothPlastic
	cachePart.Transparency = 0.35
	if cachePart:FindFirstChild(CONSUMED_HIGHLIGHT_NAME) == nil then
		local highlight = Instance.new("Highlight")
		highlight.Name = CONSUMED_HIGHLIGHT_NAME
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.FillColor = Color3.fromRGB(42, 45, 42)
		highlight.FillTransparency = 0.65
		highlight.OutlineColor = Color3.fromRGB(122, 128, 119)
		highlight.OutlineTransparency = 0.2
		highlight.Adornee = cachePart
		highlight.Parent = cachePart
	end
	presentedCacheIds[cacheId] = true
end

local function onPresentationMessage(message: unknown)
	if type(message) ~= "table" then
		return
	end
	local payload = message :: any
	if payload.kindId == Contracts.MessageKindIds.Consumed and isNonEmptyString(payload.cacheId) then
		presentConsumedCache(payload.cacheId)
	end
end

function Controller.start()
	if started then
		return
	end
	started = true
	presentationConnection = presentationRemote.OnClientEvent:Connect(onPresentationMessage)
end

function Controller.stop()
	if not started then
		return
	end
	started = false
	local connection = presentationConnection
	if connection ~= nil then
		connection:Disconnect()
		presentationConnection = nil
	end
	table.clear(presentedCacheIds)
end

return Controller
