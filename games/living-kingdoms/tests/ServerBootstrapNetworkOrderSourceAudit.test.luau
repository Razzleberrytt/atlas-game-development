--!strict

--[[
	Server bootstrap ordering.

	Several server services resolve their remotes at module scope with bounded
	`WaitForChild` calls -- ClassService waits for `ClassNetwork`,
	HordeExperienceService for `HordeNetwork`, and so on. Most of those folders do
	not exist in the place: `init.server.luau` creates them itself at boot.

	So the order remains load-bearing even though those waits are now bounded.
	Every `ensure*Network()` must run before the first service is required. Move
	one require above them and the service blocks until its timeout and then fails
	startup against a folder that the very bootstrap it interrupted would have
	created.

	This is deliberately an ordering audit rather than a rule against module-scope
	waits. Those waits are safe when bounded, and the correct ordering means they
	resolve immediately instead of consuming their failure budget.
]]

local fs = require("@lune/fs")

local function check(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local bootstrap = fs.readFile("games/living-kingdoms/src/server/init.server.luau")

--[[
	Find where the ensure calls are invoked, not where they are defined. The
	definitions sit at the top of the file and prove nothing about ordering.
]]
local ensureCalls: { [string]: number } = {}
local ensureNames: { string } = {}
for name in string.gmatch(bootstrap, "\n(ensure%w+Network)%(%)") do
	if ensureCalls[name] == nil then
		ensureCalls[name] = string.find(bootstrap, "\n" .. name .. "()", 1, true) :: number
		table.insert(ensureNames, name)
	end
end
table.sort(ensureNames)

check(#ensureNames >= 5, "the server bootstrap must still create its runtime networks, found " .. #ensureNames)

--[[
	Every ensure function that exists must actually be called. One defined and
	never invoked is a folder no service will ever find.
]]
for definition in string.gmatch(bootstrap, "local function (ensure%w+Network)%(") do
	check(
		ensureCalls[definition] ~= nil or string.find(bootstrap, definition .. "()", 1, true) ~= nil,
		"network creator " .. definition .. " is defined but never called"
	)
end

-- The first service require must come after the last network creation.

local firstRequireAt: number? = nil
for position in string.gmatch(bootstrap, "()\nlocal %w+ = require%(script%.Systems%.") do
	if firstRequireAt == nil or position < firstRequireAt then
		firstRequireAt = position
	end
end
check(firstRequireAt ~= nil, "the server bootstrap must still require its services")

local lastEnsureAt = 0
for _, name in ensureNames do
	local at = ensureCalls[name]
	if at > lastEnsureAt then
		lastEnsureAt = at
	end
end

check(
	lastEnsureAt < (firstRequireAt :: number),
	"every ensure*Network() must run before the first service require, or a module-scope "
		.. "WaitForChild consumes its timeout and fails startup against a folder this script has not created yet"
)

--[[
	The services that resolve networks at module scope are the ones this ordering
	protects. If one stops resolving there the audit still holds; if a new one
	starts, the ordering already covers it. This records which ones depend on the
	ordering today while requiring the bounded form.
]]
local waitingServices = 0
for _, entry in fs.readDir("games/living-kingdoms/src/server/Systems") do
	if string.sub(entry, -5) == ".luau" then
		local source = fs.readFile("games/living-kingdoms/src/server/Systems/" .. entry)
		if
			string.match(
				source,
				'\nlocal %w+ = ReplicatedStorage:WaitForChild%("%w+Network", NETWORK_WAIT_SECONDS%)'
			)
		then
			waitingServices += 1
		end
	end
end
check(waitingServices > 0, "expected at least one service resolving its bounded network at module scope")

print(
	string.format(
		"ServerBootstrapNetworkOrderSourceAudit: %d network creators run before the first of %d "
			.. "bounded module-scope waiting services is required",
		#ensureNames,
		waitingServices
	)
)
