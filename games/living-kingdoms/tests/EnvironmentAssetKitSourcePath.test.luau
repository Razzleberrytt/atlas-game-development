--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "EnvironmentAssetKitSourcePath assertion failed", 2)
	end
end

local registry = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/EnvironmentAssetKitRegistry.luau"), {
	debugName = "EnvironmentAssetKitRegistry",
	injectGlobals = true,
})()

for _, definition in registry.Definitions do
	check(
		string.sub(definition.sourceModelPath, 1, 12) == "Environment/",
		"environment models must stay under Environment/"
	)
	check(
		string.find(definition.sourceModelPath, "..", 1, true) == nil,
		"environment model path may not escape its source root"
	)
end
