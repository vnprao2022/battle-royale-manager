class_name MatchCareerFeedback
extends RefCounted

static func apply(state: Dictionary, result: Dictionary, own_player_stats: Array, placement: int) -> Dictionary:
	var changed: Array = []; var decisions: Array = result.get("decision_log", result.get("decisions", []))
	var successful_decisions := decisions.filter(func(item): return str(item.get("result", "")).to_lower() in ["success", "successful", "observed"]).size()
	var familiarity_delta := clampi(successful_decisions / 3, 0, 3) + (1 if placement <= 8 else -1 if placement > 12 else 0)
	state.tactical_familiarity = clampi(int(state.get("tactical_familiarity", 0)) + familiarity_delta, 0, 100)
	var chemistry_delta := 1 if placement <= 8 and own_player_stats.size() >= 4 else -1 if placement > 12 else 0
	state.chemistry = clampi(int(state.get("chemistry", 60)) + chemistry_delta, 0, 100)
	for stat in own_player_stats:
		var player_id := str(stat.get("player_id", "")); var impact := int(stat.get("kills", 0)) * 2 + int(stat.get("damage", 0)) / 250 + int(stat.get("revives", 0))
		for player in state.get("roster", []):
			if str(player.get("id", "")) != player_id: continue
			var confidence_delta := clampi(impact - 2, -2, 4); player.happiness = clampi(int(player.get("happiness", 60)) + confidence_delta, 0, 100); changed.append({"player_id":player_id, "performance_impact":impact, "happiness_delta":confidence_delta})
	return {"tactical_familiarity_delta":familiarity_delta, "chemistry_delta":chemistry_delta, "players":changed}
