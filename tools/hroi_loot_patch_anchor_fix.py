from __future__ import annotations

from pathlib import Path

path = Path("tools/hroi_loot_integration_patch.py")
source = path.read_text(encoding="utf-8")

old = '''progression = replace_once(
    progression,
    '''\t table.clear(lastUpgradeRequestTimestamps)
 \t syncCombatModifierAttributes()'''.replace("\t ", "\t"),
    '''\t table.clear(lastUpgradeRequestTimestamps)
 \t table.clear(processedFieldIntelRewardIds)
 \t table.clear(fieldIntelRewardOrder)
 \t syncCombatModifierAttributes()'''.replace("\t ", "\t"),
    "progression intel reset",
)
progression = replace_once(
    progression,
    '''\t table.clear(lastUpgradeRequestTimestamps)
 \t accumulatedSeconds = 0'''.replace("\t ", "\t"),
    '''\t table.clear(lastUpgradeRequestTimestamps)
 \t table.clear(processedFieldIntelRewardIds)
 \t table.clear(fieldIntelRewardOrder)
 \t accumulatedSeconds = 0'''.replace("\t ", "\t"),
    "progression intel stop reset",
)'''

new = '''progression = replace_once(
    progression,
    '''\t table.clear(trackedLifeStates)
 \t table.clear(upgradeStacks)
 \t table.clear(pendingChoiceIds)
 \t table.clear(lastUpgradeRequestTimestamps)
 \t syncCombatModifierAttributes()

 \t readStateRemote.OnServerInvoke'''.replace("\t ", "\t"),
    '''\t table.clear(trackedLifeStates)
 \t table.clear(upgradeStacks)
 \t table.clear(pendingChoiceIds)
 \t table.clear(lastUpgradeRequestTimestamps)
 \t table.clear(processedFieldIntelRewardIds)
 \t table.clear(fieldIntelRewardOrder)
 \t syncCombatModifierAttributes()

 \t readStateRemote.OnServerInvoke'''.replace("\t ", "\t"),
    "progression intel start reset",
)
progression = replace_once(
    progression,
    '''\t table.clear(trackedLifeStates)
 \t table.clear(upgradeStacks)
 \t table.clear(pendingChoiceIds)
 \t table.clear(lastUpgradeRequestTimestamps)
 \t syncCombatModifierAttributes()
 \t accumulatedSeconds = 0'''.replace("\t ", "\t"),
    '''\t table.clear(trackedLifeStates)
 \t table.clear(upgradeStacks)
 \t table.clear(pendingChoiceIds)
 \t table.clear(lastUpgradeRequestTimestamps)
 \t table.clear(processedFieldIntelRewardIds)
 \t table.clear(fieldIntelRewardOrder)
 \t syncCombatModifierAttributes()
 \t accumulatedSeconds = 0'''.replace("\t ", "\t"),
    "progression intel stop reset",
)'''

if source.count(old) != 1:
    raise RuntimeError(f"expected one ambiguous progression reset block, found {source.count(old)}")

path.write_text(source.replace(old, new, 1), encoding="utf-8")
print("Anchored progression start and stop reset patches")
