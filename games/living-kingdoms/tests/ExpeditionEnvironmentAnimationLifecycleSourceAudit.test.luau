--!strict

-- Regression for the BA-010 lifecycle debt: Workspace listeners created by the
-- expedition environment animation owner must be retained and disconnected on
-- stop so repeated lifecycle starts cannot accumulate stale callbacks.

local fs = require("@lune/fs")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

local function contains(source: string, token: string): boolean
	return string.find(source, token, 1, true) ~= nil
end

local source = fs.readFile("games/living-kingdoms/src/client/Controllers/ExpeditionEnvironmentAnimationController.luau")

for _, required in
	{
		"local workspaceChildAdded: RBXScriptConnection? = nil",
		"local workspaceChildRemoved: RBXScriptConnection? = nil",
		"workspaceChildAdded = Workspace.ChildAdded:Connect(function(child)",
		"workspaceChildRemoved = Workspace.ChildRemoved:Connect(function(child)",
		"workspaceChildAdded:Disconnect()",
		"workspaceChildAdded = nil",
		"workspaceChildRemoved:Disconnect()",
		"workspaceChildRemoved = nil",
		"disconnectWorkspaceListeners()",
		"bindRoot(nil)",
	}
do
	assertThat(contains(source, required), `expedition environment lifecycle is missing {required}`)
end

local _, childAddedCount = string.gsub(source, "Workspace.ChildAdded:Connect", "")
local _, childRemovedCount = string.gsub(source, "Workspace.ChildRemoved:Connect", "")
assertThat(childAddedCount == 1, "the controller must own exactly one Workspace ChildAdded listener")
assertThat(childRemovedCount == 1, "the controller must own exactly one Workspace ChildRemoved listener")

assertThat(
	not contains(source, "\n\tWorkspace.ChildAdded:Connect(function(child)"),
	"Workspace ChildAdded must never be created as an unretained anonymous listener"
)
assertThat(
	not contains(source, "\n\tWorkspace.ChildRemoved:Connect(function(child)"),
	"Workspace ChildRemoved must never be created as an unretained anonymous listener"
)

print("Expedition environment animation: Workspace listener lifecycle is retained and cleanup-safe")
