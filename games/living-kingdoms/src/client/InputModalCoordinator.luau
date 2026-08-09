--!strict

-- BA-062 C3 client-only close coordination. This module owns one Escape listener
-- and selects at most one visible registered presentation surface to close.
-- It does not create GUI, send remotes, or own gameplay state.
local UserInputService = game:GetService("UserInputService")

export type CloseRegistration = {
	Id: string,
	Priority: number,
	IsOpen: () -> boolean,
	Close: () -> (),
}

local ClosePriorities = table.freeze({
	HubRouted = 100,
	ExclusiveInputModal = 200,
})

local registrations: { [string]: CloseRegistration } = {}
local escapeConnection: RBXScriptConnection? = nil

local Coordinator = {
	ClosePriorities = ClosePriorities,
}

local function selectOpenRegistration(): CloseRegistration?
	local selected: CloseRegistration? = nil
	for _, registration in registrations do
		if registration.IsOpen() then
			if
				selected == nil
				or registration.Priority > selected.Priority
				or (registration.Priority == selected.Priority and registration.Id < selected.Id)
			then
				selected = registration
			end
		end
	end
	return selected
end

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed or input.KeyCode ~= Enum.KeyCode.Escape then
		return
	end
	local selected = selectOpenRegistration()
	if selected ~= nil then
		selected.Close()
	end
end

local function ensureEscapeListener()
	if escapeConnection == nil then
		escapeConnection = UserInputService.InputBegan:Connect(onInputBegan)
	end
end

local function disconnectIfUnused()
	if next(registrations) ~= nil or escapeConnection == nil then
		return
	end
	escapeConnection:Disconnect()
	escapeConnection = nil
end

function Coordinator.register(
	id: string,
	priority: number,
	isOpen: () -> boolean,
	close: () -> ()
): () -> ()
	assert(id ~= "", "close registration ID must be non-empty")
	assert(priority == priority and math.abs(priority) < math.huge, "close registration priority must be finite")
	assert(registrations[id] == nil, `duplicate close registration: {id}`)

	registrations[id] = {
		Id = id,
		Priority = priority,
		IsOpen = isOpen,
		Close = close,
	}
	ensureEscapeListener()

	local active = true
	return function()
		if not active then
			return
		end
		active = false
		registrations[id] = nil
		disconnectIfUnused()
	end
end

return table.freeze(Coordinator)
