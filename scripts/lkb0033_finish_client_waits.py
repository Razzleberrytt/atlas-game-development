from pathlib import Path

ROOT = Path("games/living-kingdoms/src/client")
AUDIT = Path("games/living-kingdoms/tests/ClientBootstrapDependencyWaitSourceAudit.test.luau")


def edit(rel, old, new):
    path = ROOT / rel
    source = path.read_text()
    if old in source:
        path.write_text(source.replace(old, new, 1))
        print("edited", rel)
    elif new not in source:
        raise SystemExit(f"expected source shape missing: {rel}")


edit(
    "Controllers/ClassSilhouetteController.luau",
    '\tlocal humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid")\n\tif not humanoid:IsA("Humanoid") then\n\t\treturn nil\n\tend\n\tlocal torsoName = if humanoid.RigType == Enum.HumanoidRigType.R15 then "UpperTorso" else "Torso"\n\tlocal awaitedTorso = character:WaitForChild(torsoName)\n\treturn if awaitedTorso:IsA("BasePart") then awaitedTorso else nil',
    '\tlocal humanoid = character:FindFirstChildOfClass("Humanoid")\n\tif humanoid == nil then\n\t\thumanoid = character:WaitForChild("Humanoid", NETWORK_WAIT_SECONDS)\n\tend\n\tif humanoid == nil or not humanoid:IsA("Humanoid") then\n\t\treturn nil\n\tend\n\tlocal torsoName = if humanoid.RigType == Enum.HumanoidRigType.R15 then "UpperTorso" else "Torso"\n\tlocal awaitedTorso = character:WaitForChild(torsoName, NETWORK_WAIT_SECONDS)\n\treturn if awaitedTorso ~= nil and awaitedTorso:IsA("BasePart") then awaitedTorso else nil',
)

edit(
    "Controllers/OperativeProgressionPresentationController.luau",
    '\tlocal menu = playerGui:WaitForChild("RPGMenu")\n\tlocal modal = menu:WaitForChild("Modal") :: Frame',
    '\tlocal menu = playerGui:WaitForChild("RPGMenu", NETWORK_WAIT_SECONDS)\n\tassert(menu ~= nil, "RPGMenu did not become available before the client bootstrap timeout")\n\tlocal modal = menu:WaitForChild("Modal", NETWORK_WAIT_SECONDS) :: Frame?\n\tassert(modal ~= nil and modal:IsA("Frame"), "RPGMenu.Modal did not become available before the client bootstrap timeout")',
)

life = ROOT / "Controllers/OperativeLifeWorldPresentationController.luau"
source = life.read_text()
anchor = 'local REVIVE_TARGET_ATTRIBUTE = "LK_P3_ReviveTarget"\n'
if "local BOOTSTRAP_WAIT_SECONDS = 20" not in source:
    source = source.replace(anchor, anchor + "local BOOTSTRAP_WAIT_SECONDS = 20\n", 1)
old = '\tlocal humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid")\n\tif not humanoid:IsA("Humanoid") then\n\t\treturn nil\n\tend\n\tlocal torsoName = if humanoid.RigType == Enum.HumanoidRigType.R15 then "UpperTorso" else "Torso"\n\tlocal awaitedTorso = character:WaitForChild(torsoName)\n\treturn if awaitedTorso:IsA("BasePart") then awaitedTorso else nil'
new = '\tlocal humanoid = character:FindFirstChildOfClass("Humanoid")\n\tif humanoid == nil then\n\t\thumanoid = character:WaitForChild("Humanoid", BOOTSTRAP_WAIT_SECONDS)\n\tend\n\tif humanoid == nil or not humanoid:IsA("Humanoid") then\n\t\treturn nil\n\tend\n\tlocal torsoName = if humanoid.RigType == Enum.HumanoidRigType.R15 then "UpperTorso" else "Torso"\n\tlocal awaitedTorso = character:WaitForChild(torsoName, BOOTSTRAP_WAIT_SECONDS)\n\treturn if awaitedTorso ~= nil and awaitedTorso:IsA("BasePart") then awaitedTorso else nil'
if old in source:
    source = source.replace(old, new, 1)
elif new not in source:
    raise SystemExit("expected life-world torso source shape missing")
life.write_text(source)

for rel in [
    "Controllers/SpecialEncounterTelegraphController.luau",
    "Controllers/EnemyAudioController.luau",
    "Controllers/EnemyPresentationController.luau",
    "Controllers/EnemyImpactPresentationController.luau",
    "Controllers/HordeSpecialTelegraphController.luau",
]:
    path = ROOT / rel
    source = path.read_text()
    anchor = 'local ENEMY_FOLDER_NAME = "EnemyEntities"\n'
    if "local BOOTSTRAP_WAIT_SECONDS = 20" not in source:
        source = source.replace(anchor, anchor + "local BOOTSTRAP_WAIT_SECONDS = 20\n", 1)
    source = source.replace(
        "Workspace:WaitForChild(ENEMY_FOLDER_NAME)",
        "Workspace:WaitForChild(ENEMY_FOLDER_NAME, BOOTSTRAP_WAIT_SECONDS)",
        1,
    )
    var = "found" if "local found = Workspace:WaitForChild" in source else "folder"
    type_assert = f'\tassert({var}:IsA("Folder"), "EnemyEntities must be a Folder")'
    nil_assert = f'\tassert({var} ~= nil, "EnemyEntities did not become available before the client bootstrap timeout")\n'
    if nil_assert.strip() not in source:
        if type_assert not in source:
            raise SystemExit(f"EnemyEntities assertion missing: {rel}")
        source = source.replace(type_assert, nil_assert + type_assert, 1)
    path.write_text(source)
    print("edited", rel)

edit(
    "Controllers/HordeEffectsController.luau",
    '\t\tfound = Workspace:WaitForChild("EnemyEntities")\n\tend\n\tassert(found:IsA("Folder"), "EnemyEntities must be a Folder")',
    '\t\tfound = Workspace:WaitForChild("EnemyEntities", NETWORK_WAIT_SECONDS)\n\tend\n\tassert(found ~= nil, "EnemyEntities did not become available before the client bootstrap timeout")\n\tassert(found:IsA("Folder"), "EnemyEntities must be a Folder")',
)

# Make the durable audit enforce the actual final invariant: no untimed WaitForChild anywhere in client source.
audit = AUDIT.read_text()
start = audit.index('\t\t\t\tlocal networkReceiver')
end_marker = '\t\t\tend\n\t\tend\n\tend\nend\n'
end = audit.index(end_marker, start)
replacement = '''\t\t\t\tlocal waitArguments = string.match(line, ":WaitForChild%(([^%)]+)%)")\n\t\t\t\tif waitArguments ~= nil and string.find(waitArguments, ",", 1, true) == nil then\n\t\t\t\t\trecord(childPath, lineNumber, "WaitForChild(" .. waitArguments .. ")")\n\t\t\t\tend\n'''
audit = audit[:start] + replacement + audit[end:]
AUDIT.write_text(audit)

# Independent final guard for the helper itself.
findings = []
for path in ROOT.rglob("*.luau"):
    for number, line in enumerate(path.read_text().splitlines(), 1):
        if "WaitForChild(" not in line:
            continue
        args = line.split("WaitForChild(", 1)[1].split(")", 1)[0]
        if "," not in args:
            findings.append(f"{path}:{number}: {line.strip()}")
if findings:
    raise SystemExit("untimed client waits remain:\n" + "\n".join(findings))
print("final client WaitForChild scan: 0 untimed waits")
