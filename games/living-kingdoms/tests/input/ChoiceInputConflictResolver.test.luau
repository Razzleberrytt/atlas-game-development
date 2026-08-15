--!strict

-- BA-062 C4 foundation fixture. Numbered choice arbitration must dispatch only
-- when exactly one presentation owner is active and fail closed on overlap.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "BA-062 choice input conflict resolver assertion failed", 2)
	end
end

local path = "games/living-kingdoms/src/shared/Input/ChoiceInputConflictResolver.luau"
local source = fs.readFile(path)
local resolver = luau.load(source, { debugName = "ChoiceInputConflictResolver", injectGlobals = true })()
local ids = resolver.ResolutionIds

local none = resolver.resolve({})
assert(none.ResolutionId == ids.NoneActive)
assert(none.DispatchAllowed == false)
assert(none.OwnerId == nil)
assert(#none.ActiveOwnerIds == 0)

local progression = resolver.resolve({ "ProgressionUpgrade" })
assert(progression.ResolutionId == ids.SingleActive)
assert(progression.DispatchAllowed == true)
assert(progression.OwnerId == "ProgressionUpgrade")

local relic = resolver.resolve({ "RunRelic" })
assert(relic.ResolutionId == ids.SingleActive)
assert(relic.DispatchAllowed == true)
assert(relic.OwnerId == "RunRelic")

local overlap = resolver.resolve({ "RunRelic", "ProgressionUpgrade" })
assert(overlap.ResolutionId == ids.Conflict)
assert(overlap.DispatchAllowed == false, "overlap must never dispatch a numbered choice")
assert(overlap.OwnerId == nil)
assert(overlap.ActiveOwnerIds[1] == "ProgressionUpgrade")
assert(overlap.ActiveOwnerIds[2] == "RunRelic")

local reverseOverlap = resolver.resolve({ "ProgressionUpgrade", "RunRelic" })
assert(reverseOverlap.ResolutionId == ids.Conflict)
assert(reverseOverlap.ActiveOwnerIds[1] == overlap.ActiveOwnerIds[1])
assert(reverseOverlap.ActiveOwnerIds[2] == overlap.ActiveOwnerIds[2])

for _, invalid in
	{
		{ "" },
		{ "RunRelic", "RunRelic" },
	}
do
	local result = resolver.resolve(invalid)
	assert(result.ResolutionId == ids.InvalidInput)
	assert(result.DispatchAllowed == false)
	assert(result.OwnerId == nil)
end

for _, token in
	{
		"GetService",
		"InputBegan",
		"BindAction",
		"FireServer",
		"InvokeServer",
		"RemoteEvent",
		"Instance.new",
		"DataStore",
		"SetAsync",
		"UpdateAsync",
	}
do
	assert(string.find(source, token, 1, true) == nil, `resolver must remain pure: {token}`)
end

print("BA-062 ChoiceInputConflictResolver: single-owner dispatch and fail-closed overlap passed")
