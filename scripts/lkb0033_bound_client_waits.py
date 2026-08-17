from pathlib import Path
root=Path('games/living-kingdoms/src/client')

def edit(rel, replacements):
    p=root/rel
    s=p.read_text()
    orig=s
    for old,new in replacements:
        if old not in s:
            raise SystemExit(f'MISSING in {rel}: {old!r}')
        s=s.replace(old,new,1)
    p.write_text(s)
    print('edited',rel)

# PlayerGui-only waits in controllers that already own NETWORK_WAIT_SECONDS.
for rel, obj in [
    ('Controllers/CombatFeedback/ConfirmedHitMarkerController.luau','gui'),
    ('Controllers/CombatFeedback/FloatingDamageTextController.luau','gui'),
    ('Controllers/HordeHUDController.luau','gui'),
    ('Controllers/PersonalFlashlightController.luau','gui'),
    ('Controllers/SquadPingController.luau','gui'),
    ('Controllers/WeaponSelectionController.luau','createdGui'),
]:
    edit(rel, [(f'\t{obj}.Parent = localPlayer:WaitForChild("PlayerGui")',
                f'\tlocal playerGui = localPlayer:WaitForChild("PlayerGui", NETWORK_WAIT_SECONDS) :: PlayerGui?\n'
                f'\tassert(playerGui ~= nil, "PlayerGui did not become available before the client bootstrap timeout")\n'
                f'\t{obj}.Parent = playerGui')])

# Massacre has no timeout constant yet.
edit('Controllers/MassacreCrescendoController.luau', [
    ('local Workspace = game:GetService("Workspace")\n', 'local Workspace = game:GetService("Workspace")\n\nlocal NETWORK_WAIT_SECONDS = 20\n'),
    ('\tgui.Parent = localPlayer:WaitForChild("PlayerGui")',
     '\tlocal playerGui = localPlayer:WaitForChild("PlayerGui", NETWORK_WAIT_SECONDS) :: PlayerGui?\n'
     '\tassert(playerGui ~= nil, "PlayerGui did not become available before the client bootstrap timeout")\n'
     '\tgui.Parent = playerGui'),
])

# Operative progression presentation PlayerGui.
edit('Controllers/OperativeProgressionPresentationController.luau', [
    ('\tlocal playerGui = player:WaitForChild("PlayerGui")',
     '\tlocal playerGui = player:WaitForChild("PlayerGui", NETWORK_WAIT_SECONDS) :: PlayerGui?\n'
     '\tassert(playerGui ~= nil, "PlayerGui did not become available before the client bootstrap timeout")'),
])

# Run progression: parent + complete child family + PlayerGui.
edit('Controllers/RunProgressionHUDController.luau', [
    ('local progressionNetwork = ReplicatedStorage:WaitForChild("ProgressionNetwork", NETWORK_WAIT_SECONDS)\n'
     'local stateRemote = progressionNetwork:WaitForChild("State") :: RemoteEvent\n'
     'local readStateRemote = progressionNetwork:WaitForChild("ReadState") :: RemoteFunction\n'
     'local chooseUpgradeRemote = progressionNetwork:WaitForChild("ChooseUpgrade") :: RemoteEvent',
     'local progressionNetwork = ReplicatedStorage:WaitForChild("ProgressionNetwork", NETWORK_WAIT_SECONDS)\n'
     'assert(progressionNetwork ~= nil, "ProgressionNetwork did not become available before the client bootstrap timeout")\n'
     'local stateRemote = progressionNetwork:WaitForChild("State", NETWORK_WAIT_SECONDS) :: RemoteEvent?\n'
     'assert(stateRemote ~= nil, "ProgressionNetwork.State did not become available before the client bootstrap timeout")\n'
     'local readStateRemote = progressionNetwork:WaitForChild("ReadState", NETWORK_WAIT_SECONDS) :: RemoteFunction?\n'
     'assert(readStateRemote ~= nil, "ProgressionNetwork.ReadState did not become available before the client bootstrap timeout")\n'
     'local chooseUpgradeRemote = progressionNetwork:WaitForChild("ChooseUpgrade", NETWORK_WAIT_SECONDS) :: RemoteEvent?\n'
     'assert(chooseUpgradeRemote ~= nil, "ProgressionNetwork.ChooseUpgrade did not become available before the client bootstrap timeout")'),
    ('\tlocal playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")',
     '\tlocal playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", NETWORK_WAIT_SECONDS) :: PlayerGui?\n'
     '\tassert(playerGui ~= nil, "PlayerGui did not become available before the client bootstrap timeout")'),
])

