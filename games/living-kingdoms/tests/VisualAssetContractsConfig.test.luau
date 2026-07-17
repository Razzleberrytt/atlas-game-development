--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local contractsPath = "games/living-kingdoms/src/shared/Visual/VisualAssetContracts.luau"
local configPath = "games/living-kingdoms/src/shared/Config/VisualAssetConfig.luau"
local enemyPath = "games/living-kingdoms/src/server/Systems/EnemyDirectorService.luau"
local cachePath = "games/living-kingdoms/src/server/Systems/AmmunitionCacheService.luau"
local worldPath = "games/living-kingdoms/src/server/Systems/WorldFoundationService.luau"
local missionPath = "games/living-kingdoms/src/server/Systems/MissionDirectorService.luau"

local contracts = luau.load(fs.readFile(contractsPath), {
	debugName = "VisualAssetContracts",
	injectGlobals = true,
})()

local CONTRACTS_TOKEN = {}
local config = luau.load(fs.readFile(configPath), {
	debugName = "VisualAssetConfig",
	environment = {
		script = {
			Parent = {
				Parent = {
					Visual = {
						VisualAssetContracts = CONTRACTS_TOKEN,
					},
				},
			},
		},
		require = function(token: unknown)
			if token == CONTRACTS_TOKEN then
				return contracts
			end
			error("unexpected VisualAssetConfig dependency", 2)
		end,
	},
	injectGlobals = true,
})()

assertThat(config.Version == "VIS-0101-v1", "visual asset registry version must be stable")
assertThat(#config.Registry == 28, "VIS-0101 must inventory the complete initial presentation surface")

local keyCount = 0
for _, assetKey in contracts.AssetKeys do
	keyCount += 1
	assertThat(config.ByKey[assetKey] ~= nil, "every declared visual key requires one registry entry")
end
assertThat(keyCount == #config.Registry, "registry and declared visual-key counts must match")

assertThat(
	config.ByKey[contracts.AssetKeys.WeaponBasicFirearmModel].statusId == contracts.StatusIds.MissingPresentation,
	"basic firearm must remain honestly marked as missing production presentation"
)
assertThat(
	config.ByKey[contracts.AssetKeys.OperativeBaseRig].statusId == contracts.StatusIds.DefaultAvatarPlaceholder,
	"operative rig must remain honestly marked as the default-avatar placeholder"
)
for _, assetKey in
	{
		contracts.AssetKeys.ClassCombatSpecialistEquipment,
		contracts.AssetKeys.ClassMedicEquipment,
		contracts.AssetKeys.ClassEngineerEquipment,
	}
do
	local entry = config.ByKey[assetKey]
	assertThat(
		entry.statusId == contracts.StatusIds.PrimitivePlaceholder,
		"class equipment must record the procedural fallback"
	)
	assertThat(
		entry.runtimeOwnerPath == "src/client/Controllers/ClassSilhouetteController.luau",
		"class equipment runtime owner must be the silhouette controller"
	)
	assertThat(entry.expectedRootName == "OperativeClassSilhouette", "class equipment root contract drifted")
	assertThat(#entry.requiredAttachmentNames == 0, "procedural class fallback must not claim an authored attachment")
end
assertThat(
	config.ByKey[contracts.AssetKeys.EnemyStandardHostileModel].statusId == contracts.StatusIds.PrimitivePlaceholder,
	"standard hostile must remain honestly marked as primitive geometry"
)
assertThat(
	config.ByKey[contracts.AssetKeys.InterfaceMission].statusId == contracts.StatusIds.TemporaryPresentation,
	"mission interface must remain honestly marked as temporary"
)

for _, entry in config.Registry do
	assertThat(contracts.validateRecord(entry), "every registry entry must satisfy the shared contract")
	assertThat(
		entry.statusId ~= contracts.StatusIds.ProductionApproved,
		"VIS-0101 must not falsely approve production art"
	)
	assertThat(
		not string.find(entry.sourceReference, "rbxassetid://", 1, true),
		"registry must not contain numeric asset IDs"
	)
	assertThat(
		not string.find(entry.runtimeOwnerPath, "..", 1, true),
		"runtime owner paths must not traverse directories"
	)
	if entry.allowsCosmeticVariants then
		assertThat(
			entry.familyId == contracts.FamilyIds.Weapon
				or entry.familyId == contracts.FamilyIds.Operative
				or entry.familyId == contracts.FamilyIds.ClassEquipment
				or entry.familyId == contracts.FamilyIds.Enemy,
			"only readable character or equipment families may opt into cosmetics"
		)
	end
end

local contractsMutationSucceeded = pcall(function()
	contracts.AssetKeys.WeaponBasicFirearmModel = "forged"
end)
assertThat(not contractsMutationSucceeded, "visual asset vocabulary must be frozen")

local configMutationSucceeded = pcall(function()
	config.Registry[1].statusId = contracts.StatusIds.ProductionApproved
end)
assertThat(not configMutationSucceeded, "visual asset registry records must be frozen")

local combinedDeclarations = fs.readFile(contractsPath) .. "\n" .. fs.readFile(configPath)
for _, forbidden in
	{
		"game:GetService",
		"Instance.new",
		"RemoteEvent",
		"RemoteFunction",
		"FireServer",
		"FireClient",
		"OnServerEvent",
		"task.delay",
		"task.spawn",
	}
do
	assertThat(
		not string.find(combinedDeclarations, forbidden, 1, true),
		"VIS-0101 declarations must not contain " .. forbidden
	)
end

local enemySource = fs.readFile(enemyPath)
local cacheSource = fs.readFile(cachePath)
local worldSource = fs.readFile(worldPath)
local missionSource = fs.readFile(missionPath)

assertThat(
	string.find(enemySource, "root.Size = Vector3.new(3, 5.6, 3)", 1, true) ~= nil,
	"enemy placeholder inventory must remain grounded in the current graybox body"
)
assertThat(
	string.find(enemySource, 'billboard.Name = "EnemyLabel"', 1, true) ~= nil,
	"enemy placeholder inventory must account for the temporary health billboard"
)
assertThat(
	string.find(cacheSource, "part.Size = Vector3.new(3.6, 1.8, 2.6)", 1, true) ~= nil,
	"cache placeholder inventory must remain grounded in the current primitive cache"
)
assertThat(
	string.find(worldSource, 'model:SetAttribute("Graybox", true)', 1, true) ~= nil,
	"world placeholder inventory must remain grounded in explicit graybox landmarks"
)
assertThat(
	string.find(missionSource, 'pillar.Name = "SignalPillar"', 1, true) ~= nil,
	"extraction placeholder inventory must account for the current signal pillar"
)
