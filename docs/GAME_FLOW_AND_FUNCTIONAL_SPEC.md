# Battle Royale Manager — Game Flow and Functional Specification

Implementation audit date: 2026-08-20

This document describes only behavior confirmed in the current repository. A visible control is not treated as functional unless its signal and downstream implementation were traced. The active entry point is `main.tscn`, whose root uses `scripts/main.gd`.

## 1. Game Overview and Runtime Architecture

The application is a Godot 4.7 Control-based game. `main.gd` owns the start flow, navigation controller, nearly every routed screen, popup construction, view-local state, and connection of UI signals to game systems. `GameState` owns mutable career data, simulation rules and JSON persistence. `GameDatabase` loads and normalizes the canonical player/team/tournament database. `MatchRuntime` owns the live battle simulation.

The live UI stack is:

```text
main.tscn
└─ scripts/main.gd                         view/controller and route dispatch
   ├─ scripts/ui/app_shell.gd              background, sidebar, top bar, scroll content, toast
   ├─ scripts/ui/router.gd                  route registry, aliases, history
   ├─ scripts/ui/theme/design_tokens.gd     colors, spacing, typography, styles
   ├─ scripts/ui/components/ui_components.gd reusable panels, labels, buttons, states
   ├─ scripts/ui/utilities/responsive.gd    compact breakpoints, margins, grid columns
   ├─ scripts/ui/presenters/game_presenter.gd derived view models
   ├─ scripts/ui/presenters/career_priority_presenter.gd deterministic real-state priorities
   ├─ scripts/ui/screens/performance_campus_screen.gd extracted Campus screen
   ├─ scripts/game_state.gd                 career state, rules, save/load
   ├─ scripts/game_database.gd              immutable world-data loader/normalizer
   └─ scripts/match_runtime.gd              live match simulation
```

This is a transitional architecture: the shell, tokens, components, presenter and Campus extraction are modular, but most screens remain large procedural builders inside the 2,600-line `main.gd`. `ScreenView` exists as an extraction base but is not used by the current Campus implementation and has no other screen subclasses.

## 2. Complete Navigation Flow and Screen-by-Screen Documentation

Status meanings:

- **Premium/current**: reachable implementation uses the current shell, tokens and component language.
- **Internal**: implemented, but deliberately scoped to Sandbox/Developer use.
- **Legacy/unreachable**: code remains, but active route dispatch does not call it.
- **Partial**: UI is present while part of the implied behavior is absent or could not be confirmed.

### Pre-career screens

| Screen/state | Controller | Confirmed behavior | Data/system | Status |
|---|---|---|---|---|
| Start menu | `scripts/main.gd::_ready` | Continue, New Career, Load, Custom Content, Settings, Exit | `GameState.list_save_slots`, OS quit | Premium/current |
| Save-slot browser | `main.gd::_show_save_slots` | Load, overwrite through career wizard, two-step delete confirmation | `GameState` slot metadata/load/delete | Premium/current |
| New Career: slot | `main.gd::_career_step_slot` | Select destination slot | wizard-local dictionary | Premium/current |
| New Career: settings | `main.gd::_career_step_settings` | Difficulty, starting tier, normal/sandbox career type | stored by `GameState.new_career`; difficulty affects economy, training, scouting and inbound interest outside MatchRuntime | Premium/current |
| New Career: team | `main.gd::_career_step_team` | Existing, new or replace-team choice | `GameDatabase`, career options | Premium/current |
| New Career: identity | `main.gd::_career_step_identity` | Name/tag and optional logo import for custom identity | `GameState.set_custom_identity`, file dialog | Premium/current |
| New Career: review | `main.gd::_career_step_review` | Creates career and enters Command Center | `GameState.new_career` | Premium/current |
| Custom Content | `main.gd::_show_custom_content` | Inspect/import/list/delete/export `.brm` packages with validation and rollback | `scripts/content_manager.gd`, `user://custom_content` | Premium/current; filesystem flows not interaction-tested in this pass |
| Start Settings | `main.gd::_show_start_settings` | Displays profile/system information and returns | no confirmed settings mutation | Partial/default-only |

### Player-facing routed screens

