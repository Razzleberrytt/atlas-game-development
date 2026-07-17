from pathlib import Path

path = Path('.github/scripts/apply_exclusion_walker_windup.py')
text = path.read_text(encoding='utf-8')
marker = '# Enemy director fixture: synchronize contract mock and attack lifecycle assertions.'
call_start = text.index('replace_once(', text.index(marker))
old_start = text.index("    '''", call_start)
old_end = text.index("''',\n    '''", old_start) + 3
current_block = r'''-- Attacks: in range, cooldown-gated, deterministic event IDs, Alive-only.
-- The spawn is fair; the operative then walks into melee range.
reset()
local target, targetRoot = addOperative("operative.player:7", 300, 300)
assert(service.spawnEnemy(request("enemy.biter", 0, 0)).didSpawn)
local attackModel = findCreated("Test Walker")
assert(attackModel ~= nil)
targetRoot.Position = roblox.Vector3.new(3, 2, 0)
now = 10
local swing = service.evaluateAt(now)
assert(swing.attackCommittedCount == 1 and #damageCalls == 1)
assert(damageCalls[1].operativeEntityId == "operative.player:7")
assert(damageCalls[1].expectedRevision == 0)
assert(damageCalls[1].damage.damageEventId == "enemyattack:enemy.biter:operative.player:7:10")
assert(damageCalls[1].damage.damageAmount == walker.AttackDamage)
assert(damageCalls[1].damage.sourceEntityId == "enemy.biter")
assert(damageCalls[1].damage.serverTimestamp == 10)
assert(attackModel:GetAttribute(presentationAttributes.BehaviorStateId) == "Attacking")
assert(attackModel:GetAttribute(presentationAttributes.AttackSequence) == 1)
assert(attackModel:GetAttribute(presentationAttributes.AttackServerTimestamp) == 10)
now = 10 + walker.AttackCooldownSeconds - 0.01
assert(service.evaluateAt(now).attackCommittedCount == 0, "cooldown must block the second swing")
now = 10 + walker.AttackCooldownSeconds
assert(service.evaluateAt(now).attackCommittedCount == 1)
assert(#damageCalls == 2)
assert(attackModel:GetAttribute(presentationAttributes.AttackSequence) == 2)
assert(attackModel:GetAttribute(presentationAttributes.AttackServerTimestamp) == now)
-- A rejected life commit leaves the cooldown unarmed so the swing retries.
rejectNextDamage = true
now += walker.AttackCooldownSeconds
assert(service.evaluateAt(now).attackCommittedCount == 0)
assert(
	attackModel:GetAttribute(presentationAttributes.AttackSequence) == 2,
	"rejected damage must not disclose an attack"
)
now += 0.2
assert(service.evaluateAt(now).attackCommittedCount == 1, "rejected commits must not consume the cooldown")
assert(attackModel:GetAttribute(presentationAttributes.AttackSequence) == 3)
assert(attackModel:GetAttribute(presentationAttributes.AttackServerTimestamp) == now)
-- Downed operatives are not attacked.
target.snapshot.lifeStateId = "Incapacitated"
now += walker.AttackCooldownSeconds
assert(service.evaluateAt(now).attackCommittedCount == 0, "only Alive operatives receive enemy damage")'''
text = text[:old_start] + "    '''" + current_block + "'''" + text[old_end:]
next_call = text.index('\nreplace_once(', call_start + 1)
source_audit = text.index('\n# Source audit now locks truthful windup and runtime bounds.', next_call)
text = text[:next_call] + text[source_audit:]
path.write_text(text, encoding='utf-8')
