local world = workspace:FindFirstChild("LivingKingdomsMainWorld")
local npcFolder = world and world:FindFirstChild("NPCs")
if not npcFolder then return end

-- R6 idle animation
local IDLE_ANIMATION = "rbxassetid://180435571"

local function setupNPC(npc)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local anim = Instance.new("Animation")
	anim.AnimationId = IDLE_ANIMATION
	local track = animator:LoadAnimation(anim)
	track.Looped = true
	track:Play()
end

-- Setup existing NPCs
for _, npc in ipairs(npcFolder:GetChildren()) do
	if npc:IsA("Model") then
		setupNPC(npc)
	end
end

-- Setup NPCs added later
npcFolder.ChildAdded:Connect(function(npc)
	if npc:IsA("Model") then
		setupNPC(npc)
	end
end)
