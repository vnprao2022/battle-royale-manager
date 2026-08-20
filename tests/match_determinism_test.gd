extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const MatchRuntimeScript = preload("res://scripts/match_runtime.gd")
const SAVE_PATH := "user://codex_match_determinism.json"

var checks := 0
var failures := 0

func _init() -> void:
	var game = GameStateScript.new()
	game.save_path = SAVE_PATH
	game.new_career("Determinism Career", "Seed Auditor", "SEA", {"difficulty":"Normal"})
	if game.get_playable_match().is_empty():
		var scheduled := game.get_next_match(true)
		game.data.current_date = str(scheduled.get("date", game.data.current_date))
	var event := game.get_playable_match()
	var prepared := game.prepare_match_context(event)
	_check(bool(prepared.get("ok", false)), "Match context could not be prepared")
	game.data.active_match_event_id = str(event.get("id", "determinism"))
	var snapshot: Dictionary = game.data.duplicate(true)
	var map_id := str(event.get("map", "verdant_reach"))
	var plan := game.effective_match_plan()
	var first := _simulate(snapshot, map_id, plan, 424242)
	var second := _simulate(snapshot, map_id, plan, 424242)
	var different := _simulate(snapshot, map_id, plan, 424243)
	_check(not first.is_empty() and not second.is_empty() and not different.is_empty(), "MatchRuntime did not finish all deterministic fixtures")
	_check(_canonical(first) == _canonical(second), "Identical state and seed produced different match results")
	_check(_canonical(first) != _canonical(different), "Different seeds produced an identical full match result")
	_check(str(first.get("match_id", "")).length() > 0 and int(first.get("match_seed", -1)) == 424242, "Stable result boundary is missing match_id/match_seed")
	var scoreboard: Array = first.get("scoreboard", [])
	_check(scoreboard.size() >= 2 and scoreboard.size() <= 25, "Scoreboard team count is outside the supported lobby boundary")
	var ranks := scoreboard.map(func(row): return int(row.get("rank", 0)))
	var unique_ranks: Dictionary = {}
	for rank in ranks: unique_ranks[rank] = true
	_check(unique_ranks.size() == scoreboard.size() and ranks.min() == 1 and ranks.max() == scoreboard.size(), "Scoreboard ranks are incomplete or duplicated")
	_check(not first.get("player_stats", []).is_empty() and first.has("decision_log") and first.has("timeline"), "Stable result telemetry fields are missing")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + ".backup"))
	if failures > 0:
		push_error("MATCH_DETERMINISM_TEST_FAILED checks=%d failures=%d" % [checks, failures])
		quit(1)
	else:
		print("MATCH_DETERMINISM_TEST_OK checks=%d seed=424242 teams=%d" % [checks, scoreboard.size()])
		quit(0)

func _simulate(snapshot: Dictionary, map_id: String, plan: Dictionary, seed_value: int) -> Dictionary:
	var results: Array = []
	var runtime = MatchRuntimeScript.new()
	runtime.match_finished.connect(func(result): results.append(result.duplicate(true)))
	runtime.start_match(snapshot.duplicate(true), map_id, plan.duplicate(true), seed_value)
	for tick_index in 4000:
		if not results.is_empty(): break
		runtime.tick(5.0)
	return results[0] if not results.is_empty() else {}

func _canonical(result: Dictionary) -> String:
	return JSON.stringify({
		"scoreboard":result.get("scoreboard", []),
		"player_stats":result.get("player_stats", []),
		"decision_log":result.get("decision_log", []),
		"timeline":result.get("timeline", []),
		"weapon_stats":result.get("weapon_stats", {}),
		"zone_events":result.get("zone_events", [])
	})

func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition: return
	failures += 1
	push_error("CHECK FAILED: %s" % message)
