extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const FinanceDomain = preload("res://scripts/domain/finance_domain.gd")
const SAVE_PATH := "user://codex_state_integrity.json"
const INVALID_PATH := "user://codex_state_invalid.json"
const MIGRATION_PATH := "user://codex_state_migration.json"

var checks := 0
var failures := 0

func _init() -> void:
	var game = GameStateScript.new()
	game.save_path = SAVE_PATH
	game.new_career("Integrity Career", "Validator", "SEA", {"difficulty":"Normal"})
	_check(bool(game.validate_state().get("ok", false)), "Fresh career violates centralized invariants")
	_check(game.save_game(), "Fresh career did not persist")
	_check(game.save_game() and FileAccess.file_exists(SAVE_PATH + ".backup"), "Atomic save did not retain a previous backup")

	var first_database = game.career_database()
	_check(first_database == game.career_database(), "World database was reloaded instead of reused")
	var invalid_selection := game.set_active_match_event("missing-event")
	_check(not bool(invalid_selection.get("ok", true)) and str(invalid_selection.get("error_code", "")).length() > 0, "UI command error is not structured")

	var duplicate: Dictionary = game.data.duplicate(true)
	duplicate.roster.append(duplicate.roster[0].duplicate(true))
	_check(_has_error(game.validate_state(duplicate), "PLAYER_ID_DUPLICATE"), "Duplicate roster ID was not rejected")
	var loan_overlap: Dictionary = game.data.duplicate(true)
	loan_overlap.loaned_players = [loan_overlap.roster[0].duplicate(true)]
	_check(_has_error(game.validate_state(loan_overlap), "PLAYER_ACTIVE_AND_LOANED"), "Active/loaned overlap was not rejected")
	var finance_duplicate: Dictionary = game.data.duplicate(true)
	finance_duplicate.finance_ledger.append(finance_duplicate.finance_ledger[0].duplicate(true))
	_check(_has_error(game.validate_state(finance_duplicate), "FINANCE_ID_DUPLICATE"), "Duplicate finance record was not rejected")
	var bad_calendar: Dictionary = game.data.duplicate(true)
	bad_calendar.week = 3
	_check(_has_error(game.validate_state(bad_calendar), "WEEK_DAY_MISMATCH"), "Calendar week/day mismatch was not rejected")

	var event_id := "integrity:event"
	game.data.pending_events.append({"id":event_id,"type":"integrity_test","status":"response_required","lifecycle_status":"PENDING","created_week":int(game.data.week),"deadline_week":int(game.data.week)+1,"context":{},"choices":[{"id":"accept","label":"Accept","effects":{"morale":1}}]})
	_check(bool(game.resolve_event(event_id, "accept").get("ok", false)), "Pending event did not resolve")
	_check(not bool(game.resolve_event(event_id, "accept").get("ok", true)), "Resolved event was applied twice")
	var expired_id := "integrity:expired"
	game.data.pending_events.append({"id":expired_id,"type":"integrity_test","status":"response_required","lifecycle_status":"PENDING","created_week":1,"deadline_week":0,"context":{},"choices":[{"id":"accept","label":"Accept","effects":{}}]})
	var expired := game.resolve_event(expired_id, "accept")
	_check(str(expired.get("error_code", "")) == "EVENT_EXPIRED", "Expired event did not enter a terminal state")

	var reconciliation := FinanceDomain.ledger_reconciliation(game.data.finance_ledger)
	_check(bool(reconciliation.get("ok", false)), "Valid finance ledger failed reconciliation")

	var invalid_loader = GameStateScript.new()
	invalid_loader.save_path = INVALID_PATH
	invalid_loader.data = game.data.duplicate(true)
	var stable_budget := int(invalid_loader.data.budget)
	_write(INVALID_PATH, "{ definitely not json")
	_check(not invalid_loader.load_game() and int(invalid_loader.data.budget) == stable_budget, "Malformed save changed live in-memory state")

	var legacy: Dictionary = game.data.duplicate(true)
	legacy.save_version = 10
	legacy.erase("domain_audit_log")
	legacy.erase("season_start_days_elapsed")
	legacy["unknown_future_metadata"] = {"preserve":true}
	_write(MIGRATION_PATH, JSON.stringify(legacy))
	var migrated = GameStateScript.new()
	migrated.save_path = MIGRATION_PATH
	_check(migrated.load_game(), "Version 10 save did not migrate")
	_check(int(migrated.data.get("save_version", 0)) == 11 and migrated.data.has("domain_audit_log"), "Version 11 migration fields are missing")
	_check(bool(migrated.data.get("unknown_future_metadata", {}).get("preserve", false)), "Migration discarded an unknown field")

	for path in [SAVE_PATH, SAVE_PATH + ".backup", SAVE_PATH + ".tmp", INVALID_PATH, MIGRATION_PATH, MIGRATION_PATH + ".backup", MIGRATION_PATH + ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures > 0:
		push_error("STATE_INTEGRITY_TEST_FAILED checks=%d failures=%d" % [checks, failures])
		quit(1)
	else:
		print("STATE_INTEGRITY_TEST_OK checks=%d" % checks)
		quit(0)

func _has_error(validation: Dictionary, error_code: String) -> bool:
	return validation.get("errors", []).any(func(error): return str(error.get("error_code", "")) == error_code)

func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(content)
		file.close()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition: return
	failures += 1
	push_error("CHECK FAILED: %s" % message)
