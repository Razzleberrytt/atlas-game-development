--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)
local WeaponLoadoutContracts = require(ReplicatedStorage.Shared.Weapons.WeaponLoadoutContracts)

local Resolver = {}
local Reasons = WeaponLoadoutContracts.RejectionReasonIds
local States = WeaponLoadoutContracts.SelectionStateIds

local function copyAssignment(assignment: WeaponLoadoutContracts.AuthoritativeAssignment)
	return table.freeze({
		operativeEntityId = assignment.operativeEntityId,
		weaponId = assignment.weaponId,
		selectionStateId = assignment.selectionStateId,
		revision = assignment.revision,
	})
end

local function rejected(assignment, reasonId: string, requestId: string?)
	return table.freeze({
		didSelect = false,
		rejectionReasonId = reasonId,
		requestId = requestId,
		assignmentAfter = copyAssignment(assignment),
	})
end

function Resolver.resolve(
	assignment: WeaponLoadoutContracts.AuthoritativeAssignment,
	payload: unknown,
	facts: { selectionOpen: boolean, isDuplicateRequest: boolean, isRateLimited: boolean }
)
	local requestId = if type(payload) == "table" and type((payload :: any).requestId) == "string"
		then (payload :: any).requestId
		else nil
	if assignment.selectionStateId ~= States.Open or not facts.selectionOpen then
		return rejected(assignment, Reasons.SelectionClosed, requestId)
	end
	if not WeaponLoadoutContracts.validateIntent(payload) then
		return rejected(assignment, Reasons.InvalidIntent, requestId)
	end
	local intent = payload :: WeaponLoadoutContracts.SelectionIntent
	if facts.isDuplicateRequest then
		return rejected(assignment, Reasons.DuplicateRequest, intent.requestId)
	end
	if facts.isRateLimited then
		return rejected(assignment, Reasons.RateLimited, intent.requestId)
	end
	if FirearmConfig.get(intent.weaponId) == nil then
		return rejected(assignment, Reasons.UnknownWeapon, intent.requestId)
	end
	return table.freeze({
		didSelect = true,
		rejectionReasonId = nil,
		requestId = intent.requestId,
		assignmentAfter = table.freeze({
			operativeEntityId = assignment.operativeEntityId,
			weaponId = intent.weaponId,
			selectionStateId = assignment.selectionStateId,
			revision = assignment.revision + 1,
		}),
	})
end

return table.freeze(Resolver)
