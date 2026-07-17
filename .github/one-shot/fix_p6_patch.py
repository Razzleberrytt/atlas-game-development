from pathlib import Path

path = Path(".github/one-shot/p6_0105_patch.py")
text = path.read_text()
old = '''replace_once(
    contracts,
    '\\t| "ReloadInterrupted"\\n',
    '\\t| "ReloadInterrupted"\\n\\t| "AmmunitionState"\\n\\t| "AmmunitionCollected"\\n',
)
'''
new = '''replace_once(
    contracts,
    'export type CombatPresentationMessageKindId =\\n\\t"TargetSelected"\\n\\t| "TargetCleared"\\n\\t| "ShotFired"\\n\\t| "ReloadStarted"\\n\\t| "ReloadCompleted"\\n\\t| "ReloadInterrupted"\\n',
    'export type CombatPresentationMessageKindId =\\n\\t"TargetSelected"\\n\\t| "TargetCleared"\\n\\t| "ShotFired"\\n\\t| "ReloadStarted"\\n\\t| "ReloadCompleted"\\n\\t| "ReloadInterrupted"\\n\\t| "AmmunitionState"\\n\\t| "AmmunitionCollected"\\n',
)
'''
if text.count(old) != 1:
    raise RuntimeError(f"expected one broad contract anchor, found {text.count(old)}")
text = text.replace(old, new, 1)
id_old = '''replace_once(
    contracts,
    '\\tReloadInterrupted = "ReloadInterrupted",\\n',
    '\\tReloadInterrupted = "ReloadInterrupted",\\n\\tAmmunitionState = "AmmunitionState",\\n\\tAmmunitionCollected = "AmmunitionCollected",\\n',
)
'''
id_new = '''replace_once(
    contracts,
    'CombatContracts.PresentationMessageKindIds = table.freeze({\\n\\tTargetSelected = "TargetSelected",\\n\\tTargetCleared = "TargetCleared",\\n\\tShotFired = "ShotFired",\\n\\tReloadStarted = "ReloadStarted",\\n\\tReloadCompleted = "ReloadCompleted",\\n\\tReloadInterrupted = "ReloadInterrupted",\\n})',
    'CombatContracts.PresentationMessageKindIds = table.freeze({\\n\\tTargetSelected = "TargetSelected",\\n\\tTargetCleared = "TargetCleared",\\n\\tShotFired = "ShotFired",\\n\\tReloadStarted = "ReloadStarted",\\n\\tReloadCompleted = "ReloadCompleted",\\n\\tReloadInterrupted = "ReloadInterrupted",\\n\\tAmmunitionState = "AmmunitionState",\\n\\tAmmunitionCollected = "AmmunitionCollected",\\n})',
)
'''
if text.count(id_old) != 1:
    raise RuntimeError(f"expected one broad presentation ID anchor, found {text.count(id_old)}")
text = text.replace(id_old, id_new, 1)
alignment = '\\tammunitionLabel.TextXAlignment = Enum.TextXAlignment.Center\\n'
if text.count(alignment) != 1:
    raise RuntimeError(f"expected one temporary alignment assignment, found {text.count(alignment)}")
text = text.replace(alignment, "", 1)
diagnostic_old = '''    text = file_path.read_text()
    if text.count(old) != 1:
'''
diagnostic_new = '''    text = file_path.read_text()
    print(f"PATCH {path}: {old[:80]!r}")
    if text.count(old) != 1:
'''
if text.count(diagnostic_old) != 1:
    raise RuntimeError(f"expected one diagnostic anchor, found {text.count(diagnostic_old)}")
path.write_text(text.replace(diagnostic_old, diagnostic_new, 1))
