extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const SAVE_PATH := "user://codex_career_stress.json"

var checks := 0
var failures := 0
var reloads := 0
var weeks := 0

func _init() -> void:
	seed(771177)
	var game = GameStateScript.new()
	game.save_path = SAVE_PATH
	game.new_career("Stress Career", "Long Horizon", "SEA", {"difficulty":"Normal", "starting_tier":"B"})
	game.data.budget = 5000000
	while game.data.roster.size() < 6 and not game.data.market.is_empty():
		var signed := false
		for index in range(game.data.market.size() - 1, -1, -1):
			if game.sign_player(index).begins_with("Signed"):
				signed = true
				break
		if not signed: break
	_check(game.data.roster.size() >= 5, "Stress fixture could not establish roster depth")
	if game.data.roster.size() > 4:
		var loan := game.create_loan(str(game.data.roster[-1].get("id", "")), "", 4, 50)
		_check(bool(loan.get("ok", false)), "Loan lifecycle could not start")
	var facility_result := game.upgrade_facility("Medical Room")
	_check(facility_result.contains("started"), "Facility project could not start")

	for cycle in 24:
		_resolve_pending(game)
		game.advance_week(true)
		weeks += 1
		_resolve_pending(game)
		var validation := game.validate_state()
		_check(bool(validation.get("ok", false)), "Invariant failure after stress week %d: %s" % [weeks, JSON.stringify(validation.get("errors", []))])
		_check(game.data.roster.size() >= 4 and game.organization_player_count() <= 7, "Roster boundary failed after stress week %d" % weeks)
		_check(absf(float(game.data.budget)) < 2000000000.0, "Finance escaped supported range")
		if not game.data.get("season_transition", {}).is_empty() and str(game.data.season_transition.get("status", "")) == "AVAILABLE": game.acknowledge_season_transition()
		if cycle % 4 == 3:
			_check(game.save_game(), "Stress checkpoint could not save")
			var loaded = GameStateScript.new()
			loaded.save_path = SAVE_PATH
			_check(loaded.load_game(), "Stress checkpoint could not reload")
			if not loaded.data.is_empty():
				game = loaded
				reloads += 1

	_check(int(game.data.season) >= 3, "Twenty-four weeks did not cross two season boundaries")
	_check(not game.data.get("season_history", []).is_empty(), "Long career did not archive season summaries")
	_check(game.data.get("loan_records", []).all(func(record): return str(record.get("status", "")) != "ACTIVE"), "Four-week loan did not return during stress run")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + ".backup"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + ".tmp"))
	if failures > 0:
		push_error("CAREER_STRESS_TEST_FAILED checks=%d failures=%d weeks=%d reloads=%d" % [checks, failures, weeks, reloads])
		quit(1)
	else:
		print("CAREER_STRESS_TEST_OK checks=%d weeks=%d reloads=%d season=%d" % [checks, weeks, reloads, int(game.data.season)])
		quit(0)

func _resolve_pending(game) -> void:
	for event in game.data.get("pending_events", []).duplicate(true):
		var choices: Array = event.get("choices", [])
		if choices.is_empty(): continue
		var choice_id := str(choices[0].get("id", ""))
		for preferred in ["stay_measured", "hold_meeting", "reject", "improve_result"]:
			if choices.any(func(choice): return str(choice.get("id", "")) == preferred):
				choice_id = preferred
				break
		game.resolve_event(str(event.get("id", "")), choice_id)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition: return
	failures += 1
	push_error("CHECK FAILED: %s" % message)
