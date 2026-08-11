--!strict

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "LongwatchSniperSourcePipeline assertion failed", 2)
	end
end

local root = "games/living-kingdoms/assets/visual/weapon/sniper-rifle/"
local manifest = serde.decode("json", fs.readFile(root .. "longwatch-sniper-rifle.manifest.json"))
local animations = serde.decode("json", fs.readFile(root .. manifest.animationFile))
local generator = fs.readFile(root .. manifest.generatorFile)
local factory = fs.readFile("games/living-kingdoms/src/client/Presentation/SniperRiflePresentationFactory.luau")
local registry = fs.readFile("games/living-kingdoms/src/shared/Config/WeaponVisualSkinRegistry.luau")

check(manifest.assetKey == "visual.weapon.sniper-rifle.model")
check(manifest.visualId == "weapon.visual.sniper_rifle.longwatch_v1")
check(manifest.weaponId == "weapon.sniper-rifle")
check(manifest.candidateId == "longwatch-sniper-rifle.v2")
check(manifest.status == "source-candidate-not-runtime-approved")
check(manifest.sourceKind == "ProjectOriginal")
check(manifest.minimumComponentMeshCount >= 24)
check(manifest.studioGate.imported == false)
check(manifest.studioGate.isometricReadabilityVerified == false)

for _, required in { "RightGripAttachment", "LeftGripAttachment", "Muzzle", "Magazine", "Ejection" } do
	check(manifest.attachmentLocators[required] ~= nil, "missing source locator " .. required)
end

check(animations.presentationOnly == true)
check(#animations.clips == 3)
check(string.find(generator, "import trimesh", 1, true) == nil, "Longwatch generator must remain dependency-free")
for _, component in { '"HeavyBarrel"', '"ScopeTube"', '"Magazine"', '"Bolt"', '"BipodLeftLeg"' } do
	check(string.find(generator, component, 1, true) ~= nil, "generator missing silhouette component " .. component)
end

check(string.find(factory, manifest.candidateId, 1, true) ~= nil, "runtime factory/source candidate identity drift")
check(string.find(factory, manifest.weaponId, 1, true) ~= nil, "runtime factory/source weapon identity drift")
check(string.find(registry, manifest.visualId, 1, true) ~= nil, "source visual id must remain registered")

for authority, owner in manifest.gameplayAuthority do
	check(owner == "server", "source manifest may not claim gameplay authority: " .. authority)
end
