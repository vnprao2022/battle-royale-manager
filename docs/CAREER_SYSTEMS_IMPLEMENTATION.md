# Career systems implementation status

This document records only behavior confirmed by the current implementation.

## Startup, navigation and settings

- Pre-career screens hide the career sidebar and top bar and use the full viewport width.
- Main Menu, Load Career, New Career, Custom Content and startup Settings expose an explicit return path.
- Career pages expose router-backed Back navigation.
- Master, music and SFX volume are persisted to `user://settings.json` and applied through Godot audio buses.
- Windowed, fullscreen and borderless modes, four windowed resolutions, VSync, UI scale, reduced motion, high contrast and autosave preferences are persisted.
- Career difficulty supports Casual, Normal, Hard and Director and changes economy, training, scouting and transfer-interest modifiers.
- Custom Rules can change weapon damage, zone damage, loot density, AI aggression and vehicle density. Enabling them marks the career as modified.
- The Map Manager edits drop regions, loot multipliers, hotness, loot points and traversal rules and stores overrides under `user://map_overrides`.

## New Career

- The flow has two paths: a new Tier D Story club or an existing database club.
- Both paths require a manager/head-coach name.
- Story careers support a generated academy or four manager-named founding players.
- Story player overall is generated within the Tier D range; ten additional academy prospects are generated.
- Team identity accepts validated PNG/JPG/WEBP imports or four shipped PNG patterns: shield, wing, crown and monogram.
- A Story club receives a unique organization ID and is inserted into auto-registered tournament participant lists.
- A free-form layer editor that combines multiple pattern layers and arbitrary colors is not implemented. The current implementation selects one PNG base pattern.

## Recruitment and transfers

- Player Discovery does not expose the full database as an instant shortlist.
- A scout assignment records role, age band, priority and budget ceiling, charges a fee and takes two to five career days depending on Analytics Lab level.
- A completed assignment returns three to seven players depending on facility level and creates an Inbox report.
- Scout staff rating and Analytics Lab level affect report confidence.
- Transfer Market is separate from scouting. Contracted players can only be approached in pre-season (weeks 1–2), mid-season (weeks 6–7) and post-season (weeks 11–12).
- Free agents may negotiate at any time and have no transfer fee; salary and contract negotiation still resolves through Inbox decisions.
- Multiplayer listings and bidding against human-controlled clubs are not implemented. The market is the career simulation and canonical world database.

## Training

- Team focus supports Combat, Strategy, Teamwork, Mental, Intensive and Recovery.
- Weekly schedules contain seven editable activity/intensity pairs.
- Mechanical, Strategic, Balanced and Recovery programs populate the weekly schedule; manual edits create a Custom program.
- Individual recommendations are derived from the player's lowest relevant attribute, energy or form.
- Intensive, competitive, recovery and rest days create different energy and growth trade-offs.
- Weekly processing records before/after match-relevant attributes, energy, form, developed players, team-power delta and match readiness in `training_history`.
- Training affects matches through player attributes, form, energy and teamwork already consumed by MatchRuntime. No unimplemented direct percentage combat buff is claimed.
- A real Head Coach training report is generated in Inbox after weekly processing.

## Competitive world, tournaments and rankings

- Club and National rankings are separate.
- Ranking Points are independent of team Power. Competitive profiles also store form, momentum, five recent results, tournament experience, consistency, regional strength, tier and last-active week.
- Due tournaments simulate all registered participants in the background even when the player is not participating.
- Background results update Ranking Points, form, momentum, experience, recent results and tier. Inactivity applies decay.
- Tournament entry checks participant type, country, minimum tier and optional minimum Ranking Points, plus calendar conflicts.
- Tournament matches played by the user continue to use the existing MatchRuntime; its core formulas were not modified.

## Maps

Six runtime-loadable map descriptors and PNG map assets are available:

1. Verdant Reach
2. Sunscorch Basin
3. Tactical Island
4. Frostline Valley
5. Coastal Breakwater
6. Highland Reserve

All six are available to Map Manager and scrim selection. Tactics have not been redesigned around per-map bespoke AI systems; existing data-driven region, loot and traversal rules are used.

## Connected systems already confirmed

- Scout report to shortlist to negotiation to Inbox decision to roster.
- Training schedule to player attributes/energy/form to MatchRuntime inputs to weekly report.
- Tournament result to competitive profile to Ranking Points/tier.
- Match result to tournament standings, finance, progression and Inbox.
- Facility levels affect training growth, scouting duration/result count/confidence, recovery and streaming income.

## Not completed in this pass

- Finance sponsor contracts still use the existing signing/objective model; a full KPI negotiation and penalty system is not implemented.
- Facilities retain existing upgrade projects and numeric effects; maintenance, capacity and construction-state simulation are not fully implemented.
- Inbox receives real messages from several systems, but a full authored conversation/narrative engine is not implemented.
- A multiplayer transfer market is not implemented.
- A multi-layer logo compositor is not implemented.