| Route / screen | Files controlling it | Meaningful implemented states and actions | Primary data/system | Status |
|---|---|---|---|---|
| `dashboard` — Command Center | `main.gd::_dashboard`, `game_presenter.gd`, `career_priority_presenter.gd` | Upcoming/season-complete, deterministic priority actions with reasons/routes, recent progression consequences, Next Day | pending events, calendar, contracts, energy, facilities, finance, next match | Premium/current |
| `roster` — Squad & Lineup | `main.gd::_roster` and player popups | All/Main/Substitutes/Low Energy/Contracts filters; selected player; rest; role; bench/promote confirmation; salary/renewal/list/release; active loans and return terms | roster, loan records, relationships, training, contracts in `GameState` | Premium/current |
| `player_detail` — Player Profile | `main.gd::_player_detail` | Overview/Recent Form/Career/Personality/Chemistry; actual career dictionary; owned-player actions; real loan workflow; external database scope; market recruitment | roster or `GameDatabase` profile, history, relationships, transfer market | Premium/current |
| `contracts` — Player Contracts | `main.gd::_contracts_page`, contract/salary popups | urgent/watch/stable groupings; review profile; direct 12/24/36-month renewal; salary accept/counter/reject presentation; loan salary commitments | roster/loan contract and salary state; `GameState.renew_contract`/`set_player_salary` | Premium/current; no agent negotiation model is claimed |
| `training` — Training Center | `main.gd::_training_page` | Balanced/Aggressive/Recovery team workload; individual focus; weekly plan and readiness | schedule and individual training in `GameState`; applied by weekly simulation | Premium/current |
| `tactics` — Tactics Room | `main.gd::_tactics` | four presets, reset, four primary selectors, eight tactical-layer selectors, match handoff | `coach_plan`, `GameState.set_coach_plan_values`, effective match plan | Premium/current |
| `scouting` — Player Discovery | `main.gd::_scouting` | role/U23/potential filters; value/potential/confidence/salary sort; query; paging; dossier; offer | normalized world players, scouting confidence, transfer market | Premium/current |
| `transfers` — Transfer Center | `main.gd::_transfers_page` | market prospect, active outbound negotiations, shortlist, inbound listed-player offers and Inbox handoff | `market`, `transfer_offers`, `inbound_offers`, pending events | Premium/current |
| `analytics` — Team Analysis | `main.gd::_analytics_page` | no-telemetry empty state; telemetry/meta state; meta update in Sandbox | match history and telemetry; `GameState.analyze_meta` | Premium/current; no fabricated fallback data |
| `player_stats` — Player Performance | `main.gd::_player_stats_page` | top performer, team summary, roster dossier links | roster ratings/form/energy/latest stats | Premium/current/default-only |
| `match` — Match Center | `main.gd::_match_page` | upcoming match; Early/Mid/End Fight/Rotate/Hold; start observer; completed-result replay/log/timeline | calendar, match decisions, `MatchRuntime`, `GameState.commit_match_result` | Premium/current |
| `match_lab` — Match Observer | `main.gd::_match_gameplay_lab`, `match_runtime.gd`, map overlay scripts | live clock, zone, alive count, map, team/player selection, filters, zoom/pan, loadout, feed, scoreboard, result | live `MatchRuntime.snapshot` | Premium/current; Lab tools hidden in normal careers |
| `calendar` — Schedule | `main.gd::_calendar_page` | Month/Week/Day; previous/current/next month; agenda; actionable-event completion | `calendar_events`, facility/training/match events | Premium/current; ordinary event rows are display-only |
| `tournament` — Competition Center | `main.gd::_competition_center` | registration eligibility/status, registration, tournament selection, upcoming events | tournament definitions, schedule conflicts and registrations in `GameState` | Premium/current |
| `competition_detail` — Tournament Detail | `main.gd::_competition_detail` | standings, schedule, format and Match/Calendar links | current tournament and live standings | Premium/current |
| `rankings` — World Ranking | `main.gd::_rankings` | World/region/Competition/Prize Money modes and search | `GameState.world_rankings`, tournament standings and DB teams | Premium/current |
| `team_profile` — Team Profile | `main.gd::_team_profile` | selected team identity and player dossier links | `GameDatabase` team/player records | Premium/current; tactics/results explicitly unavailable due insufficient source data |
| `facilities` — Performance Campus | `main.gd::_performance_campus`, `performance_campus_screen.gd` | facility levels, affordable/disabled upgrade, active project, max level | facility definitions/projects, budget, calendar; `GameState.upgrade_facility` | Premium/current/extracted |
| `finance` — Finance & Partners | `main.gd::_finance_hub`, `game_presenter.gd` | cash-flow summary, one active sponsor, locked/unlocked offers, risk summary | finance ledger, payroll, sponsors, weekly finance simulation | Premium/current |
| `national_team` — National Team | `main.gd::_national_team_page` | unappointed candidate state; appointment; eligible pool; call-up/release up to six; Club/National context | canonical nationality/team records and national roster IDs | Premium/current |
| `trophies` — Career History | `main.gd::_trophy_room` | achievements derived only from actual results/fans/history plus archived season timeline | `history`, `season_history`, fans/reputation/placements | Premium/current; cards are informational, no detail drill-down is claimed |
| `inbox` — Inbox | `main.gd::_inbox` | channel filters; mark read; route action; scrim accept/reject; pending-event choices including transfers | inbox, pending events, scrims, transfer resolution | Premium/current; no selected-message detail screen |
| `media` — World Feed | `main.gd::_media_page` | per-season/week story in AVAILABLE or ANSWERED state; one Positive/Neutral/Negative response with persisted fan/board effects | `media_stories`, news and `GameState.record_media_response` | Premium/current; duplicate response is rejected |
| `settings` — Settings & Profile | `main.gd::_settings_page` | Save Now and return home; status cards | save system and displayed profile values | Partial/default-only; accessibility/profile cards are not editable controls |

### Internal and legacy screens

| Route/surface | Controller | Scope/status |
|---|---|---|
| `developer` — Developer Mode | `main.gd::_developer_page`, guarded override methods in `GameState` | Internal; only available for Sandbox careers and requires Developer Mode for simulation/meta overrides |
| `map_manager` — Map Manager | `main.gd::_map_manager_page`, `scripts/map_catalog.gd` | Internal; edits validated map overrides in `user://map_overrides`; reachable from allowed Lab state |
| Lab mode within `match_lab` | `main.gd::_match_gameplay_lab` | Internal; new-match, pause/speed, map manager and tactical controls; now hidden from normal careers |
| Old interactive Campus map | `main.gd::_facilities`, `_facility_detail`, camera helpers | Legacy/unreachable. Active `facilities` dispatch calls `_performance_campus`, and router alias `facility_detail` resolves back to `facilities`; these functions should be removed after parity review |

Router aliases are `transfer → scouting`, `meta_report → analytics`, and `facility_detail → facilities`. Unknown routes fall back to `dashboard`. Detail routes are entered from UI state (`selected_player`, `selected_profile_player`, `selected_competition_id`, `selected_world_team_id`) rather than route parameters in most cases.

## 3. Main Game Loop and Confirmed System Dependency Map

```text
Career creation/load
  → Command Center
  → roster/training/tactics/scouting/finance preparation
  → Next Day
      → stop if an actionable event requires a choice
      → process dated facility/project events
      → every seven elapsed days: payroll (including retained loan salary), sponsor income,
        training, form/energy, contracts, scouting, inbound interest, conflicts and season checks
  → Match Center decisions
  → MatchRuntime live simulation
  → commit result, telemetry, finance/reputation/history
  → standings/rankings/analytics/career history update
```

Confirmed connections:

