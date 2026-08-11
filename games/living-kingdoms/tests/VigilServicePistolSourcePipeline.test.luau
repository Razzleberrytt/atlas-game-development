--!strict

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "VigilServicePistolSourcePipeline assertion failed", 2)
	end
end

local root = "games/living-kingdoms/assets/visual/weapon/service-pistol/"
local manifest = serde.decode("json", fs.readFile(root .. "vigil-service-pistol.manifest.json"))
local animations = serde.decode("json", fs.readFile(root .. manifest.animationFile))
local generator = fs.readFile(root .. manifest.generatorFile)
local factory = fs.readFile("games/living-kingdoms/src/client/Presentation/ServicePistolPresentationFactory.luau")
local registry = fs.readFile("games/living-kingdoms/src/shared/Config/WeaponVisualSkinRegistry.luau")

check(manifest.assetKey == "visual.weapon.service-pistol.model")
check(manifest.visualId == "weapon.visual.service_pistol.vigil_v1")
check(manifest.weaponId == "weapon.service-pistol")
check(manifest.candidateId == "vigil-service-pistol.v2")
check(manifest.status == "source-candidate-not-runtime-approved")
check(manifest.sourceKind == "ProjectOriginal")
check(manifest.minimumComponentMeshCount >= 20)
check(manifest.studioGate.imported == false)
check(manifest.studioGate.visualReviewPassed == false)

for _, required in { "RightGripAttachment", "Muzzle", "Magazine", "Ejection" } do
	check(manifest.attachmentLocators[required] ~= nil, "missing source locator " .. required)
end

check(animations.presentationOnly == true)
check(#animations.clips == 3)
check(string.find(generator, "import trimesh", 1, true) == nil, "Vigil generator must remain dependency-free")
check(string.find(generator, "COMPONENTS", 1, true) ~= nil)
check(string.find(generator, '"Bolt"', 1, true) ~= nil)
check(string.find(generator, '"Magazine"', 1, true) ~= nil)

check(string.find(factory, manifest.candidateId, 1, true) ~= nil, "runtime factory/source candidate identity drift")
check(string.find(factory, manifest.weaponId, 1, true) ~= nil, "runtime factory/source weapon identity drift")
check(string.find(registry, manifest.visualId, 1, true) ~= nil, "source visual id must remain registered")

for authority, owner in manifest.gameplayAuthority do
	check(owner == "server", "source manifest may not claim gameplay authority: " .. authority)
end
