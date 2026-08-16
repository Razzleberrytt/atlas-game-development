--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

local EPSILON = 0.051
local MAX_STEP_DROP = 1.0
local MIN_WIDTH = 12.0
local EXPECTED_ARRIVAL_MOUNT =
	"assets/recovered-world/models/main-world-studio-2026-08-11/MainWorld-ArrivalTraversal.model.json"
local ARRIVAL_PATH = "games/living-kingdoms/" .. EXPECTED_ARRIVAL_MOUNT

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "MainWorldArrivalHandoffSourceAudit assertion failed", 2)
	end
end

local function loadConfig(path: string, debugName: string)
	return luau.load(fs.readFile(path), {
		debugName = debugName,
		injectGlobals = true,
	})()
end

local function findNamed(node, name: string)
	if node.Name == name then
		return node
	end
	for _, child in node.Children or {} do
		local found = findNamed(child, name)
		if found ~= nil then
			return found
		end
	end
	return nil
end

local function collectPrefix(node, prefix: string, output)
	if type(node.Name) == "string" and string.sub(node.Name, 1, #prefix) == prefix then
		table.insert(output, node)
	end
	for _, child in node.Children or {} do
		collectPrefix(child, prefix, output)
	end
end

local function geometry(node)
	local properties = node.Properties
	check(type(properties) == "table", "arrival part is missing Properties")
	local cframe = properties.CFrame
	local size = properties.Size
	check(type(cframe) == "table" and #cframe >= 3, "arrival part is missing CFrame")
	check(type(size) == "table" and #size == 3, "arrival part is missing Size")
	return {
		x = cframe[1],
		y = cframe[2],
		z = cframe[3],
		sx = size[1],
		sy = size[2],
		sz = size[3],
	}
end

local function top(node): number
	local g = geometry(node)
	return g.y + g.sy / 2
end

local function south(node): number
	local g = geometry(node)
	return g.z - g.sz / 2
end

local function north(node): number
	local g = geometry(node)
	return g.z + g.sz / 2
end

local function overlapsX(a, b): boolean
	local ag = geometry(a)
	local bg = geometry(b)
	return math.min(ag.x + ag.sx / 2, bg.x + bg.sx / 2) + EPSILON
		>= math.max(ag.x - ag.sx / 2, bg.x - bg.sx / 2)
end

local function assertStaticWalkable(node)
	local properties = node.Properties
	local g = geometry(node)
	check(properties.Anchored == true, node.Name .. " must remain anchored")
	check(properties.CanCollide == true, node.Name .. " must remain collidable")
	check(properties.Material.Enum == 880, node.Name .. " must retain cobblestone route material")
	check(g.sx >= MIN_WIDTH, node.Name .. " narrowed below the arrival width floor")
end

local spawnConfig = loadConfig(
	"games/living-kingdoms/src/shared/Config/RecoveredSpawnLocationConfig.luau",
	"RecoveredSpawnLocationConfig"
)
local lifecycle = loadConfig(
	"games/living-kingdoms/src/shared/Config/MainWorldLifecycleConfig.luau",
	"MainWorldLifecycleConfig"
)
local portalConfig = loadConfig(
	"games/living-kingdoms/src/shared/Config/RecoveredDungeonPortalConfig.luau",
	"RecoveredDungeonPortalConfig"
)

check(spawnConfig.RuntimeEnabled == false)
check(spawnConfig.Spawn.position.x == 0 and spawnConfig.Spawn.position.y == 7 and spawnConfig.Spawn.position.z == 30)
check(spawnConfig.Spawn.size.x == 6 and spawnConfig.Spawn.size.y == 1 and spawnConfig.Spawn.size.z == 6)
check(spawnConfig.Spawn.anchored == true and spawnConfig.Spawn.enabled == true)
check(lifecycle.RuntimeEnabled == false)
check(lifecycle.Arrival.ContentId == spawnConfig.SourceContentId)
check(lifecycle.Arrival.TargetPath == "Workspace/LivingKingdomsMainWorld/HubCore/Arrival/SpawnLocation")
check(lifecycle.Arrival.ColdJoinStartsHere == true)

local project = serde.decode("json", fs.readFile("games/living-kingdoms/main-world.project.json"))
local arrivalMount = project.tree.Workspace.LivingKingdomsMainWorld.ArrivalTraversal
check(arrivalMount["$path"] == EXPECTED_ARRIVAL_MOUNT)

local routes = serde.decode(
	"json",
	fs.readFile(
		"games/living-kingdoms/assets/recovered-world/models/main-world-studio-2026-08-11/MainWorld-RegionalRoutes.model.json"
	)
)
local arrival = serde.decode("json", fs.readFile(ARRIVAL_PATH))
local spawnApron = findNamed(routes, "main_world.regional_route.spawn_apron")
local northTrunk = findNamed(routes, "main_world.regional_route.north_trunk")
local landing = findNamed(arrival, "main_world.arrival_handoff.landing")
check(spawnApron ~= nil, "regional spawn apron is missing")
check(northTrunk ~= nil, "regional north trunk is missing")
check(landing ~= nil, "arrival landing is missing")

local steps = {}
collectPrefix(arrival, "main_world.arrival_handoff.step.", steps)
check(#steps == 8, "arrival handoff must retain exactly eight shallow steps")
table.sort(steps, function(a, b)
	return geometry(a).z < geometry(b).z
end)

assertStaticWalkable(landing)
local spawnTop = spawnConfig.Spawn.position.y + spawnConfig.Spawn.size.y / 2
local spawnNorth = spawnConfig.Spawn.position.z + spawnConfig.Spawn.size.z / 2
local spawnWest = spawnConfig.Spawn.position.x - spawnConfig.Spawn.size.x / 2
local spawnEast = spawnConfig.Spawn.position.x + spawnConfig.Spawn.size.x / 2
local landingGeometry = geometry(landing)
check(math.abs(top(landing) - spawnTop) <= EPSILON, "arrival landing is not flush with the recovered spawn")
check(math.abs(south(landing) - spawnNorth) <= EPSILON, "arrival landing does not touch the spawn north edge")
check(
	math.min(landingGeometry.x + landingGeometry.sx / 2, spawnEast) + EPSILON
		>= math.max(landingGeometry.x - landingGeometry.sx / 2, spawnWest),
	"arrival landing does not overlap the spawn width"
)

local previous = landing
local previousTop = top(landing)
for index, step in steps do
	assertStaticWalkable(step)
	check(step.Name == string.format("main_world.arrival_handoff.step.%03d", index), "arrival step order drifted")
	check(math.abs(south(step) - north(previous)) <= EPSILON, "arrival handoff has a horizontal stair gap")
	local currentTop = top(step)
	local drop = previousTop - currentTop
	check(drop > 0 and drop <= MAX_STEP_DROP + EPSILON, "arrival handoff vertical step exceeds the safety bound")
	local g = geometry(step)
	check(math.abs(g.y - g.sy / 2) <= EPSILON, "arrival stair must remain grounded on the lower continent")
	previous = step
	previousTop = currentTop
end

check(math.abs(previousTop - top(spawnApron)) <= EPSILON, "arrival final step is not flush with the spawn apron")
check(overlapsX(previous, northTrunk), "arrival final step does not overlap the north-trunk width")
local finalGeometry = geometry(previous)
local trunkGeometry = geometry(northTrunk)
check(
	finalGeometry.z >= trunkGeometry.z - trunkGeometry.sz / 2 - EPSILON
		and finalGeometry.z <= trunkGeometry.z + trunkGeometry.sz / 2 + EPSILON,
	"arrival final step falls outside the north-trunk span"
)

local portalFrame = nil
for _, part in portalConfig.Parts do
	if part.name == "PortalFrame" then
		portalFrame = part
		break
	end
end
check(portalFrame ~= nil, "recovered portal frame contract is missing")
local portalNorth = portalFrame.position.z + portalFrame.size.z / 2
check(south(landing) >= portalNorth + 4 - EPSILON, "arrival descent intrudes into portal clearance")

print(
	"MainWorldArrivalHandoffSourceAudit: authored spawn -> 16-stud landing -> 8 shallow steps -> north-trunk road passed"
)
