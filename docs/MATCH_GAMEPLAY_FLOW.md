# MATCH GAMEPLAY TECHNICAL SPECIFICATION

Verified against repository implementation on 2026-08-21. This document describes code that exists now; a visible control is not treated as proof of functionality. Status vocabulary: **CONNECTED**, **PARTIAL**, **UI ONLY**, **NOT IMPLEMENTED**.

## 1. Document purpose

This is the technical and game-design reference for one match, the authorable map model, its career connections, and the UI controls that expose those systems. When this document, UI text, and runtime disagree, runtime code wins.

## 2. Source of truth

| Concern | Source | Authority |
|---|---|---|
| Match simulation | `scripts/match_runtime.gd` | Timers, states, movement, loot, contact, damage, zones, result telemetry |
| Career state | `scripts/game_state.gd` | Event context, tactics, difficulty, calendar, result commit, saves |
| Map loading/runtime queries | `scripts/map_catalog.gd` | Six descriptors, override migration, validation, loot/road/terrain/building queries |
| Map drawing/input | `scripts/match_map_overlay.gd` | Observer layers and real Map LAB pointer gestures |
| UI and flows | `scripts/main.gd`, `scripts/ui/router.gd`, `scripts/ui/*` | Screens, controls and responsive shell |
| Maps | `data/maps/*.json` | Square map geometry, POIs, compounds, roads, points, transport and terrain rules |
| Loot profiles | `data/loot/loot_profiles.json` | Standard, village and military category weights |
| Tactics | `data/tactics/coach_presets.json` | Valid coach-plan options |
| Competitive rules | `database/rules/competitive_rules.json` | 16 teams, four players/team, five zones, six-map pool |
| Tests | `tests/*.gd` | Executable regression evidence; latest results are in the delivery report |

The immutable pre-change findings are in `docs/PRE_IMPLEMENTATION_AUDIT_2026-08-21.md`.

## 3. Match lifecycle

```text
Career event
→ GameState prepares event/map/scoring/player data
→ effective coach plan and optional developer overrides
→ MatchRuntime.start_match(...)
→ deterministic seed and map override load
→ plane/flight → jump → landing → finite-source loot
→ regroup/rotation/contact/combat actions
→ five blue-zone phases + optional red zones + airdrops
→ one team remains or 900 seconds expires
→ scoreboard/result telemetry
→ GameState commits only a career-owned match
```

| Phase | Input and state change | Output | Code |
|---|---|---|---|
| Preparation | Event id, season, map, roster, teams, scoring, coach plan, overrides | Seed, map, teams, loadouts and source stock | `GameState.prepare_match_context()`, `MatchRuntime.start_match()` |
| Flight | Seeded route; plane completes in 75 s | `IN_PLANE`, jump position/time | `_make_flight_path()`, `_update_deployment()` |
| Drop | Policy chooses POI/compound/isolated target; accuracy can offset target | `AIRBORNE`, destination, landing time | `_team_drop_target()`, `_apply_drop_error()` |
| Loot | Position overlaps explicit source; AI ranks finite offers | Weapons, ammo, armor, healing, utility, attachments | `_initialize_loot_stock()`, `_loot_player()` |
| Rotation | Coach macro, formation, urgency, terrain and vehicles | Move target/state/transport | `_update_player_movement()`, `_tactical_zone_target()` |
| Contact | Senses, policy, distance, noise, terrain/building concealment | Contact telemetry | `_resolve_contact()` |
| Combat | Weapon, meters, hit roll, damage, armor, DBNO | Damage, knock/finish, kill feed | `_resolve_combat()`, `_apply_damage()` |
| Zones/events | Fixed blue table; seeded red zone/airdrop | Damage/effects/timeline | `_update_zone_state()`, `_update_red_zone()`, `_update_airdrops()` |
| Finish | One team remains or duration reaches 900 s | Winner, scoreboard, result | `_finish()`, `_build_result()` |
| Career commit | Result plus event ownership | History and downstream career updates | `GameState.apply_match_runtime_result()` |

## 4. Match state machine

