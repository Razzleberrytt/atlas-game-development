--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "MainWorldAcceptanceScopeResolver assertion failed", 2)
	end
end

local RESOLVER_PATH = "games/living-kingdoms/src/shared/World/MainWorldAcceptanceScopeResolver.luau"
local MATRIX_PATH = "games/living-kingdoms/src/shared/Config/MainWorldAcceptanceMatrixConfig.luau"
local REPRESENTATION_PATH = "games/living-kingdoms/src/shared/Config/MainWorldRepresentationConfig.luau"

local resolver = luau.load(fs.readFile(RESOLVER_PATH), {
	debugName = "MainWorldAcceptanceScopeResolver",
	injectGlobals = true,
})()

-- The real BA-011 and BA-014 contracts are loaded: scope must be derived from
-- committed mapping truth and the committed matrix, never from a convenient stub.
local representation = luau.load(fs.readFile(REPRESENTATION_PATH), {
	debugName = "MainWorldRepresentationConfig",
	injectGlobals = true,
})()

local REPRESENTATION_TOKEN = {}
local matrix = luau.load(fs.readFile(MATRIX_PATH), {
	debugName = "MainWorldAcceptanceMatrixConfig",
	environment = {
		script = { Parent = { MainWorldRepresentationConfig = REPRESENTATION_TOKEN } },
		require = function(token: unknown)
			if token == REPRESENTATION_TOKEN then
				return representation
			end
			error("unexpected MainWorldAcceptanceMatrixConfig dependency")
		end,
	},
	injectGlobals = true,
})()

local mappedGroupIds = representation.mappedStreamingGroupIds()
local scope = resolver.resolveScope(matrix, mappedGroupIds)

