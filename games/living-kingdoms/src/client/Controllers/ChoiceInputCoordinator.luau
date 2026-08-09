--!strict

-- BA-062 C4 single-owner keyboard coordinator for numbered choice surfaces.
-- HUDs keep their own choice semantics and network paths; this module owns only
-- direct 1/2/3 input detection and fail-closed routing between registered HUDs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ChoiceInputConflictResolver = require(ReplicatedStorage.Shared.Input.ChoiceInputConflictResolver)

type Registration = {
	isActive: () -> boolean,
	dispatchChoice: (number) -> (),
}

local Coordinator = {}
local registrations: { [string]: Registration } = {}
local inputConnection: RBXScriptConnection? = nil

local KEY_TO_CHOICE_INDEX = table.freeze({
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.KeypadOne] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.KeypadTwo] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.KeypadThree] = 3,
})

local function activeOwnerIds(): { string }
	local owners = {}
	for ownerId, registration in registrations do
		if registration.isActive() then
			table.insert(owners, ownerId)
		end
	end
	table.sort(owners)
	return owners
end

local function onInputBegan(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end
	local choiceIndex = KEY_TO_CHOICE_INDEX[input.KeyCode]
	if choiceIndex == nil then
		return
	end
	local resolution = ChoiceInputConflictResolver.resolve(activeOwnerIds())
	local ownerId = resolution.ActiveOwnerId
	if resolution.Dispatch ~= true or ownerId == nil then
		return
	end
	local registration = registrations[ownerId]
	if registration == nil or not registration.isActive() then
		return
	end
	registration.dispatchChoice(choiceIndex)
end

local function ensureListener()
	if inputConnection == nil then
		inputConnection = UserInputService.InputBegan:Connect(onInputBegan)
	end
end

local function releaseListenerIfUnused()
	if next(registrations) ~= nil or inputConnection == nil then
		return
	end
	inputConnection:Disconnect()
	inputConnection = nil
end

function Coordinator.register(ownerId: string, isActive: () -> boolean, dispatchChoice: (number) -> ()): () -> ()
	assert(ownerId ~= "", "choice input owner ID must be non-empty")
	assert(registrations[ownerId] == nil, `choice input owner already registered: {ownerId}`)
	local registration: Registration = {
		isActive = isActive,
		dispatchChoice = dispatchChoice,
	}
	registrations[ownerId] = registration
	ensureListener()

	local registered = true
	return function()
		if not registered then
			return
		end
		registered = false
		if registrations[ownerId] == registration then
			registrations[ownerId] = nil
		end
		releaseListenerIfUnused()
	end
end

return table.freeze(Coordinator)