| State | Meaning | Entry/exit |
|---|---|---|
| `IN_PLANE` | Attached to plane progress | Start → jump time |
| `AIRBORNE` | Interpolating to drop destination | Jump → computed land time |
| `LOOTING` | Repeated source offer decisions | Landing → 24–38 s loot window |
| `ALIVE` | Available for decisions/combat | Default standing state |
| `WALKING` | Foot rotation | Move target active |
| `SWIMMING` | Foot movement in water | Water profile; lower speed |
| `DRIVING` | Vehicle movement | Acquired source and resources available |
| `HEALING` / `BOOSTING` | Timed inventory action | Complete or interrupted |
| `REVIVING` | Timed teammate revive | Complete, damaged, blue interrupted, or out of range |
| `KNOCKED` | DBNO pool active | Revived, bled/finished, hazard |
| `DEAD` | Eliminated | Terminal |

There is no prone/crouch/interior navigation state.

## 5. Team behavior

- Sniper/Scout prefer SR→DMR→AR; Entry/Fragger prefer SMG→Shotgun→AR; Support prefers DMR→AR→LMG; others prefer AR→DMR→SMG.
- Drop policy selects hot POIs, safer isolated nodes, split destinations or adaptive role-based targets.
- Formation and spacing create offsets, not navmesh formations.
- Zone macro changes target position. Urgency is `1 + zone_number × 0.22`, plus `1.4` at zone 5.
- Target priority/focus fire selects closest, lowest HP, fragger, isolated, or knocked targets.
- Contact is probabilistic. Proximity combat also checks teams at distance ≤ `0.105` normalized.
- Communication participates in revive decisions; health/boost/inventory drive recovery actions.
- Vehicle acquisition occurs near an unconsumed node or through a road roll.

## 6. Player attributes

| Attribute | Runtime effect/formula | Status |
|---|---|---|
| Aim | Hit term: `aim / 115 × weapon_accuracy × range_accuracy` | CONNECTED |
| Vision | Contact term `vision / 100 × 0.46 × terrain vision` | CONNECTED |
| Hearing | Contact term `hearing / 100 × 0.16 × hearing modifier` | CONNECTED |
| Game sense | Contact/decision and technical final-tick score | CONNECTED |
| Reaction | Decision input; no weapon RPM model | PARTIAL |
| Communication | Formation/contact/revive contribution | CONNECTED |
| Discipline | Mistake/action decisions | CONNECTED |
| Composure | Decision quality; no standalone clutch model | PARTIAL |
| Stealth | Noise/concealment side of contact | CONNECTED |
| Utility | Utility decision propensity | CONNECTED |
| Zone reading / map knowledge | Rotation/zone decisions | CONNECTED |
| Drop accuracy | Chance/radius of landing error | CONNECTED |
| Landing speed | Airborne duration | CONNECTED |
| Loot efficiency | Loot interval/behavior | CONNECTED |
| Early combat / adaptability | Decision inputs without a public isolated formula | PARTIAL |
| Leadership | Preserved; no direct combat modifier confirmed | PARTIAL |
| Energy | Copied; no direct MatchRuntime speed/damage modifier confirmed | PARTIAL |
| Morale/form/training impact | Career updates; no isolated recent-training match bonus | PARTIAL |

## 7. Map system

All maps use normalized `[0,1]²`, square `map_size_km`, and `world_size_m` for distance.

| Map | Size | Loot density | Vehicle need | POI / compound / legacy point / road / vehicle | Named POIs |
|---|---:|---:|---:|---:|---|
| Tactical Island | 4×4 | ×1.25 | ×0.72 | 4 / 8 / 3 / 3 / 3 | North Port, Central City, East Base, South Fields |
| Coastal Breakwater | 4×4 | ×1.25 | ×0.72 | 5 / 10 / 3 / 3 / 3 | Terrace Village, North Bay, Container Port, South Cove, Lighthouse |
| Verdant Reach | 5×5 | ×1.00 | ×1.00 | 5 / 10 / 3 / 3 / 3 | West Harbor, Rivergate, Central Depot, East Quarry, Sunfield |
| Frostline Valley | 5×5 | ×1.00 | ×1.00 | 5 / 10 / 3 / 3 / 3 | Glacier Dam, Pine Town, Frozen Crossing, North Station, South Harbor |
| Sunscorch Basin | 6×6 | ×0.82 | ×1.35 | 5 / 10 / 3 / 3 / 4 | Dustport, Sunfire Airfield, Oasis Market, South Refinery, Mirage Town |
| Highland Reserve | 6×6 | ×0.82 | ×1.35 | 5 / 10 / 3 / 3 / 4 | West Factory, Grand Quarry, Reserve Forest, Wind Plateau, River Farms |