- Team training and individual focus are saved immediately, then applied during `advance_week`; they affect energy, form and development.
- Tactical presets/selectors save `coach_plan`. Early/Mid/End match decisions override relevant fields in `effective_match_plan`, which is consumed for the match context.
- Transfer offers create a pending Inbox event. Accept/counter/reject resolution can sign the player, deduct the fee, set contract/role, update roster/market and add news/finance entries.
- Transfer-listed owned players are evaluated deterministically during weekly progression. Inbound offers contain a real database buyer, amount and deadline; accept removes ownership and records income, reject keeps the player, and counter creates a follow-up decision.
- Loans move an owned player out of the active roster into `loaned_players`, store destination/start/return dates and salary coverage, create a return calendar event, retain the club payroll share and automatically restore the player when due.
- Direct `sign_player` also exists and is used by the underlying career system, but the premium recruitment flow is offer/Inbox based.
- Facility upgrades deduct budget, create a dated construction project and add a required Calendar event. Completion raises the level.
- Sponsor signing gives the signing bonus/fans immediately; weekly sponsor income is processed during weekly finance advancement.
- Tournament registration validates participant type, country rules and schedule conflicts, then adds the player team and calendar events.
- National selection references canonical player IDs; call-ups do not transfer ownership or alter club salaries/contracts.
- Media responses mutate fan sentiment and board confidence, append event history and permanently mark the current story ANSWERED so it cannot be submitted twice.
- Facility levels have code-backed effects: Training Center modifies weekly growth chance, Analytics Lab modifies scouting confidence, Recovery Wing/Medical Room modifies weekly and manual recovery, and Content Studio supplies weekly media income.
- Easy/Normal/Hard rules affect non-match economy, training growth chance, scouting confidence and inbound-interest threshold. MatchRuntime strength and combat formulas are unchanged.
- Season end archives actual results/finance/ranking context in `season_history`, preserves permanent career data, creates renewal income, resets seasonal registrations/results/calendar, increments season and exposes `season_transition`.
- `progression_log` records meaningful daily/weekly/system consequences. Command Center priorities are produced from actual state by `CareerPriorityPresenter`; UI code does not invent a fixed task list.
- Match completion is the source for history, telemetry, timeline, rankings/standings and analysis displays. Analytics shows an empty state when this data does not exist.
- Save/load uses JSON under `user://`; slot metadata is read from the save documents. Test runs use isolated save paths.

## 4. Data Sources and System Documentation

| Source | Consumer and purpose |
|---|---|
| `database/core/manifest.json` | Root collection manifest loaded by `GameDatabase` |
| `database/pubg_players/players.json` and referenced images | canonical player identity, history and latest-stat inputs |
| `database/pubg_teams/teams.json` and logos | canonical club/national-team identity and roster linking |
| `database/tournaments/*.json` | tournament rules, participants, format and schedule inputs |
| `database/rules/competitive_rules.json` | validation/rules data |
| career-content collection referenced by the manifest | initial roster, market, sponsors, facilities, events, staff and tier profiles |
| `data/maps/*.json` | map regions, points, terrain and movement rules for `MapCatalog`/`MatchRuntime` |
| `assets/asset_manifest.json` | logical asset IDs resolved by `AssetRegistry` |
| `GameState.data` | mutable career source of truth persisted to `user://` |
| `MatchRuntime.snapshot()` | transient live observer source of truth |
| `user://custom_content` | validated optional `.brm` packages; content is isolated and versioned |

`GameDatabase` derives ratings from imported latest stats when normalizing world players. Several profile values such as age, contract duration and financial values are normalized/derived defaults, not direct historical facts from the source dataset.

## 5. Interactive State Inventory and Audit Coverage

Automated UI audit: `tests/interaction_state_audit.gd`. It uses an isolated real career, presses visible controls, verifies resulting state and captures at 1280×720 and 1920×1080. Domain and persistence coverage is in `tests/game_systems_test.gd`, which uses `GameState`, `GameDatabase` and the repository content directly.

Confirmed tested states:

- Finance: unlocked sponsor → active sponsor.
- Performance Campus: available upgrade → active dated construction project.
- Media: AVAILABLE → Positive response → ANSWERED; response controls removed; persisted consequence.
- Squad & Lineup: Substitutes filter; selected substitute; confirmed loan → active loan record/roster removal; confirmed promotion swap.
- Player Profile: Career tab; external/market profile scope; owned-player controls absent externally.
- Player Discovery: Fragger filter.
- Transfers/Inbox: market profile → outbound transfer offer → pending Inbox negotiation; listed owned player → inbound buyer offer → Inbox choices → persisted rejection.
- Training: Recovery workload selection.
- Tactics: Aggressive Early preset persisted.
- Calendar: Week view.
- Rankings: Competition mode.
- Inbox: Media channel filter.
- National Team: appointment → successful call-up and refreshed roster state.
- Match Observer: live runtime state; Observer controls present; Lab absent in a normal career.

The final UI-audit run pressed 40 controls and produced 40 state captures (20 per size) with the rendering backend. It includes the completed-season summary and its single-use acknowledgment at both audited sizes. `tests/capture_responsive_ui.gd` separately produced 88 default-route captures: 22 routes at 1280×720, 1600×900, 1920×1080 and 2560×1080.

`tests/game_systems_test.gd` passed 110 checks covering career creation/save, lineup/role/rest, training/week consequences, contract renewal/salary, outbound and inbound transfers, the full loan return lifecycle, facilities/benefits, sponsor/payroll, national appointment/call-up/release, media duplicate prevention, tournament registration/calendar/real MatchRuntime result/standings, priority generation, season transition and acknowledgment, season-bound event cleanup, destructive contract removal, version-10 migration and save/reload of all major domains.

`tests/real_career_playtest.gd` passed 951 assertions across 84 daily advances, 12 weekly boundaries, 10 save/reload checkpoints and three deterministic matches run by the unchanged `MatchRuntime`. This is the full-season real-career evidence layer; it is separate from unit/domain and UI-interaction verification.

States not exercised end-to-end in this pass:

- destructive save deletion, file-picker logo import and `.brm` import/export;
- every visual branch of contract salary counter/reject and transfer counter negotiation (their domain mutations are covered where listed above);
- every scrim choice permutation and every random-event branch;
- alternate tournament eligibility/conflict combinations and tournament elimination/advancement boundaries; three deterministic MatchRuntime results and standings updates were tested;
- a naturally completed full MatchRuntime result at every speed;
- Sandbox Developer Mode and map override writes;
- max-level facility UI, empty databases and corrupt-save recovery. The season-summary presentation and acknowledgment were tested.

No untested state is marked PASS.

## 6. Remaining Limitations and Unconfirmed Functionality

