--!strict

-- Pure viewport-fit math for fixed-design modal surfaces. A panel can keep its
-- authored pixel layout while shrinking uniformly when the available viewport
-- is narrower or shorter than that design size.

local ResponsivePanelScale = {}

function ResponsivePanelScale.calculate(
	viewportWidth: number,
	viewportHeight: number,
	designWidth: number,
	designHeight: number,
	margin: number?
): number
	assert(viewportWidth > 0 and viewportHeight > 0, "viewport dimensions must be positive")
	assert(designWidth > 0 and designHeight > 0, "design dimensions must be positive")

	local safeMargin = math.max(0, margin or 0)
	local availableWidth = math.max(1, viewportWidth - safeMargin * 2)
	local availableHeight = math.max(1, viewportHeight - safeMargin * 2)

	return math.min(1, availableWidth / designWidth, availableHeight / designHeight)
end

return table.freeze(ResponsivePanelScale)
