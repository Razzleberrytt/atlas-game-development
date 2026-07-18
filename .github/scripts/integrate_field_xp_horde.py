from pathlib import Path
import re


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"expected text missing from {path}: {old[:120]!r}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8", newline="\n")


def regex_once(path: Path, pattern: str, replacement: str) -> None:
    text = path.read_text(encoding="utf-8")
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.DOTALL)
    if count != 1:
        raise SystemExit(f"expected one regex match in {path}: {pattern}")
    path.write_text(updated, encoding="utf-8", newline="\n")


root = Path("games/living-kingdoms")
horde_service = root / "src/server/Systems/HordeExperienceService.luau"
horde_hud = root / "src/client/Controllers/HordeHUDController.luau"
horde_config = root / "src/shared/Config/HordeExperienceConfig.luau"
progression_config = root / "src/shared/Config/RunProgressionConfig.luau"
progression_audit = root / "tests/RunProgressionSourceAudit.test.luau"
horde_audit = root / "tests/HordeVerticalSliceSourceAudit.test.luau"
p5_audit = root / "tests/P5IntegrationValidation.test.luau"
progression_doc = Path("docs/specifications/run-field-xp.md")
horde_doc = Path("docs/specifications/horde-horror-vertical-slice.md")
playtest_doc = Path("docs/production/HORDE-VERTICAL-SLICE-PLAYTEST.md")

# Horde runtime consumes canonical Field XP instead of creating a second XP economy.
replace_once(
    horde_service,
    'local OperativeLifeService = require(script.Parent.OperativeLifeService)\n',
    'local OperativeLifeService = require(script.Parent.OperativeLifeService)\n'
    'local RunProgressionService = require(script.Parent.RunProgressionService)\n',
)
replace_once(horde_service, '\txp: number,\n', '\txp: number,\n\txpForNextLevel: number,\n')
regex_once(
    horde_service,
    r'local function xpForLevel\(level: number\): number\n.*?\nend\n\nlocal function createPlayerState',
    'local function createPlayerState',
)
replace_once(horde_service, '\t\txp = 0,\n', '\t\txp = 0,\n\t\txpForNextLevel = 100,\n')
replace_once(
    horde_service,
    '\t\txpForNextLevel = xpForLevel(state.level),\n',
    '\t\txpForNextLevel = state.xpForNextLevel,\n',
)
regex_once(
    horde_service,
    r'local function addXp\(player: Player, baseAmount: number, isSpecial: boolean\)\n.*?\nend\n\nlocal function chooseWeightedRole',
    '''local function syncProgressionForPlayer(player: Player, state: PlayerState, snapshot: any)
\tlocal previousLevel = state.level
\tstate.level = snapshot.level
\tstate.xp = snapshot.xp
\tstate.xpForNextLevel = snapshot.xpForNextLevel
\tstate.kills = snapshot.squadKills
\tif state.level <= previousLevel then
\t\treturn
\tend
\tstate.unclaimedUpgrades += state.level - previousLevel
\tif #state.pendingChoices == 0 then
\t\tgenerateChoices(player, state)
\tend
\tsetEvent(player, "FIELD LEVEL " .. tostring(state.level) .. " — CHOOSE AN UPGRADE", "LevelUp")
end

local function chooseWeightedRole''',
)
replace_once(horde_service, '\t\taddXp(player, role.Xp, isSpecial)\n', '')
replace_once(
    horde_service,
    'local function spawnLoot(position: Vector3, seed: number, ownerState: PlayerState)\n',
    'local function spawnLoot(position: Vector3, seed: number, ownerState: PlayerState, isSpecial: boolean)\n',
)
regex_once(
    horde_service,
    r'\tlocal chance =\n\t\tmath\.min\(0\.8, HordeConfig\.Loot\.BaseDropChance \+ \(ownerState\.upgradeStacks\["upgrade\.scavenger"\] or 0\) \* 0\.12\)\n',
    '''\tlocal chance = HordeConfig.Loot.BaseDropChance
\t\t+ (ownerState.upgradeStacks["upgrade.scavenger"] or 0) * 0.12
\tif now() < ownerState.surgeUntilServerTimestamp then
\t\tchance += 0.15
\tend
\tif isSpecial then
\t\tchance += (ownerState.upgradeStacks["upgrade.executioner"] or 0) * 0.08
\tend
\tchance = math.min(0.85, chance)
''',
)
replace_once(
    horde_service,
    '\t\tstate.surgeUntilServerTimestamp = now() + HordeConfig.Loot.Kinds.Surge.DurationSeconds\n'
    '\t\thealPlayer(player, 8, "ADRENAL SURGE — XP AMPLIFIED")\n',
    '\t\tstate.surgeUntilServerTimestamp = now() + HordeConfig.Loot.Kinds.Surge.DurationSeconds\n'
    '\t\thealPlayer(player, 8, "ADRENAL SURGE STABILIZED")\n'
    '\t\tlocal granted = grantAmmunition(player, 10)\n'
    '\t\tsetEvent(player, "ADRENAL SURGE — +" .. tostring(granted) .. " AMMO / LOOT MAGNET", "Loot")\n',
)
replace_once(
    horde_service,
    '\t\tspawnLoot(record.root.Position, seed + player.UserId, state)\n',
    '\t\tspawnLoot(record.root.Position, seed + player.UserId, state, isSpecial)\n',
)
replace_once(
    horde_service,
    '''local function addPlayer(player: Player)
\tplayerStates[player] = createPlayerState()
\ttask.defer(function()
''',
    '''local function addPlayer(player: Player)
\tlocal state = createPlayerState()
\tlocal snapshot = RunProgressionService.readSafeSnapshot()
\tstate.level = snapshot.level
\tstate.xp = snapshot.xp
\tstate.xpForNextLevel = snapshot.xpForNextLevel
\tstate.kills = snapshot.squadKills
\tstate.unclaimedUpgrades = math.max(0, snapshot.level - 1)
\tplayerStates[player] = state
\tif state.unclaimedUpgrades > 0 then
\t\tgenerateChoices(player, state)
\tend
\ttask.defer(function()
''',
)
replace_once(
    horde_service,
    '''local function evaluate(serverTimestamp: number)
\tfor _, record in enemyRecords do
''',
    '''local function evaluate(serverTimestamp: number)
\tlocal progressionSnapshot = RunProgressionService.readSafeSnapshot()
\tfor player, state in playerStates do
\t\tsyncProgressionForPlayer(player, state, progressionSnapshot)
\tend
\tfor _, record in enemyRecords do
''',
)

