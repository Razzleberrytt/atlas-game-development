from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    file_path = Path(path)
    source = file_path.read_text(encoding="utf-8")
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    file_path.write_text(source.replace(old, new, 1), encoding="utf-8")


controller_path = "games/living-kingdoms/src/client/Controllers/WeaponPresentationController.luau"
replace_once(
    controller_path,
    'local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)\n',
    'local FirearmConfig = require(ReplicatedStorage.Shared.Config.FirearmConfig)\nlocal WeaponFeelConfig = require(ReplicatedStorage.Shared.Config.WeaponFeelConfig)\n',
    "controller feel config dependency",
)
replace_once(
    controller_path,
    'type WeaponPresentationRig = WeaponPresentationFactory.WeaponPresentationRig\n',
    'type WeaponFeelProfile = WeaponFeelConfig.WeaponFeelProfile\ntype WeaponPresentationRig = WeaponPresentationFactory.WeaponPresentationRig\n',
    "controller feel profile type",
)
replace_once(
    controller_path,
    'local BOLT_BACK_OFFSET = CFrame.new(-0.2, 0, 0)\nlocal MAGAZINE_OUT_OFFSET = CFrame.new(0.22, 0, -0.75) * CFrame.Angles(0, 0, math.rad(8))\n',
    '',
    "remove shared motion constants",
)
replace_once(
    controller_path,
    '''local function localRig(): WeaponPresentationRig?
\tlocal localPlayer = Players.LocalPlayer
\tif localPlayer == nil then
\t\treturn nil
\tend
\treturn state.rigs[localPlayer]
end
''',
    '''local function localRig(): WeaponPresentationRig?
\tlocal localPlayer = Players.LocalPlayer
\tif localPlayer == nil then
\t\treturn nil
\tend
\treturn state.rigs[localPlayer]
end

local function localGripMotor(): Motor6D?
\tlocal localPlayer = Players.LocalPlayer
\tif localPlayer == nil then
\t\treturn nil
\tend
\treturn state.gripMotors[localPlayer]
end

local function profileForRig(rig: WeaponPresentationRig): WeaponFeelProfile
\treturn WeaponFeelConfig.get(rig.model:GetAttribute("GameplayWeaponId")) or WeaponFeelConfig.Default
end

local function boltBackOffset(profile: WeaponFeelProfile): CFrame
\treturn CFrame.new(-profile.BoltTravelStuds, 0, 0)
end

local function gripKickOffset(profile: WeaponFeelProfile): CFrame
\treturn CFrame.new(-profile.GripKickBackStuds, 0, profile.GripKickUpStuds)
\t\t* CFrame.Angles(0, math.rad(-profile.GripKickDegrees), 0)
end

local function magazineOutOffset(profile: WeaponFeelProfile): CFrame
\treturn CFrame.new(profile.MagazineOutX, 0, profile.MagazineOutZ)
\t\t* CFrame.Angles(0, 0, math.rad(profile.MagazineRollDegrees))
end
''',
    "controller profile helpers",
)
replace_once(
    controller_path,
    '''\t\tcancelTween("Bolt")
\t\tcancelTween("Magazine")
''',
    '''\t\tcancelTween("Bolt")
\t\tcancelTween("Magazine")
\t\tcancelTween("Grip")
''',
    "controller grip cleanup",
)
replace_once(
    controller_path,
    '''local function lockBoltOpen(durationSeconds: number)
\tlocal rig = localRig()
\tif rig == nil then
\t\treturn
\tend
\tplayMotorTween(
\t\t"Bolt",
\t\trig.boltMotor,
\t\tdurationSeconds,
\t\trig.boltRestC0 * BOLT_BACK_OFFSET,
\t\tEnum.EasingStyle.Quad,
\t\tEnum.EasingDirection.Out
\t)
end
''',
    '''local function resetGrip(durationSeconds: number)
\tlocal rig = localRig()
\tlocal gripMotor = localGripMotor()
\tif rig == nil or gripMotor == nil then
\t\treturn
\tend
\tplayMotorTween(
\t\t"Grip",
\t\tgripMotor,
\t\tdurationSeconds,
\t\trig.gripC0,
\t\tEnum.EasingStyle.Quad,
\t\tEnum.EasingDirection.Out
\t)
end

local function lockBoltOpen(durationSeconds: number)
\tlocal rig = localRig()
\tif rig == nil then
\t\treturn
\tend
\tlocal profile = profileForRig(rig)
\tplayMotorTween(
\t\t"Bolt",
\t\trig.boltMotor,
\t\tdurationSeconds,
\t\trig.boltRestC0 * boltBackOffset(profile),
\t\tEnum.EasingStyle.Quad,
\t\tEnum.EasingDirection.Out
\t)
end
''',
    "controller profile bolt and grip reset",
)
replace_once(
    controller_path,
    '''\tstate.shotGeneration += 1
\tlocal generation = state.shotGeneration
\tlocal backTween = playMotorTween(
\t\t"Bolt",
\t\trig.boltMotor,
\t\t0.045,
\t\trig.boltRestC0 * BOLT_BACK_OFFSET,
\t\tEnum.EasingStyle.Quad,
\t\tEnum.EasingDirection.Out
\t)
\tbackTween.Completed:Once(function(playbackState)
\t\tif playbackState ~= Enum.PlaybackState.Completed or generation ~= state.shotGeneration then
\t\t\treturn
\t\tend
\t\tif state.lastLoadedRounds == 0 then
\t\t\tlockBoltOpen(0.06)
\t\telse
\t\t\tresetBolt(0.065)
\t\tend
\tend)
''',
    '''\tlocal gripMotor = state.gripMotors[shooter]
\tif gripMotor == nil then
\t\treturn
\tend
\tlocal profile = profileForRig(rig)
\tstate.shotGeneration += 1
\tlocal generation = state.shotGeneration
\tplayMotorTween(
\t\t"Grip",
\t\tgripMotor,
\t\tprofile.ShotBackSeconds,
\t\trig.gripC0 * gripKickOffset(profile),
\t\tEnum.EasingStyle.Quad,
\t\tEnum.EasingDirection.Out
\t)
\tlocal backTween = playMotorTween(
\t\t"Bolt",
\t\trig.boltMotor,
\t\tprofile.ShotBackSeconds,
\t\trig.boltRestC0 * boltBackOffset(profile),
\t\tEnum.EasingStyle.Quad,
\t\tEnum.EasingDirection.Out
\t)
\tbackTween.Completed:Once(function(playbackState)
\t\tif playbackState ~= Enum.PlaybackState.Completed or generation ~= state.shotGeneration then
\t\t\treturn
\t\tend
\t\tresetGrip(profile.ShotReturnSeconds)
\t\tif state.lastLoadedRounds == 0 then
\t\t\tlockBoltOpen(profile.ShotReturnSeconds)
\t\telse
\t\t\tresetBolt(profile.ShotReturnSeconds)
\t\tend
\tend)
''',
    "controller local shot feel",
)
replace_once(
    controller_path,
    '''\tstate.reloadGeneration += 1
\tlocal generation = state.reloadGeneration
\tstate.isReloading = true
\tstate.shotGeneration += 1
\tresetBolt(0.08)
\tlocal remaining = math.clamp(completionServerTimestamp - Workspace:GetServerTimeNow(), 0.15, 5)
\tlocal outwardDuration = remaining * 0.36
\tlocal holdDuration = remaining * 0.22
\tlocal returnDuration = remaining * 0.42
\tlocal outwardTween = playMotorTween(
\t\t"Magazine",
\t\trig.magazineMotor,
\t\toutwardDuration,
\t\trig.magazineRestC0 * MAGAZINE_OUT_OFFSET,
''',
    '''\tlocal profile = profileForRig(rig)
\tstate.reloadGeneration += 1
\tlocal generation = state.reloadGeneration
\tstate.isReloading = true
\tstate.shotGeneration += 1
\tresetBolt(0.08)
\tresetGrip(0.08)
\tlocal remaining = math.clamp(completionServerTimestamp - Workspace:GetServerTimeNow(), 0.15, 5)
\tlocal outwardDuration = remaining * profile.ReloadOutwardFraction
\tlocal holdDuration = remaining * profile.ReloadHoldFraction
\tlocal returnDuration = remaining * profile.ReloadReturnFraction
\tlocal outwardTween = playMotorTween(
\t\t"Magazine",
\t\trig.magazineMotor,
\t\toutwardDuration,
\t\trig.magazineRestC0 * magazineOutOffset(profile),
''',
    "controller reload feel",
)
replace_once(
    controller_path,
    '''\tstate.reloadGeneration += 1
\tstate.isReloading = false
\tresetMagazine(0.08)
''',
    '''\tstate.reloadGeneration += 1
\tstate.isReloading = false
\tresetMagazine(0.08)
\tresetGrip(0.08)
''',
    "controller reload completion grip reset",
)
replace_once(
    controller_path,
    '''\tstate.reloadGeneration += 1
\tstate.isReloading = false
\tresetMagazine(0.12)
''',
    '''\tstate.reloadGeneration += 1
\tstate.isReloading = false
\tresetMagazine(0.12)
\tresetGrip(0.12)
''',
    "controller reload interruption grip reset",
)

test_path = "games/living-kingdoms/tests/WeaponFeelConfig.test.luau"
replace_once(
    test_path,
    'local audioSource = fs.readFile("games/living-kingdoms/src/client/Controllers/WeaponAudioController.luau")\nlocal combined = source .. "\\n" .. effectSource .. "\\n" .. audioSource\n',
    'local audioSource = fs.readFile("games/living-kingdoms/src/client/Controllers/WeaponAudioController.luau")\nlocal motionSource = fs.readFile("games/living-kingdoms/src/client/Controllers/WeaponPresentationController.luau")\nlocal combined = source .. "\\n" .. effectSource .. "\\n" .. audioSource .. "\\n" .. motionSource\n',
    "weapon feel motion audit source",
)
replace_once(
    test_path,
    '''\t"profile.ReloadPlaybackSpeedMultiplier",
} do
''',
    '''\t"profile.ReloadPlaybackSpeedMultiplier",
\t"profile.ShotBackSeconds",
\t"profile.ShotReturnSeconds",
\t"gripKickOffset(profile)",
\t"magazineOutOffset(profile)",
} do
''',
    "weapon feel motion audit tokens",
)

print("Integrated bounded per-loadout recoil and reload presentation into the local controller")
