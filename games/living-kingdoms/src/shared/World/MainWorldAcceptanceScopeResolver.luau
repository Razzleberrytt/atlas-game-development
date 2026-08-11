--!strict

--[[
	Decides which BA-014 acceptance checks the *currently mapped* dedicated Main
	World can actually answer.

	The BA-014 matrix defines acceptance for the whole Main World: its 31 checks
	span all five BA-011 streaming groups. The dedicated place today maps only
	the hub core and the bounded primary route, so a check that depends on
	atmosphere, resources or structures has no content to observe. Running it
	would produce a result about nothing.

	This resolver partitions the matrix against mapped-group truth so the first
	evidence pass has an exact derived worklist instead of a flat 31-row sheet,
	and so a partial run can be recorded honestly rather than by leaving
	unobservable checks to look merely unrun.

	It measures nothing and relaxes nothing. Scope narrows *which* checks a run
	is allowed to record; it never lowers a threshold, never converts a missing
	observation into a pass, and never authorizes activation — a scoped pass
	leaves the full-matrix gate exactly where it was.

	Inputs are injected so this stays a pure module testable under Lune.
]]

export type Check = {
	id: string,
	blocking: boolean,
	streamingGroupIds: { string },
}

export type Matrix = {
	Checks: { Check },
	ChecksById: { [string]: Check },
	ResultStatuses: { [string]: string },
	RequiredRunIdentityFields: { string },
	evaluateRun: (run: RunRecord) -> { accepted: boolean, reasons: { string } },
}

export type RunRecord = {
	identity: { [string]: string },
	results: { [string]: string },
}

export type ScopeEntry = {
	checkId: string,
	inScope: boolean,
	blocking: boolean,
	-- Groups the check depends on that the place does not map. Empty when in scope.
	missingGroupIds: { string },
}

export type Scope = {
	mappedGroupIds: { string },
	inScopeCheckIds: { string },
	outOfScopeCheckIds: { string },
	blockingInScopeCheckIds: { string },
	entryByCheckId: { [string]: ScopeEntry },
	coversWholeMatrix: boolean,
}

export type ScopedEvaluation = {
	-- The scoped worklist is complete and every blocking in-scope check passed.
	scopeSatisfied: boolean,
	-- Whether the full BA-014 gate accepts the run. Always decided by the matrix
	-- itself, so a scoped pass can never be mistaken for Main World acceptance.
	activationAcceptable: boolean,
	reasons: { string },
}

local MainWorldAcceptanceScopeResolver = {}

local function sortedKeys(map: { [string]: any }): { string }
	local keys: { string } = {}
	for key in map do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

-- A check is in scope when every streaming group it depends on is mapped. A
-- check that names no group (an artifact-completeness check, for example) does
-- not depend on represented content and is always in scope.
function MainWorldAcceptanceScopeResolver.resolveScope(matrix: Matrix, mappedGroupIds: { string }): Scope
	local mapped: { [string]: boolean } = {}
	for _, groupId in mappedGroupIds do
		mapped[groupId] = true
	end

	local inScopeCheckIds: { string } = {}
	local outOfScopeCheckIds: { string } = {}
	local blockingInScopeCheckIds: { string } = {}
	local entryByCheckId: { [string]: ScopeEntry } = {}

	-- Matrix order is preserved so a derived worklist reads in the same order an
	-- operator works the sheet.
	for _, check in matrix.Checks do
		local missingGroupIds: { string } = {}
		for _, groupId in check.streamingGroupIds do
			if not mapped[groupId] then
				table.insert(missingGroupIds, groupId)
			end
		end

		local inScope = #missingGroupIds == 0
		entryByCheckId[check.id] = table.freeze({
			checkId = check.id,
			inScope = inScope,
			blocking = check.blocking,
			missingGroupIds = table.freeze(missingGroupIds),
		})

		if inScope then
			table.insert(inScopeCheckIds, check.id)
			if check.blocking then
				table.insert(blockingInScopeCheckIds, check.id)
			end
		else
			table.insert(outOfScopeCheckIds, check.id)
		end
	end

	return table.freeze({
		mappedGroupIds = table.freeze(table.clone(mappedGroupIds)),
		inScopeCheckIds = table.freeze(inScopeCheckIds),
		outOfScopeCheckIds = table.freeze(outOfScopeCheckIds),
		blockingInScopeCheckIds = table.freeze(blockingInScopeCheckIds),
		entryByCheckId = table.freeze(entryByCheckId),
		coversWholeMatrix = #outOfScopeCheckIds == 0,
	})
end

function MainWorldAcceptanceScopeResolver.isCheckInScope(scope: Scope, checkId: string): boolean
	local entry = scope.entryByCheckId[checkId]
	return entry ~= nil and entry.inScope
end

--[[
	Decides a run recorded against a scoped worklist.

	A scoped run is satisfied when its identity is complete, every in-scope check
	carries a known recorded status, and every blocking in-scope check recorded
	`Pass`.

	A result recorded for an out-of-scope check is rejected rather than ignored.
	The place contains no instance of that family, so an observation of it cannot
	have happened; silently accepting it would let unobservable content accrue
	passes. Such a check may still be captured informationally, but it is not a
	BA-014 result until its content is mapped.
]]
function MainWorldAcceptanceScopeResolver.evaluateScopedRun(
	matrix: Matrix,
	mappedGroupIds: { string },
	run: RunRecord
): ScopedEvaluation
	local scope = MainWorldAcceptanceScopeResolver.resolveScope(matrix, mappedGroupIds)
	local reasons: { string } = {}

	local identity = run.identity or {}
	for _, field in matrix.RequiredRunIdentityFields do
		local recorded = identity[field]
		if recorded == nil or recorded == "" then
			table.insert(reasons, `run identity is missing {field}`)
		end
	end

	local results = run.results or {}
	-- Sorted so an unknown or out-of-scope result reports deterministically.
	for _, checkId in sortedKeys(results) do
		local entry = scope.entryByCheckId[checkId]
		if entry == nil then
			table.insert(reasons, `result recorded for unknown check {checkId}`)
		elseif not entry.inScope then
			table.insert(
				reasons,
				`check {checkId} is out of scope for this build; unmapped: {table.concat(entry.missingGroupIds, ", ")}`
			)
		end
	end

	for _, checkId in scope.inScopeCheckIds do
		local status = results[checkId]
		local check = matrix.ChecksById[checkId]
		if status == nil then
			table.insert(reasons, `in-scope check {checkId} has no recorded result`)
		elseif matrix.ResultStatuses[status] == nil then
			table.insert(reasons, `in-scope check {checkId} recorded unknown status {status}`)
		elseif check.blocking and status ~= matrix.ResultStatuses.Pass then
			table.insert(reasons, `blocking in-scope check {checkId} recorded {status}`)
		end
	end

	-- Activation is never decided here. The full matrix keeps its own gate, so a
	-- satisfied partial scope leaves Main World acceptance exactly as closed as
	-- it was before the run.
	local activationAcceptable = matrix.evaluateRun(run).accepted

	return table.freeze({
		scopeSatisfied = #reasons == 0,
		activationAcceptable = activationAcceptable,
		reasons = table.freeze(reasons),
	})
end

return table.freeze(MainWorldAcceptanceScopeResolver)
