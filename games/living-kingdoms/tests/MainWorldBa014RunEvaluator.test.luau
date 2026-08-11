--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string?)
	if not condition then
		error(message or "MainWorldBa014RunEvaluator assertion failed", 2)
	end
end

local CONFIG_DIR = "games/living-kingdoms/src/shared/Config"
local RESOLVER_PATH = "games/living-kingdoms/src/shared/World/MainWorldAcceptanceScopeResolver.luau"
local EVALUATOR_PATH = "games/living-kingdoms/tools/evidence/MainWorldBa014RunEvaluator.luau"
local CLI_PATH = "games/living-kingdoms/tools/evidence/evaluate-ba014-run.luau"

local function loadModule(path: string, environment: any?): any
	local options: any = { debugName = path, injectGlobals = true }
	if environment ~= nil then
		options.environment = environment
	end
	return luau.load(fs.readFile(path), options)()
end

-- The real committed contracts are loaded: a verdict must be decided against
-- the actual matrix and actual mapping truth, never a convenient stub.
local representation = loadModule(`{CONFIG_DIR}/MainWorldRepresentationConfig.luau`)

local REPRESENTATION_TOKEN = {}
local matrix = loadModule(`{CONFIG_DIR}/MainWorldAcceptanceMatrixConfig.luau`, {
	script = { Parent = { MainWorldRepresentationConfig = REPRESENTATION_TOKEN } },
	require = function(token: unknown)
		if token == REPRESENTATION_TOKEN then
			return representation
		end
		error("unexpected MainWorldAcceptanceMatrixConfig dependency")
	end,
})

local scopeResolver = loadModule(RESOLVER_PATH)
local evaluator = loadModule(EVALUATOR_PATH)

local mappedGroupIds = representation.mappedStreamingGroupIds()
local scope = scopeResolver.resolveScope(matrix, mappedGroupIds)

local function evaluate(record: any): any
	return evaluator.evaluate(matrix, scopeResolver, mappedGroupIds, record)
end

-- Blank record -------------------------------------------------------------

local blank = evaluator.blankRunRecord(matrix, scopeResolver, mappedGroupIds)

local blankResultCount = 0
for checkId, status in blank.results do
	blankResultCount += 1
	check(status == matrix.ResultStatuses.NotRun, `blank record must ship {checkId} unrun`)
	check(scopeResolver.isCheckInScope(scope, checkId), `blank record offers out-of-scope check {checkId}`)
