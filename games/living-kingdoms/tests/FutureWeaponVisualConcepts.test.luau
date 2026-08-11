--!strict

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local luau = require("@lune/luau")

local ROOT = "games/living-kingdoms/assets/visual/weapon/concepts/"

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "FutureWeaponVisualConcepts assertion failed", 2)
	end
end

local registry =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/FutureWeaponVisualConceptRegistry.luau"), {
		debugName = "FutureWeaponVisualConceptRegistry",
		injectGlobals = true,
	})()
local manifest = serde.decode("json", fs.readFile(ROOT .. "weapon-concept-wave1.manifest.json"))

check(registry.Version == "WEAPON-VISUAL-CONCEPT-v1")
check(#registry.Concepts == 4)
check(#manifest.concepts == 4)
check(manifest.runtimeMapped == false)
check(manifest.studioApproval == false)
check(manifest.gameplayAuthority == false)
check(manifest.canonicalFirearmBindings == 0)

local byId = {}
for _, concept in registry.Concepts do
	check(byId[concept.id] == nil, "duplicate concept id: " .. concept.id)
	byId[concept.id] = concept
	check(concept.canonicalFirearmId == nil, "future visual concepts must not bind canonical firearms")
	check(concept.runtimeMapped == false)
	check(concept.studioApproval == false)
	check(concept.presentationOnly == true)
	check(concept.gameplayAuthorityOwnerId == nil)
	check(#concept.silhouetteTags >= 3)
	check(#concept.requiredSockets >= 4)
end

for _, entry in manifest.concepts do
	local concept = byId[entry.id]
	check(concept ~= nil, "manifest concept missing registry definition: " .. entry.id)
	local model = serde.decode("json", fs.readFile(ROOT .. entry.file))
	check(model.ClassName == "Model")
	local parts = 0
	local attachments = {}
	local function visit(node)
		check(node.ClassName ~= "Script" and node.ClassName ~= "LocalScript" and node.ClassName ~= "ModuleScript")
		check(node.ClassName ~= "RemoteEvent" and node.ClassName ~= "RemoteFunction")
		if node.ClassName == "Part" then
			parts += 1
			check(node.Properties ~= nil and node.Properties.Anchored == true)
		end
		if node.ClassName == "Attachment" then
			attachments[node.Name] = true
		end
		for _, child in node.Children or {} do
			visit(child)
		end
	end
	visit(model)
	check(parts >= entry.minimumPartCount, entry.id .. " has too few source Parts")
	for _, socketName in concept.requiredSockets do
		check(attachments[socketName] == true, entry.id .. " missing visual socket " .. socketName)
	end
end