-- The mapped build cannot answer the whole matrix, and the resolver must say so.
check(scope.coversWholeMatrix == false, "only two of five streaming groups are mapped today")
check(#scope.inScopeCheckIds > 0, "the mapped hub/route build must be able to answer something")
check(#scope.outOfScopeCheckIds > 0, "unmapped families must be excluded from the first run")
check(
	#scope.inScopeCheckIds + #scope.outOfScopeCheckIds == #matrix.Checks,
	"every matrix check must be partitioned exactly once"
)

-- Partition truth, derived from the committed contracts rather than restated.
local mapped: { [string]: boolean } = {}
for _, groupId in mappedGroupIds do
	mapped[groupId] = true
end
for _, matrixCheck in matrix.Checks do
	local expectedInScope = true
	for _, groupId in matrixCheck.streamingGroupIds do
		if not mapped[groupId] then
			expectedInScope = false
		end
	end
	local entry = scope.entryByCheckId[matrixCheck.id]
	check(entry ~= nil, `check {matrixCheck.id} was not partitioned`)
	check(entry.inScope == expectedInScope, `check {matrixCheck.id} was partitioned incorrectly`)
	check(entry.blocking == matrixCheck.blocking, `check {matrixCheck.id} lost its blocking flag`)
	if expectedInScope then
		check(#entry.missingGroupIds == 0, `in-scope check {matrixCheck.id} must name no missing group`)
	else
		check(#entry.missingGroupIds > 0, `out-of-scope check {matrixCheck.id} must name why`)
		for _, groupId in entry.missingGroupIds do
			check(not mapped[groupId], `check {matrixCheck.id} names mapped group {groupId} as missing`)
		end
	end
end

-- A check that depends on no streaming group does not depend on represented
-- content, so it stays in scope regardless of what is mapped.
check(
	resolver.isCheckInScope(scope, "mwam.visual.fixed_camera_capture_set"),
	"a check naming no streaming group must stay in scope"
)
-- Hub-core-only and route-only checks are answerable on the mapped build.
check(resolver.isCheckInScope(scope, "mwam.arrival.orientation_recognition"), "hub-core checks are mapped")
check(resolver.isCheckInScope(scope, "mwam.navigation.dead_travel"), "primary-route checks are mapped")
check(resolver.isCheckInScope(scope, "mwam.navigation.core_loop_traversal"), "hub-core + route checks are mapped")
-- Families with no content in the place cannot be observed.
check(not resolver.isCheckInScope(scope, "mwam.audio.accessibility"), "atmosphere is unmapped")
check(not resolver.isCheckInScope(scope, "mwam.visual.ambient_ceilings"), "atmosphere is unmapped")
check(not resolver.isCheckInScope(scope, "mwam.readability.landmark_recognition_distance"), "structures are unmapped")
check(not resolver.isCheckInScope(scope, "mwam.streaming.semantic_group_rebind"), "all-group checks are unmapped")
check(not resolver.isCheckInScope(scope, "mwam.performance.desktop_full_traversal"), "all-group checks are unmapped")
check(resolver.isCheckInScope(scope, "mwam.not.a.check") == false, "an unknown check is never in scope")

-- Ordering follows the matrix so a derived worklist reads like the sheet.
local matrixOrder: { [string]: number } = {}
for index, matrixCheck in matrix.Checks do
	matrixOrder[matrixCheck.id] = index
end
for index = 2, #scope.inScopeCheckIds do
	check(
		matrixOrder[scope.inScopeCheckIds[index]] > matrixOrder[scope.inScopeCheckIds[index - 1]],
		"in-scope checks must preserve matrix order"
	)
end

-- Every blocking in-scope check is genuinely blocking and genuinely in scope.
for _, checkId in scope.blockingInScopeCheckIds do
	check(matrix.ChecksById[checkId].blocking == true, `{checkId} is not a blocking check`)
	check(resolver.isCheckInScope(scope, checkId), `{checkId} is not in scope`)
end
check(#scope.blockingInScopeCheckIds > 0, "a scoped run that gates nothing is not worth running")

-- The scope is read-only, so no consumer can widen it in place.
check(pcall(function()
	scope.inScopeCheckIds[1] = "mwam.audio.accessibility"
end) == false, "a resolved scope must be read-only")

-- Scoped evaluation -------------------------------------------------------

local function completeIdentity(): { [string]: string }
	local identity = {}
	for _, field in matrix.RequiredRunIdentityFields do
		identity[field] = "recorded"
	end
	return identity
end

local function passingScopedResults(): { [string]: string }
	local results = {}
	for _, checkId in scope.inScopeCheckIds do
		results[checkId] = matrix.ResultStatuses.Pass
	end
	return results
end

local satisfied = resolver.evaluateScopedRun(matrix, mappedGroupIds, {
	identity = completeIdentity(),
	results = passingScopedResults(),
})
check(satisfied.scopeSatisfied == true, "a complete passing scoped run must satisfy its scope")
check(#satisfied.reasons == 0, "a satisfied scoped run needs no reasons")

-- The decisive property: satisfying a partial scope never accepts activation.
check(
	satisfied.activationAcceptable == false,
	"a scoped pass must not accept Main World activation while families stay unmapped"
)
check(
	matrix.isActivationAcceptable({ identity = completeIdentity(), results = passingScopedResults() }) == false,
	"the full BA-014 gate must still reject a partial run"
)

-- A blocking in-scope failure, a blocked transport and an unrun check each reject.
for _, rejected in { matrix.ResultStatuses.Fail, matrix.ResultStatuses.Blocked, matrix.ResultStatuses.NotRun } do
	local run = { identity = completeIdentity(), results = passingScopedResults() }
	run.results[scope.blockingInScopeCheckIds[1]] = rejected
	local evaluation = resolver.evaluateScopedRun(matrix, mappedGroupIds, run)
	check(evaluation.scopeSatisfied == false, `a blocking in-scope check recorded {rejected} must reject`)
	check(#evaluation.reasons == 1, "the evaluator must name exactly the failing check")
end

-- A missing in-scope result rejects rather than passing by omission.
local missingResult = { identity = completeIdentity(), results = passingScopedResults() }
missingResult.results[scope.inScopeCheckIds[1]] = nil
check(
	resolver.evaluateScopedRun(matrix, mappedGroupIds, missingResult).scopeSatisfied == false,
	"an in-scope check with no result must reject the scoped run"
)

-- Recording a result for content the place does not contain is rejected, not ignored.
local outOfScopeResult = { identity = completeIdentity(), results = passingScopedResults() }
outOfScopeResult.results[scope.outOfScopeCheckIds[1]] = matrix.ResultStatuses.Pass
local outOfScopeEvaluation = resolver.evaluateScopedRun(matrix, mappedGroupIds, outOfScopeResult)
check(outOfScopeEvaluation.scopeSatisfied == false, "an out-of-scope result must reject the scoped run")
check(
	string.find(outOfScopeEvaluation.reasons[1], "out of scope", 1, true) ~= nil,
	"the rejection must explain that the build cannot answer the check"
)

-- Unknown checks, unknown statuses and incomplete identity all reject.
local unknownCheck = { identity = completeIdentity(), results = passingScopedResults() }
unknownCheck.results["mwam.not.a.check"] = matrix.ResultStatuses.Pass
check(
	resolver.evaluateScopedRun(matrix, mappedGroupIds, unknownCheck).scopeSatisfied == false,
	"a result for an unknown check must reject the scoped run"
)

local badStatus = { identity = completeIdentity(), results = passingScopedResults() }
badStatus.results[scope.inScopeCheckIds[1]] = "LooksFine"
check(
	resolver.evaluateScopedRun(matrix, mappedGroupIds, badStatus).scopeSatisfied == false,
	"an unknown status must reject the scoped run"
)

local missingIdentity = { identity = completeIdentity(), results = passingScopedResults() }
missingIdentity.identity.placeArtifactSha256 = nil
check(
	resolver.evaluateScopedRun(matrix, mappedGroupIds, missingIdentity).scopeSatisfied == false,
	"an incomplete run identity must reject the scoped run"
)

-- Scope widens as content is admitted: with every group mapped, the scope is the
-- whole matrix and a complete passing run does accept activation.
local everyGroupId: { string } = {}
for _, group in representation.StreamingGroups do
	table.insert(everyGroupId, group.id)
end
local wholeScope = resolver.resolveScope(matrix, everyGroupId)
check(wholeScope.coversWholeMatrix == true, "mapping every group must cover the whole matrix")
check(#wholeScope.outOfScopeCheckIds == 0, "nothing is out of scope once every group is mapped")
check(#wholeScope.inScopeCheckIds == #matrix.Checks, "every check is answerable once every group is mapped")

local wholeResults = {}
for _, matrixCheck in matrix.Checks do
	wholeResults[matrixCheck.id] = matrix.ResultStatuses.Pass
end
local wholeEvaluation = resolver.evaluateScopedRun(matrix, everyGroupId, {
	identity = completeIdentity(),
	results = wholeResults,
})
check(wholeEvaluation.scopeSatisfied == true, "a complete passing full-scope run satisfies its scope")
check(wholeEvaluation.activationAcceptable == true, "a complete passing full-matrix run may accept activation")

-- An empty mapped set answers only the checks that name no streaming group.
local emptyScope = resolver.resolveScope(matrix, {})
check(#emptyScope.inScopeCheckIds > 0, "group-independent checks survive an empty mapping")
for _, checkId in emptyScope.inScopeCheckIds do
	check(#matrix.ChecksById[checkId].streamingGroupIds == 0, `{checkId} should need mapped content`)
end

-- Evaluating a run must never mutate the committed definition.
check(matrix.Checks[1].status == matrix.ResultStatuses.NotRun, "scoped evaluation must not record a result")

-- Boundary audit: scoping decides worklists, not runtime or measurement.
local source = fs.readFile(RESOLVER_PATH)
check(string.find(source, "game:GetService", 1, true) == nil, "the resolver must not reach for live services")
check(string.find(source, "FireServer", 1, true) == nil, "the resolver owns no networking")
check(string.find(source, "DataStore", 1, true) == nil, "the resolver owns no persistence")
check(string.find(source, "Instance.new", 1, true) == nil, "the resolver creates no instances")
check(string.find(source, "rbxassetid://", 1, true) == nil, "the resolver invents no asset IDs")
-- Scope may not restate a threshold; the matrix owns every number.
check(string.find(source, "Thresholds", 1, true) == nil, "thresholds stay owned by the BA-014 matrix")
check(string.find(source, "QualityTiers", 1, true) == nil, "tier ceilings stay owned by the BA-014 matrix")

print("MainWorldAcceptanceScopeResolver fixture passed")
