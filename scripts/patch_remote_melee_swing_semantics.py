from pathlib import Path


def patch(path: str, replacements: list[tuple[str, str]]) -> None:
    target = Path(path)
    source = target.read_text()
    for old, new in replacements:
        if new in source:
            continue
        count = source.count(old)
        if count != 1:
            raise SystemExit(f"{path}: expected one anchor, found {count}: {old[:100]!r}")
        source = source.replace(old, new, 1)
    target.write_text(source)


patch(
    "games/living-kingdoms/src/shared/Combat/MeleeContracts.luau",
    [
        (
            "export type MeleeStrikeResult = {\n\taccepted: boolean,\n\tstrikeId: MeleeStrikeId?,\n",
            "export type MeleeStrikeResult = {\n\taccepted: boolean,\n\tswingAccepted: boolean,\n\tstrikeId: MeleeStrikeId?,\n",
        ),
    ],
)

patch(
    "games/living-kingdoms/src/server/Systems/MeleeCombatService.luau",
    [
        (
            "local function rejected(reasonId: string, serverTimestamp: number): MeleeContracts.MeleeStrikeResult\n\treturn table.freeze({\n\t\taccepted = false,\n\t\tstrikeId = nil,\n",
            "local function rejected(\n\treasonId: string,\n\tserverTimestamp: number,\n\tswingAccepted: boolean?,\n\tstrikeId: string?\n): MeleeContracts.MeleeStrikeResult\n\treturn table.freeze({\n\t\taccepted = false,\n\t\tswingAccepted = swingAccepted == true,\n\t\tstrikeId = strikeId,\n",
        ),
        (
            "\tstate.lastAcceptedSwingServerTimestamp = serverTimestamp\n\trecordRequest(state, requestIdString)\n\n\tlocal facts = EnemyDirectorService.readEnemyCombatFacts()\n",
            "\tstate.lastAcceptedSwingServerTimestamp = serverTimestamp\n\trecordRequest(state, requestIdString)\n\tlocal strikeId = \"melee:\" .. tostring(player.UserId) .. \":\" .. requestIdString\n\n\tlocal facts = EnemyDirectorService.readEnemyCombatFacts()\n",
        ),
        (
            "\tif selection.targetEntityId == nil then\n\t\treturn rejected(selection.rejectionReasonId or Reasons.NoTarget, serverTimestamp)\n\tend\n",
            "\tif selection.targetEntityId == nil then\n\t\treturn rejected(selection.rejectionReasonId or Reasons.NoTarget, serverTimestamp, true, strikeId)\n\tend\n",
        ),
        (
            "\tif fact == nil then\n\t\treturn rejected(Reasons.TargetStale, serverTimestamp)\n\tend\n\tif targetOccluded(character, origin, fact) then\n\t\treturn rejected(Reasons.TargetOccluded, serverTimestamp)\n\tend\n",
            "\tif fact == nil then\n\t\treturn rejected(Reasons.TargetStale, serverTimestamp, true, strikeId)\n\tend\n\tif targetOccluded(character, origin, fact) then\n\t\treturn rejected(Reasons.TargetOccluded, serverTimestamp, true, strikeId)\n\tend\n",
        ),
        (
            "\tif healthRead == nil or healthRead.isAlive ~= true then\n\t\treturn rejected(Reasons.TargetStale, serverTimestamp)\n\tend\n",
            "\tif healthRead == nil or healthRead.isAlive ~= true then\n\t\treturn rejected(Reasons.TargetStale, serverTimestamp, true, strikeId)\n\tend\n",
        ),
        (
            "\tif not committed or type(committedDamage) ~= \"number\" or committedDamage <= 0 then\n\t\treturn rejected(Reasons.CommitRejected, serverTimestamp)\n\tend\n",
            "\tif not committed or type(committedDamage) ~= \"number\" or committedDamage <= 0 then\n\t\treturn rejected(Reasons.CommitRejected, serverTimestamp, true, strikeId)\n\tend\n",
        ),
        (
            "\treturn table.freeze({\n\t\taccepted = true,\n\t\tstrikeId = \"melee:\" .. tostring(player.UserId) .. \":\" .. requestIdString,\n",
            "\treturn table.freeze({\n\t\taccepted = true,\n\t\tswingAccepted = true,\n\t\tstrikeId = strikeId,\n",
        ),
    ],
)

patch(
    "games/living-kingdoms/src/shared/Combat/MeleePresentationContracts.luau",
    [
        (
            'export type MessageKindId = "HitConfirmed"\n',
            'export type MessageKindId = "SwingCommitted" | "HitConfirmed"\n'
            'export type SwingCommittedMessage = {\n'
            '\tkindId: MessageKindId,\n'
            '\tattackerUserId: number,\n'
            '\tstrikeId: string,\n'
            '\tserverTimestamp: number,\n'
            '}\n',
        ),
        (
            'MeleePresentationContracts.MessageKindIds = table.freeze({\n\tHitConfirmed = "HitConfirmed",\n})\n',
            'MeleePresentationContracts.MessageKindIds = table.freeze({\n'
            '\tSwingCommitted = "SwingCommitted",\n'
            '\tHitConfirmed = "HitConfirmed",\n'
            '})\n\n'
            'function MeleePresentationContracts.validateSwingCommittedMessage(message: unknown): boolean\n'
            '\tif type(message) ~= "table" then\n'
            '\t\treturn false\n'
            '\tend\n'
            '\tlocal candidate = message :: any\n'
            '\treturn candidate.kindId == MeleePresentationContracts.MessageKindIds.SwingCommitted\n'
            '\t\tand type(candidate.attackerUserId) == "number"\n'
            '\t\tand candidate.attackerUserId % 1 == 0\n'
            '\t\tand candidate.attackerUserId > 0\n'
            '\t\tand type(candidate.strikeId) == "string"\n'
            '\t\tand candidate.strikeId ~= ""\n'
            '\t\tand type(candidate.serverTimestamp) == "number"\n'
            '\t\tand candidate.serverTimestamp == candidate.serverTimestamp\n'
            '\t\tand candidate.serverTimestamp >= 0\n'
            'end\n',
        ),
    ],
)

patch(
    "games/living-kingdoms/src/server/Systems/MeleeIntentService.luau",
    [
        (
            "\tlocal result = MeleeCombatService.tryStrike(player, requestId, aimDirection)\n\tif\n",
            "\tlocal result = MeleeCombatService.tryStrike(player, requestId, aimDirection)\n"
            "\tif result.swingAccepted == true and result.strikeId ~= nil then\n"
            "\t\tpresentationRemote:FireAllClients({\n"
            "\t\t\tkindId = MessageKindIds.SwingCommitted,\n"
            "\t\t\tattackerUserId = player.UserId,\n"
            "\t\t\tstrikeId = result.strikeId,\n"
            "\t\t\tserverTimestamp = result.serverTimestamp,\n"
            "\t\t})\n"
            "\tend\n"
            "\tif\n",
        ),
    ],
)

print("patched authoritative remote melee swing semantics")
