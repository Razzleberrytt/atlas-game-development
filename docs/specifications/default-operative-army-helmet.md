# Default operative army helmet

## Player-facing behavior

Every replicated player character receives the same olive-drab procedural army helmet by default.

The helmet appears:

- before class selection
- after class selection
- after character respawn
- on late-joining players
- on both R6 and R15 characters that expose the standard `Head` part

The fallback silhouette uses three pieces:

1. armored dome
2. front brim
3. rear rim

## Presentation boundary

The helmet is client-local presentation replicated consistently by each client for every player character.

It does not:

- replace or remove avatar hair, hats, or accessories
- assign or communicate a class
- alter the character rig
- alter collision, touch, or query behavior
- change movement, health, combat, ammunition, targeting, mission state, or network ownership
- create or use a remote

Each generated part is massless, non-collidable, non-touchable, non-queryable, and welded to the character's standard `Head` part.

## Runtime bounds

- maximum three generated parts per character
- one `CharacterAdded` connection per tracked player
- two global player lifecycle connections
- zero frame loops
- zero timers
- zero remotes
- zero server runtime changes

At the planned eight-player ceiling, the fallback adds at most 24 cosmetic parts per client.

## Studio acceptance checklist

- Verify the local player wears the helmet before choosing a class.
- Verify another client sees the same helmet.
- Verify helmets return after both players respawn.
- Verify the helmet follows head and neck animation without visible separation.
- Verify the dome and rims do not obscure the face excessively from the gameplay camera.
- Verify common avatar hair and hat accessories do not create unacceptable clipping.
- Verify R6 and R15 placement separately.
- Verify the helmet creates no collision, touch, raycast, or movement change.
- Verify no warnings or runtime errors appear during player join, leave, death, or respawn.

Studio visual approval remains required because procedural proportions may need small offset adjustments after viewing the helmet from the elevated isometric camera.