- Player Career shows only fields actually present in the canonical/current career dictionary. Imported database history is not a full simulated multi-club career ledger, so no richer drill-down is claimed.
- Chemistry shows actual relationship scores/memories and relationship events; no direct MatchRuntime performance modifier is claimed.
- A loan records destination identity, duration, salary split and automatic return, but there is no destination-team playing-time simulation or loan development model.
- Inbound interest is a lightweight deterministic career system, not an autonomous league-wide transfer-market simulation.
- Team Profile tactics and results remain explicit unavailable-data states because the source database does not supply them.
- Settings accessibility/profile cards have no mutation controls. Calendar month offset, filters and selected UI tabs are view-local rather than saved.
- Inbox has no selected-message detail surface; clicking a normal message marks it read and routes to its related screen.
- Staff effects are intentionally limited to effects confirmed in code: head coach growth chance, analyst telemetry reports, scout confidence and mental-coach happiness. No unsupported percentages are displayed.
- Ranking behavior continues to use the existing result/standings implementation. No second ranking formula was introduced.
- Custom-content import/export, corrupt-save recovery and Sandbox override writes were not executed in this pass.
- Tournament definitions are a static catalog. A new season rebuilds dated calendar entries, but the catalog key/name itself is not a generated season-specific competition identity.
- The starting canonical Tier-C organization used by the playtest has exactly four starters and no substitute. Rotation therefore requires recruitment; this is confirmed starting balance, not a missing roster rendered by the UI.
- No bankruptcy enforcement or administration state exists. Weekly operating costs can take cash below zero; warnings and the season-renewal economy exist, but a hard insolvency consequence could not be confirmed.
- The finance ledger shown to the player is intentionally bounded to recent entries. It is not a complete unbounded accounting export.

## 7. Refactoring required for a full UI/UX redesign

1. Split `main.gd` by routed screen. Each screen should be a `ScreenView` (or equivalent) with explicit input data, emitted intents and local view state. Start flow and modal flows should also leave the monolith.
2. Make the router carry typed route parameters for player/team/competition IDs. Remove reliance on global `selected_*` fields, which makes deep links, back navigation and state restoration fragile.
3. Introduce application services/use cases between screens and `GameState` for transfers, contracts, calendar advancement, national selection and facilities. UI callbacks currently know too much about persistence and mutation order.
4. Create reusable stateful patterns for tab bars, filters, stat grids, entity cards, confirmation dialogs, negotiation steps, loading/error/empty states and responsive split layouts. Many are currently rebuilt procedurally.
5. Move all display strings, enum labels and formatting into presenter/localization resources. Vietnamese internal training values and English UI labels currently coexist by mapping in screen code.
6. Define a screen-state matrix and deterministic fixture builder. The current tests cover default routes and selected interactions, but every screen needs fixtures for empty, loading, error, selected, confirmation, success, disabled and overflow states.
7. Separate player-owned, market and world-database profile models at the type/presenter layer. The audit fixed the visible action leak, but the view still receives loosely shaped dictionaries.
8. Remove unreachable `_facilities`/`_facility_detail` code after confirming no desired interaction is lost. Consolidate the router alias and eliminate dead Campus camera state.
9. Continue completing deliberately limited product areas: editable accessibility/profile settings, richer career-history detail, selected-message Inbox view and destination-side loan simulation. Do not expand their claims before their systems exist.
10. Make responsive behavior component-owned and test intrinsic minimum sizes. Match Observer demonstrated that desktop HBox assumptions can overflow at the supported 1280×720 baseline.
11. Add structured accessibility: focus order, keyboard/gamepad navigation, semantic tooltips, scalable type, reduced motion and contrast modes. Current settings cards do not implement these options.
12. Add schema/versioned view-model contracts and migration tests so a UI redesign cannot silently depend on incidental `GameState.data` dictionary keys.

## 8. Visual/current-versus-legacy conclusion

All currently reachable player-facing routes use the premium dark tactical shell and shared visual language; no reachable route dispatches to the old Campus implementation. Inbound offers, loan lifecycle, media response locking, career data and Chemistry routing now have real state-backed behavior. The codebase is not architecturally redesigned: screen ownership remains concentrated in `main.gd`, while real priority derivation was extracted into `CareerPriorityPresenter`. The only confirmed legacy screen implementation is the unreachable Campus map/detail branch. Settings editing, rich career drill-down and selected-message Inbox detail remain deliberately limited and are not presented as completed systems.

## 9. Function Inventory

The table below inventories the public or UI-relevant system functions traced during this audit. Private simulation helpers are described as subsystems rather than as hundreds of individual internal calls.

