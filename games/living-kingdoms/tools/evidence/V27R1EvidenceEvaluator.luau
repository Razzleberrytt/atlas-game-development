--!strict

--[[
	Deterministic evaluator for the Blueprint v2.7 R1 runtime packet.

	This module is tooling only and lives outside src/. It turns the two
	LK_V27_R1_CAPTURE records plus the small set of operator observations into a
	PASS / FAIL / PARTIAL / INVALID decision. It does not replace Studio evidence;
	it only makes the acceptance rules explicit and repeatable.
]]

local Evaluator = {}

local EXPECTED_SCHEMA = "LK_V27_R1_CAPTURE_V1"
local EXPECTED_SOURCE_COMMIT = "2c870d270b96064c9a06343cc088b251299373f4"
local EXPECTED_ARTIFACT_ID = 9009926429
local EXPECTED_ARTIFACT_DIGEST = "sha256:587ccc2974f8188bde34a0a757213efb4b9f72e68e940db4615232cace28bf89"

local function append(target: { string }, message: string)
	table.insert(target, message)
end

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function readCaptureField(capture: any, section: string, field: string): any
	if type(capture) ~= "table" then
		return nil
	end
	local nested = capture[section]
	if type(nested) ~= "table" then
		return nil
	end
	return nested[field]
end

local function validateCaptureShape(label: string, capture: any, invalid: { string }, missing: { string }): boolean
	if capture == nil then
		append(missing, label .. " capture is missing")
		return false
	end
	if type(capture) ~= "table" then
		append(invalid, label .. " capture must be a table")
		return false
	end
	if capture.schema ~= EXPECTED_SCHEMA then
		append(invalid, label .. " capture schema must be " .. EXPECTED_SCHEMA)
		return false
	end
	for _, section in { "listener", "highlightGuard", "highlightScan" } do
		if type(capture[section]) ~= "table" then
			append(invalid, label .. " capture is missing table section " .. section)
			return false
		end
	end
	return true
end

local function requireManualField(
	manual: any,
	field: string,
	expectedType: string,
	missing: { string },
	invalid: { string }
): any
	if type(manual) ~= "table" or manual[field] == nil then
		append(missing, "manual observation " .. field .. " is missing")
		return nil
	end
	local value = manual[field]
	if type(value) ~= expectedType then
		append(invalid, "manual observation " .. field .. " must be " .. expectedType)
		return nil
	end
	return value
end

