--!strict

--[[
	Server and Main World bootstrap dependency waits stay bounded.

	An unbounded WaitForChild is the one bootstrap hazard that failure
	containment cannot reach. A pcall catches an error; it does not interrupt a
	yield. So a service that waits forever on a folder or a network stalls the
	whole start sequence behind it, with no error naming what it was waiting for.

	This audit used to match only `*Network` waits, which left every
	`Workspace:WaitForChild(...)` and `ReplicatedStorage:WaitForChild("Shared")`
	invisible to it -- including two inside started services. The guarantee was
	always "bootstrap dependency waits are bounded", so the audit now holds that
	rather than the narrower spelling: any untimed WaitForChild in these trees is
	a finding.

	Bounded waits remain correct and expected. Ordering makes most of them
	resolve immediately; the bound only decides what happens when it does not.
]]

local fs = require("@lune/fs")

local roots = {
	"games/living-kingdoms/src/server",
	"games/living-kingdoms/src/shared",
	"games/living-kingdoms/src/main-world",
}

local findings: { string } = {}

local function record(path: string, lineNumber: number, evidence: string)
	table.insert(findings, string.format("%s:%d :: %s", path, lineNumber, evidence))
end

local function scanDirectory(path: string)
	for _, entry in fs.readDir(path) do
		local childPath = path .. "/" .. entry
		if fs.isDir(childPath) then
			scanDirectory(childPath)
		elseif string.sub(entry, -5) == ".luau" then
			local source = fs.readFile(childPath)
			local lineNumber = 0
			for line in string.gmatch(source, "[^\n]+") do
				lineNumber += 1

				-- A second argument is the timeout. Its absence is the finding.
				local waitArguments = string.match(line, ":WaitForChild%(([^%)]+)%)")
				if waitArguments ~= nil and string.find(waitArguments, ",", 1, true) == nil then
					record(childPath, lineNumber, "WaitForChild(" .. waitArguments .. ")")
				end
			end
		end
	end
end

for _, root in roots do
	if fs.isDir(root) then
		scanDirectory(root)
	end
end

table.sort(findings)

if #findings > 0 then
	for _, finding in findings do
		print("UNBOUNDED_SERVER_BOOTSTRAP_WAIT :: " .. finding)
	end
	error(string.format("%d unbounded server/shared bootstrap dependency wait(s) remain", #findings), 2)
end

print("ServerBootstrapDependencyWaitSourceAudit: server, shared and Main World dependency waits are bounded")
