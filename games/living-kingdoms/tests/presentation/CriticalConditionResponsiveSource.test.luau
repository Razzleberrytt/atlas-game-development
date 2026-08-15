--!strict

local fs = require("@lune/fs")

local source = fs.readFile("games/living-kingdoms/src/client/Controllers/CriticalConditionController.luau")

local function assertContains(token: string, message: string)
	assert(string.find(source, token, 1, true) ~= nil, message)
end

assertContains("WARNING_HORIZONTAL_MARGIN", "critical warning must preserve horizontal viewport margins")
assertContains("WARNING_MAX_WIDTH", "critical warning must preserve its desktop maximum width")
assertContains('Instance.new("UISizeConstraint")', "critical warning must cap its responsive width")
assertContains("warning.TextWrapped = true", "critical warning must wrap rather than clip on narrow viewports")

print("CriticalConditionResponsiveSource.test.luau passed")
