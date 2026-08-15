--!strict

-- Pure authoritative registry for active expedition instance ownership.
-- It deliberately owns no Roblox Instances; rendering/runtime services attach
-- their own roots to the stable run records returned here.

export type InstanceRecord = {
	RunId: string,
	Seed: number,
	PlanIdentity: string,
	ReproductionKey: string,
	SlotIndex: number,
	OriginX: number,
	OriginZ: number,
}

export type Registry = {
	create: (self: Registry, runId: string, seed: number, planIdentity: string, reproductionKey: string?) -> any,
	get: (self: Registry, runId: string) -> InstanceRecord?,
	remove: (self: Registry, runId: string) -> any,
	list: (self: Registry) -> { InstanceRecord },
	count: (self: Registry) -> number,
	reset: (self: Registry) -> (),
}

local DEFAULT_MAX_ACTIVE = 16
local SLOT_SPACING = 1_024
local SLOT_COLUMNS = 4
local Registry = {}
Registry.__index = Registry

local function response(accepted: boolean, reasonId: string, record: InstanceRecord?): any
	return table.freeze({ Accepted = accepted, ReasonId = reasonId, Record = record })
end

local function validRunId(runId: any): boolean
	return type(runId) == "string" and #runId >= 8 and #runId <= 96 and string.match(runId, "^%s*$") == nil
end

local function validSeed(seed: any): boolean
	return type(seed) == "number" and seed % 1 == 0
end

local function validIdentity(value: any): boolean
	return type(value) == "string" and #value > 0 and #value <= 256
end

local function slotOrigin(slotIndex: number): (number, number)
	local zeroBased = slotIndex - 1
	local column = zeroBased % SLOT_COLUMNS
	local row = math.floor(zeroBased / SLOT_COLUMNS)
	return column * SLOT_SPACING, row * SLOT_SPACING
end

function Registry.new(maxActive: number?): Registry
	local resolvedMax = maxActive or DEFAULT_MAX_ACTIVE
	assert(
		type(resolvedMax) == "number" and resolvedMax % 1 == 0 and resolvedMax >= 1,
		"maxActive must be a positive integer"
	)
	local self = setmetatable({
		_maxActive = resolvedMax,
		_byRunId = {},
		_slotOwners = {},
		_count = 0,
	}, Registry)
	return self :: any
end

function Registry:create(runId: string, seed: number, planIdentity: string, reproductionKey: string?): any
	if not validRunId(runId) then
		return response(false, "InvalidRunId", nil)
	end
	if not validSeed(seed) then
		return response(false, "InvalidSeed", nil)
	end
	if not validIdentity(planIdentity) then
		return response(false, "InvalidPlanIdentity", nil)
	end
	local resolvedReproductionKey = reproductionKey or `run={runId}|seed={seed}|plan={planIdentity}`
	if not validIdentity(resolvedReproductionKey) then
		return response(false, "InvalidReproductionKey", nil)
	end

	local existing = self._byRunId[runId]
	if existing ~= nil then
		if existing.Seed == seed and existing.PlanIdentity == planIdentity then
			return response(false, "RunAlreadyRegistered", existing)
		end
		return response(false, "ConflictingRunOwnership", existing)
	end
	if self._count >= self._maxActive then
		return response(false, "InstanceCapacityReached", nil)
	end

	local slotIndex = nil
	for candidate = 1, self._maxActive do
		if self._slotOwners[candidate] == nil then
			slotIndex = candidate
			break
		end
	end
	assert(slotIndex ~= nil, "registry capacity bookkeeping drifted")
	local originX, originZ = slotOrigin(slotIndex)
	local record = table.freeze({
		RunId = runId,
		Seed = seed,
		PlanIdentity = planIdentity,
		ReproductionKey = resolvedReproductionKey,
		SlotIndex = slotIndex,
		OriginX = originX,
		OriginZ = originZ,
	})
	self._byRunId[runId] = record
	self._slotOwners[slotIndex] = runId
	self._count += 1
	return response(true, "RunRegistered", record)
end

function Registry:get(runId: string): InstanceRecord?
	return self._byRunId[runId]
end

function Registry:remove(runId: string): any
	local record = self._byRunId[runId]
	if record == nil then
		return response(false, "RunNotRegistered", nil)
	end
	self._byRunId[runId] = nil
	self._slotOwners[record.SlotIndex] = nil
	self._count -= 1
	return response(true, "RunRemoved", record)
end

function Registry:list(): { InstanceRecord }
	local records = {}
	for _, record in self._byRunId do
		table.insert(records, record)
	end
	table.sort(records, function(a, b)
		return a.SlotIndex < b.SlotIndex
	end)
	return table.freeze(records)
end

function Registry:count(): number
	return self._count
end

function Registry:reset()
	table.clear(self._byRunId)
	table.clear(self._slotOwners)
	self._count = 0
end

return table.freeze({
	new = Registry.new,
	DefaultMaxActive = DEFAULT_MAX_ACTIVE,
	SlotSpacing = SLOT_SPACING,
})
