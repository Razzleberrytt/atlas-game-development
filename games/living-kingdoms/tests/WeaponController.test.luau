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
local serverTimestamp = 10

local function fakeInstance(className: string)
	local properties = {}
	local instance = {
		ClassName = className,
		destroyed = false,
		attributes = {},
	}
	function instance:Destroy()
		instance.destroyed = true
	end
	function instance:GetAttribute(attributeName: string)
		return instance.attributes[attributeName]
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
		__newindex = function(_self, key, value)
			properties[key] = value
		end,
	})
end

local target = fakeInstance("Model")
target.attributes.CombatEntityId = "hostile.disclosed"
local enemyFolder = {
	GetDescendants = function()
		return { target }
	end,
}

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

local playerAttributes = {}
local localPlayer = {
	UserId = 42,
	SetAttribute = function(_self: unknown, name: string, value: unknown)
		playerAttributes[name] = value
	end,
	GetAttribute = function(_self: unknown, name: string)
		return playerAttributes[name]
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
	FindFirstChild = function(_self: unknown, name: string)
		if name == "EnemyEntities" then
			return enemyFolder
		end
		return nil
	end,
	GetServerTimeNow = function()
		return serverTimestamp
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
		AmmunitionState = "AmmunitionState",
		AmmunitionCollected = "AmmunitionCollected",
	}),
}
local config = {
	BasicFirearm = table.freeze({
		WeaponId = "weapon.basic_firearm",
		MaximumReserveRounds = 120,
	}),
}

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
	},
	Color3 = {
		fromRGB = function(r: number, g: number, b: number)
			return { R = r, G = g, B = b }
		end,
	},
}

local source = fs.readFile("games/living-kingdoms/src/client/Controllers/WeaponController.luau")
local controller = luau.load(source, {
	debugName = "WeaponController",
	environment = environment,
	injectGlobals = true,
})()

local function inputR(gameProcessed: boolean)
	inputBegan:Fire({ KeyCode = keyCodeR }, gameProcessed)
end

local function activeHighlight()
	for index = #createdInstances, 1, -1 do
		local instance = createdInstances[index]
		if instance.ClassName == "Highlight" and not instance.destroyed then
			return instance
		end
	end
	return nil
end

controller.init()
controller.init()
controller.start()
controller.start()
assert(playerAttributes.LK_HUD_LoadedRounds == nil, "start must clear stale ammunition")

inputR(true)
assert(#reloadRequests == 0, "game-processed R sent reload")
focusedTextBox = {}
inputR(false)
assert(#reloadRequests == 0, "text-focused R sent reload")
focusedTextBox = nil
inputR(false)
inputR(false)
assert(#reloadRequests == 1, "R did not send exactly one guarded reload intent")
assert(reloadRequests[1].n == 1 and reloadRequests[1][1] == "weapon.basic_firearm", "reload intent was malformed")

presentationEvent:Fire({
	kindId = "TargetSelected",
	targetEntityId = "hostile.disclosed",
	serverTimestamp = 10,
})
local highlight = activeHighlight()
assert(highlight ~= nil and highlight.Adornee == target, "disclosed target was not highlighted")
presentationEvent:Fire({ kindId = "TargetCleared", serverTimestamp = 10.1 })
assert(highlight.destroyed == true and activeHighlight() == nil, "target clear retained highlight")

presentationEvent:Fire({
	kindId = "ShotFired",
	shotId = "shot.server.1",
	operativeEntityId = "operative.player:42",
	weaponId = "weapon.basic_firearm",
	targetEntityId = "hostile.disclosed",
	serverTimestamp = 10.2,
	didApplyDamage = true,
})
assert(playerAttributes.LK_HUD_CombatStatus == "HIT CONFIRMED", "confirmed hit did not reach HUD attributes")
local confirmedUntil = playerAttributes.LK_HUD_CombatStatusUntil
presentationEvent:Fire({
	kindId = "ShotFired",
	shotId = "shot.server.1",
	operativeEntityId = "operative.player:42",
	weaponId = "weapon.basic_firearm",
	targetEntityId = "hostile.disclosed",
	serverTimestamp = 10.3,
	didApplyDamage = true,
})
assert(playerAttributes.LK_HUD_CombatStatusUntil == confirmedUntil, "duplicate ShotId was presented twice")

serverTimestamp = 20
presentationEvent:Fire({
	kindId = "ReloadStarted",
	operativeEntityId = "operative.player:42",
	weaponId = "weapon.basic_firearm",
	completionServerTimestamp = 22,
})
assert(playerAttributes.LK_HUD_CombatStatus == "RELOADING", "reload start was not presented")
presentationEvent:Fire({
	kindId = "ReloadCompleted",
	operativeEntityId = "operative.player:42",
	weaponId = "weapon.basic_firearm",
})
assert(playerAttributes.LK_HUD_CombatStatus == "RELOAD COMPLETE", "reload completion was not presented")
presentationEvent:Fire({
	kindId = "ReloadInterrupted",
	operativeEntityId = "operative.player:42",
	weaponId = "weapon.basic_firearm",
})
assert(playerAttributes.LK_HUD_CombatStatus == "RELOAD INTERRUPTED", "reload interruption was not presented")

presentationEvent:Fire({
	kindId = "AmmunitionState",
	weaponId = "weapon.basic_firearm",
	loadedRounds = 18,
	reserveRounds = 72,
	magazineCapacity = 30,
	maximumReserveRounds = 120,
})
assert(playerAttributes.LK_HUD_LoadedRounds == 18, "loaded ammunition was not bridged")
assert(playerAttributes.LK_HUD_ReserveRounds == 72, "reserve ammunition was not bridged")
assert(playerAttributes.LK_HUD_MagazineCapacity == 30, "magazine capacity was not bridged")
presentationEvent:Fire({
	kindId = "AmmunitionState",
	weaponId = "weapon.basic_firearm",
	loadedRounds = 31,
	reserveRounds = 72,
	magazineCapacity = 30,
	maximumReserveRounds = 120,
})
assert(playerAttributes.LK_HUD_LoadedRounds == 18, "malformed ammunition disclosure changed HUD state")

presentationEvent:Fire({
	kindId = "AmmunitionCollected",
	weaponId = "weapon.basic_firearm",
	loadedRounds = 18,
	reserveRounds = 92,
	magazineCapacity = 30,
	maximumReserveRounds = 120,
	grantedRounds = 20,
})
assert(playerAttributes.LK_HUD_ReserveRounds == 92, "collected ammunition was not bridged")
assert(playerAttributes.LK_HUD_CombatStatus == "+20 AMMUNITION", "collection feedback was not bridged")

controller.stop()
controller.stop()
assert(playerAttributes.LK_HUD_LoadedRounds == nil, "stop retained ammunition HUD attributes")
assert(playerAttributes.LK_HUD_CombatStatus == nil, "stop retained combat status")
inputR(false)
assert(#reloadRequests == 1, "stopped controller retained input connection")

controller.start()
inputR(false)
assert(#reloadRequests == 2, "safe restart did not reconnect once")
controller.destroy()
controller.destroy()
controller.start()
inputR(false)
assert(#reloadRequests == 2, "destroyed controller retained input")
assert(activeHighlight() == nil, "destroyed controller retained presentation")

print("WeaponController: reload input, attribute HUD bridge, disclosure, ammunition, and lifecycle checks passed")
