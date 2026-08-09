--!strict

-- BA-062 pure direct-binding collision analyzer. It inspects keyboard and
-- gamepad key-code tokens only; generic pointer/touch GUI activation is outside
-- this analyzer because it is not a unique direct shortcut claim.

export type ActionDefinition = {
	KeyboardKeyCodeNames: { string },
	GamepadKeyCodeNames: { string },
}

export type Collision = {
	FamilyId: string,
	BindingToken: string,
	ActionIds: { string },
}

export type Analysis = {
	Valid: boolean,
	ErrorId: string?,
	Collisions: { Collision },
}

local FamilyIds = table.freeze({
	Keyboard = "Keyboard",
	Gamepad = "Gamepad",
})

local ErrorIds = table.freeze({
	InvalidActionOrder = "InvalidActionOrder",
	MissingAction = "MissingAction",
	InvalidBindingList = "InvalidBindingList",
	InvalidBindingToken = "InvalidBindingToken",
})

local Analyzer = {
	FamilyIds = FamilyIds,
	ErrorIds = ErrorIds,
}

type TokenOwners = { [string]: { [string]: boolean } }

local function invalid(errorId: string): Analysis
	return table.freeze({
		Valid = false,
		ErrorId = errorId,
		Collisions = table.freeze({}),
	})
end

local function addBinding(bucket: TokenOwners, bindingToken: string, actionId: string)
	local owners = bucket[bindingToken]
	if owners == nil then
		owners = {}
		bucket[bindingToken] = owners
	end
	owners[actionId] = true
end

local function collectBindings(bucket: TokenOwners, bindingList: unknown, actionId: string): string?
	if type(bindingList) ~= "table" then
		return ErrorIds.InvalidBindingList
	end
	for index = 1, #bindingList do
		local bindingToken = bindingList[index]
		if type(bindingToken) ~= "string" or bindingToken == "" then
			return ErrorIds.InvalidBindingToken
		end
		addBinding(bucket, bindingToken, actionId)
	end
	return nil
end

local function appendCollisions(collisions: { Collision }, familyId: string, bucket: TokenOwners)
	for bindingToken, ownerSet in bucket do
		local actionIds = {}
		for actionId in ownerSet do
			table.insert(actionIds, actionId)
		end
		if #actionIds > 1 then
			table.sort(actionIds)
			table.insert(
				collisions,
				table.freeze({
					FamilyId = familyId,
					BindingToken = bindingToken,
					ActionIds = table.freeze(actionIds),
				})
			)
		end
	end
end

function Analyzer.analyze(actionOrder: unknown, actions: unknown): Analysis
	if type(actionOrder) ~= "table" or type(actions) ~= "table" then
		return invalid(ErrorIds.InvalidActionOrder)
	end

	local keyboard: TokenOwners = {}
	local gamepad: TokenOwners = {}
	local seenActionIds = {}

	for index = 1, #actionOrder do
		local actionId = actionOrder[index]
		if type(actionId) ~= "string" or actionId == "" or seenActionIds[actionId] then
			return invalid(ErrorIds.InvalidActionOrder)
		end
		seenActionIds[actionId] = true
		local definition = actions[actionId]
		if type(definition) ~= "table" then
			return invalid(ErrorIds.MissingAction)
		end
		local action = definition :: ActionDefinition
		local keyboardError = collectBindings(keyboard, action.KeyboardKeyCodeNames, actionId)
		if keyboardError ~= nil then
			return invalid(keyboardError)
		end
		local gamepadError = collectBindings(gamepad, action.GamepadKeyCodeNames, actionId)
		if gamepadError ~= nil then
			return invalid(gamepadError)
		end
	end

	local collisions = {}
	appendCollisions(collisions, FamilyIds.Keyboard, keyboard)
	appendCollisions(collisions, FamilyIds.Gamepad, gamepad)
	table.sort(collisions, function(left, right)
		if left.FamilyId ~= right.FamilyId then
			return left.FamilyId < right.FamilyId
		end
		return left.BindingToken < right.BindingToken
	end)

	return table.freeze({
		Valid = true,
		ErrorId = nil,
		Collisions = table.freeze(collisions),
	})
end

return table.freeze(Analyzer)
