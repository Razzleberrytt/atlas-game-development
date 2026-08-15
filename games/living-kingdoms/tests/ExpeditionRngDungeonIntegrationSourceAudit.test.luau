--!strict

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local planner = fs.readFile("games/living-kingdoms/src/shared/Expeditions/RoomPlacementPlanner.luau")
local placement = fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionRoomPlacementService.luau")
local barrierState = fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionRoomBarrierStateService.luau")

for _, required in {
	'LayoutVersion = "rng-grid-v1"',
	"GenerationAttempt = generationAttempt",
	"UsedFallback = usedFallback",
	"TurnId = turnId",
	"EntranceSide = entranceSide",
	"ExitSide = exitSide",
	"connector endpoints must be cardinally aligned",
} do
	assertThat(string.find(planner, required, 1, true) ~= nil, "RNG planner contract is missing " .. required)
end

for _, required in {
	'root:SetAttribute("LayoutVersion", layout.LayoutVersion)',
	'root:SetAttribute("GenerationAttempt", layout.GenerationAttempt)',
	'model:SetAttribute("LayoutTurnId", placement.TurnId)',
	'buildWallSide(sideId, center, size, doorwayWidth, openSides[sideId] == true, model)',
	'doorwayCFrame(placement.Entrance, placement.EntranceSide)',
	'doorwayCFrame(placement.Exit, placement.ExitSide)',
	'Vector3.new(connectorSize.x, connectorSize.y, connectorSize.z)',
	'bridge:SetAttribute("ConnectorAxis", connector.Axis)',
} do
	assertThat(string.find(placement, required, 1, true) ~= nil, "room placement is not consuming RNG layout metadata: " .. required)
end

assertThat(
	string.find(barrierState, 'workspace:FindFirstChild("ExpeditionRooms")', 1, true) ~= nil,
	"RNG rooms must remain under the canonical expedition root consumed by barrier authority"
)
assertThat(
	string.find(barrierState, 'child:GetAttribute("RoomIndex") == context.RoomIndex', 1, true) ~= nil,
	"encounter barrier lookup must remain keyed by ordered room index rather than physical position"
)

for _, forbidden in {
	"math.random",
	"Random.new",
	"tick()",
	"os.time()",
} do
	assertThat(not string.find(planner, forbidden, 1, true), "layout planner must not use hidden/non-replayable randomness: " .. forbidden)
end

print("Expedition RNG dungeon integration source audit passed")
