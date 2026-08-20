# Stabilization and Career Systems Implementation Report

Implementation date: 2026-08-20
Save schema: version 11

This report covers the repository stabilization pass. It describes implemented behavior only. `scripts/match_runtime.gd` was treated as frozen and was not modified.

## Changed

- Added a centralized state validator covering roster ownership/roles/contracts, finance IDs and amounts, calendar boundaries, tournament result uniqueness, relationship keys and event lifecycle.
- Added explicit v9→v10 and v10→v11 migrations. Migrations deep-copy input and preserve unknown fields.
- Hardened save/load with validation-before-commit, temporary-file writes, a rotating previous-save backup and restoration on replacement failure.
- Added stable sequence-based IDs for finance records, actions, scrim results, transfer offers, facility projects and meta patches.
- Added a bounded domain action audit log and structured command results for new UI-facing commands.
- Cached the canonical `GameDatabase` instance behind `GameState.career_database()`; routed UI database reads through that cache.
- Extracted weekly finance, roster normalization, player development and post-match career feedback into focused domain modules.
- Replaced duplicate Finance UI formulas with `GameState.weekly_finance_projection()`, the same calculation used by weekly progression.
- Removed direct UI writes for calendar view offset and active match selection.
- Removed two synthetic UI values: favorite weapon now uses recorded preference data or `NOT RECORDED`; featured opponent now comes from the next scheduled match participant list.
- Fixed the Match Center start callback so it returns only when event selection fails.

## Architecture

`GameState` remains the authoritative façade and single source of truth. Existing callers remain compatible, while focused policies now live in:

```text
GameState façade
├─ CareerStateValidator          cross-domain invariants
├─ SaveMigrations                explicit schema transitions
├─ FinanceDomain                weekly projection and ledger reconciliation
├─ RosterDomain                 roster lookup/role normalization
├─ PlayerDevelopmentDomain      weekly player progression
├─ MatchCareerFeedback          career consequences after a match
└─ cached GameDatabase          canonical immutable world data

MatchRuntime                    frozen simulation boundary
└─ MatchResult/telemetry → GameState → career consequences
```

Most routed UI screens are still procedural methods in `scripts/main.gd`; the architecture is improved but screen extraction remains incomplete.

## Gameplay

Weekly development now considers age, potential gap, morale, starter opportunity, form, personality and organization development identity in addition to the existing facility, staff, schedule, difficulty and training-focus modifiers. Weekly results expose per-player before/after development data.

Committed match results now update tactical familiarity, chemistry and player happiness through a career-side feedback policy using placement, player statistics and the existing decision log. This happens after `MatchRuntime` finishes and does not change simulation formulas.

## Persistence

- Current schema is version 11.
- Invalid or malformed saves do not replace live in-memory state.
- State is normalized and validated before it replaces the main save.
- A successful replacement retains the previous file as `<save>.backup`.
- Unknown JSON fields survive migration.
- Pending events are normalized to `PENDING`; historical events are normalized to terminal lifecycle states.

## Tests

Confirmed automated coverage:

- `game_systems_test.gd`: 110 checks.
- `real_career_playtest.gd`: 951 checks, 3 matches, 12 weeks and 10 reloads.
- `state_integrity_test.gd`: 17 checks for malformed state, migration, backup, event resolution, database caching and finance reconciliation.
- `match_determinism_test.gd`: 8 checks; identical state/seed produces identical result telemetry, a different seed changes the result, and scoreboard/result boundaries are valid.
- `career_stress_test.gd`: 90 checks over 24 weeks, 6 reloads and two completed season transitions.

## MatchRuntime

`scripts/match_runtime.gd` was not changed. Its result already supplies `match_id`, `match_seed`, scoreboard, player statistics, decision log, timeline and detailed telemetry. `GameState.apply_match_runtime_result()` now marks the committed boundary as contract version 1, prevents duplicate transaction/event commits and applies career consequences outside the simulator.

## Regression

The existing game systems test and real career playtest pass after the changes. Parser/editor loading succeeds. The renderer-backed interaction audit captured and exercised 40 controls across two sizes, and the responsive audit captured 22 screens at four resolutions (88 screen captures). These UI audits do not prove filesystem dialogs or external OS flows.

## Risks

- `GameState` is still large and exposes legacy methods with mixed return types; only new commands guarantee the structured result shape.
- Most screens remain inside `main.gd`, so view/controller separation is still transitional.
- The backup is one rotating previous version, not a multi-generation recovery system.
- Insolvency has a validator warning but no implemented bankruptcy/restructuring gameplay.
- Career feedback is intentionally modest and has not been balance-tuned with a large statistical sample.
- `MatchRuntime` owns a separate database instance by design; the career/UI cache does not alter the frozen simulator.

## Next Phase

1. Extract routed screens from `main.gd` behind small view models and command-only inputs.
2. Convert legacy string-returning mutations to the structured command result contract in compatibility-preserving batches.
3. Add multi-generation save recovery and an in-game recovery selector.
4. Run long statistical balance simulations across difficulties, organizations, seeds and lobby sizes.
5. Add explicit insolvency, board intervention and contract-promise consequence systems after balance baselines exist.