| Domain | Confirmed entry points | Inputs / gate | State effect and next visible state |
|---|---|---|---|
| Career lifecycle | `new_career`, `select_slot`, `load_slot`, `delete_slot`, `list_save_slots`, `most_recent_slot` | slot and wizard options; deletion requires UI confirmation | creates, selects, loads or deletes JSON slot data; successful create/load enters Command Center |
| Day/week progression | `advance_day`, `advance_week`, `actionable_events`, `acknowledge_calendar_event`, `progression_summary` | current date; unresolved required events can stop progression | one day increments exactly once; each seven elapsed days runs weekly finance/training/contracts/scouting/offers/loans/facilities/season checks and returns meaningful consequences |
| Squad | `set_player_role`, `move_roster_player`, `recover_player`, `set_individual_training`, `set_team_training_schedule` | owned player ID and valid option; promotion requires a selected starter to swap | mutates roster assignment, role, readiness or saved training plan; returns to refreshed squad/training state |
| Contracts | `renew_contract`, `set_player_salary`, `terminate_player_contract`, `release_player` | owned player, months/salary or confirmation | changes contract/salary or removes player; mutations save through `GameState` |
| Relationships | `get_player_relationships`, `adjust_relationship`, `queue_relationship_conflict`, `resolve_event` | two valid player IDs and/or a pending choice | changes relationship score/memory or resolves a queued event; consequences appear in player chemistry/inbox/history |
| Scouting/recruitment | `scouting_pool`, `player_profile_from_database`, `sign_database_player`, `create_transfer_offer`, `resolve_transfer_offer`, `sign_player` | database/market player; affordability, roster capacity and valid offer terms | creates a market profile or pending Inbox negotiation; acceptance deducts funds and adds the player to roster/contracts/history |
| Inbound transfers | `set_transfer_listed`, `generate_inbound_offers`, `resolve_inbound_offer`, `_expire_inbound_offers` | owned listed player, no duplicate active offer, weekly deterministic threshold | creates a buyer-backed Inbox event; accept sells/removes player and records income, counter creates follow-up, reject/expiry closes it |
| Loan | `loan_destinations`, `create_loan`, `loan_player`, `_process_loan_returns` | owned non-starter player, roster capacity and no active duplicate loan | stores terms, removes active availability, creates calendar/history records, processes retained payroll and restores roster automatically on return date |
| Tactics | `set_coach_plan_values`, `set_match_decision`, `effective_match_plan` | valid plan keys and Early/Mid/End phase decisions | persists coach intent; phase decisions modify the effective plan passed into match preparation |
| Match | `prepare_match_context`, `MatchRuntime.start_match`, `tick`, `toggle_pause`, `set_speed`, `snapshot`, `apply_match_runtime_result` | playable calendar event and roster/context | runs the battle simulation; result commit updates match history, telemetry, standings, finance/reputation and visible post-match states |
| Analytics/meta | `analyze_meta`, `apply_meta_patch` | telemetry; patch/overrides are Developer-controlled | derives weapon performance/tiers or applies a Sandbox meta patch; analytics refreshes from stored evidence |
| Facilities | `upgrade_facility`, `_process_facility_projects`, `facility_benefit_summary` | valid facility, below max level, adequate budget, no active duplicate project | deducts cost and creates dated project/event; completion raises facility level and its actual training/scouting/recovery/media effect |
| Finance/sponsors | `accept_sponsor`, weekly finance processing in `advance_week` | unlocked sponsor and no conflicting active sponsor | grants signing effects, records ledger entries and later processes weekly income/payroll |
| Tournament | `get_competition`, `tournament_registration_status`, `register_tournament`, `unregister_tournament`, `get_tournament_standings` | participant type, country and schedule-conflict validation | changes registrations/calendar; result commits update standings |
| National team | `eligible_national_players`, `select_national_team`, `set_management_context`, `call_up_player`, `release_national_player` | valid national team/player; roster capped at six | changes national appointment/context/roster IDs without transferring club ownership |
| Media | `current_media_story`, `record_media_response`, `_ensure_media_story` | current AVAILABLE story, valid tone | changes fans/board, appends history and persists ANSWERED; duplicate responses fail |
| Career/difficulty/season | `difficulty_rules`, `_record_progression`, `_end_season` | stored difficulty and weekly season boundary | applies non-match modifiers, records consequences, archives season summary, preserves permanent history and opens a new season |
| Command priorities | `CareerPriorityPresenter.build` | real career data and next match | emits ordered `{priority,title,reason,action,target_route,tone}` view models without mutating state |
| Scrims | `accept_scrim`, `reject_scrim` | pending request ID and optional scheduling choices | removes request and can create the corresponding calendar/inbox state |
| Database | `load_all`, `get_team`, `get_player`, `search_teams`, `search_players`, `get_tournament`, `validate` | manifest-backed JSON collections | supplies normalized read-only world entities and validation errors |
| Custom content | `list_packages`, `inspect_package`, `import_package`, `delete_package`, `export_package`, `resolve_enabled` | validated `.brm` package/path and dependency checks | manages isolated `user://custom_content`; destructive/import/export branches were not executed in this audit |
| Routing | `Router.resolve`, `navigate`, `descriptor`, `go_back`; `main.gd::_show_page` | registered route or alias | resolves aliases/history and rebuilds the screen; unknown routes fall back to `dashboard` |

## 10. Button and Control Inventory

This inventory lists controls whose behavior is connected in the current implementation. A visual-only element is called out explicitly.

| Surface | Connected controls | Preconditions / resulting state |
|---|---|---|
| Start menu and saves | Continue, New Career, Load, Custom Content, Settings, Exit; slot Load/Overwrite/Delete; delete confirmation | save-dependent buttons require a slot; successful load/create enters the shell |
| Career wizard | Back/Next, slot cards, difficulty/tier/type choices, team choice, identity fields/logo picker, Create Career | review step requires the wizard data; creates the selected slot |
| Global shell | Club/National context, sidebar routes, Inbox, Next Day, Save/Settings/Profile | context switch depends on national appointment; Next Day may stop at an actionable event |
| Command Center | priority and quick-navigation actions, Next Day | navigation-only except Next Day, which calls progression |
| Squad & Lineup | filter tabs, player rows/cards, role choice, rest, bench/promote, renewal, salary review, list/release, loan and confirmations | owned-player scope; promote requires a starter selection; loan creates real terms and removes active availability |
| Player Profile | Overview/Recent Form/Career/Personality/Chemistry tabs, owned-player actions, market Make Transfer Offer | controls depend on owned/market/external scope; Career and Chemistry use actual available data and no unconnected CTA remains |
| Contracts | review profile, term buttons, salary Accept/Counter/Reject, terminate/release confirmation | valid owned player; there is no autonomous agent negotiation model |
| Training | Balanced/Aggressive/Recovery, individual focus selectors | saves schedule/focus immediately; effects occur on weekly progression |
| Tactics | four presets, reset, 12 option selectors, Apply to Match | updates `coach_plan`; Apply routes to Match Center |
| Discovery | filters, sort modes, search, paging, candidate selection, dossier, transfer offer | operates on normalized database players and market state |
| Transfer Center | dossier links, outbound negotiation rows, transfer listing/inbound offer status and Inbox handoff | outbound and inbound decisions resolve through real pending Inbox events |
| Team Analysis | Prepare for Match; Update Meta Report when evidence exists | empty state never fabricates stats; meta update depends on telemetry/system permission |
| Player Performance | player dossier links and Team Analysis shortcut | summary itself is display-only |
| Match Center | phase decisions, start observer, replay previous/play/pause/next/speed/live controls on completed result | requires a playable or completed event; decisions mutate the effective plan |
| Match Observer | observer filters, entity/player selection, zoom/pan, pause/speed where permitted | normal career exposes observer functions; Developer Lab controls are absent |
| Schedule | Month/Week/Day, previous/current/next month | month offset is view-local; event rows are generally display-only unless a dedicated action button is rendered elsewhere |
| Competitions | competition selection, register/unregister where eligible, detail/Match/Calendar links | registration validation can disable/reject the action |
| Rankings | World/Region/Competition/Prize Money modes, search, team selection | rebuilds the ranking dataset/mode or opens Team Profile |
| Team Profile | player dossier links | tactics and results panels are explicit unavailable-data states, not controls |
| Performance Campus | facility cards and Upgrade/Acknowledge actions | disabled for insufficient funds, max level or active project |
| Finance & Partners | sponsor offer acceptance | requires unlocked offer and no active sponsor; other finance cards are display-only |
| National Team | appointment, Club/National context, call-up/release | appointment and eligibility gates apply; six-player cap enforced |
| Career History | no confirmed drill-down control | achievement/timeline cards are display-only |
| Inbox | channel filters, message read/action route, scrim accept/reject, pending-event choice buttons | each action depends on message/event type; there is no selected-message detail surface |
| World Feed | Positive/Neutral/Negative response while AVAILABLE, resolved summary while ANSWERED, pulse links | response changes fan/board values once; buttons are absent after resolution |
| Settings & Profile | Save Career Now, Return to Command Center | profile/accessibility cards are visual status, not editable settings |
| Developer/Map Manager | Developer toggle, override Apply/Reset, Lab/Map Manager links and map override controls | Sandbox-only and guarded; not tested in this player-facing pass |