Verdant Reach has a legacy rectangular river normalized to an editable water stroke. Other descriptors have no gameplay river/forest stroke until an override adds one. Visual terrain in map art does not count unless authored as data.

## 8. Map data model

```text
Map
├── POI (identity/drop region; no automatic loot)
│   └── Compound (legacy grouping/building-count metadata)
├── Loot Zone (large explicit finite source)
├── Loot Node (small explicit finite source)
├── Building rectangle (cover/concealment/occupancy; loot OFF by default)
├── Road path (class, width, vehicle speed/spawn chance)
├── River/Forest stroke (path, width, gameplay multipliers)
└── Transport Node (one consumable vehicle opportunity)
```

On load, each legacy compound becomes an explicit loot zone and each legacy point becomes an explicit loot node. A building joins `loot_sources()` only when `loot_enabled=true`.

## 9. Map editor

| Tool/control | Data written | Runtime effect |
|---|---|---|
| Map selector | Loads selected id | Same load path as MatchRuntime/Analyst Map |
| Select / Move | Position, rectangle center, whole-path translation | Moves real geometry |
| Add POI | `regions[]` | Drop identity/target; no loot by itself |
| Add Loot Zone | `loot_zones[]` | Finite stock, radius, slots, restrictions |
| Add Loot Node | `loot_nodes[]` | Small independent stock |
| Building Rectangle | `buildings[]` | Cover/concealment/detection/occupancy; no default loot |
| Three road brushes | Freehand `roads[].path` | Vehicle speed/acquisition near path |
| River/Forest brush | Freehand `terrain_strokes[]` | Movement/contact/cover modifiers |
| Add Vehicle Node | `transport_nodes[]` | Consumable acquisition opportunity |
| Eraser / Remove | Removes hit/selected object | Absent from later match after save |
| Width / Ctrl+wheel / `[` `]` | Width `0.008–0.18` | Geometry hit width |
| Undo / Redo | Deep-copy history, max 30 | Editor memory only until save |
| Save Override | Per-map JSON | Used by later match/Analyst loads |
| Reset | Deletes selected override | Restores repository descriptor |
| Zoom/pan/fit/grid/layer toggles | View state | No gameplay mutation |

Cursor preview shows normalized/meter coordinates, terrain, movement, vision, detection, cover, building, loot, road and vehicle chance. It is a query tool, not a duplicate match simulation.

## 10. Terrain system

`gameplay_profile_at()` combines terrain and optional building.

| Feature | Editable data | Runtime connection |
|---|---|---|
| River/water | width, move, vision, detection, hearing, cover, swim/vehicle | Movement, swimming, contact |
| Forest | width, density, move, vision, detection, hearing, cover | Movement, contact, hit penalty |
| Road | class, width, vehicle speed/spawn | Vehicle movement/acquisition |
| Building | rect, cover, concealment, detection, LOS flag, capacity | Contact/hit penalties, occupancy id |

New defaults: river move `.50`, vision `.90`, detection `.92`; forest move `.82`, vision `.68`, detection `.62`, hearing `.86`, cover `.16`, density `.70`. Inspectors change them per stroke. `los_blocking` adds a fixed `.18` hit penalty; it is not raycast LOS. Capacity is stored but not enforced.

## 11. Loot system

1. Load normalizes zones/nodes.
2. POIs, compounds and default buildings are not direct sources.
3. `effective_multiplier = source loot_multiplier × map size_density_factor`.
4. `slots = max(1, round(base slots × effective_multiplier × developer loot scale))`.
5. Each slot rolls a category from `data/loot/loot_profiles.json`, then an item.
6. Allowed/excluded categories zero weights. Source category weights override profile weights. Item weights affect weapon selection. Min/max quantity affects ammo-unit quantity; rarity multiplier affects armor-level roll.
7. Overlap chooses only the highest-multiplier source.
8. AI scores offers by role/loadout/resource plan and may reject one.
9. Accepted items are removed from shared finite stock.

`standard` is balanced (SR weight 1.5); `village` favors SMG/Shotgun/heal and has SR 0; `military` favors AR 30, DMR 20, SR 5, Vest 14, Helmet 13 and Pistol 0. Compounds under a `military_base` POI normalize to military zones. Source count is authored; POI size does not invent extra sources.

