--!strict

local fs = require("@lune/fs")

local roots = {
	"games/living-kingdoms/src/client/Controllers",
	"games/living-kingdoms/src/client/State",
	"games/living-kingdoms/src/client/Presentation",
}

local findings: { string } = {}

local function scanDirectory(path: string)
	for _, entry in fs.readDir(path) do
		local childPath = path .. "/" .. entry
		if fs.isDir(childPath) then
			scanDirectory(childPath)
		elseif string.sub(entry, -5) == ".luau" then
			local source = fs.readFile(childPath)
			for line in string.gmatch(source, "[^\n]+") do
				local receiver, child = string.match(line, '([%w_]*[Nn]etwork):WaitForChild%("([^"]+)"%)')
				if receiver ~= nil and child ~= nil then
					table.insert(findings, string.format("%s :: %s.%s", childPath, receiver, child))
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
	error("unbounded client network child waits:\n" .. table.concat(findings, "\n"), 2)
end

print("AAClientNetworkChildWaitInventory: no unbounded client network child waits")
