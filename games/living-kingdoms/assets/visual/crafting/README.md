# Crafting Presentation Source Models

Held, presentation-only source models for the existing `CraftingPresentationRegistry` surface.

This pack realizes the planned field bench, scrap bundle, fabric roll, hand tools, and parts crate without activating crafting. `FieldBenchV1` preserves the registry mapping to canonical `station.hub.crafting`; the ingredient, tool, and container props remain intentionally unbound to gameplay refs.

All source parts are anchored and all authored attachments are presentation/snap sockets only. These models contain no scripts, remotes, inventory mutation, recipe execution, reward grants, persistence, networking, or gathering authority. They remain runtime-unmapped and Studio-unapproved until a later integration pass.
