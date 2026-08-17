--!strict

local fs = require("@lune/fs")

local roots = {
	"games/living-kingdoms/src/client",
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

				local networkReceiver, networkChild = string.match(line, '([%w_]*[Nn]etwork):WaitForChild%("([^"]+)"%)')
				if networkReceiver ~= nil and networkChild ~= nil then
					record(childPath, lineNumber, networkReceiver .. "." .. networkChild)
				end

				local replicatedNetwork = string.match(line, 'ReplicatedStorage:WaitForChild%("([^"]*[Nn]etwork)"%)')
				if replicatedNetwork ~= nil then
					record(childPath, lineNumber, "ReplicatedStorage." .. replicatedNetwork)
				end

				local playerGuiReceiver = string.match(line, '([%w_]+):WaitForChild%("PlayerGui"%)')
				if playerGuiReceiver ~= nil then
					record(childPath, lineNumber, playerGuiReceiver .. ".PlayerGui")
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
	error("unbounded client bootstrap dependency waits:\n" .. table.concat(findings, "\n"), 2)
end

print("ClientBootstrapDependencyWaitSourceAudit: scoped client bootstrap dependency waits are bounded")
