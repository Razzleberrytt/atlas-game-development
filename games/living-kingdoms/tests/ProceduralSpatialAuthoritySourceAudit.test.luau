--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local assembler = fs.readFile("games/living-kingdoms/src/shared/Expeditions/RoomSequenceAssembler.luau")
local planner = fs.readFile("games/living-kingdoms/src/shared/Expeditions/RoomPlacementPlanner.luau")
local validator = fs.readFile("games/living-kingdoms/src/shared/Expeditions/InstanceLayoutValidator.luau")
local generator = fs.readFile("games/living-kingdoms/src/shared/Expeditions/ProceduralInstanceGenerator.luau")
local placement = fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionRoomPlacementService.luau")
local presentation = fs.readFile("games/living-kingdoms/src/server/Systems/ModularDungeonRoomPresentation.luau")

assertThat(
	string.find(generator, "pcall(RoomSequenceAssembler.assemble, seed)", 1, true) ~= nil,
	"procedural generator must delegate room content order to the current assembler"
)
assertThat(
	string.find(generator, "RoomPlacementPlanner.plan", 1, true) ~= nil
		and string.find(generator, "InstanceLayoutValidator.validate", 1, true) ~= nil,
	"generator must orchestrate planner then fail-closed validator"
)
assertThat(
	string.find(generator, "generateFromRoomPlan", 1, true) ~= nil,
	"runtime needs a validated path for an already-authoritative room plan"
)
assertThat(
	string.find(generator, "ExpeditionInstanceRegistry", 1, true) == nil,
	"LKB-0481 must not import later multi-run instance ownership"
)

assertThat(
	string.find(placement, "ProceduralInstanceGenerator.generateFromRoomPlan(roomPlan)", 1, true) ~= nil,
	"Roblox room placement must consume validated generator output"
)
assertThat(
	string.find(placement, "RoomPlacementPlanner", 1, true) == nil,
	"runtime placement must not bypass validation by requiring the planner directly"
)
local generationIndex =
	assert(string.find(placement, "ProceduralInstanceGenerator.generateFromRoomPlan(roomPlan)", 1, true))
local rootCreationIndex = assert(string.find(placement, 'local root = Instance.new("Folder")', 1, true))
assertThat(generationIndex < rootCreationIndex, "validation must finish before Workspace materialization begins")
assertThat(
	string.find(placement, "NorthWall", 1, true) ~= nil
		and string.find(placement, "SouthWall", 1, true) ~= nil
		and string.find(placement, "WestWall", 1, true) ~= nil
		and string.find(placement, "EastWall", 1, true) ~= nil,
	"cardinal graybox owner must support walls on every side"
)
assertThat(
	string.find(placement, "local segmentLength = (totalLength - doorwayWidth) / 2", 1, true) ~= nil,
	"open wall sides must retain collision around the exact validated doorway width"
)
assertThat(
	string.find(placement, 'value:SetAttribute("GameplayGrayboxVisual", true)', 1, true) ~= nil,
	"authoritative floor/wall collision visuals must be explicitly identifiable"
)
assertThat(
	string.find(placement, 'sideId == "East" or sideId == "West"', 1, true) ~= nil,
	"east/west doorway fixtures must rotate to match authoritative sockets"
)
assertThat(
	string.find(placement, "Vector3.new(connector.Size.x, connector.Size.y, connector.Size.z)", 1, true) ~= nil,
	"runtime connector geometry must come from the validated axis-aware layout"
)
assertThat(
	string.find(placement, "ExpeditionEnvironmentBuilder.decorate", 1, true) ~= nil
		and string.find(placement, "ModularDungeonRoomPresentation.apply", 1, true) ~= nil,
	"existing environment and modular presentation owners must remain downstream"
)

assertThat(
	string.find(presentation, 'placement.TurnId ~= "Straight"', 1, true) ~= nil
		and string.find(presentation, '"UnsupportedTurnLayout"', 1, true) ~= nil,
	"unsupported turn shells must fail visibly to authoritative graybox instead of lying about openings"
)
assertThat(
	string.find(presentation, 'child:GetAttribute("GameplayGrayboxVisual") == true', 1, true) ~= nil,
	"supported shells must hide every segmented graybox visual without dropping its collision"
)
assertThat(
	string.find(presentation, "math.rad(90)", 1, true) ~= nil,
	"supported east/west straight shells must rotate with their authoritative route"
)

for _, pureSource in { assembler, planner, validator, generator } do
	assertThat(
		string.find(pureSource, "math.random", 1, true) == nil,
		"pure procedural resolution must not use math.random"
	)
	assertThat(
		string.find(pureSource, "Random.new", 1, true) == nil,
		"pure procedural resolution must not use Random.new"
	)
	assertThat(
		string.find(pureSource, "game:GetService", 1, true) == nil,
		"pure procedural resolution must not use Roblox services"
	)
end
assertThat(
	string.find(assembler, "function RoomSequenceAssembler.assemble(seed: number)", 1, true) ~= nil,
	"current assembler public contract must remain seed-only and unexpanded by stale #568 options"
)
assertThat(
	string.find(planner, "MAX_GENERATION_ATTEMPTS = 16", 1, true) ~= nil
		and string.find(planner, "UsedFallback", 1, true) ~= nil,
	"spatial generation must stay finitely bounded with explicit fallback metadata"
)
assertThat(
	string.find(validator, 'return failure("DuplicateGridCell"', 1, true) ~= nil
		and string.find(validator, 'return failure("SocketDirectionMismatch"', 1, true) ~= nil
		and string.find(validator, 'return failure("ConnectorGeometryMismatch"', 1, true) ~= nil,
	"validator must keep core overlap/socket/connector corruption checks"
)

print("ProceduralSpatialAuthoritySourceAudit: canonical ownership, validation gate, and bounded purity passed")
