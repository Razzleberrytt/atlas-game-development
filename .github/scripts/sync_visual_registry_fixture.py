from pathlib import Path

path = Path("games/living-kingdoms/tests/VisualAssetContractsConfig.test.luau")
text = path.read_text(encoding="utf-8")
needle = '''assertThat(\n\tconfig.ByKey[contracts.AssetKeys.OperativeBaseRig].statusId == contracts.StatusIds.DefaultAvatarPlaceholder,\n\t"operative rig must remain honestly marked as the default-avatar placeholder"\n)\nassertThat(\n\tconfig.ByKey[contracts.AssetKeys.EnemyStandardHostileModel].statusId == contracts.StatusIds.PrimitivePlaceholder,'''
replacement = '''assertThat(\n\tconfig.ByKey[contracts.AssetKeys.OperativeBaseRig].statusId == contracts.StatusIds.DefaultAvatarPlaceholder,\n\t"operative rig must remain honestly marked as the default-avatar placeholder"\n)\nfor _, assetKey in {\n\tcontracts.AssetKeys.ClassCombatSpecialistEquipment,\n\tcontracts.AssetKeys.ClassMedicEquipment,\n\tcontracts.AssetKeys.ClassEngineerEquipment,\n} do\n\tlocal entry = config.ByKey[assetKey]\n\tassertThat(entry.statusId == contracts.StatusIds.PrimitivePlaceholder, "class equipment must record the procedural fallback")\n\tassertThat(\n\t\tentry.runtimeOwnerPath == "src/client/Controllers/ClassSilhouetteController.luau",\n\t\t"class equipment runtime owner must be the silhouette controller"\n\t)\n\tassertThat(entry.expectedRootName == "OperativeClassSilhouette", "class equipment root contract drifted")\n\tassertThat(#entry.requiredAttachmentNames == 0, "procedural class fallback must not claim an authored attachment")\nend\nassertThat(\n\tconfig.ByKey[contracts.AssetKeys.EnemyStandardHostileModel].statusId == contracts.StatusIds.PrimitivePlaceholder,'''
if text.count(needle) != 1:
    raise RuntimeError("visual registry fixture insertion point drifted")
path.write_text(text.replace(needle, replacement, 1), encoding="utf-8")
print("visual registry fixture synchronized")
