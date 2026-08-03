--!strict

--[[
	P10-0104 bounded per-operative contribution record and the one authored result
	snapshot.

	Contribution facts are recorded during the operation by the owners that already
	observe the confirmed events — the combat runtime (kills, damage, boss exposure
	hits), the revive session owner, the mission director (objective contribution),
	and the class owner. Nothing here is client-reported, and recording is
	deliberately inert authority: this module cannot damage, heal, kill, complete an
	objective, spend a resource, or resolve an operation. It only counts what an
	authoritative owner has already committed.

	At the single terminal boundary the mission director calls `commitResult` with
	the squad-level operation facts it owns; this module freezes them together with
	the per-operative record and the P3 survival state into one validated
	`SafeMatchResultSnapshot`. RPG-0112 adds the completed run build to the same
	snapshot — the relics each operative finished holding and the squad Field
	Upgrade stacks — pushed by the run-build owner rather than read out of RPG
	state here. The snapshot represents no XP, rank, or unlock — P11 owns those and
	reads these facts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchResultContracts = require(ReplicatedStorage.Shared.Mission.MatchResultContracts)

type SafeContributionSnapshot = MatchResultContracts.SafeContributionSnapshot
type SafeMatchResultSnapshot = MatchResultContracts.SafeMatchResultSnapshot

-- Squad-level operation facts the mission director owns and hands over once.
export type OperationResultFacts = {
	operationId: string,
	outcomeId: string,
	causeId: string,
	durationSeconds: number,
	phaseReachedId: string,
	objectivesCompleted: number,
	bossDefeated: boolean,
	wavesSurvived: number,
}

type ContributionRecord = {
	equippedRelicIds: { string },
	kills: number,
	damageDealt: number,
	revivesPerformed: number,
	objectivesContributed: number,
	classActionsCommitted: number,
	bossExposureHits: number,
}

local MatchResultService = {}

-- The record is bounded in both dimensions: how many operatives it will ever
-- track, and how high any single counter may climb. Neither is a gameplay limit;
-- both stop a long or adversarial operation from growing server state without end.
-- The operative ceiling deliberately exceeds the current four-operative squad so
-- no fixed-four assumption is baked in here (P12-0107).
local MAXIMUM_TRACKED_OPERATIVES = 8
local MAXIMUM_COUNTER_VALUE = 1e9

local started = false
local recordsByOperativeEntityId: { [string]: ContributionRecord } = {}
local trackedOperativeOrder: { string } = {}
local resultSnapshot: SafeMatchResultSnapshot? = nil
local squadUpgradeStacks: { MatchResultContracts.SafeUpgradeStackSnapshot } = table.freeze({})

local function isRecordableId(operativeEntityId: unknown): boolean
	return type(operativeEntityId) == "string" and operativeEntityId ~= "" and #operativeEntityId <= 240
end

local function isRecordableAmount(amount: unknown): boolean
	return type(amount) == "number" and amount == amount and amount ~= math.huge and amount > 0 and amount % 1 == 0
end

--[[
	Returns the operative's record, creating it on first contribution. Returns nil
	once the operation is stopped, once the result is frozen, or beyond the tracked
	population ceiling — a late or unknown identity is dropped rather than growing
	the record.
]]
local function recordFor(operativeEntityId: string): ContributionRecord?
	if not started or resultSnapshot ~= nil or not isRecordableId(operativeEntityId) then
		return nil
	end
	local existing = recordsByOperativeEntityId[operativeEntityId]
	if existing ~= nil then
		return existing
	end
	if #trackedOperativeOrder >= MAXIMUM_TRACKED_OPERATIVES then
		return nil
	end
	local created: ContributionRecord = {
		equippedRelicIds = {},
		kills = 0,
		damageDealt = 0,
		revivesPerformed = 0,
		objectivesContributed = 0,
		classActionsCommitted = 0,
		bossExposureHits = 0,
	}
	recordsByOperativeEntityId[operativeEntityId] = created
	table.insert(trackedOperativeOrder, operativeEntityId)
	return created
end

local function add(operativeEntityId: string, field: string, amount: number)
	if not isRecordableAmount(amount) then
		return
	end
	local record = recordFor(operativeEntityId)
	if record == nil then
		return
	end
	local recordAsAny = record :: any
	recordAsAny[field] = math.min(MAXIMUM_COUNTER_VALUE, recordAsAny[field] + amount)
end

function MatchResultService.recordKills(operativeEntityId: string, killCount: number)
	add(operativeEntityId, "kills", killCount)
end

function MatchResultService.recordDamageDealt(operativeEntityId: string, damageAmount: number)
	add(operativeEntityId, "damageDealt", damageAmount)
end

function MatchResultService.recordBossExposureHit(operativeEntityId: string)
	add(operativeEntityId, "bossExposureHits", 1)
end

function MatchResultService.recordRevivePerformed(operativeEntityId: string)
	add(operativeEntityId, "revivesPerformed", 1)
end

function MatchResultService.recordObjectiveContribution(operativeEntityId: string)
	add(operativeEntityId, "objectivesContributed", 1)
end

function MatchResultService.recordClassActionCommitted(operativeEntityId: string)
	add(operativeEntityId, "classActionsCommitted", 1)
end

--[[
	RPG-0112: the run build the operative finished with. The run-build owner pushes
	it whenever an equipped relic changes, so a disconnect cannot lose it and the
	ledger never has to reach into RPG state. The list replaces rather than
	accumulates — it is a snapshot of the slots, not a history.
]]
function MatchResultService.recordEquippedRelics(operativeEntityId: string, relicIds: { string })
	if type(relicIds) ~= "table" then
		return
	end
	local record = recordFor(operativeEntityId)
	if record == nil then
		return
	end
	local copied = {}
	for _, relicId in relicIds do
		if type(relicId) == "string" and relicId ~= "" then
			table.insert(copied, relicId)
		end
	end
	record.equippedRelicIds = copied
end

--[[
	RPG-0112: the squad Field Upgrades the run finished with, pushed by the same
	owner when a selection commits. Squad-level, so it is stored once rather than
	per operative.
]]
function MatchResultService.recordSquadUpgradeStacks(upgradeStacks: { [string]: number })
	if not started or resultSnapshot ~= nil or type(upgradeStacks) ~= "table" then
		return
	end
	local entries = {}
	for upgradeId, stacks in upgradeStacks do
		if
			type(upgradeId) == "string"
			and upgradeId ~= ""
			and type(stacks) == "number"
			and stacks == stacks
			and stacks > 0
			and stacks % 1 == 0
		then
			table.insert(entries, { upgradeId = upgradeId, stacks = stacks })
		end
	end
	-- Stable order so the summary reads identically for every operative.
	table.sort(entries, function(left, right)
		return left.upgradeId < right.upgradeId
	end)
	local frozen = {}
	for _, entry in entries do
		table.insert(frozen, table.freeze(entry))
	end
	squadUpgradeStacks = table.freeze(frozen)
end

-- The operative's life state at resolution, read from the P3 owner. An operative
-- who has already left the roster is reported Dead: they did not walk out.
local function survivalStateIdFor(operativeEntityId: string): string
	local didRead, read = pcall(function()
		-- Resolve this owner only when the operation ends. Loading it at module
		-- scope closes a cycle through OperativeLifeService ->
		-- RelicModifierService -> RunBuildService -> MatchResultService and
		-- prevents the entire server bootstrap from starting.
		local OperativeLifeService = require(script.Parent.OperativeLifeService)
		return OperativeLifeService.readByOperativeEntityId(operativeEntityId)
	end)
	if not didRead or type(read) ~= "table" or type(read.snapshot) ~= "table" then
		return "Dead"
	end
	return read.snapshot.lifeStateId
end

local function buildContributions(): { SafeContributionSnapshot }
	local contributions = {}
	for _, operativeEntityId in trackedOperativeOrder do
		local record = recordsByOperativeEntityId[operativeEntityId]
		if record == nil then
			continue
		end
		table.insert(
			contributions,
			table.freeze({
				operativeEntityId = operativeEntityId,
				kills = record.kills,
				damageDealt = record.damageDealt,
				revivesPerformed = record.revivesPerformed,
				objectivesContributed = record.objectivesContributed,
				classActionsCommitted = record.classActionsCommitted,
				bossExposureHits = record.bossExposureHits,
				survivalStateId = survivalStateIdFor(operativeEntityId),
				equippedRelicIds = table.freeze(table.clone(record.equippedRelicIds)),
			}) :: SafeContributionSnapshot
		)
	end
	return table.freeze(contributions)
end

--[[
	Freezes the one result snapshot for this operation. First commit wins: a second
	call is rejected, so the terminal boundary staying single is preserved here too.
	An invalid snapshot is refused rather than published.
]]
function MatchResultService.commitResult(facts: OperationResultFacts): boolean
	if not started or resultSnapshot ~= nil or type(facts) ~= "table" then
		return false
	end
	local candidate = table.freeze({
		operationId = facts.operationId,
		outcomeId = facts.outcomeId,
		causeId = facts.causeId,
		durationSeconds = facts.durationSeconds,
		phaseReachedId = facts.phaseReachedId,
		objectivesCompleted = facts.objectivesCompleted,
		bossDefeated = facts.bossDefeated,
		wavesSurvived = facts.wavesSurvived,
		contributions = buildContributions(),
		upgradeStacks = squadUpgradeStacks,
	}) :: SafeMatchResultSnapshot
	if not MatchResultContracts.validateSafeMatchResultSnapshot(candidate) then
		return false
	end
	resultSnapshot = candidate
	return true
end

-- The frozen result, or nil while the operation is unresolved.
function MatchResultService.readSafeResultSnapshot(): SafeMatchResultSnapshot?
	return resultSnapshot
end

-- Live contribution facts for the operatives tracked so far. Used by validation
-- and by the result owner; it exposes copies only.
function MatchResultService.readContributions(): { SafeContributionSnapshot }
	return buildContributions()
end

function MatchResultService.start()
	if started then
		return
	end
	started = true
	table.clear(recordsByOperativeEntityId)
	table.clear(trackedOperativeOrder)
	squadUpgradeStacks = table.freeze({})
	resultSnapshot = nil
end

function MatchResultService.stop()
	if not started then
		return
	end
	started = false
	table.clear(recordsByOperativeEntityId)
	table.clear(trackedOperativeOrder)
	squadUpgradeStacks = table.freeze({})
	resultSnapshot = nil
end

return table.freeze(MatchResultService)
