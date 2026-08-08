--!strict

-- BA-012 contract for stable Main World / hub interaction anchors.
--
-- An anchor identifies a presentation surface and the canonical owner it may
-- delegate to. It never grants the surface authority to mutate gameplay.

local Contracts = {}

Contracts.SurfaceKindIds = table.freeze({
	Preparation = "Preparation",
	OperationBoard = "OperationBoard",
	Vendor = "Vendor",
	Npc = "Npc",
	Crafting = "Crafting",
	Gathering = "Gathering",
	Portal = "Portal",
	Social = "Social",
})

Contracts.WorldSpaceIds = table.freeze({
	CurrentOperationBridge = "CurrentOperationBridge",
	AuthoredMainWorld = "AuthoredMainWorld",
})

Contracts.PlacementStatusIds = table.freeze({
	ActiveSourceManaged = "ActiveSourceManaged",
	RecoveredHeld = "RecoveredHeld",
	UnassignedHeld = "UnassignedHeld",
})

Contracts.AuthorityStatusIds = table.freeze({
	ExistingCanonical = "ExistingCanonical",
	PresentationOnly = "PresentationOnly",
	DomainContractRequired = "DomainContractRequired",
	PolicyRequired = "PolicyRequired",
})

export type SurfaceKindId =
	"Preparation"
	| "OperationBoard"
	| "Vendor"
	| "Npc"
	| "Crafting"
	| "Gathering"
	| "Portal"
	| "Social"

export type WorldSpaceId = "CurrentOperationBridge" | "AuthoredMainWorld"

export type PlacementStatusId = "ActiveSourceManaged" | "RecoveredHeld" | "UnassignedHeld"

export type AuthorityStatusId = "ExistingCanonical" | "PresentationOnly" | "DomainContractRequired" | "PolicyRequired"

export type AnchorDefinition = {
	id: string,
	worldContentId: string,
	displayName: string,
	surfaceKindId: SurfaceKindId,
	worldSpaceId: WorldSpaceId,
	placementStatusId: PlacementStatusId,
	sourcePath: string?,
	interactionIntentId: string,
	presentationOwnerId: string?,
	mutationOwnerId: string?,
	authorityStatusId: AuthorityStatusId,
	runtimeEnabled: boolean,
	bridgeActionId: string?,
	dependencyIds: { string },
	notes: string?,
}

local function containsValue(values: { [string]: string }, candidate: unknown): boolean
	if type(candidate) ~= "string" then
		return false
	end
	for _, value in values do
		if value == candidate then
			return true
		end
	end
	return false
end

local function isNonEmptyBoundedString(value: unknown, maximumLength: number): boolean
	return type(value) == "string" and #value > 0 and #value <= maximumLength
end

function Contracts.isValidStableId(value: unknown): boolean
	return isNonEmptyBoundedString(value, 96) and string.match(value :: string, "^[a-z0-9][a-z0-9._%-]*$") ~= nil
end

function Contracts.validateAnchor(definition: AnchorDefinition): (boolean, string?)
	if not Contracts.isValidStableId(definition.id) then
		return false, "invalid anchor id"
	end
	if not Contracts.isValidStableId(definition.worldContentId) then
		return false, "invalid world content id"
	end
	if not Contracts.isValidStableId(definition.interactionIntentId) then
		return false, "invalid interaction intent id"
	end
	if not isNonEmptyBoundedString(definition.displayName, 128) then
		return false, "displayName must not be empty"
	end
	if not containsValue(Contracts.SurfaceKindIds, definition.surfaceKindId) then
		return false, "invalid surface kind"
	end
	if not containsValue(Contracts.WorldSpaceIds, definition.worldSpaceId) then
		return false, "invalid world space"
	end
	if not containsValue(Contracts.PlacementStatusIds, definition.placementStatusId) then
		return false, "invalid placement status"
	end
	if not containsValue(Contracts.AuthorityStatusIds, definition.authorityStatusId) then
		return false, "invalid authority status"
	end
	if type(definition.runtimeEnabled) ~= "boolean" then
		return false, "runtimeEnabled must be boolean"
	end
	if definition.sourcePath ~= nil and string.sub(definition.sourcePath, 1, #"Workspace/") ~= "Workspace/" then
		return false, "sourcePath must be a Workspace path"
	end
	if definition.placementStatusId == Contracts.PlacementStatusIds.RecoveredHeld and definition.sourcePath == nil then
		return false, "recovered placement requires sourcePath"
	end
	if definition.placementStatusId == Contracts.PlacementStatusIds.UnassignedHeld and definition.sourcePath ~= nil then
		return false, "unassigned placement may not claim sourcePath"
	end

	local ownerAssigned = definition.mutationOwnerId ~= nil
	if definition.authorityStatusId == Contracts.AuthorityStatusIds.ExistingCanonical and not ownerAssigned then
		return false, "existing canonical authority requires mutation owner"
	end
	if
		definition.authorityStatusId ~= Contracts.AuthorityStatusIds.ExistingCanonical
		and definition.mutationOwnerId ~= nil
	then
		return false, "held or presentation-only anchor may not invent mutation owner"
	end
	if
		definition.authorityStatusId == Contracts.AuthorityStatusIds.PresentationOnly
		and definition.presentationOwnerId == nil
	then
		return false, "presentation-only anchor requires presentation owner"
	end

	if definition.runtimeEnabled then
		if definition.worldSpaceId ~= Contracts.WorldSpaceIds.CurrentOperationBridge then
			return false, "only the current bridge may be runtime enabled"
		end
		if definition.placementStatusId ~= Contracts.PlacementStatusIds.ActiveSourceManaged then
			return false, "runtime-enabled anchor requires active source-managed placement"
		end
		if definition.authorityStatusId ~= Contracts.AuthorityStatusIds.ExistingCanonical then
			return false, "runtime-enabled anchor requires existing canonical authority"
		end
		if definition.presentationOwnerId == nil or definition.bridgeActionId == nil then
			return false, "runtime-enabled bridge requires presentation owner and action"
		end
	elseif definition.bridgeActionId ~= nil then
		return false, "held anchor may not claim an active bridge action"
	end

	local seenDependencies: { [string]: boolean } = {}
	for _, dependencyId in definition.dependencyIds do
		if not isNonEmptyBoundedString(dependencyId, 64) then
			return false, "invalid dependency id"
		end
		if seenDependencies[dependencyId] then
			return false, "duplicate dependency id"
		end
		seenDependencies[dependencyId] = true
	end

	return true, nil
end

function Contracts.indexById(definitions: { AnchorDefinition }): { [string]: AnchorDefinition }
	local byId: { [string]: AnchorDefinition } = {}
	for _, definition in definitions do
		local valid, reason = Contracts.validateAnchor(definition)
		assert(valid, reason)
		assert(byId[definition.id] == nil, "duplicate hub interaction anchor id: " .. definition.id)
		byId[definition.id] = definition
	end
	return byId
end

function Contracts.indexByWorldContentId(definitions: { AnchorDefinition }): { [string]: { AnchorDefinition } }
	local byWorldContentId: { [string]: { AnchorDefinition } } = {}
	for _, definition in definitions do
		local bucket = byWorldContentId[definition.worldContentId]
		if bucket == nil then
			bucket = {}
			byWorldContentId[definition.worldContentId] = bucket
		end
		table.insert(bucket, definition)
	end
	for _, bucket in byWorldContentId do
		table.freeze(bucket)
	end
	return byWorldContentId
end

return table.freeze(Contracts)
