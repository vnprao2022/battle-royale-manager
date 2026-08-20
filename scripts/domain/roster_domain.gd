class_name RosterDomain
extends RefCounted

static func normalize_squad_roles(roster: Array) -> void:
	for index in roster.size(): roster[index].squad_role = "starter" if index < 4 else "substitute"

static func find_player(rows: Array, player_id: String) -> Dictionary:
	for player in rows:
		if str(player.get("id", "")) == player_id: return player
	return {}

static func contains_player(rows: Array, player_id: String) -> bool:
	return not find_player(rows, player_id).is_empty()
