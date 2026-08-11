# Living Kingdoms — Environment Asset Kit Registry

**Status:** SOURCE-PREPARED CONTENT FACTORY BOUNDARY  
**Purpose:** make the 20th rock, 50th prop, or 100th environment variant mostly model/data work rather than new gameplay code.

## Direction

Living Kingdoms environment art targets **dark frontier / corrupted wilderness / abandoned industry**. The registry is an ingestion boundary for modular visual content, not a second gameplay system.

Initial families include rocks/cliffs, living and dead vegetation, roots/brush/clutter, structures, props, bridges, caves, abandoned-industry pieces, camps, and unknown/corrupted structures.

Every registered environment asset declares:

- stable semantic asset ID and variant ID;
- environment family and intended biome IDs;
- scale class and physical footprint;
- collision policy;
- semantic streaming group;
- Minimum/Reduced/Full presentation intent;
- optional VFX/audio/prop/snap/traversal sockets;
- source model path;
- explicit presentation-only status.

## Authority boundary

Environment models and registry rows do **not** own combat, enemies, interaction eligibility, inventory, crafting, gathering, quests, progression, persistence, networking, or other consequential gameplay truth.

`EnvironmentAssetKitContracts.validate` fails closed when a registered asset attempts to declare a gameplay authority owner. Final meshes may replace placeholder/source-safe models without changing semantic IDs or gameplay ownership.

## First seed definitions

The v1 registry includes four representative rows to exercise the pipeline:

- `env.rock.frontier.boulder_a`
- `env.tree.corrupted.dead_pine_a`
- `env.structure.industry.mine_support_a`
- `env.camp.frontier.abandoned_fire_ring_a`

They establish the registry shape; they are not claims that final production meshes already exist or have passed Studio visual review.

## Expansion rule

New environment content should prefer adding validated registry data and model assets over new runtime scripts. Variants should share families, sockets, materials, and modular conventions where possible so content breadth compounds rather than multiplying maintenance cost.
