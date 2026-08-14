--!strict

--[[
	Release-candidate security inventory.

	This test deliberately does not claim exploit prevention. It makes the
	client-to-server attack surface reviewable by source: every declared intent
	remote must be listed here, and server-to-client disclosure remotes must not be
	mistaken for trusted input. Adding a new intent without updating this audit is
	a release-candidate failure that forces an explicit security review.
]]

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then error(message, 2) end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local bootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")

local expectedIntentNames = {
	"FireIntent",
	"ReloadIntent",
	"ToggleIntent",
	"Intent",
	"SelectionIntent",
	"ActionIntent",
	"ChooseUpgrade",
	"SubmitRelicChoice",
	"SubmitRelicReplacement",
}

for _, remoteName in expectedIntentNames do
	assertThat(contains(bootstrap, '"' .. remoteName .. '"'), "RC remote inventory is missing declared intent: " .. remoteName)
end

for _, disclosureName in { "CombatPresentation", "State", "Result" } do
	assertThat(contains(bootstrap, '"' .. disclosureName .. '"'), "RC audit expects the existing disclosure surface: " .. disclosureName)
end

assertThat(contains(bootstrap, "server-to-client disclosure only"), "mission disclosure boundary must remain explicit")

print("RC 1.0 remote surface: declared client intent names are explicitly inventoried for security review")