end
check(blankResultCount == #scope.inScopeCheckIds, "the blank record must cover exactly the in-scope checks")

for _, field in matrix.RequiredRunIdentityFields do
	check(blank.identity[field] == "", `blank record must offer identity field {field}`)
end

-- A blank record is never a pass.
local blankDecision = evaluate(blank)
check(blankDecision.result == "PARTIAL", "an unfilled record is incomplete, not failed and not passed")
check(blankDecision.activationAcceptable == false, "a blank record never accepts activation")

-- Helpers ------------------------------------------------------------------

local function identityValue(field: string): string
	if field == "repositoryCommit" or field == "rollbackCheckpointCommit" then
		return string.rep("a", 40)
	elseif field == "placeArtifactSha256" then
		return string.rep("b", 64)
	end
	return "recorded"
end

local function passingRecord(): any
	local identity: { [string]: string } = {}
	for _, field in matrix.RequiredRunIdentityFields do
		identity[field] = identityValue(field)
	end
	local results: { [string]: string } = {}
	for _, checkId in scope.inScopeCheckIds do
		results[checkId] = matrix.ResultStatuses.Pass
	end
	return { identity = identity, results = results }
end

local function firstBlockingInScope(): string
	return scope.blockingInScopeCheckIds[1]
end

local function firstNonBlockingInScope(): string
	for _, checkId in scope.inScopeCheckIds do
		if not matrix.ChecksById[checkId].blocking then
			return checkId
		end
	end
	error("the scoped worklist must retain a non-blocking check")
end

-- Scoped pass --------------------------------------------------------------

local passed = evaluate(passingRecord())
check(passed.result == "PASS", "a complete passing scoped record must pass its scope")
check(passed.scopeSatisfied == true)
check(#passed.invalidReasons == 0 and #passed.missingEvidence == 0 and #passed.failures == 0)
check(passed.inScopeCheckCount == #scope.inScopeCheckIds)
check(passed.outOfScopeCheckCount == #scope.outOfScopeCheckIds)

-- The decisive property: a scoped pass authorizes nothing.
check(passed.scopeCoversWholeMatrix == false, "the mapped build does not cover the whole matrix")
check(passed.activationAcceptable == false, "a scoped PASS must never accept Main World activation")

-- Decision precedence ------------------------------------------------------

local blockingFailure = passingRecord()
blockingFailure.results[firstBlockingInScope()] = matrix.ResultStatuses.Fail
local failed = evaluate(blockingFailure)
check(failed.result == "FAIL", "a blocking in-scope failure must fail the run")
check(#failed.failures == 1, "the evaluator must name exactly the failing check")

-- A transport failure leaves the run incomplete rather than failed; it is not a
-- runtime defect and must not be reported as one.
local blocked = passingRecord()
blocked.results[firstBlockingInScope()] = matrix.ResultStatuses.Blocked
local blockedDecision = evaluate(blocked)
check(blockedDecision.result == "PARTIAL", "a blocked check is missing evidence, not a defect")
check(#blockedDecision.failures == 0, "a blocked check must not be recorded as a failure")

local notRun = passingRecord()
notRun.results[firstBlockingInScope()] = matrix.ResultStatuses.NotRun
check(evaluate(notRun).result == "PARTIAL", "an unrun check leaves the run incomplete")

local omitted = passingRecord()
omitted.results[firstBlockingInScope()] = nil
check(evaluate(omitted).result == "PARTIAL", "an omitted in-scope check must not pass by omission")

-- `Invalid` means observed without usable identity, which outranks incompleteness.
local invalidStatus = passingRecord()
invalidStatus.results[firstBlockingInScope()] = matrix.ResultStatuses.Invalid
check(evaluate(invalidStatus).result == "INVALID", "an Invalid observation must decide INVALID")

-- A malformed record is decided before an incomplete one.
local bothWrong = passingRecord()
bothWrong.results[firstBlockingInScope()] = matrix.ResultStatuses.NotRun
bothWrong.results["mwam.not.a.check"] = matrix.ResultStatuses.Pass
check(evaluate(bothWrong).result == "INVALID", "a malformed record outranks an incomplete one")

check(evaluate("not a table").result == "INVALID", "a non-table record is invalid")
check(evaluate({}).result == "PARTIAL", "an empty record is incomplete")

-- Non-blocking results are surfaced but do not gate.
local nonBlockingFailure = passingRecord()
nonBlockingFailure.results[firstNonBlockingInScope()] = matrix.ResultStatuses.Fail
local nonBlockingDecision = evaluate(nonBlockingFailure)
check(nonBlockingDecision.result == "PASS", "a non-blocking result must not gate acceptance")
check(#nonBlockingDecision.nonBlockingFindings == 1, "a non-blocking failure must still reach the packet")

-- Out-of-scope and unknown results ----------------------------------------

local outOfScope = passingRecord()
local outOfScopeId = scope.outOfScopeCheckIds[1]
outOfScope.results[outOfScopeId] = matrix.ResultStatuses.Pass
local outOfScopeDecision = evaluate(outOfScope)
check(outOfScopeDecision.result == "INVALID", "recording an unobservable check must invalidate the run")
check(
	string.find(outOfScopeDecision.invalidReasons[1], "out of scope", 1, true) ~= nil,
	"the rejection must explain that the build cannot answer the check"
)

local unknownCheck = passingRecord()
unknownCheck.results["mwam.not.a.check"] = matrix.ResultStatuses.Pass
check(evaluate(unknownCheck).result == "INVALID", "a result for an unknown check must invalidate the run")

local unknownStatus = passingRecord()
unknownStatus.results[firstBlockingInScope()] = "LooksFine"
check(evaluate(unknownStatus).result == "INVALID", "an unknown status must invalidate the run")

-- Identity -----------------------------------------------------------------

local missingIdentity = passingRecord()
missingIdentity.identity.placeArtifactSha256 = nil
check(evaluate(missingIdentity).result == "PARTIAL", "an incomplete identity leaves the run incomplete")

local emptyIdentityField = passingRecord()
emptyIdentityField.identity.repositoryCommit = ""
check(evaluate(emptyIdentityField).result == "PARTIAL", "a blank identity field is not a recorded one")

local nonStringIdentity = passingRecord()
nonStringIdentity.identity.repositoryCommit = 12345
check(evaluate(nonStringIdentity).result == "INVALID", "a non-string identity field is malformed")

-- Widening scope -----------------------------------------------------------

-- Once every group is mapped the scope is the whole matrix, and a complete
-- passing run does accept activation. The gate is narrow, not one-way.
local everyGroupId: { string } = {}
for _, group in representation.StreamingGroups do
	table.insert(everyGroupId, group.id)
end

local wholeBlank = evaluator.blankRunRecord(matrix, scopeResolver, everyGroupId)
local wholeResults: { [string]: string } = {}
for checkId in wholeBlank.results do
	wholeResults[checkId] = matrix.ResultStatuses.Pass
end
local wholeIdentity: { [string]: string } = {}
for _, field in matrix.RequiredRunIdentityFields do
	wholeIdentity[field] = identityValue(field)
end

local wholeDecision =
	evaluator.evaluate(matrix, scopeResolver, everyGroupId, { identity = wholeIdentity, results = wholeResults })
check(wholeDecision.result == "PASS", "a complete passing full-matrix run passes")
check(wholeDecision.scopeCoversWholeMatrix == true, "every group mapped covers the whole matrix")
check(wholeDecision.activationAcceptable == true, "a complete passing full-matrix run may accept activation")
check(wholeDecision.outOfScopeCheckCount == 0)

-- Evaluating never mutates the committed definition.
check(matrix.Checks[1].status == matrix.ResultStatuses.NotRun, "evaluation must not record a result")

-- Boundary audit -----------------------------------------------------------

local source = fs.readFile(EVALUATOR_PATH)
check(string.find(source, "game:GetService", 1, true) == nil, "the evaluator must not reach for live services")
check(string.find(source, "FireServer", 1, true) == nil, "the evaluator owns no networking")
check(string.find(source, "DataStore", 1, true) == nil, "the evaluator owns no persistence")
check(string.find(source, "Instance.new", 1, true) == nil, "the evaluator creates no instances")
check(string.find(source, "rbxassetid://", 1, true) == nil, "the evaluator invents no asset IDs")
-- Every number stays owned by the BA-014 matrix.
check(string.find(source, "Thresholds", 1, true) == nil, "thresholds stay owned by the BA-014 matrix")
check(string.find(source, "QualityTiers", 1, true) == nil, "tier ceilings stay owned by the BA-014 matrix")

-- The CLI must keep reporting the scoped nature of a pass, and must not be able
-- to report acceptance on its own.
local cliSource = fs.readFile(CLI_PATH)
check(string.find(cliSource, "SCOPED", 1, true) ~= nil, "the CLI must state that a partial result is scoped")
check(string.find(cliSource, "activationAcceptable", 1, true) ~= nil, "the CLI must report the activation gate")
check(string.find(cliSource, "isActivationAcceptable", 1, true) == nil, "the CLI must not decide activation itself")

print("MainWorldBa014RunEvaluator fixture passed")
