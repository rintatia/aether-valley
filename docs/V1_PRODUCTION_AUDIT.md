# V1 Production Audit — 22 November 2026

## Audit verdict

The current `main` branch is a prototype foundation, not a V1 game and not an acceptable V1 test candidate.

Audited baseline: `main` at `e3bce9879602de5fcd7521bc7f6e9d8ad7242963`.

## Direct evidence in source

- `scripts/world.gd` draws the world at runtime with `draw_colored_polygon`, `draw_circle`, `draw_rect`, and `draw_polyline`. The ground is a repeated diamond grid. The home, trees, rocks, chicken, and crops are primitive drawings.
- `scripts/player.gd` draws a simple geometric player directly in `_draw()`; there is no sprite sheet, directional animation, equipment animation, or character asset pipeline.
- `scenes/main.tscn` contains one main world node, one player, one circle collision shape, one camera, and touch controls. There is no modular terrain, prop, building, water, foliage, or interaction scene composition.
- `scripts/world.gd` currently seeds six plots, three trees, two rocks, and one chicken. It contains rudimentary turnip growth/harvest, chicken feed/egg, tree chopping, and mining.
- `tests/gameplay_smoke.gd` validates only those narrow loops and a save payload. It does not validate a complete region, depth sorting, collision against environment, animation, UI layout, progression, or Android touch behavior.
- `export_presets.cfg` on main contains only an Android Debug preset. It does not establish a V1 Release candidate.
- `scripts/save_service.gd` implements local save scaffolding. Cloud authentication and cloud save sync are not present in this runtime.

## Required production work before V1 Candidate

1. Replace the procedural diamond ground and primitive object drawings with approved, imported visual assets and modular scene layers.
2. Implement a complete Spring Valley region with terrain boundaries, paths, buildings, water, bridges, cliffs, foliage, resource nodes, and readable traversal.
3. Replace the geometric player with an approved chibi sprite set and 8-direction movement/idle/tool animations; validate sorting and collision footprints.
4. Implement usable farming, animal care, woodcutting, and mining interactions in the world, with inventory and progression feedback.
5. Replace debug-like HUD presentation with a finished mobile-first game UI and reliable touch controls.
6. Validate local persistence, day/season progression, and recovery.
7. Run Godot import/parse, automated gameplay tests, desktop runtime checks, Android Release export/signature checks, and physical-device acceptance.

## Acceptance rule

An APK export succeeding is only a packaging result. It is not evidence that the game is a V1. A V1 Candidate may be labeled as such only after the production items above are implemented and automated checks pass. Physical-device behavior must remain explicitly marked untested until actually tested.

## Visual constraints

Use the user's approved master showcase and Spring Valley benchmark as authoritative art direction. The Spring Valley panorama is a composition study, not a modular runtime tileset. Do not stretch it across the screen and call it a finished world. Do not lock tile dimensions before visual integration validation.

## Current status

- Prototype source audit: COMPLETE.
- V1 production implementation: NOT COMPLETE.
- V1 visual integration: NOT COMPLETE.
- V1 Android Release candidate: NOT READY.
