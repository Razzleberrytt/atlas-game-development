local RunService = game:GetService("RunService")

-- Collect all fire/flame parts and flags
local fireParts = {}
local flags = {}

for _, part in ipairs(workspace:GetDescendants()) do
	if part:IsA("BasePart") then
		if part.Name == "Fire" or part.Name == "Flame" then
			fireParts[#fireParts + 1] = part
		elseif part.Name == "Flag" then
			flags[#flags + 1] = part
		end
	end
end

-- Handle props added later
workspace.DescendantAdded:Connect(function(part)
	if part:IsA("BasePart") then
		if part.Name == "Fire" or part.Name == "Flame" then
			fireParts[#fireParts + 1] = part
		elseif part.Name == "Flag" then
			flags[#flags + 1] = part
		end
	end
end)

RunService.Heartbeat:Connect(function()
	local t = os.clock()

	-- Flicker fire lights
	for _, fire in ipairs(fireParts) do
		local light = fire:FindFirstChildOfClass("PointLight")
		if light then
			light.Brightness = 1.5 + math.sin(t * 9 + fire.Position.X * 0.5) * 0.6
		end
	end

	-- Wave flags
	for _, flag in ipairs(flags) do
		local pivot = flag:GetPivot()
		local sway = math.sin(t * 2.5 + pivot.Position.X) * 0.18
		flag:PivotTo(pivot * CFrame.Angles(0, sway, 0))
	end
end)