## 11. Save/Persistence, Progression, Empty/Error and Responsive Behavior

### Save and persistence

- `GameState.save_game` serializes the mutable `data` dictionary as JSON to the selected `user://` slot. `load_game`/`load_slot` parse it and `_migrate_save` fills schema additions for older careers. Schema version is 10.
- Version 10 retains the version-9 career fields and adds/migrates `season_start_budget` and `next_record_sequence`. Existing finance records receive stable IDs, legacy inbound-offer events become asynchronous/non-blocking, and stale offers are expired during migration.
- Committed management actions generally call save through their owning `GameState` method or through the UI action flow. The Settings screen also exposes an explicit Save Career Now action.
- The calendar month offset, filters, selected entities, route-local tabs and most popup state are view-local and are not persisted.
- Match Observer snapshots are transient. Only the committed match result, derived telemetry/timeline/history and affected career values persist.
- Custom content is stored separately under `user://custom_content`; package management does not make an unvalidated archive part of career data.

### Progression logic

- A day advances through `advance_day`. Required events can stop the UI flow until acknowledged or resolved. `days_elapsed` is the single weekly-boundary clock; `advance_day` does not also add seven days.
- Every seven elapsed days, `advance_week(false)` runs payroll/sponsor/Content Studio income, active-loan payroll share, training effects, form/energy/happiness, contracts, scouting, inbound offers, conflicts/events, facilities/loan returns and season checks. Direct `advance_week(true)` advances the calendar by exactly seven days and runs the same systems.
- Training selections are configuration now, consequence later: team load and individual focus are applied during the weekly step.
- Facilities are budgeted projects tied to completion dates and calendar events, not instant level mutations.
- A completed match is the dependency root for match history, telemetry, standings/rankings, analytics, prize/reputation/fan consequences and Career History displays.
- Season end archives results and context, records opening/closing budget and financial result, applies renewal income, expires season-bound offers/events, resets seasonal registrations/results/calendar, increments the season and preserves permanent roster/career/finance records. Command Center presents the summary and exposes a single-use `BEGIN SEASON N` acknowledgment; both transition and interaction are deterministically tested.

### Empty, unavailable and error states

- Team Analysis has a confirmed zero-telemetry state with the next real scheduled match; it does not show synthetic charts.
- Discovery/Transfer panels show explicit empty copy when no players/offers are present. Team Profile explicitly labels missing tactics/results source data.
- Editable accessibility settings, detailed imported multi-club career history and Inbox message detail are documented as limited rather than inferred as functional.
- User-visible mutations return success/error dictionaries or strings and are surfaced by toast/popup copy. Corrupt-save recovery and deliberately empty/corrupt source databases were not tested.
- Loading spinners or asynchronous loading states were not found; repository-backed JSON and local saves are loaded synchronously.

### Responsive behavior

- Supported audit sizes are 1280×720, 1600×900, 1920×1080 and 2560×1080. The default-route suite rendered 22 routes at every size.
- `ResponsiveScript.is_compact` swaps selected HBox splits to VBox stacks. Shared shell margins, grid columns and minimum sizes supply the remaining adaptation.
- Schedule cells expand across seven columns at wide resolutions while retaining a 130-pixel minimum for the 1280 baseline.
- Team Analysis and World Feed stack their composed layouts at compact width. Tactics keeps its actual roster formation readable at the 1280 baseline.
- Content remains vertically scrollable. The audit confirmed no runtime crash in the 88 default captures, but exhaustive keyboard/gamepad focus traversal and every popup at every resolution were not tested.

## 12. Player Journey

The implemented career loop is optional-action management around a calendar. The player can skip non-blocking preparation, but required pending events can interrupt Next Day.

| Phase | Purpose and decisions | Data used | Consequence / next state |
|---|---|---|---|
| Start Game | Continue an existing slot, load/delete a slot, or create a career | save-slot metadata | selected JSON career is loaded, or wizard begins |
| Career Creation | Choose slot, difficulty, tier/type, organization and identity | `GameDatabase`, wizard choices | `GameState.new_career` creates deterministic version-10 defaults and enters Command Center |
| Command Center | Understand date, next match and highest-value issue; choose a routed action or Next Day | priority presenter over events/calendar/contracts/energy/facilities/finance | routes to the real system; Next Day advances only when blocking work is clear |
| Daily Management | Rotate/rest/role players, handle contracts, scout/recruit/list/loan, sponsor, facility, national and Inbox decisions | persistent roster, contracts, market, events, ledger and projects | each accepted action mutates and saves real career state; UI rebuilds from that state |
| Weekly Management | Choose workload/individual focus/tactics before a seven-day boundary | training schedule, focus, facilities, staff, difficulty, loan payroll | weekly processing changes energy/form/development/happiness, finance, contracts, scouting and market interest; meaningful effects enter `progression_log` |
| Match Preparation | Select phase decisions and confirm current lineup/readiness | calendar event, owned starters, `coach_plan`, match decisions | `effective_match_plan` and prepared career context are passed to MatchRuntime |
| Match | Observe the frozen existing battle simulation | `MatchRuntime.snapshot()` | the simulation produces its existing result; no combat formula was modified |
| Result | Review placement, kills, feed, timeline and telemetry | MatchRuntime result | `commit_match_result` persists history, player career stats/earnings/titles, tournament result, finance/reputation/fans and progression entry |
| Consequences | Read priorities, news, Inbox and recent progression | history, pending events, ledger, progression log | manager resolves required events or adjusts preparation |
| Tournament/Ranking/Career | Register eligible events, inspect real standings/rankings and archived achievements/seasons | database tournaments, calendar, result history, `season_history` | registration creates schedule; committed results update existing standings/rankings/history |
| Next Day / Next Week | Move the calendar when no blocking event requires input | current date, `days_elapsed`, calendar/pending events | daily due work runs; each seventh day triggers one coherent weekly update |
| Season End | Archive the completed season and start the next | results, ranking, fans, finance, history | summary saved and shown, renewal income applied, seasonal state reset, season increments, permanent career state retained; acknowledgment is single-use |

