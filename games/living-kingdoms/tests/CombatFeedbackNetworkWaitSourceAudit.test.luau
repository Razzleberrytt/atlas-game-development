--!strict

local fs = require("@lune/fs")

local controllerPaths = {
	"games/living-kingdoms/src/client/Controllers/CombatFeedback/ConfirmedHitMarkerController.luau",
	"games/living-kingdoms/src/client/Controllers/CombatFeedback/FloatingDamageTextController.luau",
}

for _, path in controllerPaths do
	local source = fs.readFile(path)
	assert(
		string.find(source, 'ReplicatedStorage:WaitForChild("CombatNetwork", NETWORK_WAIT_SECONDS)', 1, true) ~= nil,
		path .. " must bound the CombatNetwork wait"
	)
	assert(
		string.find(source, 'combatNetwork:WaitForChild("CombatPresentation", NETWORK_WAIT_SECONDS)', 1, true) ~= nil,
		path .. " must bound the CombatPresentation wait"
	)
	assert(
		string.find(source, 'combatNetwork:WaitForChild("CombatPresentation")', 1, true) == nil,
		path .. " must never regress to an unbounded CombatPresentation wait"
	)
	assert(
		string.find(source, "CombatNetwork did not become available before the client bootstrap timeout", 1, true)
			~= nil,
		path .. " must fail closed when CombatNetwork is absent"
	)
	assert(
		string.find(
			source,
			"CombatNetwork.CombatPresentation did not become available before the client bootstrap timeout",
			1,
			true
		) ~= nil,
		path .. " must fail closed when CombatPresentation is absent"
	)
end

print("CombatFeedbackNetworkWaitSourceAudit: confirmed-hit and floating-damage network waits are bounded")
