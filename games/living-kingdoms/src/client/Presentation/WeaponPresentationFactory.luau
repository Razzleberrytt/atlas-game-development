--!strict

--[[
	Client-only router for the complete firearm presentation roster. Every
	selectable weapon owns a dedicated project-original mechanical rig. When the
	generated modular library is available, a modular weapon shell is mounted on
	that rig without changing grip, recoil, reload, muzzle, or combat authority.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)
local BasicFirearmPresentationFactory = require(script.Parent.BasicFirearmPresentationFactory)
local BreachShotgunPresentationFactory = require(script.Parent.BreachShotgunPresentationFactory)
local LightMachineGunPresentationFactory = require(script.Parent.LightMachineGunPresentationFactory)
local ModularWeaponPresentationAdapter = require(script.Parent.ModularWeaponPresentationAdapter)
local ModularWeaponPresentationConfig = require(script.Parent.ModularWeaponPresentationConfig)
local ServicePistolPresentationFactory = require(script.Parent.ServicePistolPresentationFactory)
local SniperRiflePresentationFactory = require(script.Parent.SniperRiflePresentationFactory)
local SubmachineGunPresentationFactory = require(script.Parent.SubmachineGunPresentationFactory)
local WeaponVisualModelBuilder = require(script.Parent.WeaponVisualModelBuilder)

export type WeaponPresentationRig = WeaponVisualModelBuilder.WeaponVisualModelRig

local Factory = {}

local function createBasicWeapon(weaponId: string): WeaponPresentationRig
	local basic = BasicFirearmPresentationFactory.create()
	basic.model.Name = "WeaponPresentation"
	basic.model:SetAttribute("GameplayWeaponId", weaponId)
	basic.model:SetAttribute("PresentationOnly", true)
	return table.freeze({
		model = basic.model,
		root = basic.root,
		boltMotor = basic.boltMotor,
		magazineMotor = basic.magazineMotor,
		boltRestC0 = basic.boltRestC0,
		magazineRestC0 = basic.magazineRestC0,
		muzzleAttachment = basic.muzzleAttachment,
		rightGripAttachment = basic.rightGripAttachment,
		leftGripAttachment = basic.leftGripAttachment,
		ejectionAttachment = basic.ejectionAttachment,
		muzzleFlash = basic.muzzleFlash,
		muzzleLight = basic.muzzleLight,
		gripC0 = CFrame.new(0, -0.55, -0.15) * CFrame.Angles(math.rad(-8), math.rad(90), math.rad(-90)),
	})
end

local function createProceduralRig(weaponId: string): WeaponPresentationRig
	if weaponId == FirearmConfig.BasicFirearm.WeaponId then
		return createBasicWeapon(weaponId)
	elseif weaponId == FirearmConfig.LightMachineGun.WeaponId then
		return LightMachineGunPresentationFactory.create()
	elseif weaponId == FirearmConfig.BreachShotgun.WeaponId then
		return BreachShotgunPresentationFactory.create()
	elseif weaponId == FirearmConfig.SniperRifle.WeaponId then
		return SniperRiflePresentationFactory.create()
	elseif weaponId == FirearmConfig.ServicePistol.WeaponId then
		return ServicePistolPresentationFactory.create()
	elseif weaponId == FirearmConfig.SubmachineGun.WeaponId then
		return SubmachineGunPresentationFactory.create()
	end
	error("weapon presentation requires a configured weapon: " .. weaponId)
end

function Factory.create(weaponId: string): WeaponPresentationRig
	local rig = createProceduralRig(weaponId)
	local modularAssetId = ModularWeaponPresentationConfig.GetAssetId(weaponId)
	if modularAssetId ~= nil then
		ModularWeaponPresentationAdapter.Apply(rig, modularAssetId)
	end
	return rig
end

return table.freeze(Factory)
