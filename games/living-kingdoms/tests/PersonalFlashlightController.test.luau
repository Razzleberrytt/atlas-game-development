--!strict

-- LK-0406 local prediction, reconciliation, accessibility, and cleanup fixtures.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assert(condition: unknown, message: string?)
	if not condition then
		error(message or "LK-0406 controller fixture assertion failed", 2)
	end
end

local config = luau.load(fs.readFile("games/living-kingdoms/src/shared/Config/PersonalFlashlightConfig.luau"), {
	debugName = "PersonalFlashlightConfig",
	environment = {},
	injectGlobals = true,
})()
local contracts = luau.load(
	fs.readFile("games/living-kingdoms/src/shared/Lighting/PersonalFlashlightContracts.luau"),
	{ debugName = "PersonalFlashlightContracts", environment = {}, injectGlobals = true }
)()

local function signal()
	local listeners = {}
	local value = {}
	function value:Connect(callback)
		table.insert(listeners, callback)
		local connected = true
		return {
			Disconnect = function()
				if not connected then
					return
				end
				connected = false
				local index = table.find(listeners, callback)
				if index ~= nil then
					table.remove(listeners, index)
				end
			end,
		}
	end
	function value:Fire(...)
		for _, callback in table.clone(listeners) do
			callback(...)
		end
	end
	function value:Count()
		return #listeners
	end
	return value
end

local stateSignal = signal()
local lifeSignal = signal()
local characterAdded = signal()
local characterRemoving = signal()
local renderStepped = signal()
local firedRequests = {}
local intentRemote = {
	FireServer = function(_, requestedActive)
		table.insert(firedRequests, requestedActive)
	end,
}
local stateRemote = { OnClientEvent = stateSignal }
local network = {
	WaitForChild = function(_, name)
		return if name == "ToggleIntent" then intentRemote else stateRemote
	end,
}

local createdInstances = {}
local destroyedCount = 0
local function createInstance(className)
	local instance = { ClassName = className, Destroyed = false }
	function instance:Destroy()
		if self.Destroyed then
			return
		end
		self.Destroyed = true
		destroyedCount += 1
	end
	table.insert(createdInstances, instance)
	return instance
end

local head = {
	IsA = function(_, className)
		return className == "BasePart"
	end,
}
local character = {
	FindFirstChild = function(_, name)
		return if name == "Head" then head else nil
	end,
}
local attributes = { LK_P3_LifeState = "Alive" }
local localPlayer = {
	Character = character,
	CharacterAdded = characterAdded,
	CharacterRemoving = characterRemoving,
	GetAttribute = function(_, name)
		return attributes[name]
	end,
	GetAttributeChangedSignal = function(_, name)
		assert(name == "LK_P3_LifeState", "only life state may be observed")
		return lifeSignal
	end,
	WaitForChild = function(_, name)
		assert(name == "PlayerGui", "only PlayerGui may be requested")
		return {}
	end,
}
local workspace = { CurrentCamera = { CFrame = "CameraCFrame" } }
local runService = { RenderStepped = renderStepped }

local boundAction = nil
local titles = {}
local contextActionService = {
	BindAction = function(_, name, callback, createTouchButton, keyboard, gamepad)
		assert(name == "LK0406PersonalFlashlight")
		assert(createTouchButton == true, "touch control must be present")
		assert(keyboard == "F" and gamepad == "ButtonY", "keyboard/gamepad mappings must be explicit")
		boundAction = callback
	end,
	UnbindAction = function(_, name)
		assert(name == "LK0406PersonalFlashlight")
		boundAction = nil
	end,
	SetTitle = function(_, _, title)
		table.insert(titles, title)
	end,
	SetPosition = function() end,
}

local CONFIG_TOKEN = {}
local CONTRACTS_TOKEN = {}
local replicatedStorage = {
	Shared = {
		Config = { PersonalFlashlightConfig = CONFIG_TOKEN },
		Lighting = { PersonalFlashlightContracts = CONTRACTS_TOKEN },
	},
	WaitForChild = function(_, name)
		assert(name == "FlashlightNetwork")
		return network
	end,
}
local players = { LocalPlayer = localPlayer }
local enum = {
	KeyCode = { F = "F", ButtonY = "ButtonY" },
	NormalId = { Front = "Front" },
	Font = { GothamMedium = "GothamMedium" },
	UserInputState = { Begin = "Begin" },
	ContextActionResult = { Pass = "Pass", Sink = "Sink" },
}

