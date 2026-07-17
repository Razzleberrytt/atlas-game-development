from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    text = file_path.read_text()
    if text.count(old) != 1:
        raise RuntimeError(f"expected one anchor in {path}, found {text.count(old)}")
    file_path.write_text(text.replace(old, new, 1))


contracts = "games/living-kingdoms/src/shared/Combat/CombatContracts.luau"
replace_once(
    contracts,
    '\t| "ReloadInterrupted"\n',
    '\t| "ReloadInterrupted"\n\t| "AmmunitionState"\n\t| "AmmunitionCollected"\n',
)
replace_once(
    contracts,
    '''export type ReloadInterruptedPresentationMessage = {\n\tkindId: "ReloadInterrupted",\n\tweaponId: WeaponId,\n}\n\nexport type CombatPresentationMessage =\n''',
    '''export type ReloadInterruptedPresentationMessage = {\n\tkindId: "ReloadInterrupted",\n\tweaponId: WeaponId,\n}\n\nexport type AmmunitionStatePresentationMessage = {\n\tkindId: "AmmunitionState",\n\tweaponId: WeaponId,\n\tloadedRounds: number,\n\treserveRounds: number,\n\tmagazineCapacity: number,\n\tmaximumReserveRounds: number,\n}\n\nexport type AmmunitionCollectedPresentationMessage = {\n\tkindId: "AmmunitionCollected",\n\tweaponId: WeaponId,\n\tgrantedRounds: number,\n\tloadedRounds: number,\n\treserveRounds: number,\n\tmagazineCapacity: number,\n\tmaximumReserveRounds: number,\n}\n\nexport type CombatPresentationMessage =\n''',
)
replace_once(
    contracts,
    '\t| ReloadInterruptedPresentationMessage\n',
    '\t| ReloadInterruptedPresentationMessage\n\t| AmmunitionStatePresentationMessage\n\t| AmmunitionCollectedPresentationMessage\n',
)
replace_once(
    contracts,
    '\tReloadInterrupted = "ReloadInterrupted",\n',
    '\tReloadInterrupted = "ReloadInterrupted",\n\tAmmunitionState = "AmmunitionState",\n\tAmmunitionCollected = "AmmunitionCollected",\n',
)

