--!strict

local fs = require("@lune/fs")

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local resolver = fs.readFile("games/living-kingdoms/src/shared/Assets/ModularAssetResolver.luau")
local bootstrap = fs.readFile("games/living-kingdoms/src/server/ModularAssetBootstrap.server.luau")
local weaponAdapter = fs.readFile("games/living-kingdoms/src/client/Presentation/ModularWeaponPresentationAdapter.luau")
local survivalPresentation =
	fs.readFile("games/living-kingdoms/src/server/Systems/ModularRewardContainerPresentation.luau")

for _, token in
	{
		'GENERATED_ROOT_READY_ATTRIBUTE = "GeneratedPrototypeReady"',
		"root:GetAttribute(GENERATED_ROOT_READY_ATTRIBUTE) == true",
		"function Resolver.WaitForGeneratedAssetById",
		"assert(timeoutSeconds >= 0 and timeoutSeconds < math.huge",
		"Resolver.FindByAssetId(root, assetId)",
		"task.wait(math.min(READY_POLL_SECONDS, remaining))",
	}
do
	assert(contains(resolver, token), "modular resolver readiness contract missing " .. token)
end

for _, token in
	{
		'READY_ATTRIBUTE = "GeneratedPrototypeReady"',
		'not existing:IsA("Folder")',
		"existing:GetAttribute(READY_ATTRIBUTE) ~= true",
		"Factory.BuildStarterLibrary(generatedRoot)",
		"generatedRoot:SetAttribute(READY_ATTRIBUTE, true)",
		"generatedRoot.Parent = atlasAssets",
	}
do
	assert(contains(bootstrap, token), "modular bootstrap readiness contract missing " .. token)
end

local buildStart = assert(string.find(bootstrap, "Factory.BuildStarterLibrary(generatedRoot)", 1, true))
local readyStart = assert(string.find(bootstrap, "generatedRoot:SetAttribute(READY_ATTRIBUTE, true)", 1, true))
local publishStart = assert(string.find(bootstrap, "generatedRoot.Parent = atlasAssets", 1, true))
assert(buildStart < readyStart, "generated modular library must finish building before it is marked ready")
assert(readyStart < publishStart, "generated modular library must be marked ready before publication")

for label, source in pairs({
	weapon = weaponAdapter,
	survivalChest = survivalPresentation,
}) do
	assert(contains(source, "ASSET_READY_WAIT_SECONDS = 0.75"), label .. " wait must stay tightly bounded")
	assert(contains(source, "local readinessWaitSpent = false"), label .. " must track the one-shot wait budget")
	assert(
		contains(source, "ModularAssetResolver.WaitForGeneratedAssetById"),
		label .. " must use asset-specific readiness"
	)
	assert(contains(source, "if readinessWaitSpent then"), label .. " must not repeat the bounded startup wait")
	assert(contains(source, "ModularAssetResolver.GetGeneratedRoot"), label .. " must retain an immediate fast path")
	assert(contains(source, "ModularAssetResolver.CloneByAssetId"), label .. " must retain stable-ID cloning")
end

for _, prohibited in
	{
		'WaitForChild("GeneratedModularAssets")',
		"while true do\n\t\ttask.wait()",
	}
do
	assert(not contains(resolver, prohibited), "modular readiness must not introduce an unbounded wait")
end

print("ModularAssetReadinessSourceAudit: atomic publication + bounded asset-specific readiness passed")
