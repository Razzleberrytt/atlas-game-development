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
path.write_text(text.replace(old, new, 1))
