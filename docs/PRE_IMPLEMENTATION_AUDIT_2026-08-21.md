# PRE-IMPLEMENTATION AUDIT — 2026-08-21

This is the code/runtime audit captured before the Map LAB, settings and match-reference implementation phase. Status is based on repository commit `4258634`, not screenshots or UI copy.

## Resolution and UI scale

| Concern | Evidence | Status before implementation |
|---|---|---|
| Base viewport | `project.godot`: 1280×720 | Implemented |
| Startup window override | `project.godot`: 1920×1080 | Implemented, but causes the 1280 canvas to render at 1.5× |
| Stretch | `canvas_items`, aspect `expand` | Connected; contributes to inconsistent effective coordinates |
| Responsive breakpoints | `responsive.gd`: 1440/1800/2400 | Connected, but classification observes the stretched viewport and fixed minimum sizes remain common |
| Sidebar/topbar | 176/206 px sidebar; 60/68 px topbar | Connected |
| Map preview | 720 px minimum plus 600 px inspector | Connected but too large for the first compact viewport |
| 2560×1080 | Classified ultrawide; no maximum content width | Partial; can produce overly spread layouts |

Primary cause of the oversized UI is the 1280×720 viewport combined with the 1920×1080 override (`1.5×`). Fixed pixel minimum sizes are a secondary cause.

## Settings

| Setting | Stored | Consumer | Persistence | Audit status |
|---|---|---|---|---|
| Master volume | `UserSettings.values` | Master audio bus dB/mute | `user://settings.json` | Working |
| Music volume | same | Dynamically-created Music bus | same | Working at bus level; no music playback was found |
| SFX volume | same | Dynamically-created SFX bus | same | Working at bus level; playback routing not confirmed |
| Display mode | same | `DisplayServer` | same | Working |
| Windowed resolution | same | Applied only in WINDOWED mode | same | Working in windowed; intentionally irrelevant to fullscreen/borderless |
| VSync | same | `DisplayServer.window_set_vsync_mode` | same | Working |
| UI scale | same | `Window.content_scale_factor` | same | Working, but compounds the existing 1.5× project scaling problem |
| Reduce motion | same | No code consumer found | same | UI only |
| High contrast | same | No theme/runtime consumer found | same | UI only |
| Autosave | same | No GameState consumer; GameState saves actions unconditionally | same | UI only / misleading |
| Career difficulty | career save | economy, training, scouting, inbound interest | career save | Working outside MatchRuntime; no direct combat modifier |
| Developer mode | career save | gates simulation overrides and tools | career save | Working |
| Five simulation scales | career save | MatchRuntime | career save | Working for new matches only |

## Map data and editor

| Feature | Code/runtime evidence | Audit status |
|---|---|---|
| Six selected maps | `MapCatalog.MAP_PATHS`; selector loads descriptor/override | Implemented + connected |
| Per-map overrides | `user://map_overrides/<id>.json` | Implemented + connected |
| Square 4/5/6 km validation | `MapCatalog.validate` | Implemented + connected |
| POI (`regions`) | drop selection, terrain lookup, editor | Implemented + connected, but name/loot semantics are mixed |
| Compounds | direct runtime loot sources | Implemented + connected |
| Points | direct runtime isolated loot sources | Implemented + connected |
| Roads | freehand path, width, vehicle speed/spawn | Partial: create/delete works; existing path points cannot be edited |
| River/forest strokes | freehand path and width | Partial: create/delete works; no density/hearing/detection/cover inspector |
| Buildings | rectangle, cover, loot settings | Implemented but semantically wrong: every building is automatically a loot source |
| Transport nodes | runtime acquisition and rendering | Implemented + connected; no editor create/move/delete |
| Select/move | POI, compound, point, building | Partial; stroke selection/editing is not implemented |
| Eraser | Remove buttons only | Not implemented as a canvas tool |
| Undo/redo | none | Not implemented |
| Grid/coordinates/physical scale | none | Not implemented |
| Map editor zoom/pan/fit | overlay emits signals, Map Manager does not connect them | Implemented but not connected |
| Brush cursor | only committed/in-progress path is drawn | Not implemented |
| Layer visibility | one design-layer flag | Partial; no per-layer controls |
| Test/preview mode | none | Not implemented |
| Analyst Map | reloads map data, design layers visible, editor disabled | Implemented + connected, read-only |

