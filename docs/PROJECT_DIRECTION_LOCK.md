# Aether Valley — Project Direction Lock

- Product identity: Aether Valley. Clean project from zero; do not reuse old project code, repository, build outputs, or CI.
- Engine target: Godot 4.x / GDScript.
- Camera phrase: **Stylized Isometric 2.5D — Elevated Three-Quarter View (Orthographic-Style).**
- Character proportion: chibi.
- Visual direction: high-detail hybrid pixel art, cozy fantasy, restrained detail, consistent with the original user-provided showcase reference. Valley Landscape is the Phase 01 visual benchmark, not a final modular asset pack.
- Movement: 8 directions.
- World: large, offline-first single-player.
- Gameplay priorities: farming/gardening, livestock/animal care, forestry/woodcutting, mining/resources.
- Seasons: the 14 user-approved Dynamic Fantasy Seasons are defined in data/seasons.json; architecture must remain data-driven and extensible.
- Save: local autosave every 30 seconds while dirty; save on app pause/close; cloud sync must never block offline play.

Temporary geometry, the player drawing, and 64x32 grid diamonds are placeholders only. Do not lock final tile dimensions, sprites, collision dimensions, or asset scale from this prototype.
