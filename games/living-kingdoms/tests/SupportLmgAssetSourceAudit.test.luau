--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local assetRoot = "games/living-kingdoms/assets/visual/weapon/basic-firearm/"
local generator = fs.readFile(assetRoot .. "generate_blackwater_support_lmg.py")
local animations = fs.readFile(assetRoot .. "blackwater_support_lmg.animations.json")
local manifest = fs.readFile(assetRoot .. "blackwater-support-lmg.manifest.json")
local readme = fs.readFile(assetRoot .. "README.md")
local factory = fs.readFile("games/living-kingdoms/src/client/Presentation/BasicFirearmPresentationFactory.luau")

for _, componentName in
	{
		"Receiver",
		"FeedCover",
		"HeatShield",
		"Magazine",
		"AmmoBoxLid",
		"Bolt",
		"MuzzleDevice",
		"CarryHandle",
		"BipodLeftLeg",
		"BipodRightLeg",
	}
do
	assertThat(
		string.find(generator, '"' .. componentName .. '"', 1, true) ~= nil,
		"support LMG generator missing component " .. componentName
	)
	assertThat(
		string.find(factory, '"' .. componentName .. '"', 1, true) ~= nil,
		"support LMG runtime fallback missing component " .. componentName
	)
end

assertThat(
	string.find(generator, 'f"BeltRound{index + 1:02d}"', 1, true) ~= nil
		and string.find(factory, '"BeltRound%02d"', 1, true) ~= nil,
	"support LMG source must generate named belt rounds"
)
assertThat(
	string.find(generator, 'f"BeltLink{index + 1:02d}"', 1, true) ~= nil
		and string.find(factory, '"BeltLink%02d"', 1, true) ~= nil,
	"support LMG source must generate named belt links"
)

assertThat(
	string.find(factory, 'model:SetAttribute("VisualCandidateId", "blackwater-support-lmg.v1")', 1, true) ~= nil,
	"runtime fallback must identify the support LMG candidate"
)
assertThat(
	string.find(factory, 'model:SetAttribute("VisualStatus", "ProceduralFallback")', 1, true) ~= nil,
	"runtime support LMG must remain honestly labeled as fallback presentation"
)
assertThat(
	string.find(factory, 'model:SetAttribute("GameplayFootprintId", "weapon.basic-firearm")', 1, true) ~= nil,
	"support LMG appearance must preserve the existing gameplay footprint"
)

assertThat(
	string.find(generator, 'scene.export(file_type="obj")', 1, true) ~= nil,
	"support LMG generator must emit a Roblox-importable OBJ"
)
assertThat(
	string.find(generator, "blackwater_support_lmg_preview.svg", 1, true) ~= nil,
	"support LMG generator must emit a review preview"
)
assertThat(
	string.find(manifest, '"componentMeshCount": 45', 1, true) ~= nil,
	"support LMG manifest must record the generated component count"
)
assertThat(
	string.find(manifest, '"status": "source-candidate-not-runtime-approved"', 1, true) ~= nil,
	"support LMG manifest must not claim Studio approval"
)
assertThat(
	string.find(manifest, '"sourceKind": "ProjectOriginal"', 1, true) ~= nil,
	"support LMG source ownership must remain explicit"
)
assertThat(
	string.find(manifest, '"cadence": "server"', 1, true) ~= nil
		and string.find(manifest, '"ammunition": "server"', 1, true) ~= nil
		and string.find(manifest, '"damage": "server"', 1, true) ~= nil,
	"support LMG manifest must preserve server gameplay authority"
)

for _, clipName in { "Fire", "Reload", "Empty" } do
	assertThat(
		string.find(animations, '"name": "' .. clipName .. '"', 1, true) ~= nil,
		"support LMG source missing animation clip " .. clipName
	)
end
assertThat(string.find(animations, '"node": "Bolt"', 1, true) ~= nil, "support LMG must expose a bolt track")
assertThat(
	string.find(animations, '"node": "Magazine"', 1, true) ~= nil,
	"support LMG ammo box must retain the stable Magazine animation node"
)
assertThat(
	string.find(readme, "presentation only", 1, true) ~= nil,
	"support LMG import guidance must preserve the authority boundary"
)
assertThat(
	string.find(readme, "project-original", 1, true) ~= nil,
	"support LMG documentation must distinguish the model from branded replicas"
)

for _, forbidden in
	{
		"rbxassetid://",
		"requests.get",
		"urllib.request",
		"subprocess",
		"FireServer",
		"InvokeServer",
		"DamagePerHit =",
		"CadenceSeconds =",
		"loadedRounds -=",
	}
do
	assertThat(
		not string.find(generator .. "\n" .. factory, forbidden, 1, true),
		"support LMG source must not contain external-fetch or gameplay-authority token " .. forbidden
	)
end