All six shipped JSON descriptors have zero `terrain_strokes` and zero `buildings`; the optional arrays are injected at load. Existing authored roads are polylines with at least two points.

## Terrain and buildings

| Rule | Runtime consumer | Audit status |
|---|---|---|
| River movement | `terrain_profile_at` → movement | Connected, data-driven per stroke |
| Forest movement | same | Connected, data-driven per stroke |
| Forest vision | observer-side contact score | Connected, but only the observer position is sampled |
| Forest detection/hearing/cover | no explicit fields/consumers | Not implemented |
| Building cover | target hit-chance penalty | Connected |
| Building concealment/detection | no consumer | Not implemented |
| LOS blocking/occupancy | no model | Not implemented |
| Road vehicle speed | `movement_profile` | Connected |
| Road vehicle spawn | `_can_acquire_vehicle` | Connected, probabilistic |

## Loot

| Feature | Evidence | Audit status |
|---|---|---|
| Runtime item offers | `_generate_source_loot` | Implemented + connected |
| Map-size density | source effective multiplier | Implemented + connected |
| Source size | compound building count / explicit slots | Implemented + connected |
| AI pickup preference | `_choose_loot_item`, role category score | Implemented + connected |
| Allowed/excluded categories | no source schema or filter | Not implemented |
| Category/item weights | hard-coded runtime category roll | Not data-driven |
| Military loot | no source type or pool | Not implemented |
| Respawn | item is removed; no refill | Not implemented |
| Building separation | buildings are currently appended by `loot_sources()` | Incorrect before implementation |
| Team-level `_loot_event` | adds aggregate resources independently of physical source stock | Partial / parallel simplified system |

## Weapons, attachments, armor and ammo

| Feature | Audit status |
|---|---|
| 41 weapon names | Implemented in MatchRuntime constants |
| Per-weapon damage/accuracy/category | Implemented; 29 in primary table, 12 in a legacy-named active table |
| Range/falloff | Category-derived, connected |
| Physical meters | normalized distance × map `world_size_m`, connected |
| Kill-feed distance | connected |
| Headshot | fixed 16% chance and ×1.5 damage |
| Armor/helmet | durability is virtual HP; head uses helmet, body uses vest |
| Internal ammo | one unit consumed per shot |
| UI ammo | category multiplier only; does not change simulation |
| Attachment compatibility/equip | implemented |
| Attachment combat effects | none; attachments are inventory/UI only |
| Reload | keys are checked, but no reload action sets them | Implemented but not connected |
| Magazine size/ammo caliber/fire rate | not simulated |
| Loot rarity | hard-coded category probability; no explicit per-weapon rarity database |

## Match systems

| System | Audit status |
|---|---|
| Deterministic seed | Implemented and regression-tested |
| Flight/drop/loot/movement/contact/combat | Implemented + connected |
| Five blue-zone phases | Implemented + connected |
| Red zone | Implemented + connected |
| Airdrop | Implemented; player organization only can acquire it |
| Heal/boost/revive | Implemented + connected |
| Smoke | visual effect only; no contact/LOS modifier |
| Frag/Molotov | damage implemented |
| Flash | visual/event only |
| Vehicle fuel/durability | implemented, simplified |
| Vehicle source consumption | not implemented; the same source may roll repeatedly |
| Pathfinding/road graph/interiors/projectile physics | not implemented |

## Documentation and test discrepancy

`docs/MATCH_GAMEPLAY_FLOW.md` documents the recent range/armor/brush changes but is not yet a complete technical specification. It does not contain the required full weapon, attachment, attribute, settings, control, persistence and test inventories.

Existing tests cover schema, two terrain modifiers, building cover/loot, ammo presentation, range falloff, armor and kill-feed distance. They currently assert the incorrect rule that a building is a loot source. Existing visual tests create layers through callbacks, not real pointer gestures, and the 1280 capture path resizes the resulting image; it is not sufficient proof that the physical window configuration is correct.

This snapshot will not be rewritten after implementation. The final technical specification must describe the resulting code separately and call out any remaining limitations.
