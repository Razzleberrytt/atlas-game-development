# Operative class silhouettes — VIS-0104 procedural fallback

This source package defines the first project-original operative and starting-class identity pass for Living Kingdoms. It is a runtime procedural fallback, not an imported or Studio-approved production rig.

## Runtime presentation

`ClassSilhouetteController` reads the existing validated `SafeClassSelectionSnapshot` produced by `ClassService`. For every replicated operative identity in the safe squad roster, it attaches a local model named `OperativeClassSilhouette` to the character torso.

Every operative receives a four-part neutral armor base. Six additional parts provide class identity:

- **Combat Specialist:** broad reinforced shoulder guards, paired ammunition cases, a horizontal back roll, and a diagonal chest band.
- **Medic:** a compact medical pack, two tall canisters, paired side satchels, and a round upper beacon.
- **Engineer:** a wide utility pack, squared tool cases, a frame bar, and a tall asymmetric antenna.

The three kits remain distinguishable through geometry, not color alone. Palette differences are supplemental. Duplicate-class squads intentionally receive the same readable equipment shape because duplicate roles are legal.

## Character compatibility

The fallback resolves either `UpperTorso` for R15 or `Torso` for R6. All generated equipment parts are:

- massless;
- non-collidable;
- non-touchable;
- non-queryable;
- welded only to the replicated torso;
- limited to ten parts per operative.

The controller does not replace the Roblox avatar, resize body parts, move the character, alter the `HumanoidRootPart`, or change animation, collision, network ownership, health, weapon, ammunition, class assignment, or mission state.

## Networking and lifecycle

No network surface is added. The controller listens to the existing class-state event and performs one read-only `ReadState` request at startup so it cannot miss the initial assignment snapshot.

Runtime bounds:

- three global connections: class state, player added, and player removing;
- two bounded connections per player: character added and operative-ID attribute changed;
- zero frame connections;
- zero timers or delayed tasks;
- zero new remotes;
- zero server runtime changes.

## Honest limitations

This slice does not claim a canonical operative rig, firearm carry integration, locomotion animation, incapacitation/revive/death pose work, or class-action effects. Those cues must attach only after their corresponding authoritative gameplay states exist and are disclosed safely.

Roblox Studio gameplay-camera review, imported asset replacement, low-quality validation, avatar-scale coverage, and representative 1/2/4-operative performance evidence remain pending.
