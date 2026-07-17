--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local config = luau.load(
	fs.readFile("games/living-kingdoms/src/client/Presentation/SupplyCachePresentationConfig.luau"),
	{
		debugName = "SupplyCachePresentationConfig",
		injectGlobals = true,
	}
)()

assertThat(config.Version == "VIS-0105-supply-cache-v1", "supply cache visual version drifted")
assertThat(config.PresentationModelName == "SupplyCachePresentation", "supply cache model name drifted")
assertThat(config.MaximumPartsPerCache == 13, "supply cache part budget drifted")
assertThat(#config.Parts + 1 == config.MaximumPartsPerCache, "lid plus static parts must match the part budget")
assertThat(config.StateIds.Available == "Available" and config.StateIds.Consumed == "Consumed", "state IDs drifted")

local function isFinite(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local seenNames = {}
for _, definition in config.Parts do
	assertThat(type(definition.name) == "string" and definition.name ~= "", "part name missing")
	assertThat(not seenNames[definition.name], "duplicate supply cache part: " .. definition.name)
	seenNames[definition.name] = true
	for _, vector in { definition.size, definition.offset, definition.rotationDegrees } do
		assertThat(isFinite(vector.x) and isFinite(vector.y) and isFinite(vector.z), "part vectors must be finite")
	end
	assertThat(definition.size.x > 0 and definition.size.y > 0 and definition.size.z > 0, "part size must be positive")
end

for _, vector in {
	config.Lid.Size,
	config.Lid.ClosedOffset,
	config.Lid.ClosedRotationDegrees,
	config.Lid.ConsumedOffset,
	config.Lid.ConsumedRotationDegrees,
} do
	assertThat(isFinite(vector.x) and isFinite(vector.y) and isFinite(vector.z), "lid vectors must be finite")
end
assertThat(config.Lid.ConsumedRotationDegrees.x ~= config.Lid.ClosedRotationDegrees.x, "consumed lid must visibly open")

local mutationSucceeded = pcall(function()
	config.Parts[1].size.x = 999
end)
assertThat(not mutationSucceeded, "supply cache visual definitions must be immutable")

print("SupplyCachePresentationConfig: budget, states, finite geometry, uniqueness, lid readability, and immutability passed")
