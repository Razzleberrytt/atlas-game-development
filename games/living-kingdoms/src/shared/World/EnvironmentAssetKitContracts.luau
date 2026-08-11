--!strict

export type EnvironmentFamily =
	"Rock"
	| "Cliff"
	| "Tree"
	| "DeadTree"
	| "Root"
	| "Brush"
	| "GroundClutter"
	| "Structure"
	| "Prop"
	| "Bridge"
	| "Cave"
	| "Industrial"
	| "Camp"
	| "UnknownStructure"

export type ScaleClass = "Tiny" | "Small" | "Medium" | "Large" | "Hero"
export type CollisionPolicy = "None" | "Simple" | "Walkable" | "Blocker" | "Custom"
export type QualityTier = "Minimum" | "Reduced" | "Full"

export type SocketDefinition = {
	id: string,
	kind: "VFX" | "Audio" | "Prop" | "Snap" | "Traversal",
}

export type EnvironmentAssetDefinition = {
	id: string,
	family: EnvironmentFamily,
	variantId: string,
	biomeIds: { string },
	scaleClass: ScaleClass,
	collisionPolicy: CollisionPolicy,
	streamingGroupId: string,
	qualityTiers: { QualityTier },
	sockets: { SocketDefinition },
	sourceModelPath: string,
	footprintStuds: { x: number, y: number, z: number },
	presentationOnly: boolean,
	gameplayAuthorityOwnerId: string?,
}

export type ValidationIssue = {
	assetId: string?,
	code: string,
	message: string,
}

local Contracts = {}

local VALID_FAMILIES = table.freeze({
	Rock = true,
	Cliff = true,
	Tree = true,
	DeadTree = true,
	Root = true,
	Brush = true,
	GroundClutter = true,
	Structure = true,
	Prop = true,
	Bridge = true,
	Cave = true,
	Industrial = true,
	Camp = true,
	UnknownStructure = true,
})

local VALID_SCALE_CLASSES = table.freeze({ Tiny = true, Small = true, Medium = true, Large = true, Hero = true })
local VALID_COLLISION = table.freeze({ None = true, Simple = true, Walkable = true, Blocker = true, Custom = true })
local VALID_QUALITY_TIERS = table.freeze({ Minimum = true, Reduced = true, Full = true })
local VALID_SOCKET_KINDS = table.freeze({ VFX = true, Audio = true, Prop = true, Snap = true, Traversal = true })

function Contracts.validate(definitions: { EnvironmentAssetDefinition }): { ValidationIssue }
	local issues = {}
	local seenIds = {}

	local function issue(assetId: string?, code: string, message: string)
		table.insert(issues, { assetId = assetId, code = code, message = message })
	end

	for _, definition in definitions do
		local id = definition.id
		if id == "" then
			issue(nil, "MissingAssetId", "environment asset id must be non-empty")
		elseif seenIds[id] then
			issue(id, "DuplicateAssetId", "environment asset ids must be unique")
		else
			seenIds[id] = true
		end

		if not VALID_FAMILIES[definition.family] then
			issue(id, "InvalidFamily", "environment family is not registered")
		end
		if definition.variantId == "" then
			issue(id, "MissingVariantId", "variant id must be non-empty")
		end
		if #definition.biomeIds == 0 then
			issue(id, "MissingBiome", "at least one biome id is required")
		end
		if not VALID_SCALE_CLASSES[definition.scaleClass] then
			issue(id, "InvalidScaleClass", "scale class is invalid")
		end
		if not VALID_COLLISION[definition.collisionPolicy] then
			issue(id, "InvalidCollisionPolicy", "collision policy is invalid")
		end
		if definition.streamingGroupId == "" then
			issue(id, "MissingStreamingGroup", "streaming group id must be non-empty")
		end
		if definition.sourceModelPath == "" then
			issue(id, "MissingSourceModelPath", "source model path must be non-empty")
		end
		if definition.footprintStuds.x <= 0 or definition.footprintStuds.y <= 0 or definition.footprintStuds.z <= 0 then
			issue(id, "InvalidFootprint", "footprint dimensions must all be positive")
		end
		if not definition.presentationOnly or definition.gameplayAuthorityOwnerId ~= nil then
			issue(
				id,
				"GameplayAuthorityForbidden",
				"environment kit assets are presentation-only and may not own gameplay authority"
			)
		end

		local seenQuality = {}
		for _, tier in definition.qualityTiers do
			if not VALID_QUALITY_TIERS[tier] then
				issue(id, "InvalidQualityTier", "quality tier is invalid")
			elseif seenQuality[tier] then
				issue(id, "DuplicateQualityTier", "quality tiers must not repeat")
			else
				seenQuality[tier] = true
			end
		end
		if not seenQuality.Minimum then
			issue(id, "MinimumTierRequired", "every environment asset must define a Minimum-readable tier")
		end

		local seenSockets = {}
		for _, socket in definition.sockets do
			if socket.id == "" then
				issue(id, "MissingSocketId", "socket ids must be non-empty")
			elseif seenSockets[socket.id] then
				issue(id, "DuplicateSocketId", "socket ids must be unique within an asset")
			else
				seenSockets[socket.id] = true
			end
			if not VALID_SOCKET_KINDS[socket.kind] then
				issue(id, "InvalidSocketKind", "socket kind is invalid")
			end
		end
	end

	return issues
end

function Contracts.isValid(definitions: { EnvironmentAssetDefinition }): boolean
	return #Contracts.validate(definitions) == 0
end

return table.freeze(Contracts)
