--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local root = "games/living-kingdoms/assets/visual/weapon/basic-firearm/"
local model = fs.readFile(root .. "blackwater_service_carbine.obj")
local animations = fs.readFile(root .. "blackwater_service_carbine.animations.json")
local manifest = fs.readFile(root .. "asset-manifest.json")
local generator = fs.readFile(root .. "generate_blackwater_carbine.py")
local readme = fs.readFile(root .. "README.md")

assertThat(string.find(model, "# https://github.com/mikedh/trimesh", 1, true) ~= nil, "weapon source must identify its generator")

for _, componentName in {
	"Receiver",
	"Magazine",
	"Bolt",
	"MuzzleDevice",
	"PistolGrip",
} do
	assertThat(string.find(model, "o " .. componentName, 1, true) ~= nil, "missing source component " .. componentName)
end

for _, clipName in { "Fire", "Reload", "Empty" } do
	assertThat(string.find(animations, '"name": "' .. clipName .. '"', 1, true) ~= nil, "missing animation clip " .. clipName)
end

assertThat(string.find(animations, '"node": "Bolt"', 1, true) ~= nil, "bolt animation track must remain explicit")
assertThat(string.find(animations, '"node": "Magazine"', 1, true) ~= nil, "magazine animation track must remain explicit")

assertThat(
	string.find(manifest, '"status": "source-candidate-not-runtime-approved"', 1, true) ~= nil,
	"manifest must not claim Studio or runtime approval"
)
assertThat(string.find(manifest, '"sourceKind": "ProjectOriginal"', 1, true) ~= nil, "source ownership must be recorded")
assertThat(string.find(manifest, '"imported": false', 1, true) ~= nil, "Studio import must remain honestly pending")
assertThat(string.find(manifest, '"cadence": "server"', 1, true) ~= nil, "manifest must preserve server cadence authority")
assertThat(string.find(manifest, '"damage": "server"', 1, true) ~= nil, "manifest must preserve server damage authority")

for _, forbidden in { "rbxassetid://", "requests.get", "urllib.request", "subprocess" } do
	assertThat(not string.find(generator, forbidden, 1, true), "generator must not fetch or execute external content: " .. forbidden)
end

assertThat(string.find(readme, "presentation only", 1, true) ~= nil, "import guide must preserve the authority boundary")