runtime = "games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau"
replace_once(
    runtime,
    '\tcommitReviveCombatState: (player: Player, expectedGeneration: number, combatState: any) -> boolean,\n',
    '\tcommitReviveCombatState: (player: Player, expectedGeneration: number, combatState: any, grantedRounds: number?) -> boolean,\n\tpublishAmmunitionState: (player: Player, grantedRounds: number?) -> boolean,\n',
)
replace_once(
    runtime,
    '''local function deepCopy(value: any): any\n\tif type(value) ~= "table" then\n\t\treturn value\n\tend\n\tlocal result = {}\n\tfor key, child in value do\n\t\tresult[key] = deepCopy(child)\n\tend\n\treturn result\nend\n\n''',
    '''local function deepCopy(value: any): any\n\tif type(value) ~= "table" then\n\t\treturn value\n\tend\n\tlocal result = {}\n\tfor key, child in value do\n\t\tresult[key] = deepCopy(child)\n\tend\n\treturn result\nend\n\nfunction OperativeCombatRuntimeService.publishAmmunitionState(player: Player, grantedRounds: number?): boolean\n\tlocal playerState = playerStates[player]\n\tif playerState == nil then\n\t\treturn false\n\tend\n\tlocal ammunition = playerState.weaponState.ammunition\n\tlocal kindId = if grantedRounds == nil\n\t\tthen CombatContracts.PresentationMessageKindIds.AmmunitionState\n\t\telse CombatContracts.PresentationMessageKindIds.AmmunitionCollected\n\tlocal payload = {\n\t\tkindId = kindId,\n\t\tweaponId = ammunition.weaponId,\n\t\tloadedRounds = ammunition.loadedRounds,\n\t\treserveRounds = ammunition.reserveRounds,\n\t\tmagazineCapacity = ammunition.magazineCapacity,\n\t\tmaximumReserveRounds = FirearmConfig.BasicFirearm.MaximumReserveRounds,\n\t}\n\tif grantedRounds ~= nil then\n\t\tpayload.grantedRounds = grantedRounds\n\tend\n\tpresentationRemote:FireClient(player, payload)\n\treturn true\nend\n\n''',
)
replace_once(
    runtime,
    '''function OperativeCombatRuntimeService.commitReviveCombatState(\n\tplayer: Player,\n\texpectedGeneration: number,\n\tcombatState: any\n): boolean\n''',
    '''function OperativeCombatRuntimeService.commitReviveCombatState(\n\tplayer: Player,\n\texpectedGeneration: number,\n\tcombatState: any,\n\tgrantedRounds: number?\n): boolean\n''',
)
replace_once(
    runtime,
    '''\tplayerState.weaponState = deepCopy(combatState.weaponState)\n\tplayerState.processedShotIds = deepCopy(combatState.processedShotIds)\n\tplayerState.selectedTargetEntityId = nil\n\treturn true\nend\n''',
    '''\tplayerState.weaponState = deepCopy(combatState.weaponState)\n\tplayerState.processedShotIds = deepCopy(combatState.processedShotIds)\n\tplayerState.selectedTargetEntityId = nil\n\tOperativeCombatRuntimeService.publishAmmunitionState(player, grantedRounds)\n\treturn true\nend\n''',
)
replace_once(
    runtime,
    '''\tlocal fireResolution = AutomaticFireResolver.resolve({\n\t\tentityId = playerState.operativeState.entityId,\n\t\tcombatStateId = playerState.operativeState.combatStateId,\n\t}, selectedTarget, playerState.weaponState, nowTimestamp)\n\tplayerState.weaponState = fireResolution.weaponStateAfter\n\tif fireResolution.decision.shouldFire then\n\t\tresolveAcceptedShot(player, playerState, operativePosition, fireResolution.fireResult, nowTimestamp)\n\tend\n''',
    '''\tlocal fireResolution = AutomaticFireResolver.resolve({\n\t\tentityId = playerState.operativeState.entityId,\n\t\tcombatStateId = playerState.operativeState.combatStateId,\n\t}, selectedTarget, playerState.weaponState, nowTimestamp)\n\tplayerState.weaponState = fireResolution.weaponStateAfter\n\tif fireResolution.decision.shouldFire then\n\t\tresolveAcceptedShot(player, playerState, operativePosition, fireResolution.fireResult, nowTimestamp)\n\t\tOperativeCombatRuntimeService.publishAmmunitionState(player)\n\tend\n''',
)
replace_once(
    runtime,
    '''\tplayerState.operativeState = resolution.operativeStateAfter\n\tplayerState.weaponState = resolution.weaponStateAfter\n\tif resolution.didComplete then\n''',
    '''\tplayerState.operativeState = resolution.operativeStateAfter\n\tplayerState.weaponState = resolution.weaponStateAfter\n\tif resolution.didComplete or resolution.wasInterrupted then\n\t\tOperativeCombatRuntimeService.publishAmmunitionState(player)\n\tend\n\tif resolution.didComplete then\n''',
)
replace_once(
    runtime,
    '''local function addPlayer(player: Player)\n\tresetPlayer(player)\n\tcharacterAddedConnections[player] = player.CharacterAdded:Connect(function()\n\t\tresetPlayer(player)\n\tend)\nend\n''',
    '''local function addPlayer(player: Player)\n\tresetPlayer(player)\n\tOperativeCombatRuntimeService.publishAmmunitionState(player)\n\tcharacterAddedConnections[player] = player.CharacterAdded:Connect(function()\n\t\tresetPlayer(player)\n\t\tOperativeCombatRuntimeService.publishAmmunitionState(player)\n\tend)\nend\n''',
)