## 13. Implemented System State Machines

Only code-backed states are listed.

### Outbound transfer

```text
MARKET/SCOUTED → OFFERED → pending Inbox response
  → ACCEPT → SIGNED (roster + contract + fee/ledger/history)
  → COUNTER → manager accepts counter → SIGNED
  → REJECT → closed
```

### Inbound transfer

```text
OWNED → TRANSFER_LISTED → PENDING
  → ACCEPTED → TRANSFERRED_OUT + income/history
  → COUNTERED → follow-up pending → ACCEPTED or REJECTED
  → REJECTED
  → EXPIRED (deadline passed)
```

### Contract

```text
ACTIVE → renewed months and/or changed salary → ACTIVE
ACTIVE → weekly month reduction → EXPIRING/EXPIRED urgency
ACTIVE → TERMINATED or RELEASED → removed from owned roster
```

The salary popup offers Accept/Counter/Reject presentation, but there is no autonomous agent state machine and none is claimed.

### Loan

```text
OWNED_ACTIVE → ACTIVE_LOAN
  (destination + start/return date + duration + salary coverage;
   player moved to loaned_players and return event created)
→ due-date processing → RETURNED → owned active roster restored
```

### Facility

```text
AVAILABLE_LEVEL → PROJECT_ACTIVE → due-date completion → LEVEL_INCREASED
→ AVAILABLE_LEVEL or MAX_LEVEL
```

Insufficient funds, duplicate active project and max level are rejected/disabled states.

### Inbox event

```text
response_required → one listed choice → resolved → event_history
```

Inbound counter creates a new response-required event. Normal inbox messages independently move UNREAD → READ.

### Media

```text
AVAILABLE → ANSWERED
```

One story is created per season/week. A second response to the same story is rejected.

### Tournament

```text
AVAILABLE → REGISTERED → calendar schedule → completed match result → standings/history
AVAILABLE → SCHEDULE_CONFLICT or NOT_ELIGIBLE
REGISTERED → unregister → AVAILABLE (uncompleted schedule removed)
```

### National selection

```text
UNAPPOINTED → APPOINTED → NATIONAL context
eligible player → CALLED_UP → RELEASED
NATIONAL context ↔ CLUB context
```

Call-up IDs reference canonical players and never change club ownership.

### Season progression

```text
SEASON_ACTIVE → weekly boundary past final week → ARCHIVED + SUMMARY_AVAILABLE
→ seasonal reset + renewal income → NEXT_SEASON_ACTIVE
→ BEGIN SEASON N → SUMMARY_ACKNOWLEDGED
```

## 14. Persistent Fields and Dependencies Added Through Version 10

| Field | Purpose |
|---|---|
| `days_elapsed` | one authoritative daily-to-weekly boundary counter |
| `progression_log` | bounded real consequence feed for Command Center/Next Day feedback |
| `season_history` | archived season summaries derived from actual career state |
| `season_transition` | most recent archived summary for transition presentation |
| `loaned_players` | owned players currently unavailable to the active roster |
| `loan_records` | destination, dates, duration, coverage and ACTIVE/RETURNED lifecycle |
| `inbound_offers` | buyer, amount, deadline and PENDING/COUNTERED/ACCEPTED/REJECTED/EXPIRED state |
| `transferred_out_players` | persistent ownership/history record for accepted sales |
| `media_stories` | per-season/week prompt, AVAILABLE/ANSWERED state, answer and effects |
| `season_start_budget` | opening cash baseline used to calculate the archived season financial result |
| `next_record_sequence` | monotonic source for stable progression, finance and Inbox record IDs |

Dependencies remain incremental: `GameState` is persistent career truth, `GameDatabase` is canonical world truth, Calendar drives progression, Inbox carries asynchronous decisions, and `CareerPriorityPresenter` derives UI priorities. `MatchRuntime` remains the unchanged black-box battle simulation.

## 15. Final Implementation Status and QA Evidence

| Previously incomplete area | Final status | Evidence / boundary |
|---|---|---|
| Loan lifecycle | IMPLEMENTED | destination, duration, dates, UI-fixed 50% destination salary coverage, payroll share, calendar return and automatic roster restoration tested |
| Inbound offers | IMPLEMENTED | deterministic weekly/forced generation, real buyer, Inbox, accept/reject/counter/expiry; accept and UI rejection tested |
| Player Career | IMPLEMENTED WITH AVAILABLE DATA | actual career dictionary and archived career data; no invented history |
| Player Chemistry | IMPLEMENTED WITH AVAILABLE DATA | actual relationship values/memories and route; no MatchRuntime effect claimed |
| Difficulty | IMPLEMENTED OUTSIDE MATCH | economy/training/scouting/inbound-interest rules; MatchRuntime unchanged |
| Staff advertised effects | IMPLEMENTED OR CLAIM REMOVED | only head-coach/scout/mental-coach effects and analyst telemetry claim remain |
| Media repeated response | IMPLEMENTED | AVAILABLE → ANSWERED and duplicate rejection tested |
| Achievement detail | LIMITED/INFORMATIONAL | achievements derive from actual data; no drill-down control is shown/claimed |
| Season end | IMPLEMENTED | archive/reset/preserve/new-season, summary metrics, persistence and single-use acknowledgment tested |
| Accessibility/profile editing | NOT IMPLEMENTED | cards remain informational; no mutation is claimed |
| Custom-content filesystem flows | IMPLEMENTATION EXISTS, NOT RETESTED | source was audited; import/export/file-picker branches were outside this gameplay pass |

