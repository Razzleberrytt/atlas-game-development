--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Evaluator = luau.load(
	fs.readFile("games/living-kingdoms/tools/evidence/V27R1EvidenceEvaluator.luau"),
	{ injectGlobals = true }
)()

local function capture(messages: number, revision: number, broadCount: number?)
	local stillEnabledBroad = {}
	for index = 1, broadCount or 0 do
		table.insert(stillEnabledBroad, { highlight = "Broad" .. tostring(index) })
	end
	return {
		schema = "LK_V27_R1_CAPTURE_V1",
		listener = {
			bound = true,
			messagesReceived = messages,
			invalidMessages = 0,
			lastRevision = revision,
		},
		highlightGuard = {
			active = true,
			rejectedCount = 0,
		},
		highlightScan = {
			stillEnabledBroad = stillEnabledBroad,
		},
	}
end

local function validInput()
	return {
		identity = {
			sourceCommit = "2c870d270b96064c9a06343cc088b251299373f4",
			artifactId = 9009926429,
			artifactDigest = "sha256:587ccc2974f8188bde34a0a757213efb4b9f72e68e940db4615232cace28bf89",
		},
		firstCapture = capture(2, 2),
		finalCapture = capture(120, 120),
		manual = {
			queueDiscardWarningCount = 0,
			startupRegression = false,
			narrowEnemyHighlightWorks = true,
			broadWorldWashAppears = false,
			otherNewClientErrorCount = 0,
		},
	}
end

local pass = Evaluator.evaluate(validInput())
assert(pass.result == "PASS", "complete passing evidence must evaluate PASS")
assert(#pass.invalidReasons == 0 and #pass.missingEvidence == 0 and #pass.failures == 0)

local invalidIdentity = validInput()
invalidIdentity.identity.artifactId = 1
local invalid = Evaluator.evaluate(invalidIdentity)
assert(invalid.result == "INVALID", "wrong canonical artifact must invalidate the packet")
assert(#invalid.invalidReasons == 1)

local partialInput = validInput()
partialInput.manual.narrowEnemyHighlightWorks = nil
local partial = Evaluator.evaluate(partialInput)
assert(partial.result == "PARTIAL", "missing required observation must evaluate PARTIAL")
assert(#partial.missingEvidence == 1)

local failedInput = validInput()
failedInput.finalCapture.listener.messagesReceived = failedInput.firstCapture.listener.messagesReceived
failedInput.finalCapture.highlightScan.stillEnabledBroad = { { highlight = "Workspace.BadHighlight" } }
failedInput.manual.queueDiscardWarningCount = 1
failedInput.manual.broadWorldWashAppears = true
local failed = Evaluator.evaluate(failedInput)
assert(failed.result == "FAIL", "complete but failing evidence must evaluate FAIL")
assert(#failed.failures == 4, "expected four independent R1 acceptance failures")

local badSchemaInput = validInput()
badSchemaInput.finalCapture.schema = "UNKNOWN"
local badSchema = Evaluator.evaluate(badSchemaInput)
assert(badSchema.result == "INVALID", "capture schema mismatch must invalidate the packet")

print("V27R1EvidenceEvaluator: PASS/FAIL/PARTIAL/INVALID acceptance semantics passed")
