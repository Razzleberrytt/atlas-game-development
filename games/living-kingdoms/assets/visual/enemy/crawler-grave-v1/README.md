# Crawler Grave V1 — source blockout

This directory contains the first project-original source blockout for `enemy.presentation.crawler.grave_v1`.

The blockout exists to lock the enemy's **identity**, not to claim final mesh/rig quality. A production mesh may replace every primitive Part while preserving the semantic presentation ID and the following silhouette requirements:

- four-point ground contact;
- shoulders slope inward/down rather than reading as a normal humanoid T-pose;
- exposed spinal mass rises above the head line;
- the head hangs low and forward beneath the torso;
- long forelimbs create a wall-shadow / low-predator profile;
- the exposed spine remains visually legible as the weak-point presentation region;
- the body-freeze → spine-rise → lunge tell must remain readable when animation is authored.

`CrawlerGraveV1.model.json` is held source geometry only. It is **not runtime mapped**, creates no AI, damage, locomotion, spawning, rewards, networking, or weak-point authority, and makes no Studio approval claim. Those remain in canonical enemy/gameplay owners.

Future art passes should prioritize silhouette and locomotion readability over adding small surface detail. The Crawler should be recognizable at distance and frightening from motion/posture before texture detail is visible.