local controller =
	luau.load(fs.readFile("games/living-kingdoms/src/client/Controllers/PersonalFlashlightController.luau"), {
		debugName = "PersonalFlashlightController",
		environment = {
			game = {
				GetService = function(_, name)
					if name == "ContextActionService" then
						return contextActionService
					elseif name == "Players" then
						return players
					elseif name == "RunService" then
						return runService
					elseif name == "Workspace" then
						return workspace
					end
					return replicatedStorage
				end,
			},
			require = function(token)
				return if token == CONFIG_TOKEN
					then config
					else if token == CONTRACTS_TOKEN then contracts else error("dependency")
			end,
			Instance = { new = createInstance },
			Enum = enum,
			Vector2 = {
				new = function(x, y)
					return { X = x, Y = y }
				end,
			},
			Vector3 = {
				new = function(x, y, z)
					return { X = x, Y = y, Z = z }
				end,
			},
			UDim2 = {
				new = function(...)
					return { ... }
				end,
				fromOffset = function(...)
					return { ... }
				end,
			},
			Color3 = {
				fromRGB = function(...)
					return { ... }
				end,
			},
			task = {
				defer = function(callback)
					callback()
				end,
			},
		},
		injectGlobals = true,
	})()

local function latest(className)
	for index = #createdInstances, 1, -1 do
		if createdInstances[index].ClassName == className then
			return createdInstances[index]
		end
	end
	return nil
end

controller.start()
assert(boundAction ~= nil and stateSignal:Count() == 1 and lifeSignal:Count() == 1)
assert(string.find(titles[#titles], "OFF", 1, true), "active state must not rely only on color")
boundAction("LK0406PersonalFlashlight", enum.UserInputState.Begin)
assert(firedRequests[1] == true, "client must send only predicted boolean intent")
local light = latest("SpotLight")
assert(light ~= nil and light.Enabled == true, "prediction must present immediately")
assert(light.Shadows == true and light.Brightness == 4.2, "flashlight must visibly illuminate the survival space")

stateSignal:Fire({
	stateId = "Inactive",
	revision = 0,
	resultStatusId = "Rejected",
	rejectionReasonId = "Cooldown",
})
assert(light.Enabled == false, "rejection must reconcile without flashing")
stateSignal:Fire({ stateId = "Active", revision = 2, resultStatusId = "Changed" })
assert(light.Enabled == true)
stateSignal:Fire({ stateId = "Inactive", revision = 1, resultStatusId = "Changed" })
assert(light.Enabled == true, "stale state must not override newer state")
stateSignal:Fire({ stateId = "Active", revision = 3, resultStatusId = "Changed", targetEntityId = "hidden" })
assert(light.Enabled == true, "unsafe payload must be ignored")

attributes.LK_P3_LifeState = "Dead"
lifeSignal:Fire()
assert(light.Enabled == false, "death must stop presentation")
characterRemoving:Fire(character)
assert(latest("Attachment").Destroyed, "character removal must destroy presentation attachment")

controller.stop()
local destroyedAfterStop = destroyedCount
controller.stop()
assert(destroyedCount == destroyedAfterStop, "presentation cleanup must be idempotent")
assert(stateSignal:Count() == 0 and lifeSignal:Count() == 0 and boundAction == nil)

local source = fs.readFile("games/living-kingdoms/src/client/Controllers/PersonalFlashlightController.luau")
assert(string.find(source, "USE_REDUCED_VISUAL_INTENSITY", 1, true))
assert(string.find(source, "createdLight.Shadows = true", 1, true))
assert(not string.find(source, "Raycast", 1, true))
assert(not string.find(source, "VisibilityResolver", 1, true))
assert(not string.find(source, "targetEntityId", 1, true))
assert(string.find(source, "currentCamera.CFrame", 1, true), "the local beam must follow the camera")

print("PersonalFlashlightController: LK-0406 prediction, reconciliation, accessibility, and cleanup passed")