# Squad ping: parent assert + children; PlayerGui handled above.
edit('Controllers/SquadPingController.luau', [
    ('local network = ReplicatedStorage:WaitForChild("SquadPingNetwork", NETWORK_WAIT_SECONDS)\n'
     'local intentRemote = network:WaitForChild("Intent") :: RemoteEvent\n'
     'local stateRemote = network:WaitForChild("State") :: RemoteEvent',
     'local network = ReplicatedStorage:WaitForChild("SquadPingNetwork", NETWORK_WAIT_SECONDS)\n'
     'assert(network ~= nil, "SquadPingNetwork did not become available before the client bootstrap timeout")\n'
     'local intentRemote = network:WaitForChild("Intent", NETWORK_WAIT_SECONDS) :: RemoteEvent?\n'
     'assert(intentRemote ~= nil, "SquadPingNetwork.Intent did not become available before the client bootstrap timeout")\n'
     'local stateRemote = network:WaitForChild("State", NETWORK_WAIT_SECONDS) :: RemoteEvent?\n'
     'assert(stateRemote ~= nil, "SquadPingNetwork.State did not become available before the client bootstrap timeout")'),
])

# Survival HUD family + PlayerGui.
edit('Controllers/SurvivalHUDController.luau', [
    ('local network = ReplicatedStorage:WaitForChild("SurvivalNetwork", NETWORK_WAIT_SECONDS)\n'
     'local stateRemote = network:WaitForChild("State") :: RemoteEvent\n'
     'local readState = network:WaitForChild("ReadState") :: RemoteFunction',
     'local network = ReplicatedStorage:WaitForChild("SurvivalNetwork", NETWORK_WAIT_SECONDS)\n'
     'assert(network ~= nil, "SurvivalNetwork did not become available before the client bootstrap timeout")\n'
     'local stateRemote = network:WaitForChild("State", NETWORK_WAIT_SECONDS) :: RemoteEvent?\n'
     'assert(stateRemote ~= nil, "SurvivalNetwork.State did not become available before the client bootstrap timeout")\n'
     'local readState = network:WaitForChild("ReadState", NETWORK_WAIT_SECONDS) :: RemoteFunction?\n'
     'assert(readState ~= nil, "SurvivalNetwork.ReadState did not become available before the client bootstrap timeout")'),
    ('\tcreated.Parent = player:WaitForChild("PlayerGui")',
     '\tlocal playerGui = player:WaitForChild("PlayerGui", NETWORK_WAIT_SECONDS) :: PlayerGui?\n'
     '\tassert(playerGui ~= nil, "PlayerGui did not become available before the client bootstrap timeout")\n'
     '\tcreated.Parent = playerGui'),
])

# Weapon audio/presentation child family.
for rel in ['Controllers/WeaponAudioController.luau','Controllers/WeaponPresentationController.luau']:
    edit(rel, [
        ('local combatNetwork = ReplicatedStorage:WaitForChild("CombatNetwork", NETWORK_WAIT_SECONDS)\n'
         'local presentationRemote = combatNetwork:WaitForChild("CombatPresentation") :: RemoteEvent',
         'local combatNetwork = ReplicatedStorage:WaitForChild("CombatNetwork", NETWORK_WAIT_SECONDS)\n'
         'assert(combatNetwork ~= nil, "CombatNetwork did not become available before the client bootstrap timeout")\n'
         'local presentationRemote = combatNetwork:WaitForChild("CombatPresentation", NETWORK_WAIT_SECONDS) :: RemoteEvent?\n'
         'assert(\n'
         '\tpresentationRemote ~= nil,\n'
         '\t"CombatNetwork.CombatPresentation did not become available before the client bootstrap timeout"\n'
         ')'),
    ])

