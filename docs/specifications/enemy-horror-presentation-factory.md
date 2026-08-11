# Living Kingdoms — Distinctive Horror Enemy Presentation Factory

**Status:** SOURCE-PREPARED PRESENTATION BOUNDARY

Living Kingdoms enemies should be identifiable from silhouette and movement before the player can read a nameplate. Visual variants may reuse canonical enemy mechanics, but should not collapse into simple recolors of one generic body.

## Design rule

Build fear from **silhouette + posture + locomotion + audio/VFX identity + readable attack tells**, not gore volume.

Each enemy presentation definition carries a stable canonical archetype/role binding, custom-model family/path, silhouette class, locomotion presentation class, animation/audio/VFX identities, optional weak-point presentation, cosmetic skin variants, horror tags, and attack-tell tags.

Presentation never owns health, speed, attack damage, spawning, targeting, rewards, or enemy state. Those remain in the existing canonical enemy/horde services.

## First custom-model identities

The current six horde roles receive distinct planned model families:

- Exclusion Stalker — broken humanoid stalking silhouette;
- Runner — razor-thin sprinter silhouette;
- **Crawler — grave-low predator silhouette**;
- Screamer — tall choir/beacon silhouette;
- Bloater — asymmetric pressure-sac hazard silhouette;
- Brute — heavy overgrown juggernaut silhouette.

### Crawler priority

Crawler is the first enemy that should receive a genuinely different production mesh/rig treatment. Its target identity is four-point ground contact, inverted shoulder line, spine rising above the head, and a wall-shadow-like profile. It should read as something that moves incorrectly even before it attacks.

Horror may not erase fairness. Crawler still requires visible/audible attack tells: body freeze before lunge, spine rise, and a short jaw-click burst are presentation targets. These are not new gameplay timings or AI behaviors; they are art/animation/audio hooks around existing canonical behavior until a separately authorized gameplay change exists.

## Variant strategy

Initial cosmetic mutation directions are Wet Decay, Ash Burned, and Mine Rot. They change material/palette and physical-detail language only; they never alter health, damage, speed, rewards, or role selection.

Future enemy populations should gain diversity by combining mechanical role + model family + validated skin/mutation variants before multiplying AI authorities.