cache_service = "games/living-kingdoms/src/server/Systems/AmmunitionCacheService.luau"
replace_once(
    cache_service,
    'if not OperativeCombatRuntimeService.commitReviveCombatState(player, read.generation, combatState) then',
    'if not OperativeCombatRuntimeService.commitReviveCombatState(player, read.generation, combatState, result.grantedRounds) then',
)

controller = "games/living-kingdoms/src/client/Controllers/WeaponController.luau"
replace_once(
    controller,
    '\tstatusLabel: TextLabel?,\n',
    '\tstatusLabel: TextLabel?,\n\tammunitionLabel: TextLabel?,\n',
)
replace_once(
    controller,
    '\tstatusLabel = nil,\n',
    '\tstatusLabel = nil,\n\tammunitionLabel = nil,\n',
)
replace_once(
    controller,
    '''local function setStatus(text: string)\n\tlocal statusLabel = state.statusLabel\n\tif statusLabel ~= nil then\n\t\tstatusLabel.Text = text\n\t\tstatusLabel.Visible = text ~= ""\n\tend\nend\n\n''',
    '''local function setStatus(text: string)\n\tlocal statusLabel = state.statusLabel\n\tif statusLabel ~= nil then\n\t\tstatusLabel.Text = text\n\t\tstatusLabel.Visible = text ~= ""\n\tend\nend\n\nlocal function presentAmmunition(loadedRounds: number, reserveRounds: number, magazineCapacity: number)\n\tlocal ammunitionLabel = state.ammunitionLabel\n\tif ammunitionLabel ~= nil then\n\t\tammunitionLabel.Text = string.format("%d / %d   RESERVE %d", loadedRounds, magazineCapacity, reserveRounds)\n\t\tammunitionLabel.Visible = true\n\tend\nend\n\n''',
)
replace_once(
    controller,
    '''local function isFiniteNumber(value: unknown): boolean\n\treturn type(value) == "number" and value == value and math.abs(value) < math.huge\nend\n\n''',
    '''local function isFiniteNumber(value: unknown): boolean\n\treturn type(value) == "number" and value == value and math.abs(value) < math.huge\nend\n\nlocal function isWholeNonnegative(value: unknown): boolean\n\treturn isFiniteNumber(value) and value >= 0 and value % 1 == 0\nend\n\nlocal function presentAmmunitionPayload(payload: any): boolean\n\tif\n\t\tpayload.weaponId ~= FirearmConfig.BasicFirearm.WeaponId\n\t\tor not isWholeNonnegative(payload.loadedRounds)\n\t\tor not isWholeNonnegative(payload.reserveRounds)\n\t\tor not isWholeNonnegative(payload.magazineCapacity)\n\t\tor payload.magazineCapacity <= 0\n\t\tor payload.loadedRounds > payload.magazineCapacity\n\t\tor not isWholeNonnegative(payload.maximumReserveRounds)\n\t\tor payload.reserveRounds > payload.maximumReserveRounds\n\tthen\n\t\treturn false\n\tend\n\tpresentAmmunition(payload.loadedRounds, payload.reserveRounds, payload.magazineCapacity)\n\treturn true\nend\n\n''',
)
replace_once(
    controller,
    '''\telseif kindId == CombatContracts.PresentationMessageKindIds.ReloadInterrupted then\n\t\tif payload.weaponId == FirearmConfig.BasicFirearm.WeaponId then\n\t\t\tsetStatus("Reload interrupted")\n\t\tend\n\tend\nend\n''',
    '''\telseif kindId == CombatContracts.PresentationMessageKindIds.ReloadInterrupted then\n\t\tif payload.weaponId == FirearmConfig.BasicFirearm.WeaponId then\n\t\t\tsetStatus("Reload interrupted")\n\t\tend\n\telseif kindId == CombatContracts.PresentationMessageKindIds.AmmunitionState then\n\t\tpresentAmmunitionPayload(payload)\n\telseif kindId == CombatContracts.PresentationMessageKindIds.AmmunitionCollected then\n\t\tif\n\t\t\tpresentAmmunitionPayload(payload)\n\t\t\tand isWholeNonnegative(payload.grantedRounds)\n\t\t\tand payload.grantedRounds > 0\n\t\tthen\n\t\t\tsetStatus("+" .. tostring(payload.grantedRounds) .. " rifle ammunition")\n\t\tend\n\tend\nend\n''',
)
replace_once(
    controller,
    '''\tstatusLabel.Parent = screenGui\n\n\tscreenGui.Parent = localPlayer:WaitForChild("PlayerGui")\n\tstate.screenGui = screenGui\n\tstate.statusLabel = statusLabel\n''',
    '''\tstatusLabel.Parent = screenGui\n\n\tlocal ammunitionLabel = Instance.new("TextLabel")\n\tammunitionLabel.Name = "Ammunition"\n\tammunitionLabel.AnchorPoint = Vector2.new(1, 1)\n\tammunitionLabel.Position = UDim2.new(1, -28, 1, -28)\n\tammunitionLabel.Size = UDim2.fromOffset(280, 42)\n\tammunitionLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 26)\n\tammunitionLabel.BackgroundTransparency = 0.2\n\tammunitionLabel.BorderSizePixel = 0\n\tammunitionLabel.Font = Enum.Font.GothamBold\n\tammunitionLabel.Text = ""\n\tammunitionLabel.TextColor3 = Color3.fromRGB(245, 245, 245)\n\tammunitionLabel.TextSize = 18\n\tammunitionLabel.TextXAlignment = Enum.TextXAlignment.Center\n\tammunitionLabel.Visible = false\n\tammunitionLabel.Parent = screenGui\n\n\tscreenGui.Parent = localPlayer:WaitForChild("PlayerGui")\n\tstate.screenGui = screenGui\n\tstate.statusLabel = statusLabel\n\tstate.ammunitionLabel = ammunitionLabel\n''',
)
replace_once(
    controller,
    '\tstate.statusLabel = nil\n',
    '\tstate.statusLabel = nil\n\tstate.ammunitionLabel = nil\n',
)

