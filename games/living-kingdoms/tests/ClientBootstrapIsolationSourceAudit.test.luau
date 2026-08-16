--!strict

--[[
	Client bootstrap isolation.

	The bootstrap requires ~55 controllers and starts them in a deliberate order.
	It used to do both bare, so one controller erroring during require -- or
	during start -- took every controller after it with it. That is how a client
	ends up with a single PlayerGui child instead of the ~22 a healthy session
	has, and the symptom gives no hint which controller caused it.

	Isolation alone is not enough, because the common failure is not an error but
	a *yield*: an unbounded `WaitForChild` on a network folder the server has not
	created yet blocks forever, and pcall does not interrupt a yield. Bounding
	those waits is what converts an unrecoverable hang into a catchable error, so
	both halves are asserted here together.
]]

local fs = require("@lune/fs")

local function check(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local bootstrap = fs.readFile("games/living-kingdoms/src/client/init.client.luau")

local function count(pattern: string): number
	local _, total = string.gsub(bootstrap, pattern, "")
	return total
end

-- 1. Nothing in the bootstrap runs outside the isolation helpers.

check(count("safeRequire%(") > 40, "the bootstrap must load controllers through the isolating helper")
check(count("safeStep%(") > 40, "the bootstrap must invoke controller steps through the isolating helper")
check(
	count("\nlocal %w+ = require%(script%.") == 0,
	"a bare top-level controller require would take every later controller down with it"
)
check(count("\n%w+%.start%(%)") == 0, "a bare top-level start would take every later controller down with it")
check(count("\n%w+%.init%(%)") == 0, "a bare top-level init would take every later controller down with it")

--[[
	A contained failure must still be reported. Silently missing UI is harder to
	diagnose than a crash, because nothing says which controller is absent.
]]
check(
	string.find(bootstrap, "controller step(s) failed", 1, true) ~= nil,
	"a failed controller must be named rather than left to be inferred from missing UI"
)
check(string.find(bootstrap, "failedControllers", 1, true) ~= nil, "failures must be collected, not only warned once")

--[[
	Isolation must not become reordering. The order carries meaning, so the
	helpers wrap each step in place rather than deferring it.
]]
check(string.find(bootstrap, "task.spawn", 1, true) == nil, "controller steps must not be deferred; the order matters")
check(string.find(bootstrap, "task.defer", 1, true) == nil, "controller steps must not be deferred; the order matters")

-- 2. Every direct module-scope WaitForChild in client modules is bounded.
--
-- This intentionally checks the receiver generically rather than only
-- ReplicatedStorage. A network folder can itself exist while one of its child
-- remotes is missing; an unbounded child wait hangs the same ordered require
-- chain just as completely as an unbounded root wait.

local unbounded: { string } = {}
for _, directory in { "Controllers", "State", "Presentation" } do
	local root = "games/living-kingdoms/src/client/" .. directory
	if fs.isDir(root) then
		for _, entry in fs.readDir(root) do
			if string.sub(entry, -5) == ".luau" then
				local source = fs.readFile(root .. "/" .. entry)
				for line in string.gmatch(source, "[^\n]+") do
					if string.match(line, '^local %w+ = [%w%.]+:WaitForChild%("%w+"%)') then
						table.insert(unbounded, entry)
					end
				end
			end
		end
	end
end
table.sort(unbounded)
check(
	#unbounded == 0,
	"a module-scope wait must be bounded or it hangs the whole require chain: " .. table.concat(unbounded, ", ")
)

print("ClientBootstrapIsolationSourceAudit: isolated requires and steps, ordered, with bounded network waits")
