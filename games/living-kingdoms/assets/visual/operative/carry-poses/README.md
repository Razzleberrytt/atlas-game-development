# Operative Firearm Carry Pose Fallback

## Status

This package is a project-original, client-local procedural fallback for VIS-0104. It is not a canonical operative rig or an approved production animation set. Roblox Studio approval remains pending.

## Readability contract

The existing Blackwater Support LMG remains attached through the existing `WeaponGrip` Motor6D. An event-driven presentation controller applies bounded upper-body baselines for:

- ready firearm carry;
- an authoritative active reviver lowering the weapon;
- incapacitated arm and weapon slack;
- dead arm and weapon slack.

Death overrides stale revive disclosure. Incapacitation overrides revive disclosure. Unknown life state restores captured baselines instead of inventing a pose.

## Rig coverage

The fallback has separate conservative definitions for R6 and R15 shoulder layouts. It uses the existing shoulder Motor6Ds and existing weapon grip only. It does not create a replacement character rig, resize body parts, move the root, or change animation ownership.

## Runtime bounds

- two global player lifecycle connections;
- three connections per tracked player;
- two descendant lifecycle connections per active character;
- at most three Motor6D baseline writes per operative event;
- zero frame connections;
- zero timers;
- zero new remotes;
- zero server runtime changes.

Every captured shoulder and grip baseline is restored when the character, player, controller, or weapon binding is removed. Stale `WeaponGrip` motors are destroyed by the weapon presentation owner before replacement.

## Remaining gates

Roblox Studio gameplay-camera review, avatar-scale coverage, animation interaction review, canonical operative rig import, authored carry/revive/incapacitation/death animation, and representative squad performance evidence remain required.