AWM and Lynx AMR are excluded from normal rolls. AWM has an airdrop path; no Lynx acquisition path is confirmed. Backpack capacity is 50/150/220/270. Overweight discard removes Bandages then aggregate ammo; per-weapon ammo reconciliation in that discard path is **PARTIAL**.

## 12. Weapon database

There are 40 weapons. Damage/accuracy are per weapon; range/falloff/UI ammo come from category. RPM, magazine, reload, caliber, rarity and unique slots do not exist.

| Weapon | Cat. | Dmg | Acc. | Optimal/max | Floor | Normal | Airdrop / note |
|---|---|---:|---:|---:|---:|---|---|
| UMP45 | SMG | 31 | .82 | 60/180 m | .44 | Yes | — |
| Vector | SMG | 30 | .85 | 60/180 m | .44 | Yes | — |
| MP5K | SMG | 33 | .84 | 60/180 m | .44 | Yes | — |
| Micro Uzi | SMG | 26 | .78 | 60/180 m | .44 | Yes | — |
| Tommy Gun | SMG | 40 | .76 | 60/180 m | .44 | Yes | Active legacy table |
| PP-19 Bizon | SMG | 35 | .80 | 60/180 m | .44 | Yes | Active legacy table |
| M416 | AR | 41 | .86 | 180/450 m | .52 | Yes | — |
| SCAR-L | AR | 41 | .84 | 180/450 m | .52 | Yes | — |
| AUG | AR | 42 | .88 | 180/450 m | .52 | Yes | — |
| QBZ | AR | 42 | .83 | 180/450 m | .52 | Yes | — |
| Beryl M762 | AR | 48 | .80 | 180/450 m | .52 | Yes | — |
| AKM | AR | 48 | .78 | 180/450 m | .52 | Yes | — |
| ACE32 | AR | 46 | .82 | 180/450 m | .52 | Yes | — |
| Groza | AR | 49 | .87 | 180/450 m | .52 | Yes | Not airdrop-only in code |
| G36C | AR | 41 | .85 | 180/450 m | .52 | Yes | Active legacy table |
| FAMAS | AR | 42 | .86 | 180/450 m | .52 | Yes | Active legacy table |
| M16A4 | AR | 43 | .80 | 180/450 m | .52 | Yes | No burst model |
| Mutant | AR | 44 | .82 | 180/450 m | .52 | Yes | No burst model |
| Mini14 | DMR | 51 | .88 | 380/850 m | .62 | Yes | — |
| Mk12 | DMR | 51 | .88 | 380/850 m | .62 | Yes | — |
| SLR | DMR | 56 | .84 | 380/850 m | .62 | Yes | — |
| SKS | DMR | 53 | .80 | 380/850 m | .62 | Yes | — |
| Dragunov | DMR | 58 | .86 | 380/850 m | .62 | Yes | — |
| VSS | DMR | 44 | .80 | 380/850 m | .62 | Yes | No suppressor effect |
| M24 | SR | 79 | .90 | 700/1250 m | .72 | Yes | ≥105 raw inside optimal |
| Kar98k | SR | 75 | .87 | 700/1250 m | .72 | Yes | ≥105 raw inside optimal |
| AWM | SR | 105 | .94 | 700/1250 m | .72 | No | Yes; 3 internal units |
| Lynx AMR | SR | 118 | .92 | 700/1250 m | .72 | No | No confirmed source |
| M249 | LMG | 43 | .78 | 220/520 m | .52 | Yes | — |
| MG3 | LMG | 40 | .77 | 220/520 m | .52 | Yes | — |
| DP-28 | LMG | 51 | .80 | 220/520 m | .52 | Yes | — |
| S12K | Shotgun | 88 | .79 | 12/40 m | .34 | Yes | ≥105 raw inside optimal |
| DBS | Shotgun | 92 | .84 | 12/40 m | .34 | Yes | ≥105 raw inside optimal |
| S686 | Shotgun | 96 | .82 | 12/40 m | .34 | Yes | ≥105 raw inside optimal |
| S1897 | Shotgun | 91 | .78 | 12/40 m | .34 | Yes | Active legacy table |
| O12 | Shotgun | 84 | .81 | 12/40 m | .34 | Yes | Active legacy table |
| P92 | Pistol | 34 | .72 | 45/120 m | .42 | Yes | — |
| Deagle | Pistol | 62 | .76 | 45/120 m | .42 | Yes | — |
| R1895 | Pistol | 55 | .74 | 45/120 m | .42 | Yes | — |
| P18C | Pistol | 29 | .74 | 45/120 m | .42 | Yes | Active legacy table |

