--!strict

-- Focused controller fixture using signals and lightweight Roblox API stubs.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function createSignal()
	local listeners = {}
	local signal = {}

	function signal:Connect(callback: (...any) -> ())
		local connection = { connected = true }
		function connection:Disconnect()
			connection.connected = false
		end
		table.insert(listeners, { callback = callback, connection = connection })
		return connection
	end

	function signal:Fire(...: any)
		for _, listener in listeners do
			if listener.connection.connected then
				listener.callback(...)
			end
		end
	end

	return signal
end

local inputBegan = createSignal()
local presentationEvent = createSignal()
local focusedTextBox: unknown = nil
local reloadRequests = {}
local createdInstances = {}

local function fakeInstance(className: string)
	local properties = {}
	local instance = {
		ClassName = className,
		destroyed = false,
		textWrites = {},
	}
	function instance:Destroy()
		instance.destroyed = true
	end
	function instance:GetAttribute(attributeName: string)
		return instance.attributes and instance.attributes[attributeName] or nil
	end
	table.insert(createdInstances, instance)
	return setmetatable(instance, {
		__index = function(self, key)
			local directValue = rawget(self, key)
			if directValue ~= nil then
				return directValue
			end
			return properties[key]
		end,
		__newindex = function(self, key, value)
			if key == "Text" then
				table.insert(self.textWrites, value)
			end
			properties[key] = value
		end,
	})
end

local target = fakeInstance("Model")
target.attributes = { CombatEntityId = "hostile.disclosed" }

local reloadIntentRemote = {
	FireServer = function(_self: unknown, ...: any)
		table.insert(reloadRequests, table.pack(...))
	end,
}
local presentationRemote = { OnClientEvent = presentationEvent }
local combatNetwork = {
	WaitForChild = function(_self: unknown, name: string)
		if name == "ReloadIntent" then
			return reloadIntentRemote
		end
		if name == "CombatPresentation" then
			return presentationRemote
		end
		error("unexpected combat network child")
	end,
}

local CONTRACTS_TOKEN = {}
local CONFIG_TOKEN = {}
local replicatedStorage = {
	Shared = {
		Combat = { CombatContracts = CONTRACTS_TOKEN },
		Config = { FirearmConfig = CONFIG_TOKEN },
	},
	WaitForChild = function(_self: unknown, name: string)
		assert(name == "CombatNetwork", "unexpected replicated child")
		return combatNetwork
	end,
}

local playerGui = fakeInstance("PlayerGui")
local localPlayer = {
	UserId = 42,
	WaitForChild = function(_self: unknown, name: string)
		assert(name == "PlayerGui", "unexpected player child")
		return playerGui
	end,
}
local players = { LocalPlayer = localPlayer }
local userInputService = {
	InputBegan = inputBegan,
	GetFocusedTextBox = function()
		return focusedTextBox
	end,
}
local workspace = {
	GetDescendants = function()
		return { target }
	end,
}

local services = {
	Players = players,
	ReplicatedStorage = replicatedStorage,
	UserInputService = userInputService,
	Workspace = workspace,
}

local contracts = {
	PresentationMessageKindIds = table.freeze({
		TargetSelected = "TargetSelected",
		TargetCleared = "TargetCleared",
		ShotFired = "ShotFired",
		ReloadStarted = "ReloadStarted",
		ReloadCompleted = "ReloadCompleted",
		ReloadInterrupted = "ReloadInterrupted",
	}),
}
local config = { BasicFirearm = table.freeze({ WeaponId = "weapon.basic_firearm" }) }

local keyCodeR = {}
local environment = {
	game = {
		GetService = function(_self: unknown, serviceName: string)
			local service = services[serviceName]
			assert(service ~= nil, "unexpected service " .. serviceName)
			return service
		end,
	},
	require = function(token: unknown)
		if token == CONTRACTS_TOKEN then
			return contracts
		end
		if token == CONFIG_TOKEN then
			return config
		end
		error("unexpected module request")
	end,
	Instance = { new = fakeInstance },
	Enum = {
		KeyCode = { R = keyCodeR },
		HighlightDepthMode = { Occluded = "Occluded" },
		Font = { GothamMedium = "GothamMedium" },
	},
	Color3 = {
		fromRGB = function(r: number, g: number, b: number)
			return { R = r, G = g, B = b }
		end,
	},
	UDim2 = {
		new = function(...: any)
			return table.pack(...)
		end,
		fromOffset = function(...: any)
			return table.pack(...)
		end,
	},
	Vector2 = {
		new = function(x: number, y: number)
			return { X = x, Y = y }
		end,
	},
}

local source = fs.readFile("games/living-kingdoms/src/client/Controllers/WeaponController.luau")
local loadController = luau.load(source, {
	debugName = "WeaponController",
	environment = environment,
	injectGlobals = true,
})
local controller = loadController()

local function inputR(gameProcessed: boolean)
	inputBegan:Fire({ KeyCode = keyCodeR }, gameProcessed)
end

