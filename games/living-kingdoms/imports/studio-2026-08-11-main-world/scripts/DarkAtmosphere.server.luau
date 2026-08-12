local world = workspace:FindFirstChild("LivingKingdomsMainWorld")
local dark = world and world:FindFirstChild("Dark")
if not dark then return end

local RunService = game:GetService("RunService")

-- Hooded statue eerie red glow
local statue = dark:FindFirstChild("HoodedStatue")
if statue then
	local pp = statue.PrimaryPart or statue:FindFirstChildWhichIsA("BasePart")
	if pp then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(140, 0, 0)
		light.Range = 10
		light.Brightness = 1
		light.Parent = pp
	end
end

-- Graveyard mist
local graveyard = dark:FindFirstChild("Graveyard")
if graveyard then
	local pp = graveyard.PrimaryPart or graveyard:FindFirstChildWhichIsA("BasePart")
	if pp then
		local attach = Instance.new("Attachment")
		attach.Parent = pp
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
		pe.Color = ColorSequence.new(Color3.fromRGB(90, 110, 90))
		pe.Rate = 4
		pe.Lifetime = NumberRange.new(3, 5)
		pe.Speed = NumberRange.new(1, 2)
		pe.Size = NumberSequence.new(2, 5)
		pe.Transparency = NumberSequence.new(0.4, 1)
		pe.Parent = attach
	end
end

-- Raven flies in a circle
local raven = dark:FindFirstChild("Raven")
if raven then
	local start = raven:GetPivot()
	local t = 0
	RunService.Heartbeat:Connect(function(dt)
		t = t + dt
		local radius = 6
		local x = start.Position.X + math.cos(t * 0.8) * radius
		local z = start.Position.Z + math.sin(t * 0.8) * radius
		local y = start.Position.Y + math.sin(t * 1.5) * 2
		raven:PivotTo(CFrame.new(x, y, z) * CFrame.Angles(0, -t * 0.8, 0))
	end)
end