test_path = Path("games/living-kingdoms/tests/P6AmmunitionPresentation.test.luau")
test_path.write_text('''--!strict\n\nlocal fs = require("@lune/fs")\n\nlocal function check(condition: unknown, message: string?)\n\tif not condition then\n\t\terror(message or "P6 ammunition presentation audit failed", 2)\n\tend\nend\n\nlocal contracts = fs.readFile("games/living-kingdoms/src/shared/Combat/CombatContracts.luau")\nlocal runtime = fs.readFile("games/living-kingdoms/src/server/Systems/OperativeCombatRuntimeService.luau")\nlocal cache = fs.readFile("games/living-kingdoms/src/server/Systems/AmmunitionCacheService.luau")\nlocal controller = fs.readFile("games/living-kingdoms/src/client/Controllers/WeaponController.luau")\n\ncheck(string.find(contracts, "AmmunitionState", 1, true) ~= nil)\ncheck(string.find(contracts, "AmmunitionCollected", 1, true) ~= nil)\ncheck(string.find(runtime, "publishAmmunitionState", 1, true) ~= nil)\ncheck(string.find(runtime, "presentationRemote:FireClient", 1, true) ~= nil)\ncheck(string.find(cache, "result.grantedRounds", 1, true) ~= nil)\ncheck(string.find(cache, "commitReviveCombatState", 1, true) ~= nil)\ncheck(string.find(controller, "presentAmmunitionPayload", 1, true) ~= nil)\ncheck(string.find(controller, "FireServer", 1, true) ~= nil)\ncheck(string.find(controller, "reserveRounds =", 1, true) == nil, "client must not assign authoritative reserve rounds")\ncheck(string.find(controller, "loadedRounds =", 1, true) == nil, "client must not assign authoritative loaded rounds")\n''')

Path(".github/workflows/p6-0105-one-shot.yml").unlink()
Path(".github/one-shot/p6_0105_patch.py").unlink()
# trigger
