--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local resolver =
	luau.load(fs.readFile("games/living-kingdoms/src/client/Presentation/OperativeCarryPoseResolver.luau"), {
		debugName = "OperativeCarryPoseResolver",
		injectGlobals = true,
	})()

assertThat(resolver.resolve({
	operativeEntityId = "operative.player:1",
	lifeStateId = "Alive",
	reviveStatus = nil,
	reviveReviverOperativeEntityId = nil,
}) == "Ready", "alive operatives must use the ready carry pose")

assertThat(resolver.resolve({
	operativeEntityId = "operative.player:1",
	lifeStateId = "Alive",
	reviveStatus = "Active",
	reviveReviverOperativeEntityId = "operative.player:1",
}) == "Reviving", "the authoritative reviver must lower into the revive pose")

assertThat(resolver.resolve({
	operativeEntityId = "operative.player:1",
	lifeStateId = "Alive",
	reviveStatus = "Active",
	reviveReviverOperativeEntityId = "operative.player:2",
}) == "Ready", "the revive target disclosure must not make another alive operative pose as reviver")

assertThat(resolver.resolve({
	operativeEntityId = "operative.player:1",
	lifeStateId = "Incapacitated",
	reviveStatus = "Active",
	reviveReviverOperativeEntityId = "operative.player:1",
}) == "Incapacitated", "incapacitation must override stale revive disclosure")

assertThat(resolver.resolve({
	operativeEntityId = "operative.player:1",
	lifeStateId = "Dead",
	reviveStatus = "Active",
	reviveReviverOperativeEntityId = "operative.player:1",
}) == "Dead", "death must have first precedence")

assertThat(resolver.resolve({
	operativeEntityId = "operative.player:1",
	lifeStateId = "Forged",
	reviveStatus = nil,
	reviveReviverOperativeEntityId = nil,
}) == "Hidden", "unknown life state must fail closed")

local function isFinite(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local expectedPoseIds = {
	Ready = true,
	Reviving = true,
	Incapacitated = true,
	Dead = true,
}

for _, rigId in { "R6", "R15" } do
	local definitions = resolver.DefinitionsByRigId[rigId]
	assertThat(type(definitions) == "table", rigId .. " definitions missing")
	local poseCount = 0
	for poseId, definition in definitions do
		poseCount += 1
		assertThat(expectedPoseIds[poseId] == true, "unexpected carry pose definition: " .. tostring(poseId))
		for _, vector in
			{
				definition.rightShoulderRotationDegrees,
				definition.leftShoulderRotationDegrees,
				definition.gripOffset,
				definition.gripRotationDegrees,
			}
		do
			assertThat(isFinite(vector.x) and isFinite(vector.y) and isFinite(vector.z), "pose vectors must be finite")
		end
		assertThat(resolver.definitionFor(rigId, poseId) == definition, "definition lookup must be deterministic")
	end
	assertThat(poseCount == 4, rigId .. " must define exactly four visible carry poses")
	assertThat(resolver.definitionFor(rigId, "Hidden") == nil, "hidden state must restore captured baselines")
end

local mutationSucceeded = pcall(function()
	resolver.DefinitionsByRigId.R15.Ready.gripOffset.x = 999
end)
assertThat(not mutationSucceeded, "carry pose definitions must be immutable")

print("OperativeCarryPoseResolver: precedence, rig coverage, finite geometry, lookup, and immutability passed")
