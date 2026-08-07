--!strict

--[[
	VIS-0105 semantic material language for procedural world presentation.
	These roles are presentation-only and do not change collision, navigation,
	mission truth, interaction state, or server-authored world geometry.
]]

local function role(color: Color3, material: Enum.Material)
	return table.freeze({
		color = color,
		material = material,
	})
end

local WorldMaterialLanguageConfig = {
	Version = "VIS-0105-world-material-v1",
	Roles = table.freeze({
		InfrastructureMetal = role(Color3.fromRGB(183, 197, 187), Enum.Material.Metal),
		InfrastructureSignal = role(Color3.fromRGB(215, 167, 72), Enum.Material.Neon),
		SecurityMetal = role(Color3.fromRGB(184, 184, 161), Enum.Material.Metal),
		SecuritySignal = role(Color3.fromRGB(213, 113, 56), Enum.Material.Neon),
		CampFabric = role(Color3.fromRGB(142, 152, 111), Enum.Material.Fabric),
		CampEmber = role(Color3.fromRGB(135, 82, 55), Enum.Material.SmoothPlastic),
		CrossingWood = role(Color3.fromRGB(156, 126, 88), Enum.Material.Wood),
		CrossingWarning = role(Color3.fromRGB(225, 187, 51), Enum.Material.SmoothPlastic),
		OverlookMetal = role(Color3.fromRGB(155, 154, 142), Enum.Material.Metal),
		OverlookStone = role(Color3.fromRGB(104, 110, 108), Enum.Material.Slate),
	}),
	Rules = table.freeze({
		NoGameplayAuthority = true,
		NoDestinationEncoding = true,
		NoHiddenMissionState = true,
		GeometryPlusMaterialRequired = true,
		ProductionApprovalRequiredForReplacement = true,
	}),
}

return table.freeze(WorldMaterialLanguageConfig)
