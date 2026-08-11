--!strict

--[[
	Deterministic evaluator for a recorded BA-014 Main World acceptance run.

	This module is tooling only and lives outside src/. It turns an operator's
	run record into an INVALID / PARTIAL / FAIL / PASS decision using the
	committed BA-014 matrix and the derived scope for the currently mapped
	build, so a Studio session cannot be talked into an acceptance it did not
	earn.

	It does not replace Studio evidence and it measures nothing. Every threshold
	stays owned by `MainWorldAcceptanceMatrixConfig`; this module only decides
	statuses an operator recorded against checks the build can actually answer.

	A `PASS` here is a *scoped* pass. `activationAcceptable` is reported
	separately from the full matrix and stays false while any streaming group is
	unmapped, so a satisfied partial scope can never read as Main World
	acceptance.

	Dependencies are injected so this stays testable under Lune.
]]

local Evaluator = {}

export type RunRecord = {
	identity: { [string]: string },
	results: { [string]: string },
}

export type Decision = {
	result: string,
	scopeSatisfied: boolean,
	activationAcceptable: boolean,
	scopeCoversWholeMatrix: boolean,
	inScopeCheckCount: number,
	outOfScopeCheckCount: number,
	invalidReasons: { string },
	missingEvidence: { string },
	failures: { string },
	nonBlockingFindings: { string },
}

local IDENTITY_HEX_LENGTHS = table.freeze({
	repositoryCommit = 40,
	rollbackCheckpointCommit = 40,
	placeArtifactSha256 = 64,
})

local function append(target: { string }, message: string)
	table.insert(target, message)
end

local function sortedKeys(map: { [string]: any }): { string }
	local keys: { string } = {}
	for key in map do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

local function isHexOfLength(value: string, expectedLength: number): boolean
	return #value == expectedLength and string.match(value, "^[0-9a-fA-F]+$") ~= nil
end

local function decisionFor(invalid: { string }, missing: { string }, failures: { string }): string
	-- Precedence matches the V2.7 R1 evaluator: a malformed record is decided
	-- before an incomplete one, and an incomplete one before a defect, so a run
	-- can never be reported as a clean FAIL when its identity is unusable.
	if #invalid > 0 then
		return "INVALID"
	elseif #missing > 0 then
		return "PARTIAL"
	elseif #failures > 0 then
		return "FAIL"
	end
	return "PASS"
end