# Weapon selection family; PlayerGui handled above.
edit('Controllers/WeaponSelectionController.luau', [
    ('local network = ReplicatedStorage:WaitForChild("WeaponLoadoutNetwork", NETWORK_WAIT_SECONDS)\n'
     'local intentRemote = network:WaitForChild("SelectionIntent") :: RemoteEvent\n'
     'local stateRemote = network:WaitForChild("State") :: RemoteEvent\n'
     'local readState = network:WaitForChild("ReadState") :: RemoteFunction',
     'local network = ReplicatedStorage:WaitForChild("WeaponLoadoutNetwork", NETWORK_WAIT_SECONDS)\n'
     'assert(network ~= nil, "WeaponLoadoutNetwork did not become available before the client bootstrap timeout")\n'
     'local intentRemote = network:WaitForChild("SelectionIntent", NETWORK_WAIT_SECONDS) :: RemoteEvent?\n'
     'assert(\n'
     '\tintentRemote ~= nil,\n'
     '\t"WeaponLoadoutNetwork.SelectionIntent did not become available before the client bootstrap timeout"\n'
     ')\n'
     'local stateRemote = network:WaitForChild("State", NETWORK_WAIT_SECONDS) :: RemoteEvent?\n'
     'assert(stateRemote ~= nil, "WeaponLoadoutNetwork.State did not become available before the client bootstrap timeout")\n'
     'local readState = network:WaitForChild("ReadState", NETWORK_WAIT_SECONDS) :: RemoteFunction?\n'
     'assert(readState ~= nil, "WeaponLoadoutNetwork.ReadState did not become available before the client bootstrap timeout")'),
])

# Operative progression map presentation.
edit('Presentation/OperativeProgressionMapPresentation.luau', [
    ('local progressionNetwork = ReplicatedStorage:WaitForChild("OperativeProgressionNetwork", NETWORK_WAIT_SECONDS)\n'
     'local progressionReadState = progressionNetwork:WaitForChild("ReadState") :: RemoteFunction',
     'local progressionNetwork = ReplicatedStorage:WaitForChild("OperativeProgressionNetwork", NETWORK_WAIT_SECONDS)\n'
     'assert(\n'
     '\tprogressionNetwork ~= nil,\n'
     '\t"OperativeProgressionNetwork did not become available before the client bootstrap timeout"\n'
     ')\n'
     'local progressionReadState = progressionNetwork:WaitForChild("ReadState", NETWORK_WAIT_SECONDS) :: RemoteFunction?\n'
     'assert(\n'
     '\tprogressionReadState ~= nil,\n'
     '\t"OperativeProgressionNetwork.ReadState did not become available before the client bootstrap timeout"\n'
     ')'),
])

# Chained root-network waits in files without a constant.
edit('Controllers/HordeEffectsController.luau', [
    ('local Workspace = game:GetService("Workspace")\n', 'local Workspace = game:GetService("Workspace")\n\nlocal NETWORK_WAIT_SECONDS = 20\n'),
    ('local presentationRemote =\n\tReplicatedStorage:WaitForChild("CombatNetwork"):WaitForChild("CombatPresentation") :: RemoteEvent',
     'local combatNetwork = ReplicatedStorage:WaitForChild("CombatNetwork", NETWORK_WAIT_SECONDS)\n'
     'assert(combatNetwork ~= nil, "CombatNetwork did not become available before the client bootstrap timeout")\n'
     'local presentationRemote = combatNetwork:WaitForChild("CombatPresentation", NETWORK_WAIT_SECONDS) :: RemoteEvent?\n'
     'assert(\n'
     '\tpresentationRemote ~= nil,\n'
     '\t"CombatNetwork.CombatPresentation did not become available before the client bootstrap timeout"\n'
     ')'),
])

