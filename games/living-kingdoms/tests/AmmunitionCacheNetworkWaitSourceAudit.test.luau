--!strict

local fs = require("@lune/fs")

local source = fs.readFile("games/living-kingdoms/src/client/Controllers/AmmunitionCachePresentationController.luau")

local function assertThat(condition: unknown, message: string)
	if not condition then
		error(message, 2)
	end
end

assertThat(
	string.find(source, 'ReplicatedStorage:WaitForChild("CombatNetwork", NETWORK_WAIT_SECONDS)', 1, true) ~= nil,
	"CombatNetwork must use the bounded client bootstrap timeout"
)
assertThat(
	string.find(source, 'combatNetwork:WaitForChild("CombatPresentation", NETWORK_WAIT_SECONDS)', 1, true) ~= nil,
	"CombatPresentation must use the bounded client bootstrap timeout"
)
assertThat(
	string.find(source, 'combatNetwork:WaitForChild("CombatPresentation")', 1, true) == nil,
	"CombatPresentation must never regress to an unbounded module-scope wait"
)
assertThat(
	string.find(source, "CombatNetwork did not become available before the client bootstrap timeout", 1, true) ~= nil,
	"missing CombatNetwork bootstrap assertion"
)
assertThat(
	string.find(
		source,
		"CombatNetwork.CombatPresentation did not become available before the client bootstrap timeout",
		1,
		true
	) ~= nil,
	"missing CombatPresentation bootstrap assertion"
)

print("AmmunitionCacheNetworkWaitSourceAudit: CombatNetwork and CombatPresentation waits are bounded")