Damage also multiplies seeded random `.82–1.18`, distance falloff, optional headshot `×1.5`, global developer scale and per-weapon scale.

## 13. Weapon category table

| Category | Optimal | Max | Floor | UI rounds/internal unit |
|---|---:|---:|---:|---:|
| Shotgun | 12 m | 40 m | 34% | 5 |
| Pistol | 45 m | 120 m | 42% | 15 |
| SMG | 60 m | 180 m | 44% | 30 |
| AR | 180 m | 450 m | 52% | 30 |
| LMG | 220 m | 520 m | 52% | 50 |
| DMR | 380 m | 850 m | 62% | 10 |
| SR | 700 m | 1,250 m | 72% | 5 |

Beyond max, hit chance is forced to `.01`; the damage helper remains at the floor.

## 14. Attachments

| Items | Slot | Compatibility | Combat effect |
|---|---|---|---|
| Red Dot, 2x | Scope | All non-pistol categories | None |
| 3x, 4x, 6x, 8x | Scope | AR/LMG/DMR/SR | None |
| Compensator, Suppressor, Flash Hider | Muzzle | AR/SMG/DMR/SR/LMG | None |
| Extended Mag, Quickdraw Mag | Magazine | AR/SMG/DMR/SR/LMG | None |
| Vertical, Angled, Lightweight Grip | Grip | AR/SMG | None |
| Tactical Stock, Cheek Pad | Stock | AR/SMG/DMR/SR | None |

Runtime spawns, scores, equips and replaces one per weapon-slot/type; primary scope appears in UI. No attachment changes accuracy/range/damage/ammo/reload/detection. **PARTIAL**.

## 15. Armor / helmet

| Virtual HP | Lv.1 | Lv.2 | Lv.3 |
|---|---:|---:|---:|
| Helmet | 35 | 60 | 90 |
| Vest | 50 | 80 | 120 |

```text
selected durability = helmet for headshot, vest otherwise
absorbed = min(raw damage, durability)
durability -= absorbed
HP damage = raw damage - absorbed
broken when durability <= 0
```

It is virtual HP, not percentage reduction. Durability is match loadout state, not persistent career equipment.

## 16. Ammo

One fire event consumes one primary/secondary internal unit. UI multiplies it by section 13 values and never changes simulation stock. Weapon selection checks a `<slot>_reload_until` key, but no code sets it. Magazine, caliber and reload are **NOT IMPLEMENTED**.

## 17. Combat system

Distance is `normalized Euclidean distance × world_size_m`, correct for 4/5/6 km maps.

```text
range_accuracy = clamp(1 - distance_m/max_range × .58, .18, 1)
cover_penalty = terrain_cover × .38 + building_concealment × .12
              + (.18 if building.los_blocking else 0)
competitive modifier = +.07 AI→player, -.035 player→AI
hit = .01 beyond max
    else clamp(aim/115 × accuracy × range_accuracy
               + competitive modifier + tactical bonus - cover penalty,
               .05, .84)
distance damage = 1 through optimal, linear to floor at max
raw = base × random(.82,1.18) × distance damage
Shotgun/SR raw >= 105 inside optimal
headshot chance .16; headshot ×1.5
```

Armor absorbs next. Zero HP knocks a standing player; hazards or damage against knocked can finish. Kill feed stores actor, target, weapon, outcome and rounded meters. No projectile, penetration, recoil, geometric LOS or interior ballistics exists.

## 18. Movement

- Player base: foot `.00075`, swim `.00038`, vehicle `.0022` normalized/s.
- AI member base: foot `.00068`, vehicle `.0018`.
- Terrain/stroke multiplier applies at current position.
- Roads multiply vehicle speed within `width × .6` of path.
- Movement is direct toward target; no A*, road graph, collision avoidance or building pathfinding.
- Zone urgency increases movement. AI does not plan around terrain; terrain modifies it while occupied.