# Role kill text reflects canonical fixed Field XP. Executioner and Surge now improve loot, not XP.
text = horde_config.read_text(encoding="utf-8")
for old in ("Xp = 10", "Xp = 14", "Xp = 16", "Xp = 28", "Xp = 34", "Xp = 60"):
    if old not in text:
        raise SystemExit(f"missing role XP token: {old}")
    text = text.replace(old, "Xp = 20", 1)
text = text.replace(
    'Description = "Special enemies award 25% more XP per stack.",',
    'Description = "Special enemies become 8% more likely to drop loot per stack.",',
    1,
)
horde_config.write_text(text, encoding="utf-8", newline="\n")

# Unified HUD reads canonical Field XP attributes and treats streak as combat feedback only.
replace_once(horde_hud, 'local lastEventSequence = -1\n', 'local lastEventSequence = -1\nlocal lastFieldGainSequence = -1\n')
replace_once(
    horde_hud,
    '''\tlocal level = tonumber(payload.level) or 1
\tlocal xp = tonumber(payload.xp) or 0
\tlocal xpForNext = math.max(1, tonumber(payload.xpForNextLevel) or 1)
\tif levelLabel ~= nil then
\t\tlevelLabel.Text = string.format("LEVEL %02d  //  WEAPON TIER %d", level, tonumber(payload.weaponTier) or 0)
\tend
\tif xpText ~= nil then
\t\txpText.Text = string.format("XP  %d / %d", xp, xpForNext)
\tend
\tsetBar(xpFill, xp / xpForNext)
''',
    '''\tlocal level = readNumberAttribute("LK_HUD_FieldLevel", tonumber(payload.level) or 1)
\tlocal xp = readNumberAttribute("LK_HUD_FieldXp", tonumber(payload.xp) or 0)
\tlocal xpForNext = readNumberAttribute("LK_HUD_FieldXpForNext", tonumber(payload.xpForNextLevel) or 0)
\tif levelLabel ~= nil then
\t\tlevelLabel.Text = string.format("FIELD LEVEL %02d  //  WEAPON TIER %d", level, tonumber(payload.weaponTier) or 0)
\tend
\tif xpText ~= nil then
\t\txpText.Text = if xpForNext <= 0 then "MAX LEVEL" else string.format("XP  %d / %d", xp, xpForNext)
\tend
\tsetBar(xpFill, if xpForNext <= 0 then 1 else xp / xpForNext)
''',
)
replace_once(
    horde_hud,
    '''\t\tstreakLabel.Text = if streak >= 2
\t\t\tthen string.format("MASSACRE x%d  //  %.2fx XP", streak, tonumber(payload.streakMultiplier) or 1)
\t\t\telse ""
''',
    '''\t\tstreakLabel.Text = if streak >= 2 then string.format("MASSACRE x%d", streak) else ""
''',
)
replace_once(
    horde_hud,
    '''\tupdateCombatPresentation(serverTimestamp)
\tupdateSquadPresentation()
\tif eventLabel ~= nil and eventLabel.Visible and serverTimestamp > eventVisibleUntil then
''',
    '''\tupdateCombatPresentation(serverTimestamp)
\tupdateSquadPresentation()
\tlocal fieldGainSequence = readNumberAttribute("LK_HUD_FieldGainSequence", -1)
\tif eventLabel ~= nil and fieldGainSequence > lastFieldGainSequence then
\t\tlastFieldGainSequence = fieldGainSequence
\t\teventLabel.Text = readStringAttribute("LK_HUD_FieldGainText", "")
\t\teventLabel.TextColor3 = Color3.fromRGB(247, 198, 79)
\t\teventLabel.Visible = eventLabel.Text ~= ""
\t\teventVisibleUntil = serverTimestamp + 2
\tend
\tif eventLabel ~= nil and eventLabel.Visible and serverTimestamp > eventVisibleUntil then
''',
)
replace_once(
    horde_hud,
    '\tlastEventSequence = -1\nend\n\nreturn Controller\n',
    '\tlastEventSequence = -1\n\tlastFieldGainSequence = -1\nend\n\nreturn Controller\n',
)