--[[
	`matrix` is `MainWorldAcceptanceMatrixConfig`, `scopeResolver` is
	`MainWorldAcceptanceScopeResolver`, and `mappedGroupIds` normally comes from
	`MainWorldRepresentationConfig.mappedStreamingGroupIds()`.
]]
function Evaluator.evaluate(matrix: any, scopeResolver: any, mappedGroupIds: { string }, input: any): Decision
	local invalid: { string } = {}
	local missing: { string } = {}
	local failures: { string } = {}
	local nonBlockingFindings: { string } = {}

	local scope = scopeResolver.resolveScope(matrix, mappedGroupIds)

	if type(input) ~= "table" then
		return table.freeze({
			result = "INVALID",
			scopeSatisfied = false,
			activationAcceptable = false,
			scopeCoversWholeMatrix = scope.coversWholeMatrix,
			inScopeCheckCount = #scope.inScopeCheckIds,
			outOfScopeCheckCount = #scope.outOfScopeCheckIds,
			invalidReasons = table.freeze({ "run record must be a table" }),
			missingEvidence = table.freeze({}),
			failures = table.freeze({}),
			nonBlockingFindings = table.freeze({}),
		})
	end

	-- Identity ------------------------------------------------------------
	local identity = input.identity
	if identity == nil then
		append(missing, "identity block is missing")
		identity = {}
	elseif type(identity) ~= "table" then
		append(invalid, "identity block must be a table")
		identity = {}
	end

	for _, field in matrix.RequiredRunIdentityFields do
		local recorded = identity[field]
		if recorded == nil or recorded == "" then
			append(missing, `run identity is missing {field}`)
		elseif type(recorded) ~= "string" then
			append(invalid, `run identity field {field} must be a string`)
		else
			local expectedHexLength = IDENTITY_HEX_LENGTHS[field]
			if expectedHexLength ~= nil and not isHexOfLength(recorded, expectedHexLength) then
				append(
					invalid,
					`run identity field {field} must be a {expectedHexLength}-character hexadecimal value`
				)
			end
		end
	end

	-- Results --------------------------------------------------------------
	local results = input.results
	if results == nil then
		append(missing, "results block is missing")
		results = {}
	elseif type(results) ~= "table" then
		append(invalid, "results block must be a table")
		results = {}
	end

	-- Sorted so a malformed record reports the same reasons in the same order
	-- on every machine.
	for _, checkId in sortedKeys(results) do
		local entry = scope.entryByCheckId[checkId]
		if entry == nil then
			append(invalid, `result recorded for unknown check {checkId}`)
		elseif not entry.inScope then
			-- The place holds no instance of that family, so the observation
			-- cannot have happened. Rejecting rather than ignoring stops
			-- unobservable content from accruing passes.
			append(
				invalid,
				`check {checkId} is out of scope for this build; unmapped: {table.concat(entry.missingGroupIds, ", ")}`
			)
		end
	end

	for _, checkId in scope.inScopeCheckIds do
		local status = results[checkId]
		local check = matrix.ChecksById[checkId]
		if status == nil then
			append(missing, `in-scope check {checkId} has no recorded result`)
		elseif type(status) ~= "string" or matrix.ResultStatuses[status] == nil then
			append(invalid, `in-scope check {checkId} recorded unknown status {tostring(status)}`)
		elseif status == matrix.ResultStatuses.Invalid then
			append(invalid, `check {checkId} was observed without complete run identity`)
		elseif status == matrix.ResultStatuses.NotRun then
			append(missing, `in-scope check {checkId} was not run`)
		elseif status == matrix.ResultStatuses.Blocked then
			-- A tooling/transport failure is not a runtime defect. It leaves the
			-- run incomplete rather than failed.
			append(missing, `in-scope check {checkId} was blocked by evidence transport`)
		elseif status == matrix.ResultStatuses.Fail then
			if check.blocking then
				append(failures, `blocking check {checkId} failed`)
			else
				-- Recorded so it reaches the packet, but the matrix does not let
				-- a non-blocking result gate acceptance.
				append(nonBlockingFindings, `non-blocking check {checkId} failed`)
			end
		end
	end

	local result = decisionFor(invalid, missing, failures)

	-- Activation is never decided here. The full matrix keeps its own gate, so a
	-- scoped PASS leaves Main World acceptance exactly as closed as it was.
	local activationAcceptable = false
	if type(input.identity) == "table" and type(input.results) == "table" then
		activationAcceptable = matrix.isActivationAcceptable(input)
	end

	return table.freeze({
		result = result,
		scopeSatisfied = result == "PASS",
		activationAcceptable = activationAcceptable,
		scopeCoversWholeMatrix = scope.coversWholeMatrix,
		inScopeCheckCount = #scope.inScopeCheckIds,
		outOfScopeCheckCount = #scope.outOfScopeCheckIds,
		invalidReasons = table.freeze(invalid),
		missingEvidence = table.freeze(missing),
		failures = table.freeze(failures),
		nonBlockingFindings = table.freeze(nonBlockingFindings),
	})
end

-- A blank record for the current derived scope. Generated rather than committed
-- as a static template so it cannot drift when a streaming group is admitted.
function Evaluator.blankRunRecord(matrix: any, scopeResolver: any, mappedGroupIds: { string }): RunRecord
	local scope = scopeResolver.resolveScope(matrix, mappedGroupIds)

	local identity: { [string]: string } = {}
	for _, field in matrix.RequiredRunIdentityFields do
		identity[field] = ""
	end

	local results: { [string]: string } = {}
	for _, checkId in scope.inScopeCheckIds do
		results[checkId] = matrix.ResultStatuses.NotRun
	end

	return {
		identity = identity,
		results = results,
	}
end

return table.freeze(Evaluator)