## 19. Vehicles

Map need and developer density affect acquisition. Nodes and roads have authored chances. Each source id is consumed after successful acquisition, preventing repeated awards from that source. Vehicle state tracks fuel/durability/expiry. A driving shooter has 16% event chance for raw 120 impact. Types are labels: handling, seats, repair, collision geometry and vehicle combat are not modeled.

## 20. Blue zone

| Zone | Reveal | Start | End | Radius | Damage | Severity |
|---:|---:|---:|---:|---:|---:|---|
| 1 | 80 | 130 | 260 | .38 | 1 | Very low |
| 2 | 260 | 310 | 450 | .25 | 2 | Low |
| 3 | 450 | 490 | 610 | .15 | 4 | Medium |
| 4 | 610 | 645 | 750 | .08 | 8 | Elevated |
| 5 | 750 | 780 | 900 | 0 | 18 | High |

Standing loss is `damage × developer zone scale × delta × .55`; knocked DBNO loss uses `×.42`. Centers are seeded/clamped. Final simultaneous elimination uses a seeded technical tie score (kills, damage, aim/game sense, random), not an official tournament rule.

## 21. Red zone

First eligible at seeded `145–190 s`, only with more than two teams. It stays inside active circle, lasts `24–38 s`, then waits `135–210 s`. Each update has 10% shell chance; a hit within `.032` normalized deals raw 140. Buildings provide no red-zone protection.

## 22. Airdrop

First at 285 s, then seeded `210–280 s`, while more than two teams remain. It lands within 72% of active circle. An eligible player-team member within `.13` and non-`AVOID` engagement directly receives AWM (3 units), Helmet Lv.3 (90) and Vest Lv.3 (120). Enemy contest/crate inventory is not simulated.

## 23. Heal / boost / revive

| Action | Effect | Time |
|---|---|---:|
| Bandage | +10, cap 75 | 4 s |
| First Aid | HP to 75 | 6 s |
| Med Kit | HP to 100 | 8 s |
| Energy Drink | +40 boost | 4 s |
| Painkiller | +60 boost | 6 s |
| Adrenaline | +100 boost | 10 s |
| Revive | Restore from DBNO | 8 s |

Revive range is `.028` normalized. Distance/damage can cancel. Boost decays and heals while active.

## 24. Utility

| Utility | Actual behavior | Status |
|---|---|---|
| Smoke | Timed visual/event | PARTIAL: no detection/LOS effect |
| Frag | Raw 90 simplified area damage | CONNECTED/SIMPLIFIED |
| Molotov | Raw 64 fire damage and visual | CONNECTED/SIMPLIFIED |
| Flash | Short visual/event | UI/EVENT ONLY; no debuff |

## 25. Score system

Score is event placement points plus `kills × kill_point`. Sorting prioritizes alive count, later elimination time, then kills. Tournament/career consumes committed results. No separate survival-time points exist unless the event scoring supplies them.

## 26. Telemetry

Result contains replay version/id/seed, winner, placement, kills, damage, duration, scoreboard, player stats, own stats, loot statistics, combat/zone/vehicle/utility/airdrop events, decisions, kill feed, timeline and final snapshot. Snapshot exposes circles, phase, resources, contacts, teams, map/profile and effects. Some optional event-schema fields remain empty. Replay is history, not seekable re-simulation.

## 27. Match Observer

| Control | Effect | Status |
|---|---|---|
| Pause/resume | Runtime pause | CONNECTED |
| 1×/4×/16×/32× | Runtime speed | CONNECTED |
| Map/team/player select | Inspection target | CONNECTED |
| Team filters/show dead | Overlay visibility | CONNECTED |
| Zoom/pan/reset | View only | CONNECTED |
| Loadout/resources/feed/scoreboard | Live snapshot | CONNECTED |
| Direct player control | None | NOT IMPLEMENTED |

## 28. Match LAB

Developer-enabled LAB observes the same MatchRuntime. New Match, pause/speed, coach-plan selectors, live readouts and event feed work. Overrides for weapon/zone damage, loot, aggression and vehicles are consumed only in developer mode. It cannot force a shot, spawn arbitrary entities, scrub backward or pilot a player.

## 29. Map LAB