Executed final QA on 2026-08-20:

- Godot editor parser/startup validation: PASS; no script compilation/load errors.
- `tests/game_systems_test.gd`: PASS, 110 checks, including an unmodified MatchRuntime result committed into tournament standings.
- `tests/real_career_playtest.gd`: PASS, 951 assertions, 84 days, 12 weekly boundaries, 10 reload checkpoints and three matches executed by the frozen MatchRuntime.
- `tests/interaction_state_audit.gd`: PASS, 2 sizes, 40 controls, 40 interaction-state captures.
- `tests/capture_responsive_ui.gd`: PASS, 4 sizes × 22 routes = 88 default-state captures.
- Save/reload: PASS for season, roster IDs, salary, training, tactics, facility level, budget, national appointment, media state, loan state and inbound-offer state; migration and destructive contract branches also passed.
- Visual inspection: Command Center, Squad, Transfers, Contracts, Training, Tactics, Inbox, Finance and Season Summary were inspected at both 1280×720 and 1920×1080 after the final captures. The stale season/week sidebar found during summary inspection was fixed and the interaction audit was rerun successfully.

Known untested branches are listed in section 5 and limitations in section 6. No unexecuted branch is marked PASS.

# Real Career Playthrough

Verification level: **REAL CAREER**. `tests/real_career_playtest.gd` starts a fresh Tier-C Normal career from the real repository database and advances it through all 84 days of Season 1 into Season 2. It does not replace the runtime with a mock: three matches are started and completed through the frozen `MatchRuntime`, then committed through the production result path.

The playthrough exercised sponsor selection, squad roles, balanced/aggressive/recovery training, contract term and salary changes, outbound recruitment and Inbox resolution, inbound reject/counter/accept/expiry, a replacement signing, two facility projects, a four-week loan and automatic return, national appointment/call-up/release, weekly media creation/response safeguards, priorities, finance reconciliation and season transition. State was saved and reloaded at ten checkpoints. Reload did not create media, duplicate events, alter money or lose transfer/loan/facility/national state.

Confirmed terminal state: Season 2, Week 1; five owned players; no active loan; no leaked pending event; Training Room Level 2; Medical Room Level 2; 662,186 cash after renewal. The three played matches produced placements 9/3/1, 19 total kills, 42 points and 210,000 prize income. Season 1 archived world rank #79, closing cash 334,186, operating financial result -115,814 and renewal income 328,000.

# Balance Findings

Verification level: **REAL CAREER** unless stated otherwise.

- Balanced training produced a weekly energy delta of +2; aggressive produced -6 with a higher growth chance; recovery produced +9 in the configured system and +2 in the measured squad-average checkpoint after other weekly effects. The choices are materially distinct.
- Two Level-2 facility projects cost 120,000 each. Their delayed completion and cash cost were both observed.
- Starting payroll was 52,080 in the playtest scenario and ended at 67,600 after squad changes. Season operations closed 115,814 below the opening budget before renewal, so recurring costs remained meaningful.
- Selling a high-value starter through a counteroffer generated 788,288, but ownership was lost and the weaker replacement contributed to a final #79 power rank. This was a strong tradeoff, not free value.
- The canonical Tier-C starting roster has no substitute. This makes early recruitment strategically important but leaves no rotation buffer at career start.
- Cash can become negative because no insolvency enforcement exists. This is a remaining balance/design risk, not a verified exploit fix.

# Exploit Findings

Verification level: **REAL CAREER + UNIT/DOMAIN**.

- Duplicate match-result commits, media answers, weekly media creation, facility projects, loans and active transfer outcomes were rejected or remained idempotent in the tested paths.
- Reloading at ten checkpoints did not grant duplicate cash, recreate gameplay state or repeat resolved outcomes.
- Ignoring an inbound offer no longer freezes the calendar; the offer remains actionable asynchronously and expires at its deadline.
- High inbound transfer revenue is possible, but the tested transaction permanently removed the sold player and reduced sporting strength. No repeat-sale or retained-player exploit was found.
- No confirmed infinite-money, duplicate-reward, duplicate-player or season-transition replay exploit remained in the executed paths.
- Behavior outside the executed branches—especially corrupt saves, custom-content filesystem flows, all random-event variants and Sandbox overrides—could not be confirmed.

# Regression Findings

Verification levels are deliberately separated:

- **UNIT/DOMAIN:** `tests/game_systems_test.gd` — PASS, 110 checks.
- **REAL CAREER:** `tests/real_career_playtest.gd` — PASS, 951 assertions across one complete season.
- **INTERACTION:** `tests/interaction_state_audit.gd` — PASS, 40 connected controls and 40 captured states across two resolutions.
- **RESPONSIVE DEFAULT ROUTES:** `tests/capture_responsive_ui.gd` — PASS, 22 routes × 4 resolutions = 88 captures.
- **PARSER/STARTUP:** Godot headless editor validation — PASS with no script compilation/load error.

Fixed regressions found by the playthrough: starter-guaranteed signings now occupy and normalize starter slots; starter sales normalize remaining roles; inbound offers no longer block progression; expired offers remove stale events; reload is idempotent; season-end state no longer leaks pending offers/events; no impossible Week-13 media story is created; season summary is actionable once; finance/progression/Inbox records have stable unique IDs; random-event budget changes enter the ledger; and the sidebar refreshes to the new season immediately.

# Future Systems

These are not claimed as implemented:

- Generated season-specific tournament catalog identities and full tournament elimination/advancement flow.
- Destination-side loan appearances, development and playing-time simulation.
- Bankruptcy/administration consequences and recovery rules.
- A complete, unbounded finance export beyond the rolling UI ledger.
- Richer season-summary aggregates such as transfer-by-transfer review, team-growth graph and notable-event ranking; reliable season-scoped aggregates do not yet exist for all of them.
- Natural full-season completion with every scheduled match played at every observer speed.
- Editable accessibility/profile settings, selected-message Inbox detail and richer imported multi-club player history.
- Corrupt-save recovery, empty/corrupt database recovery and fully retested custom-content import/export.
