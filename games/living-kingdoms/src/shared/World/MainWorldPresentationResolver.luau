--!strict

-- Resolves source-managed Main World presentation by stable semantic content ID.
-- The caller supplies child lookup so this module can be tested without Roblox
-- Instances. Resolution is deliberately non-blocking: streamed-out presentation
-- returns Missing rather than waiting or changing gameplay truth.

export type CompositionComponent = {
	id: string,
	targetRelativePath: string,
}

export type Composition = {
	componentById: (id: string) -> CompositionComponent?,
}

export type ResolveStatus = "Present" | "Missing" | "UnknownContentId"

export type ResolveResult<T> = {
	status: ResolveStatus,
	contentId: string,
	relativePath: string?,
	value: T?,
	missingSegment: string?,
}

local MainWorldPresentationResolver = {}

local function result<T>(
	status: ResolveStatus,
	contentId: string,
	relativePath: string?,
	value: T?,
	missingSegment: string?
): ResolveResult<T>
	return table.freeze({
		status = status,
		contentId = contentId,
		relativePath = relativePath,
		value = value,
		missingSegment = missingSegment,
	})
end

function MainWorldPresentationResolver.pathForContentId(composition: Composition, contentId: string): string?
	local component = composition.componentById(contentId)
	if component == nil then
		return nil
	end
	return component.targetRelativePath
end

function MainWorldPresentationResolver.resolve<T>(
	composition: Composition,
	contentId: string,
	root: T,
	findChild: (parent: T, name: string) -> T?
): ResolveResult<T>
	local relativePath = MainWorldPresentationResolver.pathForContentId(composition, contentId)
	if relativePath == nil then
		return result("UnknownContentId", contentId, nil, nil, nil)
	end

	local cursor = root
	for segment in string.gmatch(relativePath, "[^/]+") do
		local child = findChild(cursor, segment)
		if child == nil then
			return result("Missing", contentId, relativePath, nil, segment)
		end
		cursor = child
	end

	return result("Present", contentId, relativePath, cursor, nil)
end

return table.freeze(MainWorldPresentationResolver)