edit('Controllers/MissionController.luau', [
    ('local RADIO_VISIBLE_SECONDS = 6\n', 'local NETWORK_WAIT_SECONDS = 20\nlocal RADIO_VISIBLE_SECONDS = 6\n'),
    ('local stateRemote = ReplicatedStorage:WaitForChild("MissionNetwork"):WaitForChild("State") :: RemoteEvent',
     'local missionNetwork = ReplicatedStorage:WaitForChild("MissionNetwork", NETWORK_WAIT_SECONDS)\n'
     'assert(missionNetwork ~= nil, "MissionNetwork did not become available before the client bootstrap timeout")\n'
     'local stateRemote = missionNetwork:WaitForChild("State", NETWORK_WAIT_SECONDS) :: RemoteEvent?\n'
     'assert(stateRemote ~= nil, "MissionNetwork.State did not become available before the client bootstrap timeout")'),
])

edit('Controllers/MissionObjectPresentationController.luau', [
    ('local Controller = {}\n\nlocal RELAY_MODEL_NAME', 'local Controller = {}\n\nlocal NETWORK_WAIT_SECONDS = 20\nlocal RELAY_MODEL_NAME'),
    ('local stateRemote = ReplicatedStorage:WaitForChild("MissionNetwork"):WaitForChild("State") :: RemoteEvent',
     'local missionNetwork = ReplicatedStorage:WaitForChild("MissionNetwork", NETWORK_WAIT_SECONDS)\n'
     'assert(missionNetwork ~= nil, "MissionNetwork did not become available before the client bootstrap timeout")\n'
     'local stateRemote = missionNetwork:WaitForChild("State", NETWORK_WAIT_SECONDS) :: RemoteEvent?\n'
     'assert(stateRemote ~= nil, "MissionNetwork.State did not become available before the client bootstrap timeout")'),
])

edit('Controllers/OperativeLifeController.luau', [
    ('local ACTION_NAME = "LK_Revive"\n', 'local ACTION_NAME = "LK_Revive"\nlocal NETWORK_WAIT_SECONDS = 20\n'),
    ('local reviveIntentRemote =\n\tReplicatedStorage:WaitForChild("OperativeLifeNetwork"):WaitForChild("ReviveIntent") :: RemoteEvent',
     'local operativeLifeNetwork = ReplicatedStorage:WaitForChild("OperativeLifeNetwork", NETWORK_WAIT_SECONDS)\n'
     'assert(operativeLifeNetwork ~= nil, "OperativeLifeNetwork did not become available before the client bootstrap timeout")\n'
     'local reviveIntentRemote = operativeLifeNetwork:WaitForChild("ReviveIntent", NETWORK_WAIT_SECONDS) :: RemoteEvent?\n'
     'assert(\n'
     '\treviveIntentRemote ~= nil,\n'
     '\t"OperativeLifeNetwork.ReviveIntent did not become available before the client bootstrap timeout"\n'
     ')'),
])

# Early horde listener: bound inside start so listener remains first-owner but cannot hang forever.
edit('State/HordeStateEarlyListener.luau', [
    ('local ReplicatedStorage = game:GetService("ReplicatedStorage")\n', 'local ReplicatedStorage = game:GetService("ReplicatedStorage")\n\nlocal NETWORK_WAIT_SECONDS = 20\n'),
    ('\tlocal network = ReplicatedStorage:WaitForChild("HordeNetwork")\n'
     '\tdiagnosticNetwork = network\n'
     '\tlocal stateRemote = network:WaitForChild("State")\n'
     '\tassert(stateRemote:IsA("RemoteEvent"), "HordeNetwork.State must be a RemoteEvent")',
     '\tlocal network = ReplicatedStorage:WaitForChild("HordeNetwork", NETWORK_WAIT_SECONDS)\n'
     '\tassert(network ~= nil, "HordeNetwork did not become available before the client bootstrap timeout")\n'
     '\tdiagnosticNetwork = network\n'
     '\tlocal stateRemote = network:WaitForChild("State", NETWORK_WAIT_SECONDS)\n'
     '\tassert(stateRemote ~= nil, "HordeNetwork.State did not become available before the client bootstrap timeout")\n'
     '\tassert(stateRemote:IsA("RemoteEvent"), "HordeNetwork.State must be a RemoteEvent")'),
])

print('done')
