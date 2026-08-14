--!strict

--[[
	Patch 0.7 #85. Every reason the persistence layer can return must be
	classified, because callers branch on the classification rather than on the
	string: transient means retry, operational means the request was understood
	and declined, corrupt means quarantine.

	An unclassified reason falls through to corrupt, which is the safe default
	for something genuinely unknown and the wrong answer for a reason someone
	simply forgot to add. This audit reads the reasons out of the sources rather
	than from a hand-kept list, so forgetting is what fails.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function check(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local recovery =
	luau.load(fs.readFile("games/living-kingdoms/src/shared/Persistence/InventoryRecoveryContracts.luau"), {
		debugName = "InventoryRecoveryContracts",
		injectGlobals = true,
	})()

local SOURCES = {
	"games/living-kingdoms/src/server/Systems/PlayerInventoryPersistenceService.luau",
	"games/living-kingdoms/src/server/Systems/InventorySessionLeaseService.luau",
	"games/living-kingdoms/src/server/Systems/InventoryLiveService.luau",
	"games/living-kingdoms/src/shared/Persistence/InventoryDismantleResolver.luau",
}

--[[
	Success reasons describe what happened, not what went wrong, so they are not
	failure classifications. They are listed explicitly rather than inferred, so
	adding a success reason is a deliberate act and a *failure* reason cannot be
	hidden here by accident.
]]
local SUCCESS_REASON_IDS = table.freeze({
	LoadedRecord = true,
	MigratedRecord = true,
	CreatedNewRecord = true,
	RecordReleased = true,
	NoRecordHeld = true,
	RewardApplied = true,
	ItemDismantled = true,
	InventoryDisclosed = true,
	LeaseAcquired = true,
	LeaseRenewed = true,
	LeaseReleased = true,
	Compared = true,
})

local emitted: { [string]: string } = {}
for _, path in SOURCES do
	local source = fs.readFile(path)
	for reasonId in string.gmatch(source, 'ReasonId = "([A-Za-z]+)"') do
		emitted[reasonId] = path
	end
	for reasonId in string.gmatch(source, 'result%(false, "([A-Za-z]+)"') do
		emitted[reasonId] = path
	end
	for reasonId in string.gmatch(source, 'return nil, false, "([A-Za-z]+)"') do
		emitted[reasonId] = path
	end
	for reasonId in string.gmatch(source, 'reject%("([A-Za-z]+)"%)') do
		emitted[reasonId] = path
	end
end

local emittedCount = 0
for _ in emitted do
	emittedCount += 1
end
check(emittedCount >= 20, "the audit must actually be finding reasons, found " .. tostring(emittedCount))

local unclassified = {}
for reasonId, path in emitted do
	if SUCCESS_REASON_IDS[reasonId] ~= true and not recovery.isClassified(reasonId) then
		table.insert(unclassified, string.format("%s (%s)", reasonId, path))
	end
end
table.sort(unclassified)
check(
	#unclassified == 0,
	"every persistence reason must be classified; unclassified: " .. table.concat(unclassified, ", ")
)

-- The three classes must stay meaningfully distinct.
check(recovery.classify("LoadFailed") == "Transient", "a failed read is retryable")
check(recovery.classify("MigrationRaceDetected") == "Transient", "a lost migration race is retryable")
check(recovery.classify("RewardAlreadyApplied") == "Operational", "a replay is a refusal, not damage")
check(recovery.classify("RecordSizeExceeded") == "Operational", "an oversized record is a bound, not damage")
check(recovery.classify("InvalidSavedRecord") == "Corrupt", "an unparseable record is damage")

--[[
	Only corrupt reasons may quarantine. Quarantining an ordinary refusal would
	copy a perfectly good record aside as damaged, and quarantining a transient
	failure would do it for a blip.
]]
for _, reasonId in { "LoadFailed", "MigrationRaceDetected", "RewardAlreadyApplied", "RecordSizeExceeded" } do
	check(recovery.classify(reasonId) ~= "Corrupt", "a healthy record must never be quarantined for: " .. reasonId)
end

check(not recovery.isRecoverable("RecordSizeExceeded"), "retrying an oversized write fails identically")
check(recovery.isRecoverable("MigrationRaceDetected"), "a lost race is fixed by the retry it must be allowed")
check(not recovery.isClassified("SomethingNobodyDeclared"), "an undeclared reason must read as unclassified")
check(recovery.classify("SomethingNobodyDeclared") == "Corrupt", "an undeclared reason must fail safe")

--[[
	A success reason must never appear in a failure table. If one did, a healthy
	outcome would be classified as damage and could trigger quarantine.

	`ItemEquipped` is deliberately excluded from the success list: it is genuinely
	both, naming a successful equip and a refused dismantle. That overload is a
	real diagnostic weakness -- a caller branching on the string alone cannot tell
	which happened -- but it is the established reason id, so it is classified as
	the refusal it also is rather than renamed underneath existing consumers.
]]
for successReasonId in SUCCESS_REASON_IDS do
	check(
		not recovery.isClassified(successReasonId),
		"a success reason must not be classified as a failure: " .. successReasonId
	)
end

print(string.format("PersistenceReasonClassificationAudit: %d reasons emitted, all classified", emittedCount))