# The progression observer must cover the 96-enemy profiling budget plus corpse overlap.
text = progression_config.read_text(encoding="utf-8")
text = text.replace("MaximumTrackedEnemyModels = 64", "MaximumTrackedEnemyModels = 128", 1)
text = text.replace("<= 64", "<= 128", 1)
progression_config.write_text(text, encoding="utf-8", newline="\n")
replace_once(progression_audit, "config.MaximumTrackedEnemyModels == 64", "config.MaximumTrackedEnemyModels == 128")

# The committed project adds exactly two horde RemoteEvents.
replace_once(
    p5_audit,
    'assert(projectRemoteCount == 7, "the committed remote surface changed size")',
    '''assert(projectRemoteCount == 9, "the committed remote surface changed size")
assert(string.find(project, '"HordeNetwork"', 1, true) ~= nil, "horde remotes require one explicit folder")
assert(string.find(project, '"ChooseUpgrade"', 1, true) ~= nil, "upgrade intent must remain explicit and reviewable")''',
)

# Authority audit: canonical progression owns XP; horde runtime may only observe it.
replace_once(
    horde_audit,
    '\t"EnemyDirectorService.spawnEnemy",\n',
    '\t"EnemyDirectorService.spawnEnemy",\n\t"RunProgressionService.readSafeSnapshot",\n',
)
replace_once(
    horde_audit,
    '\t"clientEnemy",\n',
    '\t"clientEnemy",\n\t"local function addXp",\n',
)

# Documentation follows the measured 96-enemy budget and canonical Field XP owner.
for path in (progression_doc, horde_doc, playtest_doc):
    text = path.read_text(encoding="utf-8")
    text = text.replace("112", "96")
    text = text.replace("at most 64 tracked", "at most 128 tracked")
    text = text.replace("64-model observation ceiling", "128-model observation ceiling")
    text = text.replace("24-living-enemy gameplay cap", "96-living-enemy profiling cap")
    path.write_text(text, encoding="utf-8", newline="\n")

text = horde_doc.read_text(encoding="utf-8")
text = text.replace(
    "Kills award XP to the active squad. Consecutive kills inside the streak window increase an XP multiplier. Level thresholds grow geometrically and each level creates three deterministic server-authored upgrade choices.",
    "The canonical RunProgressionService awards shared Field XP from confirmed deaths. The horde layer observes Field Level changes and creates three deterministic server-authored upgrade choices without minting XP itself. Consecutive kills remain a combat-feedback streak rather than an XP multiplier.",
)
horde_doc.write_text(text, encoding="utf-8", newline="\n")

print("Integrated canonical Field XP with horde upgrades, HUD, loot, tests, and docs")
