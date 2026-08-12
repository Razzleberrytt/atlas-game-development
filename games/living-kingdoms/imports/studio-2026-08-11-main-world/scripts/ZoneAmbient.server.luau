local world = workspace:FindFirstChild("LivingKingdomsMainWorld")
local zones = world and world:FindFirstChild("Zones")
local village = world and world:FindFirstChild("Village")
local forest = world and world:FindFirstChild("Forest")

-- Fireflies in the forest
local forestPlat = zones and zones:FindFirstChild("ForestPlatform")
if forestPlat then
	local attach = Instance.new("Attachment")
	attach.Position = Vector3.new(0, 5, 0)
	attach.Parent = forestPlat
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(Color3.fromRGB(180, 255, 120))
	pe.Rate = 8
	pe.Lifetime = NumberRange.new(2, 4)
	pe.Speed = NumberRange.new(1, 3)
	pe.Size = NumberSequence.new(0.3, 0.1)
	pe.SpreadAngle = Vector2.new(360, 360)
	pe.Parent = attach
end

-- Warm glow on the tavern
local tavern = village and village:FindFirstChild("Tavern")
if tavern then
	local pp = tavern.PrimaryPart or tavern:FindFirstChildWhichIsA("BasePart")
	if pp then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 190, 90)
		light.Range = 14
		light.Brightness = 1.2
		light.Parent = pp
	end
end

-- Forge glow on the blacksmith
local forge = village and village:FindFirstChild("BlacksmithForge")
if forge then
	local pp = forge.PrimaryPart or forge:FindFirstChildWhichIsA("BasePart")
	if pp then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 120, 40)
		light.Range = 12
		light.Brightness = 1.5
		light.Parent = pp
	end
end

-- Helper to add a particle emitter to a platform
local function addEmitter(platformName, color, rate, size, speed)
	local plat = zones and zones:FindFirstChild(platformName)
	if not plat then return end
	local attach = Instance.new("Attachment")
	attach.Position = Vector3.new(0, 5, 0)
	attach.Parent = plat
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(color)
	pe.Rate = rate
	pe.Lifetime = NumberRange.new(2, 4)
	pe.Speed = NumberRange.new(1, speed)
	pe.Size = NumberSequence.new(size, size * 0.3)
	pe.SpreadAngle = Vector2.new(360, 360)
	pe.Parent = attach
end

-- Geyser steam (white rising steam)
addEmitter("GeyserPlatform", Color3.fromRGB(230, 235, 240), 12, 0.8, 3)

-- Lava embers on volcanic
addEmitter("VolcanicPlatform", Color3.fromRGB(255, 120, 30), 10, 0.5, 2)

-- Crystal sparkle on crystal cave
addEmitter("CrystalPlatform", Color3.fromRGB(160, 120, 255), 8, 0.4, 1.5)

-- Ice sparkle on snow
addEmitter("SnowPlatform", Color3.fromRGB(200, 230, 255), 6, 0.3, 1.5)

-- Meadow fireflies (golden)
addEmitter("MeadowPlatform", Color3.fromRGB(255, 230, 140), 10, 0.4, 2)

-- Mushroom spores (blue bioluminescent)
addEmitter("MushroomPlatform", Color3.fromRGB(120, 200, 255), 8, 0.4, 1.5)

-- Sky mist (soft white)
addEmitter("SkyPlatform", Color3.fromRGB(240, 245, 255), 6, 0.6, 1)

-- Ocean shimmer (aqua)
addEmitter("OceanPlatform", Color3.fromRGB(120, 220, 255), 8, 0.4, 1.5)

-- Swamp mist (murky green)
addEmitter("SwampPlatform", Color3.fromRGB(140, 180, 120), 8, 0.5, 1.5)

-- Lavender pollen (soft purple)
addEmitter("LavenderPlatform", Color3.fromRGB(200, 160, 255), 8, 0.4, 1.5)

-- Cherry blossom petals (pink)
addEmitter("CherryPlatform", Color3.fromRGB(255, 180, 200), 10, 0.4, 1.5)

-- Tundra frost (icy white)
addEmitter("TundraPlatform", Color3.fromRGB(210, 230, 255), 6, 0.3, 1.5)

-- Jungle humidity (green)
addEmitter("JunglePlatform", Color3.fromRGB(150, 220, 120), 8, 0.5, 1.5)

-- Autumn leaves (orange)
addEmitter("AutumnPlatform", Color3.fromRGB(255, 160, 60), 8, 0.4, 1.5)

-- Ice sparkle
addEmitter("IcePlatform", Color3.fromRGB(190, 220, 255), 6, 0.3, 1.5)

-- Ruins dust (grey)
addEmitter("RuinsPlatform", Color3.fromRGB(200, 200, 200), 6, 0.4, 1.5)

-- Canyon dust (warm sand)
addEmitter("CanyonPlatform", Color3.fromRGB(220, 180, 130), 6, 0.4, 1.5)

-- Bamboo mist (soft green)
addEmitter("BambooPlatform", Color3.fromRGB(170, 220, 150), 6, 0.4, 1.5)

-- Beach sea spray (white)
addEmitter("BeachPlatform", Color3.fromRGB(220, 240, 255), 6, 0.4, 1.5)

-- Desert heat shimmer (pale gold)
addEmitter("DesertPlatform", Color3.fromRGB(255, 220, 160), 5, 0.4, 1.5)

-- Coral bubbles (aqua)
addEmitter("CoralPlatform", Color3.fromRGB(140, 230, 255), 8, 0.4, 2)

-- Crystal desert shimmer (pale gold)
addEmitter("CrystalDesertPlatform", Color3.fromRGB(255, 240, 200), 6, 0.4, 1.5)

-- Geothermal steam (white)
addEmitter("GeothermalPlatform", Color3.fromRGB(235, 240, 245), 12, 0.8, 3)

-- Oasis water sparkle (blue)
addEmitter("OasisPlatform", Color3.fromRGB(150, 210, 255), 8, 0.4, 1.5)