Section 9 lists controls. Real pointer gestures support freehand curved paths, rectangles, selection/movement, erase, resize, undo/redo, square zoom/pan/fit, visibility, preview, restrictions, independent save/reset. Runtime consumes arbitrary category/item weight dictionaries, but dedicated UI focuses on profile and allow/exclude; weight UI coverage is **PARTIAL**.

## 30. Analyst Map

Team Analysis loads upcoming map plus saved override and draws POIs, compounds, explicit loot, buildings, roads, terrain and transport. It never enables editor input and exposes no save/reset. Read-only is confirmed.

## 31. Career integration and control inventory

Career-owned match result updates history/events and downstream tournament/ranking/career data through `GameState`; sandbox LAB does not auto-commit.

| Screen | Important control/action | Data/effect | Persistence | Status |
|---|---|---|---|---|
| Start / Saves | Load/delete/select slot | Opens local career | Save files | CONNECTED |
| New Career | Career path, manager/team identity | Creates career/team/roster | Save | CONNECTED |
| Custom Content | Import/validation navigation | Supported custom records | Local/save | PARTIAL |
| Command Center | Cards, Next Day | Time/events/system simulation | Autosave | CONNECTED |
| Squad & Lineup | Filters, select, bench/promote | Match roster assignments | Save | CONNECTED |
| Player Profile | Role/contract/rest/reserve/offer actions | Player/contract/finance when valid | Save | PARTIAL/context-bound |
| Training | Team focus, schedule/program, individual focus | Growth/energy/form plan | Save | CONNECTED; no separate recent-training match bonus |
| Tactics | Drop/zone/formation/engagement/options | Match coach plan | Save | CONNECTED |
| Player Discovery | Start scout, filter/sort, inspect/sign | Time-gated report/player flow | Save | CONNECTED |
| Transfer Center | Listing/evaluate/negotiate | Transfer/offer/finance when window allows | Save | CONNECTED/context-bound |
| Player Contracts | Renew/negotiate/release | Contract/payroll | Save | CONNECTED |
| Team Analysis | Reports + Analyst Map | Reads telemetry/map | Read-only | CONNECTED |
| Player Performance | Player/stat filters | Reads accumulated stats | Read-only | CONNECTED |
| Match Center | Prepare/start/view result | Match context/runtime/result | Result commit | CONNECTED |
| Schedule | Event selection/actions | Calendar/event availability | Save | CONNECTED |
| Tournaments | Register/view | Eligibility/event state | Save | CONNECTED |
| Tournament Detail | Stages/standings/match entry | Progress/scoring | Save | CONNECTED |
| World Ranking | Rows/team navigation | Reads competitive ranking | Read-only | CONNECTED |
| Team Profile | Inspect club | Comparison data | Read-only | CONNECTED |
| Performance Campus | Pan/zoom/select/upgrade | Facility/finance/unlocks | Save | CONNECTED/SIMPLIFIED |
| Finance & Partners | Sponsor/finance actions | Cash/contracts/revenue | Save | CONNECTED/SIMPLIFIED |
| National Team | Appointment/squad/program | International state when eligible | Save | PARTIAL/context-bound |
| Career History | Trophy/history view | Reads records | Read-only | CONNECTED |
| Inbox | Select/read/respond | Read flags and consequences | Save | CONNECTED; some messages information-only |
| World Feed | Media response | Fan/board/story effects | Save | CONNECTED |
| Settings | Audio/display/UI/difficulty/rules/save | Section 32 | Settings/save | MIXED |
| Match Observer | Live controls/readout | Runtime view/pause/speed | Result only | CONNECTED |
| Match LAB | Sandbox plan/speed/overrides | Same runtime, no auto-commit | None | CONNECTED/PARTIAL |
| Map LAB | Author/save/reset | Per-map override | Override JSON | CONNECTED |
| Analyst Map | View map layers | No mutation | Reads override | CONNECTED read-only |

## 32. Settings audit

