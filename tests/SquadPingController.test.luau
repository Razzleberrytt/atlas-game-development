--!strict

-- LK-0407 client input, visual accessibility, reconciliation, and scope audit.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "LK-0407 controller fixture assertion failed", 2)
	end
end

local function robloxTypeof(value: unknown): string
	return if type(value) == "userdata" then "Vector3" else type(value)
end

local contracts = luau.load(fs.readFile("games/living-kingdoms/src/shared/Navigation/SquadPingContracts.luau"), {
	debugName = "SquadPingContracts",
	environment = { typeof = robloxTypeof },
	injectGlobals = true,
})()

local valid = {
	operationId = "Snapshot",
	revision = 4,
	pings = {
		{
			pingId = "ping:4",
			categoryId = "Location",
			position = roblox.Vector3.new(4, 0, 8),
			senderOperativeEntityId = "operative:sender",
			expiresAtServerTimestamp = 16,
			revision = 4,
			sequence = 4,
		},
	},
}
assert(contracts.validateSafeSnapshot(valid))
local accepted, pings, revision = contracts.reconcileSnapshot(3, valid)
assert(accepted and #pings == 1 and revision == 4)
assert(not contracts.reconcileSnapshot(5, valid))

local rejection = { operationId = "Rejected", revision = 4, rejectionReasonId = "RateLimited" }
assert(contracts.validateSafeSnapshot(rejection))
assert(not contracts.reconcileSnapshot(3, rejection))
for _, reasonId in contracts.RejectionReasonIds do
	assert(reasonId:match("^[A-Z][A-Za-z]+$") ~= nil, "rejection IDs must remain PascalCase")
	local payload = { operationId = "Rejected", revision = 4, rejectionReasonId = reasonId }
	assert(contracts.validateSafeSnapshot(payload), "rejection taxonomy not accepted: " .. reasonId)
end

local invalidPayloads = {
	{},
	{ operationId = "Snapshot", revision = -1, pings = {} },
	{ operationId = "Snapshot", revision = 1, pings = {}, recipients = {} },
	{ operationId = "Rejected", revision = 1, rejectionReasonId = "rate_limited" },
	{
		operationId = "Snapshot",
		revision = 1,
		pings = {
			{
				pingId = "ping:1",
				categoryId = "ObservedHostile",
				position = roblox.Vector3.zero,
				senderOperativeEntityId = "operative:sender",
				expiresAtServerTimestamp = 6,
				revision = 1,
				sequence = 1,
			},
		},
	},
}
for _, payload in invalidPayloads do
	assert(not contracts.validateSafeSnapshot(payload))
end

local source = fs.readFile("games/living-kingdoms/src/client/Controllers/SquadPingController.luau")
local configSource = fs.readFile("games/living-kingdoms/src/shared/Config/SquadPingConfig.luau")
assert(string.find(source, "MouseButton3", 1, true), "middle mouse input missing")
assert(string.find(configSource, 'KeyboardKeyCodeName = "G"', 1, true), "keyboard G input missing")
assert(string.find(configSource, 'GamepadKeyCodeName = "DPadUp"', 1, true), "gamepad input missing")
assert(string.find(source, "BindAction", 1, true) and string.find(source, "true,", 1, true), "touch action missing")
assert(string.find(source, "◇  LOCATION", 1, true), "marker needs non-color category text/shape")
assert(string.find(source, "TextLabel", 1, true), "visual presentation missing")
assert(not string.find(source, "Sound", 1, true), "audio must not be required")
assert(not string.find(source, "Minimap", 1, true))
assert(not string.find(source, "Compass", 1, true))
assert(not string.find(source, "Trail", 1, true))
assert(not string.find(source, "Tween", 1, true), "marker must not flash or strobe")
assert(not string.find(source, "Target", 1, true))
assert(not string.find(source, "Discovery", 1, true))
assert(string.find(source, "clearMarkers", 1, true) and string.find(source, "Controller.stop", 1, true))

print("SquadPingController: LK-0407 input, visual accessibility, reconciliation, and cleanup passed")
