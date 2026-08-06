--!strict

-- Deterministic, bounded environment dressing for expedition graybox rooms.
-- Visual parts are non-authoritative and live beneath the room model so normal
-- expedition teardown removes every fixture automatically.

local Builder = {}

local ROLE_COLORS = {
	Entry = Color3.fromRGB(235, 169, 92),
	Traversal = Color3.fromRGB(107, 178, 184),
	Combat = Color3.fromRGB(224, 118, 72),
	Elite = Color3.fromRGB(184, 104, 255),
	Boss = Color3.fromRGB(92, 169, 255),
	Secret = Color3.fromRGB(167, 255, 216),
}

local function visualPart(name: string, size: Vector3, cframe: CFrame, material: Enum.Material, color: Color3, parent: Instance): Part
	local value = Instance.new("Part")
	value.Name = name
	value.Size = size
	value.CFrame = cframe
	value.Anchored = true
	value.CanCollide = false
	value.CanQuery = false
	value.CanTouch = false
	value.Material = material
	value.Color = color
	value.CastShadow = true
	value.Parent = parent
	return value
end

local function markAnimated(instance: Instance, mode: string, phase: number, speed: number)
	instance:SetAttribute("ExpeditionAnimated", true)
	instance:SetAttribute("AnimationMode", mode)
	instance:SetAttribute("AnimationPhase", phase)
	instance:SetAttribute("AnimationSpeed", speed)
end

local function addWallLamp(parent: Instance, position: Vector3, color: Color3, phase: number)
	local mount = visualPart("WallLamp", Vector3.new(1.2, 3.4, 1.2), CFrame.new(position), Enum.Material.Metal, Color3.fromRGB(55, 61, 67), parent)
	local core = visualPart("LampCore", Vector3.new(0.55, 1.6, 0.55), mount.CFrame, Enum.Material.Neon, color, parent)
	local light = Instance.new("PointLight")
	light.Name = "PracticalLight"
	light.Color = color
	light.Brightness = 2.2
	light.Range = 20
	light.Shadows = true
	light.Parent = core
	markAnimated(core, "Flicker", phase, 1.1)
end

local function addPillar(parent: Instance, position: Vector3, color: Color3, phase: number, height: number)
	visualPart("RunePillar", Vector3.new(3.2, height, 3.2), CFrame.new(position), Enum.Material.Slate, Color3.fromRGB(46, 52, 58), parent)
	local rune = visualPart("RuneBand", Vector3.new(3.5, 0.45, 3.5), CFrame.new(position + Vector3.new(0, height * 0.2, 0)), Enum.Material.Neon, color, parent)
	markAnimated(rune, "Pulse", phase, 0.75)
end

local function addDust(parent: Instance, position: Vector3, color: Color3)
	local anchor = visualPart("DustAnchor", Vector3.new(0.2, 0.2, 0.2), CFrame.new(position), Enum.Material.SmoothPlastic, color, parent)
	anchor.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "DriftingDust"
	emitter.Color = ColorSequence.new(Color3.fromRGB(160, 151, 137), color)
	emitter.LightInfluence = 0.75
	emitter.Rate = 5
	emitter.Lifetime = NumberRange.new(4, 7)
	emitter.Speed = NumberRange.new(0.3, 0.8)
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-12, 12)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.16), NumberSequenceKeypoint.new(1, 0.04) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(1, 1) })
	emitter.Parent = anchor
end

local function addRelicCore(parent: Instance, position: Vector3, color: Color3, phase: number, bossScale: boolean)
	local scale = if bossScale then 2.2 else 1.2
	local pedestal = visualPart("RelicPedestal", Vector3.new(6 * scale, 2, 6 * scale), CFrame.new(position), Enum.Material.Slate, Color3.fromRGB(35, 40, 48), parent)
	local core = visualPart("RelicCore", Vector3.new(2.4 * scale, 2.4 * scale, 2.4 * scale), pedestal.CFrame + Vector3.new(0, 4.5 * scale, 0), Enum.Material.Neon, color, parent)
	core.Shape = Enum.PartType.Ball
	markAnimated(core, "Orbit", phase, if bossScale then 0.55 else 0.8)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = if bossScale then 4 else 2.5
	light.Range = if bossScale then 34 else 22
	light.Shadows = true
	light.Parent = core
end

function Builder.decorate(model: Model, placement: any, seed: number)
	local roleId = placement.RoleId
	local color = ROLE_COLORS[roleId] or ROLE_COLORS.Traversal
	local center = placement.Center
	local size = placement.Size
	local random = Random.new(seed + placement.Index * 7919)
	local visuals = Instance.new("Folder")
	visuals.Name = "EnvironmentVisuals"
	visuals:SetAttribute("VisualTheme", "RuinedSciFantasy")
	visuals.Parent = model

	local halfX = size.x * 0.5 - 4
	local halfZ = size.z * 0.5 - 7
	addWallLamp(visuals, Vector3.new(center.x - halfX, 6, center.z - halfZ * 0.45), color, random:NextNumber(0, 6.28))
	addWallLamp(visuals, Vector3.new(center.x + halfX, 6, center.z + halfZ * 0.45), color, random:NextNumber(0, 6.28))
	addPillar(visuals, Vector3.new(center.x - halfX * 0.72, 4, center.z), color, random:NextNumber(0, 6.28), 8)
	addPillar(visuals, Vector3.new(center.x + halfX * 0.72, 4, center.z), color, random:NextNumber(0, 6.28), 8)
	addDust(visuals, Vector3.new(center.x, 3, center.z))

	if roleId == "Combat" or roleId == "Elite" then
		for side = -1, 1, 2 do
			local barricade = visualPart("BrokenBarricade", Vector3.new(8, 2.2, 1.3), CFrame.new(center.x + side * 12, 1.6, center.z + random:NextNumber(-9, 9)) * CFrame.Angles(0, random:NextNumber(-0.35, 0.35), 0), Enum.Material.CorrodedMetal, Color3.fromRGB(72, 66, 60), visuals)
			barricade:SetAttribute("EnvironmentCover", true)
		end
	end

	if roleId == "Elite" then
		addRelicCore(visuals, Vector3.new(center.x, 1, center.z), color, random:NextNumber(0, 6.28), false)
	elseif roleId == "Boss" then
		addRelicCore(visuals, Vector3.new(center.x, 1, center.z), color, random:NextNumber(0, 6.28), true)
	elseif roleId == "Secret" then
		addRelicCore(visuals, Vector3.new(center.x, 1, center.z), ROLE_COLORS.Secret, random:NextNumber(0, 6.28), false)
	end
end

return table.freeze(Builder)
