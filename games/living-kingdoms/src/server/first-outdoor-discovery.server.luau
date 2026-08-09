--!strict

-- BA-052 server-only mount. WorldFoundationService is built by the main server
-- bootstrap, so this mount waits for the canonical generated world/Lookout
-- anchor rather than creating a second world lifecycle or depending on script
-- execution order between sibling ServerScriptService scripts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldFoundationConfig = require(ReplicatedStorage.Shared.Config.WorldFoundationConfig)
local FirstOutdoorDiscoveryService = require(script.Parent.Systems.FirstOutdoorDiscoveryService)

local worldRoot = Workspace:WaitForChild(WorldFoundationConfig.WorldRootName, 15)
if worldRoot ~= nil then
	local deadline = os.clock() + 15
	repeat
		if worldRoot:FindFirstChild("LookoutTower", true) ~= nil then
			break
		end
		task.wait(0.1)
	until os.clock() >= deadline
	FirstOutdoorDiscoveryService.start()
else
	warn("[FirstOutdoorDiscovery] generated world root did not become available")
end

game:BindToClose(function()
	FirstOutdoorDiscoveryService.stop()
end)
