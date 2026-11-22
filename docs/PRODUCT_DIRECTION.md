# Aether Valley — Approved Product Direction

## Product identity and build target
- Product name: Aether Valley.
- New project from zero; no old repository code, mixed branding, CI workflows, or old APKs as the foundation.
- Engine target: Godot 4.x / GDScript.
- Initial delivery target: Android ARM64 debug APK for owner testing; desktop is the development and regression-test target.
- Offline-first single-player. Account/cloud save is persistence infrastructure, not a gameplay prerequisite.

## Core experience
Aether Valley is a sandbox-story cozy fantasy life-simulation RPG built around a living, reactive world. The player chooses daily goals while world systems simulate relevant relationships, needs, local economy, ecology, events, conflicts, discoveries, and mysteries. The intended experience is open-ended through systemic combinations and modular authored content, not literally infinite content.

## Core V1.0 activity priorities
1. Farming and gardening.
2. Livestock and animal care.
3. Forestry and woodcutting.
4. Mining and resource gathering.

Fishing, crafting, cooking, social systems, adventure, and narrative expansion are layered in after the initial playable region and core loop are stable.

## World and presentation
- Large, expandable world built from curated regions; begin with one deliberately small but complete playable region.
- 8-direction movement.
- Camera: Stylized Isometric 2.5D — Elevated Three-Quarter View (Orthographic-Style).
- Chibi character proportion.
- Phase 01 visual benchmark: Valley Landscape.
- High-detail hybrid pixel art, cozy fantasy, rich but restrained detail. The Phase 01 panorama/player are composition and behavior placeholders, not a final modular asset pack.

## Dynamic Fantasy Seasons
Spring, Summer, Autumn, Winter, Bloomveil, Crimsonfall, Frostveil, Solstice of Embers, Lunaris, Starfall, Tidal Bloom, Veil of Whispers, Crystalwake, Astral Drift. The 14 names are user-approved. Natural seasons provide a predictable annual rhythm; rare seasons may be recurring, regional, rare, story-triggered, or condition-triggered. The system remains data-driven and extensible. Avoid FOMO and progression softlocks.

## Dual-calendar and festival direction
- Real-world calendar: local device date/time as an offline source for optional date-linked event windows and original fantasy adaptations of selected celebrations.
- Fantasy world calendar: independent months, weekdays, anniversaries, festivals, celestial events, and supernatural phenomena; it governs the world's own time and progression.
- Cultural/religious/national event packs are configurable and not assumed universal. Exact fantasy month structure, supported event packs, opt-in defaults, and launch festival count remain open.

## Living World and emergent gameplay
The Living World Engine coordinates persistent world, NPC, ecology, local economy, event, consequence, and story state. Simulation detail scales by relevance/distance: nearby entities update in detail, distant regions use scheduled summaries, and inactive systems advance deterministically when time passes.

Approved dimensions: contextual interaction possibilities; authored/system events; quests emerging from NPC needs, shortages, discoveries, relationships, seasons and unresolved situations; NPC memory and relationships creating personal stories; curated regions, secrets, changing points of interest and resource variation.

Events must be legible, proportionate, fair, and not arbitrary punishment. Quest generation uses validated templates, constraints, cooldowns, player capability checks, and alternate routes for essential progression.

## Persistence requirements
- Local autosave every 30 seconds while dirty, plus best-effort save on pause/close.
- Cloud autosave every 60 minutes while online and authenticated.
- Queue latest local generation while offline.
- On login/reinstall/new device, compare local/cloud versions before restore; never silently overwrite a newer generation.
- Keep a recoverable previous generation and version every save schema.
- Cloud must never block offline play.

## First implementation slice
Phase 01: clean Godot project, Valley Landscape + chibi visual benchmark, elevated three-quarter movement, camera framing, HUD, basic touch controls, and local save foundation. Do not begin mass final asset production until runtime and visual benchmark gates pass.

## Explicitly not locked yet
- Exact tile/pixel dimensions and final collision footprints.
- Fantasy month names, month lengths, weekday structure, season durations and trigger rates.
- Full region map and world size implementation details.
- NPC cast, main mystery canon, exact quest/event catalogue and simulation tuning.
- Cloud provider project provisioning and final account UI.
