--!strict

-- Server-owned presentation state for expedition doorway barriers.
-- The service consumes only authoritative encounter context and replicates
-- sanitized room attributes. It never accepts client input or advances gameplay.

local Service = {}

local activeRoom: Model? = nil
local completed: { [Model]: boolean } = {}

local function roomRoot(): Instance?
	return workspace:FindFirstChild("ExpeditionRooms")
end

local function findRoom(context: any): Model?
	local root = roomRoot()
	if root == nil or context == nil then
		return nil
	end

	if type(context.RoomIndex) == "number" then
		for _, child in root:GetChildren() do
			if child:IsA("Model") and child:GetAttribute("RoomIndex") == context.RoomIndex then
				return child
			end
		end
	end

	local desiredRole = if context.PhaseId == "Elite" then "Elite" elseif context.PhaseId == "Boss" then "Boss" else nil
	if desiredRole ~= nil then
		for _, child in root:GetChildren() do
			if child:IsA("Model") and child:GetAttribute("RoomRoleId") == desiredRole then
				return child
			end
		end
	end
	return nil
end

local function setState(room: Model, stateId: string, encounterToken: string?)
	room:SetAttribute("BarrierState", stateId)
	room:SetAttribute("BarrierEncounterToken", encounterToken)
end

function Service.update(context: any?)
	local nextRoom = findRoom(context)
	if activeRoom ~= nil and activeRoom ~= nextRoom and activeRoom.Parent ~= nil then
		completed[activeRoom] = true
		setState(activeRoom, "Cleared", nil)
	end

	activeRoom = nextRoom
	if nextRoom ~= nil then
		local roleId = nextRoom:GetAttribute("RoomRoleId")
		local lockForEncounter = roleId == "Combat" or roleId == "Elite" or roleId == "Boss"
		if lockForEncounter then
			completed[nextRoom] = nil
			setState(nextRoom, "Locked", if context then context.Token else nil)
		else
			setState(nextRoom, "Open", if context then context.Token else nil)
		end
	end
end

function Service.reset()
	local root = roomRoot()
	if root ~= nil then
		for _, child in root:GetChildren() do
			if child:IsA("Model") then
				child:SetAttribute("BarrierState", "Dormant")
				child:SetAttribute("BarrierEncounterToken", nil)
			end
		end
	end
	activeRoom = nil
	table.clear(completed)
end

return table.freeze(Service)
