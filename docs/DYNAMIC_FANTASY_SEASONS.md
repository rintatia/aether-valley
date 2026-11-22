# Dynamic Fantasy Seasons — Approved Catalogue

The user approved this initial 14-season catalogue on 22 November 2026. Four natural seasons are the foundation, not the system limit.

| Season | Category | Intended identity |
|---|---|---|
| Spring | Natural | Renewal, blossoms, planting rhythm |
| Summer | Natural | Warmth, long days, growth |
| Autumn | Natural | Harvest, amber foliage, preparation |
| Winter | Natural | Frost, dormancy, cold-weather resources |
| Bloomveil | Magical | A valley-wide bloom surge and unusual flowering |
| Crimsonfall | Magical | Red foliage, ember-like leaves, rare harvest effects |
| Frostveil | Magical | Enchanted frost and altered winter ecology |
| Solstice of Embers | Magical | Warmth, glowing embers, fire-aligned phenomena |
| Lunaris | Celestial | Moonlight, nocturnal wildlife, lunar events |
| Starfall | Celestial | Meteoric traces, rare minerals, sky events |
| Tidal Bloom | Elemental | Water cycles, river/floodplain changes, aquatic growth |
| Veil of Whispers | Mythical | Mist, echoes, hidden paths, unusual encounters |
| Crystalwake | Magical | Crystal growth, resonant mineral phenomena |
| Astral Drift | Celestial | Unusual constellations and altered ambient magic |

## Architecture contract
- Load definitions from data; do not hard-code a 4-value enum.
- Each definition needs a stable ID, display name, category, duration/trigger policy, region scope, visual profile, gameplay modifiers, and transition rules.
- Natural seasons form the predictable calendar rhythm. Rare seasons may be global, regional, recurring, or condition/story-triggered.
- Rare seasons may overlap a natural season as modifiers.
- Farming, plants, livestock, wildlife, fishing, resources, NPC schedules, festivals, routes, quests, monsters, lighting, weather, and environment consume season tags/modifiers through data contracts.
- Essential progression resources must have alternate paths; rare seasons must not create FOMO traps.
- Save active season IDs, regional modifiers, and transition history. Unknown IDs during migration safely fall back to a valid base season while preserving diagnostics.
- New seasons should be addable through data and assets, not core-system rewrites.

## Implementation status
The clean-start project currently contains the approved IDs and basic catalog loading only. Season scheduling, regional overlap, gameplay effects, transition UI, and save migration are not implemented yet.
