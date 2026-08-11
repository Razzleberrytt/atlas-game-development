--!strict

--[[
	CLI for the BA-014 Main World acceptance run evaluator.

	Run from the repository root:

		# print a blank run record for the currently mapped build
		lune run games/living-kingdoms/tools/evidence/evaluate-ba014-run.luau

		# decide a filled-in run record
		lune run games/living-kingdoms/tools/evidence/evaluate-ba014-run.luau <record.json>

	The skeleton is generated from the committed contracts rather than kept as a
	static template, so it cannot drift when a streaming group is admitted.

	Exit codes: 0 for PASS, 1 for anything else, so an evidence step can be
	wired into a script without parsing the printed report.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")

local CONFIG_DIR = "games/living-kingdoms/src/shared/Config"
local RESOLVER_PATH = "games/living-kingdoms/src/shared/World/MainWorldAcceptanceScopeResolver.luau"
local EVALUATOR_PATH = "games/living-kingdoms/tools/evidence/MainWorldBa014RunEvaluator.luau"

local function loadModule(path: string, environment: any?): any
	local options: any = { debugName = path, injectGlobals = true }
	if environment ~= nil then
		options.environment = environment
	end
	return luau.load(fs.readFile(path), options)()
end

local representation = loadModule(`{CONFIG_DIR}/MainWorldRepresentationConfig.luau`)

-- The matrix requires the representation contract; hand it the real one so the
-- report can never be produced against a convenient stub.
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

local recordPath = process.args[1]

if recordPath == nil then
	local blank = evaluator.blankRunRecord(matrix, scopeResolver, mappedGroupIds)
	print(serde.encode("json", blank, true))
	return
end

if not fs.isFile(recordPath) then
	error(`run record not found: {recordPath}`)
end

local record = serde.decode("json", fs.readFile(recordPath))
local decision = evaluator.evaluate(matrix, scopeResolver, mappedGroupIds, record)

local function printSection(title: string, entries: { string })
	if #entries == 0 then
		return
	end
	print(`\n{title}:`)
	for _, entry in entries do
		print(`  - {entry}`)
	end
end

print(`BA-014 run record: {recordPath}`)
print(`mapped streaming groups: {table.concat(mappedGroupIds, ", ")}`)
print(`scope: {decision.inScopeCheckCount} in scope, {decision.outOfScopeCheckCount} out of scope`)
print(`result: {decision.result}`)

printSection("invalid", decision.invalidReasons)
printSection("missing evidence", decision.missingEvidence)
printSection("failures", decision.failures)
printSection("non-blocking findings", decision.nonBlockingFindings)

-- Stated on every run, including a PASS, so a scoped result is never filed as
-- Main World acceptance.
if not decision.scopeCoversWholeMatrix then
	print(
		`\nThis is a SCOPED result over {decision.inScopeCheckCount} of {#matrix.Checks} checks. `
			.. `{decision.outOfScopeCheckCount} checks cover streaming groups this build does not map.`
	)
end
print(`activation acceptable: {decision.activationAcceptable}`)
if decision.result == "PASS" and not decision.activationAcceptable then
	print("Patch 0.5 stays BUILT — VERIFICATION PENDING; full BA-014 acceptance remains gated.")
end

if decision.result ~= "PASS" then
	process.exit(1)
end
