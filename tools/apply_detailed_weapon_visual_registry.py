from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    file_path = Path(path)
    source = file_path.read_text(encoding="utf-8")
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    file_path.write_text(source.replace(old, new, 1), encoding="utf-8")


contracts_path = "games/living-kingdoms/src/shared/Visual/VisualAssetContracts.luau"
replace_once(
    contracts_path,
    '\tWeaponBasicFirearmModel = "visual.weapon.basic-firearm.model",',
    '''\tWeaponBasicFirearmModel = "visual.weapon.basic-firearm.model",
\tWeaponBreachShotgunModel = "visual.weapon.breach-shotgun.model",
\tWeaponSniperRifleModel = "visual.weapon.sniper-rifle.model",
\tWeaponServicePistolModel = "visual.weapon.service-pistol.model",
\tWeaponSubmachineGunModel = "visual.weapon.submachine-gun.model",''',
    "weapon visual asset keys",
)

registry_path = "games/living-kingdoms/src/shared/Config/VisualAssetConfig.luau"
registry_anchor = '''\trecord(
\t\tKeys.WeaponBasicFirearmModel,
\t\tFamilyIds.Weapon,
\t\tStatusIds.MissingPresentation,
\t\t"src/client/Presentation/BasicFirearmPresentationFactory.luau",
\t\t"Blackwater Support LMG uses a project-original procedural fallback and deterministic source candidate; canonical imported production approval remains pending.",
\t\t"BasicFirearm",
\t\t{ "RightGripAttachment", "Muzzle", "Magazine", "Ejection" },
\t\t"weapon.basic-firearm",
\t\ttrue
\t),'''
registry_insert = registry_anchor + '''
\trecord(
\t\tKeys.WeaponBreachShotgunModel,
\t\tFamilyIds.Weapon,
\t\tStatusIds.PrimitivePlaceholder,
\t\t"src/client/Presentation/BreachShotgunPresentationFactory.luau",
\t\t"Morrow Breach Shotgun uses a dedicated project-original multi-part fallback with a vented heat shield, pump, box magazine, shell rack, and side light; Studio approval and a canonical imported production asset remain pending.",
\t\t"WeaponPresentation",
\t\t{ "RightGripAttachment", "LeftGripAttachment", "Muzzle", "Magazine", "Ejection" },
\t\t"weapon.breach-shotgun",
\t\ttrue
\t),
\trecord(
\t\tKeys.WeaponSniperRifleModel,
\t\tFamilyIds.Weapon,
\t\tStatusIds.PrimitivePlaceholder,
\t\t"src/client/Presentation/SniperRiflePresentationFactory.luau",
\t\t"Longwatch Sniper Rifle uses a dedicated project-original multi-part fallback with a free-floated heavy barrel, full optic stack, working bolt presentation, precision stock, and folded bipod; Studio approval and a canonical imported production asset remain pending.",
\t\t"WeaponPresentation",
\t\t{ "RightGripAttachment", "LeftGripAttachment", "Muzzle", "Magazine", "Ejection" },
\t\t"weapon.sniper-rifle",
\t\ttrue
\t),
\trecord(
\t\tKeys.WeaponServicePistolModel,
\t\tFamilyIds.Weapon,
\t\tStatusIds.PrimitivePlaceholder,
\t\t"src/client/Presentation/ServicePistolPresentationFactory.luau",
\t\t"Vigil Service Pistol uses a dedicated project-original multi-part fallback with a moving detailed slide, visible barrel hood, duty frame, iron sights, magazine assembly, and weapon light; Studio approval and a canonical imported production asset remain pending.",
\t\t"WeaponPresentation",
\t\t{ "RightGripAttachment", "LeftGripAttachment", "Muzzle", "Magazine", "Ejection" },
\t\t"weapon.service-pistol",
\t\ttrue
\t),
\trecord(
\t\tKeys.WeaponSubmachineGunModel,
\t\tFamilyIds.Weapon,
\t\tStatusIds.PrimitivePlaceholder,
\t\t"src/client/Presentation/SubmachineGunPresentationFactory.luau",
\t\t"Razor Compact SMG uses a dedicated project-original multi-part fallback with a short barrel shroud, folding wire stock, curved magazine, reflex optic, vertical foregrip, and identity panels; Studio approval and a canonical imported production asset remain pending.",
\t\t"WeaponPresentation",
\t\t{ "RightGripAttachment", "LeftGripAttachment", "Muzzle", "Magazine", "Ejection" },
\t\t"weapon.submachine-gun",
\t\ttrue
\t),'''
replace_once(registry_path, registry_anchor, registry_insert, "weapon visual registry records")

audit_path = "games/living-kingdoms/tests/WeaponRosterSourceAudit.test.luau"
audit_old = '''assert(contains(factory, "FirearmConfig.BreachShotgun.WeaponId"), "shotgun silhouette required")
assert(contains(factory, "FirearmConfig.SniperRifle.WeaponId"), "sniper silhouette required")
assert(contains(factory, "FirearmConfig.ServicePistol.WeaponId"), "pistol silhouette required")
assert(contains(factory, "FirearmConfig.SubmachineGun.WeaponId"), "SMG silhouette required")'''
audit_new = '''assert(contains(factory, "BreachShotgunPresentationFactory.create()"), "shotgun model routing required")
assert(contains(factory, "SniperRiflePresentationFactory.create()"), "sniper model routing required")
assert(contains(factory, "ServicePistolPresentationFactory.create()"), "pistol model routing required")
assert(contains(factory, "SubmachineGunPresentationFactory.create()"), "SMG model routing required")
assert(not contains(factory, "compactRig"), "scaled-box placeholder factory must stay removed")'''
replace_once(audit_path, audit_old, audit_new, "weapon roster visual routing audit")

visual_test_path = "games/living-kingdoms/tests/VisualAssetContractsConfig.test.luau"
replace_once(
    visual_test_path,
    'assertThat(#config.Registry == 28, "VIS-0101 must inventory the complete initial presentation surface")',
    'assertThat(#config.Registry == 32, "VIS-0101 must inventory the expanded presentation surface")',
    "visual asset registry count",
)
weapon_assertion = '''assertThat(
\tconfig.ByKey[contracts.AssetKeys.WeaponBasicFirearmModel].statusId == contracts.StatusIds.MissingPresentation,
\t"basic firearm must remain honestly marked as missing production presentation"
)'''
weapon_assertion_insert = weapon_assertion + '''
for _, assetKey in
\t{
\t\tcontracts.AssetKeys.WeaponBreachShotgunModel,
\t\tcontracts.AssetKeys.WeaponSniperRifleModel,
\t\tcontracts.AssetKeys.WeaponServicePistolModel,
\t\tcontracts.AssetKeys.WeaponSubmachineGunModel,
\t}
do
\tlocal entry = config.ByKey[assetKey]
\tassertThat(entry.statusId == contracts.StatusIds.PrimitivePlaceholder, "new weapon models must remain honest fallbacks")
\tassertThat(entry.expectedRootName == "WeaponPresentation", "new weapon model root contract drifted")
\tassertThat(#entry.requiredAttachmentNames == 5, "new weapon models require the shared five-locator contract")
end'''
replace_once(visual_test_path, weapon_assertion, weapon_assertion_insert, "new weapon registry assertions")

print("Registered four dedicated weapon models and updated visual inventory audits")
