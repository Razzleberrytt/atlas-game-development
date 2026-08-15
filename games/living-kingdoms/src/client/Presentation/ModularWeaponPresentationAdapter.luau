--!strict

-- Mounts generated modular weapon geometry onto the existing presentation rig.
-- The procedural rig remains the mechanical skeleton for grip, bolt, magazine,
-- recoil, reload, muzzle, and ejection behavior. This adapter owns visuals only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModularAssetResolver = require(ReplicatedStorage.Shared.Assets.ModularAssetResolver)

export type WeaponPresentationRig = {
	model: Model,
	root: BasePart,
	boltMotor: Motor6D,
	magazineMotor: Motor6D,
	muzzleAttachment: Attachment,
	rightGripAttachment: Attachment,
	muzzleFlash: BasePart,
}

local Adapter = {}

local MIN_SOCKET_SPAN = 0.05
local MIN_SCALE = 0.05
local MAX_SCALE = 4
local SHELL_NAME = "ModularWeaponShell"

local function findAttachment(root: Instance, name: string): Attachment?
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("Attachment") and descendant.Name == name then
			return descendant
		end
	end
	return nil
end

local function connectedParts(model: Model, start: BasePart?): { [BasePart]: boolean }
	local connected: { [BasePart]: boolean } = {}
	if start == nil then
		return connected
	end

	local constraints = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("WeldConstraint") then
			table.insert(constraints, descendant)
		end
	end

	local queue = { start }
	connected[start] = true
	local cursor = 1
	while cursor <= #queue do
		local current = queue[cursor]
		cursor += 1
		for _, constraint in ipairs(constraints) do
			local other: BasePart? = nil
			if constraint.Part0 == current then
				other = constraint.Part1
			elseif constraint.Part1 == current then
				other = constraint.Part0
			end
			if other ~= nil and other:IsDescendantOf(model) and connected[other] ~= true then
				connected[other] = true
				table.insert(queue, other)
			end
		end
	end
	return connected
end

local function preserveMechanicalParts(rig: WeaponPresentationRig): { [BasePart]: boolean }
	local preserve: { [BasePart]: boolean } = {
		[rig.root] = true,
		[rig.muzzleFlash] = true,
	}
	for part in pairs(connectedParts(rig.model, rig.boltMotor.Part1)) do
		preserve[part] = true
	end
	for part in pairs(connectedParts(rig.model, rig.magazineMotor.Part1)) do
		preserve[part] = true
	end
	return preserve
end

local function hideProceduralShell(rig: WeaponPresentationRig)
	local preserve = preserveMechanicalParts(rig)
	for _, descendant in ipairs(rig.model:GetDescendants()) do
		if descendant:IsA("BasePart") and preserve[descendant] ~= true then
			descendant.LocalTransparencyModifier = 1
		end
	end
end

local function stripSourceIdentity(instance: Instance)
	instance:SetAttribute("AssetId", nil)
	instance:SetAttribute("PackId", nil)
	instance:SetAttribute("CatalogVersion", nil)
	instance:SetAttribute("GeneratedPrototype", nil)
end

local function prepareShell(shell: Model, sourceAssetId: string)
	stripSourceIdentity(shell)
	shell.Name = SHELL_NAME
	shell:SetAttribute("SourceAssetId", sourceAssetId)
	shell:SetAttribute("PresentationOnly", true)
	shell:SetAttribute("ModularWeaponShell", true)

	for _, descendant in ipairs(shell:GetDescendants()) do
		stripSourceIdentity(descendant)
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end
end

local function fitShellToRig(shell: Model, rig: WeaponPresentationRig): (boolean, number)
	local sourceGrip = findAttachment(shell, "Grip")
	local sourceMuzzle = findAttachment(shell, "Muzzle")
	if sourceGrip == nil or sourceMuzzle == nil then
		return false, 1
	end

	local sourceSpan = (sourceMuzzle.WorldPosition - sourceGrip.WorldPosition).Magnitude
	local targetSpan = (rig.muzzleAttachment.WorldPosition - rig.rightGripAttachment.WorldPosition).Magnitude
	if sourceSpan < MIN_SOCKET_SPAN or targetSpan < MIN_SOCKET_SPAN then
		return false, 1
	end

	local scale = math.clamp(targetSpan / sourceSpan, MIN_SCALE, MAX_SCALE)
	shell:ScaleTo(scale)

	-- ScaleTo changes attachment locations, so resolve the frames after scaling.
	sourceGrip = findAttachment(shell, "Grip")
	sourceMuzzle = findAttachment(shell, "Muzzle")
	if sourceGrip == nil or sourceMuzzle == nil then
		return false, scale
	end

	local sourceUp = if shell.PrimaryPart ~= nil then shell.PrimaryPart.CFrame.UpVector else Vector3.yAxis
	local targetUp = rig.root.CFrame.UpVector
	local sourceFrame = CFrame.lookAt(sourceGrip.WorldPosition, sourceMuzzle.WorldPosition, sourceUp)
	local targetFrame = CFrame.lookAt(
		rig.rightGripAttachment.WorldPosition,
		rig.muzzleAttachment.WorldPosition,
		targetUp
	)
	local alignment = targetFrame * sourceFrame:Inverse()
	shell:PivotTo(alignment * shell:GetPivot())
	return true, scale
end

local function weldShellToRoot(shell: Model, root: BasePart)
	for _, descendant in ipairs(shell:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Name = "ModularShellWeld"
			weld.Part0 = root
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
end

function Adapter.Apply(rig: WeaponPresentationRig, assetId: string): boolean
	if assetId == "" then
		return false
	end
	if rig.model:FindFirstChild(SHELL_NAME) ~= nil then
		return true
	end

	local generatedRoot = ModularAssetResolver.GetGeneratedRoot(ReplicatedStorage)
	if generatedRoot == nil then
		return false
	end

	local clone = ModularAssetResolver.CloneByAssetId(generatedRoot, assetId)
	if clone == nil or not clone:IsA("Model") then
		if clone ~= nil then
			clone:Destroy()
		end
		return false
	end
	local shell = clone :: Model
	if shell.PrimaryPart == nil then
		shell:Destroy()
		return false
	end

	local fitted, scale = fitShellToRig(shell, rig)
	if not fitted then
		shell:Destroy()
		return false
	end

	prepareShell(shell, assetId)
	weldShellToRoot(shell, rig.root)
	hideProceduralShell(rig)
	shell.Parent = rig.model

	rig.model:SetAttribute("ModularWeaponAssetId", assetId)
	rig.model:SetAttribute("ModularWeaponScale", scale)
	rig.model:SetAttribute("VisualStatus", "ModularGeneratedAsset")
	return true
end

return table.freeze(Adapter)
