--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local module = luau.load(fs.readFile("games/living-kingdoms/src/server/Systems/ExpeditionDiagnosticsService.luau"), { injectGlobals = true })()

local journal = module.new(10)
for index = 1, 12 do
	journal:record("Event" .. tostring(index), { Value = index, Ignored = {} }, index)
end
local entries = journal:read()
assert(#entries == 10, "journal should remain bounded")
assert(entries[1].Sequence == 3 and entries[10].Sequence == 12, "journal should retain newest entries")
assert(entries[1].Fields.Ignored == nil, "unsafe nested fields should be discarded")
journal:clear()
assert(#journal:read() == 0, "clear should remove entries")
journal:destroy()
assert(#journal:read() == 0, "destroyed journal should disclose nothing")

print("ExpeditionDiagnosticsService.test.luau passed")
