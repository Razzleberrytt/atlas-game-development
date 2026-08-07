--!strict

-- Server-only bounded event journal for Studio/live defect capture. It stores
-- sanitized facts only and exposes no client networking surface.

export type Service = {
	record: (self: Service, eventId: string, fields: any?, atUnix: number) -> (),
	read: (self: Service) -> { any },
	clear: (self: Service) -> (),
	destroy: (self: Service) -> (),
}

local Service = {}
Service.__index = Service

local function copyFields(fields: any): any
	if type(fields) ~= "table" then
		return table.freeze({})
	end
	local safe = {}
	for key, value in fields do
		if
			type(key) == "string" and (type(value) == "string" or type(value) == "number" or type(value) == "boolean")
		then
			safe[key] = value
		end
	end
	return table.freeze(safe)
end

function Service.new(maximumEntries: number?): Service
	local maximum = maximumEntries or 200
	assert(type(maximum) == "number" and maximum >= 10 and maximum % 1 == 0, "invalid diagnostic capacity")
	return setmetatable({ _maximum = maximum, _entries = {}, _sequence = 0, _destroyed = false }, Service) :: any
end

function Service:record(eventId: string, fields: any?, atUnix: number)
	local selfAny = self :: any
	if selfAny._destroyed then
		return
	end
	assert(type(eventId) == "string" and #eventId >= 3 and #eventId <= 80, "invalid event id")
	assert(type(atUnix) == "number" and atUnix >= 0, "invalid timestamp")
	selfAny._sequence += 1
	table.insert(
		selfAny._entries,
		table.freeze({ Sequence = selfAny._sequence, EventId = eventId, AtUnix = atUnix, Fields = copyFields(fields) })
	)
	while #selfAny._entries > selfAny._maximum do
		table.remove(selfAny._entries, 1)
	end
end

function Service:read(): { any }
	local selfAny = self :: any
	if selfAny._destroyed then
		return {}
	end
	return table.freeze(table.clone(selfAny._entries))
end

function Service:clear()
	local selfAny = self :: any
	if selfAny._destroyed then
		return
	end
	table.clear(selfAny._entries)
end

function Service:destroy()
	local selfAny = self :: any
	if selfAny._destroyed then
		return
	end
	selfAny._destroyed = true
	table.clear(selfAny._entries)
end

return table.freeze(Service)