| Setting | Storage/consumer/effect | Status |
|---|---|---|
| Master/Music/SFX | `settings.json` → ensured AudioServer buses and dB/mute | WORKING; assets must route to the bus |
| Window mode | File → DisplayServer window/fullscreen/borderless | WORKING |
| Resolution | File → windowed size; 1280×720, 1600×900, 1920×1080, 2560×1080 | WORKING |
| VSync | File → DisplayServer | WORKING |
| UI scale 80–130 | File → `Window.content_scale_factor` | WORKING |
| Reduce motion | File → page/progress/toast branches | WORKING |
| High contrast | Legacy stored key, unavailable label, no consumer | NOT IMPLEMENTED |
| Autosave toggle | Legacy key, unavailable label; actions autosave regardless | NOT IMPLEMENTED |
| Career difficulty | Career → `GameState.set_difficulty()` | WORKING/PARTIAL; not a direct MatchRuntime hit formula |
| Developer mode | Career toggle | Unlocks tools and marks career modified | WORKING |
| Five simulation overrides | Career → MatchRuntime | Damage/zone/loot/aggression/vehicle | WORKING |
| Map overrides | Separate JSON → MapCatalog | Later matches/Analyst Map | WORKING |

The oversized UI came from a 1280×720 base plus forced 1920×1080 override and canvas-item stretch, effectively presenting at 1.5×. Forced override/stretch was removed. Breakpoints support all four target resolutions, square canvas, and ultrawide content capped at 2100 px.

## 33. Save / persistence

- Career schema/version was unchanged.
- Settings: `user://settings.json`.
- Maps: `user://map_overrides/<map_id>.json`, map schema 2.
- Load normalization adds explicit loot layers and editable legacy water strokes.
- Invalid override falls back to repository descriptor; Reset removes only selected override.
- Active match owns its loaded map snapshot; a new save affects later loads.

## 34. Determinism

Default seed is absolute hash of `event id | map id | season`; explicit seed wins. RNG is seeded before route/team/loot/zone/red-zone/airdrop/combat rolls. Same input/map override/seed is intended to reproduce result and is tested. Changing override, collection ordering, RNG call order or engine behavior can change it; this is not network lockstep certification.

## 35. Test matrix

| Requirement | Evidence |
|---|---|
| UI scale/resolutions/audio/reduce-motion consumer | `settings_resolution_test.gd` |
| Six maps, independent save/reload/reset, migration, size scaling | `map_authoring_system_test.gd` |
| Pointer brush/rectangle/resize/erase/undo/redo; Analyst read-only | `map_lab_ui_test.gd` |
| Building ≠ loot and combat integration | `map_editor_combat_test.gd` |
| Loot restrictions/military/vehicle consumption | `map_authoring_system_test.gd` |
| Weapons/range/falloff/ammo/attachments/armor/distance/zones | `match_rules_inventory_test.gd` |
| Deterministic result | `match_determinism_test.gd` |
| Map schema/baseline gameplay | `map_structure_test.gd` |
| Career/state regression | `game_systems_test.gd`, `state_integrity_test.gd`, `redesign_systems_test.gd`, career tests |
| Four-resolution visual matrix and editor states | `phase_ui_capture_test.gd` |

A test is only PASS when the final delivery report records a successful execution.

## 36. Known limitations

- **NOT IMPLEMENTED:** geometric LOS, interiors/doors/windows, pathfinding, projectile travel, recoil, caliber, magazine/reload, fire modes, physical friendly-fire resolution.
- **PARTIAL:** LOS flag is a fixed hit penalty; occupancy capacity is not enforced.
- **PARTIAL:** attachments equip but have no combat effect.
- **PARTIAL:** Smoke/Flash do not modify detection/aim; Molotov is simplified.
- **PARTIAL:** vehicles are acquisition/speed/fuel/durability state, not physics; source consumption works.
- **PARTIAL:** Map LAB fully consumes data weights but does not dedicate UI rows to every arbitrary category/item weight.
- **PARTIAL:** compounds remain grouping/drop metadata; building count does not generate rectangles.
- **PARTIAL:** map art is not auto-converted to terrain.
- **PARTIAL:** airdrop awards only the nearby player team; Lynx has no acquisition path.
- **PARTIAL:** overweight aggregate-ammo discard does not fully reconcile weapon ammo fields.
- **SIMPLIFIED:** direct movement receives local modifiers but does not route around obstacles.
- **SIMPLIFIED:** competitive hit modifier currently favors AI versus player and needs balance playtesting.
- **UI ONLY/unavailable:** high contrast and configurable autosave are honestly labeled unavailable.
- **NO CAREER MIGRATION REQUIRED:** career schema was unchanged; map normalization is backward compatible and tested.