function Evaluator.evaluate(input: any)
	local invalid = {}
	local missing = {}
	local failures = {}

	if type(input) ~= "table" then
		return table.freeze({
			result = "INVALID",
			invalidReasons = table.freeze({ "input must be a table" }),
			missingEvidence = table.freeze({}),
			failures = table.freeze({}),
		})
	end

	local identity = input.identity
	if type(identity) ~= "table" then
		append(missing, "identity block is missing")
	else
		if identity.sourceCommit == nil then
			append(missing, "identity.sourceCommit is missing")
		elseif identity.sourceCommit ~= EXPECTED_SOURCE_COMMIT then
			append(invalid, "source commit does not match the canonical R1 build")
		end
		if identity.artifactId == nil then
			append(missing, "identity.artifactId is missing")
		elseif identity.artifactId ~= EXPECTED_ARTIFACT_ID then
			append(invalid, "artifact ID does not match the canonical R1 build")
		end
		if identity.artifactDigest == nil then
			append(missing, "identity.artifactDigest is missing")
		elseif identity.artifactDigest ~= EXPECTED_ARTIFACT_DIGEST then
			append(invalid, "artifact digest does not match the canonical R1 build")
		end
	end

	local firstCapture = input.firstCapture
	local finalCapture = input.finalCapture
	local firstShapeValid = validateCaptureShape("first", firstCapture, invalid, missing)
	local finalShapeValid = validateCaptureShape("final", finalCapture, invalid, missing)

	if firstShapeValid then
		local firstBound = readCaptureField(firstCapture, "listener", "bound")
		if firstBound == nil then
			append(missing, "first capture listener.bound is missing")
		elseif firstBound ~= true then
			append(failures, "early state listener was not bound in the first capture")
		end

		local firstMessages = readCaptureField(firstCapture, "listener", "messagesReceived")
		if firstMessages ~= nil and not isFiniteNumber(firstMessages) then
			append(invalid, "first capture listener.messagesReceived must be numeric")
		end
		local firstRevision = readCaptureField(firstCapture, "listener", "lastRevision")
		if firstRevision ~= nil and not isFiniteNumber(firstRevision) then
			append(invalid, "first capture listener.lastRevision must be numeric when present")
		end
	end

	if finalShapeValid then
		local finalBound = readCaptureField(finalCapture, "listener", "bound")
		if finalBound == nil then
			append(missing, "final capture listener.bound is missing")
		elseif finalBound ~= true then
			append(failures, "early state listener was not bound in the final capture")
		end

		local finalMessages = readCaptureField(finalCapture, "listener", "messagesReceived")
		if finalMessages == nil then
			append(missing, "final capture listener.messagesReceived is missing")
		elseif not isFiniteNumber(finalMessages) then
			append(invalid, "final capture listener.messagesReceived must be numeric")
		elseif finalMessages <= 0 then
			append(failures, "no HordeNetwork.State messages were received")
		end

		local invalidMessages = readCaptureField(finalCapture, "listener", "invalidMessages")
		if invalidMessages == nil then
			append(missing, "final capture listener.invalidMessages is missing")
		elseif not isFiniteNumber(invalidMessages) then
			append(invalid, "final capture listener.invalidMessages must be numeric")
		elseif invalidMessages ~= 0 then
			append(failures, "invalid HordeNetwork.State messages were observed")
		end

		local finalRevision = readCaptureField(finalCapture, "listener", "lastRevision")
		if finalRevision == nil then
			append(missing, "final capture listener.lastRevision is missing")
		elseif not isFiniteNumber(finalRevision) then
			append(invalid, "final capture listener.lastRevision must be numeric")
		end

		local guardActive = readCaptureField(finalCapture, "highlightGuard", "active")
		if guardActive == nil then
			append(missing, "final capture highlightGuard.active is missing")
		elseif guardActive ~= true then
			append(failures, "broad Highlight guard was not active")
		end

		local stillEnabledBroad = readCaptureField(finalCapture, "highlightScan", "stillEnabledBroad")
		if stillEnabledBroad == nil then
			append(missing, "final capture highlightScan.stillEnabledBroad is missing")
		elseif type(stillEnabledBroad) ~= "table" then
			append(invalid, "final capture highlightScan.stillEnabledBroad must be a table")
		elseif #stillEnabledBroad > 0 then
			append(failures, "one or more broad Highlight targets remained enabled")
		end
	end

	if firstShapeValid and finalShapeValid then
		local firstMessages = readCaptureField(firstCapture, "listener", "messagesReceived")
		local finalMessages = readCaptureField(finalCapture, "listener", "messagesReceived")
		if isFiniteNumber(firstMessages) and isFiniteNumber(finalMessages) and finalMessages <= firstMessages then
			append(failures, "HordeNetwork.State received count did not increase between captures")
		end

		local firstRevision = readCaptureField(firstCapture, "listener", "lastRevision")
		local finalRevision = readCaptureField(finalCapture, "listener", "lastRevision")
		if isFiniteNumber(firstRevision) and isFiniteNumber(finalRevision) and finalRevision < firstRevision then
			append(failures, "HordeNetwork.State revision regressed between captures")
		end
	end

	local manual = input.manual
	local queueDiscardWarningCount = requireManualField(manual, "queueDiscardWarningCount", "number", missing, invalid)
	local startupRegression = requireManualField(manual, "startupRegression", "boolean", missing, invalid)
	local narrowEnemyHighlightWorks =
		requireManualField(manual, "narrowEnemyHighlightWorks", "boolean", missing, invalid)
	local broadWorldWashAppears = requireManualField(manual, "broadWorldWashAppears", "boolean", missing, invalid)
	local otherNewClientErrorCount = requireManualField(manual, "otherNewClientErrorCount", "number", missing, invalid)

	if isFiniteNumber(queueDiscardWarningCount) and queueDiscardWarningCount ~= 0 then
		append(failures, "HordeNetwork.State queue/discard warnings were observed")
	end
	if startupRegression == true then
		append(failures, "a startup regression was observed")
	end
	if narrowEnemyHighlightWorks == false then
		append(failures, "legitimate narrow enemy Highlight feedback did not work")
	end
	if broadWorldWashAppears == true then
		append(failures, "a broad world Highlight wash remained visible")
	end
	if isFiniteNumber(otherNewClientErrorCount) and otherNewClientErrorCount ~= 0 then
		append(failures, "new client errors attributable to the R1 slice were observed")
	end

	local result: string
	if #invalid > 0 then
		result = "INVALID"
	elseif #missing > 0 then
		result = "PARTIAL"
	elseif #failures > 0 then
		result = "FAIL"
	else
		result = "PASS"
	end

	return table.freeze({
		result = result,
		invalidReasons = table.freeze(invalid),
		missingEvidence = table.freeze(missing),
		failures = table.freeze(failures),
		expectedIdentity = table.freeze({
			sourceCommit = EXPECTED_SOURCE_COMMIT,
			artifactId = EXPECTED_ARTIFACT_ID,
			artifactDigest = EXPECTED_ARTIFACT_DIGEST,
		}),
	})
end

return table.freeze(Evaluator)