local function activeInstance(className: string, instanceName: string?)
	for index = #createdInstances, 1, -1 do
		local instance = createdInstances[index]
		if
			instance.ClassName == className
			and not instance.destroyed
			and (instanceName == nil or instance.Name == instanceName)
		then
			return instance
		end
	end
	return nil
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[key] = deepCopy(child)
	end
	return copy
end

local function deepEqual(first: any, second: any): boolean
	if type(first) ~= type(second) then
		return false
	end
	if type(first) ~= "table" then
		return first == second
	end
	for key, value in first do
		if not deepEqual(value, second[key]) then
			return false
		end
	end
	for key in second do
		if first[key] == nil then
			return false
		end
	end
	return true
end

controller.init()
controller.init()
controller.start()
controller.start()

inputR(true)
assert(#reloadRequests == 0, "game-processed R sent reload")
focusedTextBox = {}
inputR(false)
assert(#reloadRequests == 0, "text-focused R sent reload")
focusedTextBox = nil
inputR(false)
inputR(false)
assert(#reloadRequests == 1, "R did not send exactly one guarded reload intent")
assert(reloadRequests[1].n == 1, "reload intent sent extra values")
assert(reloadRequests[1][1] == "weapon.basic_firearm", "reload intent sent wrong weapon")

controller.stop()
controller.stop()
inputR(false)
assert(#reloadRequests == 1, "stopped controller retained input connection")
controller.start()
inputR(false)
assert(#reloadRequests == 2, "safe restart did not reconnect once")

presentationEvent:Fire({
	kindId = "NotADisclosure",
	targetEntityId = "hostile.disclosed",
})
assert(activeInstance("Highlight") == nil, "undisclosed target ID was presented")

presentationEvent:Fire({
	kindId = "TargetSelected",
	targetEntityId = "hostile.disclosed",
})
assert(activeInstance("Highlight") == nil, "malformed known target disclosure was presented")

presentationEvent:Fire({
	kindId = "TargetSelected",
	operativeEntityId = "operative.player:42",
	targetEntityId = "hostile.disclosed",
	serverTimestamp = 10,
})
local highlight = activeInstance("Highlight")
assert(highlight ~= nil, "disclosed selected target was not highlighted")
assert(highlight.Adornee == target, "highlight adorned the wrong target")

presentationEvent:Fire({ kindId = "TargetCleared", operativeEntityId = "operative.player:42", serverTimestamp = 10.1 })
assert(highlight.destroyed == true, "target clear retained highlight")
assert(activeInstance("Highlight") == nil, "target clear retained target presentation")

local authoritativePayload = {
	kindId = "ShotFired",
	shotId = "shot.server.1",
	operativeEntityId = "operative.player:42",
	weaponId = "weapon.basic_firearm",
	targetEntityId = "hostile.undisclosed",
	serverTimestamp = 10.2,
	ammunitionAfter = { loadedRounds = 3, reserveRounds = 7 },
	healthAfter = 80,
}
local authoritativePayloadBefore = deepCopy(authoritativePayload)
local statusLabel = activeInstance("TextLabel", "Status")
presentationEvent:Fire(authoritativePayload)
presentationEvent:Fire(authoritativePayload)
presentationEvent:Fire({
	kindId = "ShotFired",
	shotId = "shot.server.2",
	operativeEntityId = "operative.player:42",
	weaponId = "weapon.basic_firearm",
	targetEntityId = "hostile.disclosed",
	serverTimestamp = 10.4,
})
presentationEvent:Fire({
	kindId = "ShotFired",
	shotId = "shot.server.remote",
	operativeEntityId = "operative.player:99",
	weaponId = "weapon.basic_firearm",
	targetEntityId = "hostile.disclosed",
	serverTimestamp = 10.45,
})
presentationEvent:Fire(authoritativePayload)
local shotWrites = 0
for _, value in statusLabel.textWrites do
	if value == "Shot fired" then
		shotWrites += 1
	end
end
assert(shotWrites == 2, "disclosed ShotIds were not presented exactly once")
assert(activeInstance("Highlight") == nil, "shot target created an undisclosed target indicator")
assert(deepEqual(authoritativePayload, authoritativePayloadBefore), "presentation mutated ammo or health payload")

presentationEvent:Fire({
	kindId = "ReloadStarted",
	weaponId = "weapon.basic_firearm",
	completionServerTimestamp = 12,
})
assert(statusLabel.Text == "Reloading", "reload start was not presented")
presentationEvent:Fire({ kindId = "ReloadCompleted", weaponId = "weapon.basic_firearm" })
assert(statusLabel.Text == "Reload complete", "reload completion was not presented")
presentationEvent:Fire({ kindId = "ReloadInterrupted", weaponId = "weapon.basic_firearm" })
assert(statusLabel.Text == "Reload interrupted", "reload interruption was not presented")

controller.destroy()
controller.destroy()
controller.start()
inputR(false)
presentationEvent:Fire({ kindId = "TargetSelected", targetEntityId = "hostile.disclosed" })
assert(#reloadRequests == 2, "destroyed controller retained input")
assert(activeInstance("Highlight") == nil, "destroyed controller retained presentation")

print("WeaponController: reload input, cooldown, focus, lifecycle, disclosure, shot, and authority checks passed")
