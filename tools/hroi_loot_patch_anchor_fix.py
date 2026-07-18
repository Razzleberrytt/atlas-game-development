from __future__ import annotations

from pathlib import Path

path = Path("tools/hroi_loot_integration_patch.py")
source = path.read_text(encoding="utf-8")

old = """progression = replace_once(
    progression,
    '''\ttable.clear(lastUpgradeRequestTimestamps)
\tsyncCombatModifierAttributes()''',
    '''\ttable.clear(lastUpgradeRequestTimestamps)
\ttable.clear(processedFieldIntelRewardIds)
\ttable.clear(fieldIntelRewardOrder)
\tsyncCombatModifierAttributes()''',
    "progression intel reset",
)
progression = replace_once(
    progression,
    '''\ttable.clear(lastUpgradeRequestTimestamps)
\taccumulatedSeconds = 0''',
    '''\ttable.clear(lastUpgradeRequestTimestamps)
\ttable.clear(processedFieldIntelRewardIds)
\ttable.clear(fieldIntelRewardOrder)
\taccumulatedSeconds = 0''',
    "progression intel stop reset",
)"""

new = """progression = replace_once(
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

if source.count(old) != 1:
    raise RuntimeError(f"expected one ambiguous progression reset block, found {source.count(old)}")

path.write_text(source.replace(old, new, 1), encoding="utf-8")
print("Anchored progression start and stop reset patches")
