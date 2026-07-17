from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    content = file_path.read_text(encoding="utf-8")
    count = content.count(old)
    if count != 1:
        raise RuntimeError(f"expected one fixture replacement in {path}, found {count}")
    file_path.write_text(content.replace(old, new, 1), encoding="utf-8")


replace_once(
    "games/living-kingdoms/tests/EnemyBehaviorResolver.test.luau",
    '''assert(first.shouldAttack == second.shouldAttack)
assert((first.attack :: any).damageEventId == (second.attack :: any).damageEventId)''',
    '''assert(first.shouldAttack == second.shouldAttack and not first.shouldAttack)
assert(first.behaviorStateIdAfter == second.behaviorStateIdAfter and first.behaviorStateIdAfter == "WindingUp")
assert(first.attackWindupActionId == second.attackWindupActionId and first.attackWindupActionId == "Begin")
assert(first.attack == nil and second.attack == nil)''',
)

replace_once(
    "games/living-kingdoms/tests/EnemyDirectorService.test.luau",
    '''service.beginOperationPressure()
now = 501
assert(service.evaluateAt(now).attackCommittedCount == 1, "pressure restart must wake stood-down enemies")
assert(standTarget.snapshot.lifeStateId == "Alive")''',
    '''service.beginOperationPressure()
now = 501
assert(service.evaluateAt(now).attackCommittedCount == 0, "pressure restart must begin a disclosed windup")
local wokeModel = findCreated("Test Walker")
assert(wokeModel ~= nil and wokeModel:GetAttribute(presentationAttributes.BehaviorStateId) == "WindingUp")
now += walker.AttackWindupSeconds
assert(service.evaluateAt(now).attackCommittedCount == 1, "woken enemies commit only after windup")
assert(standTarget.snapshot.lifeStateId == "Alive")''',
)
