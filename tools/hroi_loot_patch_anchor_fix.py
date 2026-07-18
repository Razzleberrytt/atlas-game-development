from __future__ import annotations

from pathlib import Path

path = Path("tools/hroi_loot_integration_patch.py")
source = path.read_text(encoding="utf-8")

first_label = '"progression intel reset"'
second_label = '"progression intel stop reset"'
if source.count(first_label) != 1 or source.count(second_label) != 1:
    raise RuntimeError("expected unique progression reset patch labels")

first_label_index = source.index(first_label)
start = source.rfind("progression = replace_once(", 0, first_label_index)
second_label_index = source.index(second_label, first_label_index)
end = source.index("\n)", second_label_index) + 2
if start < 0 or end <= start:
    raise RuntimeError("could not bound the progression reset patch region")

replacement = """progression = replace_once(
    progression,
    '''\ttable.clear(trackedLifeStates)
\ttable.clear(upgradeStacks)
\ttable.clear(pendingChoiceIds)
\ttable.clear(lastUpgradeRequestTimestamps)
\tsyncCombatModifierAttributes()

\treadStateRemote.OnServerInvoke''',
    '''\ttable.clear(trackedLifeStates)
\ttable.clear(upgradeStacks)
\ttable.clear(pendingChoiceIds)
\ttable.clear(lastUpgradeRequestTimestamps)
\ttable.clear(processedFieldIntelRewardIds)
\ttable.clear(fieldIntelRewardOrder)
\tsyncCombatModifierAttributes()

\treadStateRemote.OnServerInvoke''',
    "progression intel start reset",
)
progression = replace_once(
    progression,
    '''\ttable.clear(trackedLifeStates)
\ttable.clear(upgradeStacks)
\ttable.clear(pendingChoiceIds)
\ttable.clear(lastUpgradeRequestTimestamps)
\tsyncCombatModifierAttributes()
\taccumulatedSeconds = 0''',
    '''\ttable.clear(trackedLifeStates)
\ttable.clear(upgradeStacks)
\ttable.clear(pendingChoiceIds)
\ttable.clear(lastUpgradeRequestTimestamps)
\ttable.clear(processedFieldIntelRewardIds)
\ttable.clear(fieldIntelRewardOrder)
\tsyncCombatModifierAttributes()
\taccumulatedSeconds = 0''',
    "progression intel stop reset",
)"""

path.write_text(source[:start] + replacement + source[end:], encoding="utf-8")
print("Anchored progression start and stop reset patches")
