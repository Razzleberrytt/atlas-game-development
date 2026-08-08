--!strict

-- Canonical identifiers for source-managed Living Kingdoms world content.
-- These IDs are deliberately independent of Roblox instance names so imported
-- Studio content can be reconciled without making legacy hierarchy names part
-- of gameplay authority.

local WorldContentContracts = {}

export type ContentKind =
	"world"
	| "zone"
	| "landmark"
	| "route"
	| "portal"
	| "vendor"
	| "resource"
	| "spawn"

export type ContentId = string

export type ContentDescriptor = {
	id: ContentId,
	kind: ContentKind,
	displayName: string,
	legacyAliases: { string },
	active: boolean,
	notes: string?,
}

local VALID_KINDS = table.freeze({
	world = true,
	zone = true,
	landmark = true,
	route = true,
	portal = true,
	vendor = true,
	resource = true,
	spawn = true,
})

function WorldContentContracts.isValidId(id: unknown): boolean
	if type(id) ~= "string" then
		return false
	end
	if #id < 3 or #id > 96 then
		return false
	end
	return string.match(id, "^[a-z0-9][a-z0-9._%-]*$") ~= nil
end

function WorldContentContracts.validateDescriptor(descriptor: ContentDescriptor): (boolean, string?)
	if not WorldContentContracts.isValidId(descriptor.id) then
		return false, "invalid content id"
	end
	if VALID_KINDS[descriptor.kind] ~= true then
		return false, "invalid content kind"
	end
	if descriptor.displayName == "" then
		return false, "displayName must not be empty"
	end
	for _, alias in descriptor.legacyAliases do
		if alias == "" then
			return false, "legacy alias must not be empty"
		end
	end
	return true, nil
end

function WorldContentContracts.indexById(descriptors: { ContentDescriptor }): { [ContentId]: ContentDescriptor }
	local byId: { [ContentId]: ContentDescriptor } = {}
	for _, descriptor in descriptors do
		local valid, reason = WorldContentContracts.validateDescriptor(descriptor)
		assert(valid, reason)
		assert(byId[descriptor.id] == nil, "duplicate world content id: " .. descriptor.id)
		byId[descriptor.id] = descriptor
	end
	return byId
end

function WorldContentContracts.indexLegacyAliases(descriptors: { ContentDescriptor }): { [string]: ContentId }
	local aliases: { [string]: ContentId } = {}
	for _, descriptor in descriptors do
		for _, alias in descriptor.legacyAliases do
			local existing = aliases[alias]
			assert(existing == nil or existing == descriptor.id, "legacy alias maps to multiple IDs: " .. alias)
			aliases[alias] = descriptor.id
		end
	end
	return aliases
end

return table.freeze(WorldContentContracts)
