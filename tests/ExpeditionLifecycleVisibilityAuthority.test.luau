--!strict

local fs = require("@lune/fs")

local source = fs.readFile("games/living-kingdoms/src/client/Controllers/ExpeditionLifecycleVisibilityController.luau")
assert(string.find(source, "OnClientEvent", 1, true), "visibility policy must listen to server state")
assert(string.find(source, "ReadState", 1, true), "late joiners need read-only state")
assert(not string.find(source, "InvokeServer(\"Start", 1, true), "visibility policy must not start runs")
assert(not string.find(source, "InvokeServer(\"Stop", 1, true), "visibility policy must not stop runs")
assert(not string.find(source, "FireServer", 1, true), "visibility policy sends no gameplay request")

print("ExpeditionLifecycleVisibilityAuthority.test.luau passed")
