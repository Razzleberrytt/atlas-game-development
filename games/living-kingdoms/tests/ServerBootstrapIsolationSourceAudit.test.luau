--!strict

--[[
	Server bootstrap failure containment.

	The bootstrap requires every server system and starts them in one deliberate
	order. Bare, that order is also a failure chain: one service erroring during
	require or during start aborts the script and silently takes every owner
	behind it -- mission, loot, class, loadout, and the replay owner that starts
	last -- leaving a server that still accepts players with no error naming what
	broke. The client bootstrap was contained for exactly this reason; this audit
	holds the server counterpart.

	Two owners are deliberately *not* contained. WorldFoundationService
	establishes the world root later owners resolve against, and MatchResultService
	is the contribution ledger that must exist before any owner able to commit a
	fact starts. Continuing past either would produce a server that looks alive
	while committing facts no ledger recorded, so they abort loudly and by name.

	This audit pins the guarantee -- every service load and every start is
	contained, the two ordering-critical owners abort instead of failing open, and
	failures are reported by name -- not any particular spelling of the helpers.
]]

local fs = require("@lune/fs")

local BOOTSTRAP_PATH = "games/living-kingdoms/src/server/init.server.luau"
local CRITICAL_OWNERS = { "WorldFoundationService", "MatchResultService" }

local bootstrap = fs.readFile(BOOTSTRAP_PATH)

local function check(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(haystack: string, needle: string): boolean
	return string.find(haystack, needle, 1, true) ~= nil
end

local function occurrences(haystack: string, pattern: string): number
	local count = 0
	for _ in string.gmatch(haystack, pattern) do
		count += 1
	end
	return count
end

local function isCritical(name: string): boolean
	for _, critical in CRITICAL_OWNERS do
		if critical == name then
			return true
		end
	end
	return false
end

-- 1. Both helpers must actually contain the call they wrap.
for _, helper in { "safeRequire", "safeStep", "criticalStep" } do
	local definition = string.match(bootstrap, "local function " .. helper .. "%(.-\nend\n")
	check(definition ~= nil, "the server bootstrap must define " .. helper)
	check(
		contains(definition :: string, "pcall("),
		helper .. " must contain the failure rather than let it abort the bootstrap"
	)
end

--[[
	criticalStep is the one helper that must re-raise. A contained critical owner
	would be worse than the bare call it replaced: the bootstrap would continue
	past a missing world root or a missing ledger while reporting only a warning.
]]
local criticalDefinition = string.match(bootstrap, "local function criticalStep%(.-\nend\n") :: string
check(contains(criticalDefinition, "error("), "criticalStep must abort the bootstrap rather than warn and continue")
local safeStepDefinition = string.match(bootstrap, "local function safeStep%(.-\nend\n") :: string
check(not contains(safeStepDefinition, "error("), "safeStep must not abort the bootstrap")

-- 2. Every Systems require goes through the isolating loader.
local requireCount = occurrences(bootstrap, "require%(script%.Systems%.")
local guardedRequireCount = occurrences(bootstrap, 'safeRequire%("[%w_]+", function%(%)')
check(requireCount > 0, "the server bootstrap must still require its services")
check(
	requireCount == guardedRequireCount,
	string.format(
		"every service require must be reached through safeRequire: %d require(script.Systems.) vs %d safeRequire",
		requireCount,
		guardedRequireCount
	)
)

-- 3. The binding name and the reported name must agree, or a warning names the wrong service.
local services: { string } = {}
for name, label in string.gmatch(bootstrap, 'local ([%w_]+) = safeRequire%("([%w_]+)"') do
	check(name == label, string.format("safeRequire label %q does not match its binding %q", label, name))
	table.insert(services, name)
end
check(#services == requireCount, "every safeRequire must bind a named service")

-- 4. No start may be left bare at statement level.
local bareStart = string.match(bootstrap, "\n([%w_]+)%.start%(%)")
check(bareStart == nil, "uncontained service start in the server bootstrap: " .. tostring(bareStart) .. ".start()")

-- 5. Every required service is started exactly once, through the correct helper.
for _, name in services do
	local guardedStarts = occurrences(bootstrap, 'safeStep%("' .. name .. '%.start"')
	local criticalStarts = occurrences(bootstrap, 'criticalStep%("' .. name .. '%.start"')
	check(
		guardedStarts + criticalStarts == 1,
		string.format(
			"%s must be started exactly once through one isolation helper, found %d safeStep and %d criticalStep",
			name,
			guardedStarts,
			criticalStarts
		)
	)
	if isCritical(name) then
		check(
			criticalStarts == 1,
			name .. " is ordering-critical and must abort the bootstrap rather than be contained"
		)
		check(
			contains(bootstrap, string.format('assert(%s ~= nil, "%s failed to load")', name, name)),
			name .. " must also abort when its module failed to load, not silently skip"
		)
	else
		check(guardedStarts == 1, name .. " must be started through the contained helper")
	end
end

-- 6. A failure that was contained has to surface by name.
check(
	contains(bootstrap, "failedServices") and contains(bootstrap, "table.concat(failedServices"),
	"contained failures must be reported by name rather than inferred from missing gameplay"
)

print(
	string.format(
		"ServerBootstrapIsolationSourceAudit: %d services contained, %d ordering-critical owners abort by name",
		#services,
		#CRITICAL_OWNERS
	)
)
