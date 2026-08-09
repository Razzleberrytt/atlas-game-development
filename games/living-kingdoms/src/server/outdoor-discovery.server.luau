--!strict

-- BA-052 application-scoped mount for the optional outdoor discovery runtime.
-- The service is server-only and exposes no client remote surface.
local OutdoorDiscoveryService = require(script.Parent.Systems.OutdoorDiscoveryService)

OutdoorDiscoveryService.start()

game:BindToClose(function()
	OutdoorDiscoveryService.stop()
end)

print("[Living Kingdoms] Outdoor discovery runtime mounted")
