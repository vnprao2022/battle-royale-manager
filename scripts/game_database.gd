class_name GameDatabase
extends RefCounted

const MANIFEST_PATH := "res://database/core/manifest.json"

var manifest: Dictionary = {}
var rules: Dictionary = {}
var career_content: Dictionary = {}
var teams: Array = []
var players: Array = []
var tournaments: Array = []
var _team_by_id: Dictionary = {}
var _player_by_id: Dictionary = {}
var _tournament_by_id: Dictionary = {}

func load_all() -> PackedStringArray:
	var errors := PackedStringArray()
	manifest = _read_json(MANIFEST_PATH, errors)
	if manifest.is_empty():
		return errors
	var collections: Dictionary = manifest.get("collections", {})
	var player_data: Variant = _read_collection(collections, "players", errors)
	var team_data: Variant = _read_collection(collections, "teams", errors)
	_load_pubg_database(_as_array(team_data), _as_array(player_data))
	rules = _read_collection(collections, "rules", errors)
	var career_data: Variant = _read_collection(collections, "career_content", errors)
	career_content = career_data if career_data is Dictionary else {}
	var tournament_data: Variant = _read_collection(collections, "tournaments", errors)
	tournaments = tournament_data if tournament_data is Array else [tournament_data]
	_index(teams, _team_by_id, "team", errors)
	_index(players, _player_by_id, "player", errors)
	_index(tournaments, _tournament_by_id, "tournament", errors)
	errors.append_array(validate())
	return errors

func get_team(team_id: String) -> Dictionary:
	return _team_by_id.get(team_id, {})

func get_player(player_id: String) -> Dictionary:
	return _player_by_id.get(player_id, {})

func search_teams(query := "", region := "", tier := "", team_type := "") -> Array:
	var result: Array = []
	var needle := query.to_lower().strip_edges()
	for team in teams:
		if not needle.is_empty() and not needle in str(team.get("name", "")).to_lower(): continue
		if not region.is_empty() and str(team.get("region", "")) != region: continue
		if not tier.is_empty() and str(team.get("tier", "")) != tier: continue
		if not team_type.is_empty() and str(team.get("team_type", "CLUB")) != team_type: continue
		result.append(team)
	return result

func search_players(query := "", nationality := "", role := "", team_id := "") -> Array:
	var result: Array = []
	var needle := query.to_lower().strip_edges()
	for player in players:
		var searchable := "%s %s %s" % [player.get("display_name", ""), player.get("handle", ""), player.get("current_team_name", "")]
		if not needle.is_empty() and not needle in searchable.to_lower(): continue
		if not nationality.is_empty() and str(player.get("nationality", "")) != nationality: continue
		if not role.is_empty() and str(player.get("role", "")) != role: continue
		if not team_id.is_empty() and str(player.get("team_id", "")) != team_id: continue
		result.append(player)
	return result

func get_tournament(tournament_id: String) -> Dictionary:
	return _tournament_by_id.get(tournament_id, {})

func get_active_tournament() -> Dictionary:
	return get_tournament(str(manifest.get("active_tournament_id", "")))

func get_team_players(team_id: String) -> Array:
	var result: Array = []
	for player in players:
		if str(player.get("team_id", "")) == team_id:
			result.append(player)
	return result

func _load_pubg_database(raw_teams: Array, raw_players: Array) -> void:
	teams.clear(); players.clear()
	var team_id_by_name: Dictionary = {}
	for source in raw_teams:
		var team_id := "pubg_team_%s" % _source_id(source.get("id", ""))
		var name := str(source.get("name", "Unknown Team")).strip_edges()
		var team := {
			"id":team_id, "name":name, "display_name":name, "tag":_team_tag(name), "region":"Global", "country":"Unknown", "team_type":_team_type(name), "tier":"D",
			"logo_asset_id":_database_asset_path(str(source.get("logo_file", ""))), "source_url":str(source.get("source_url", "")),
			"roster_ids":[], "ranking":{"power":50}, "performance":{"consistency":50}
		}
		teams.append(team); team_id_by_name[_name_key(name)] = team_id
	var team_lookup: Dictionary = {}
	var team_rating_totals: Dictionary = {}
	var team_country_counts: Dictionary = {}
	for team in teams: team_lookup[str(team.id)] = team
	for source in raw_players:
		var stats: Dictionary = source.get("latest_stats", {})
		var avg_rank := _number(stats.get("avg_rank", null), 10.0)
		var avg_kill := _number(stats.get("avg_kill", null), 0.45)
		var avg_damage := _number(stats.get("avg_damage", null), 115.0)
		var survive_minutes := _survive_minutes(str(stats.get("avg_survive_time", "-")))
		var combat_score := clampi(roundi(35.0 + avg_kill * 28.0 + avg_damage * 0.105), 30, 99)
		var survival_score := clampi(roundi(25.0 + survive_minutes * 2.65), 30, 99)
		var placement_score := clampi(roundi(101.0 - avg_rank * 5.0), 30, 99)
		var overall := clampi(roundi(combat_score * 0.45 + survival_score * 0.25 + placement_score * 0.30), 35, 96)
		var current_team := str(source.get("current_team", "")).strip_edges()
		var team_id := str(team_id_by_name.get(_name_key(current_team), ""))
		var national_team_id := ""
		if team_lookup.has(team_id) and str(team_lookup[team_id].get("team_type", "CLUB")) == "NATIONAL":
			national_team_id = team_id
			for history_entry in source.get("team_history", []):
				var historical_name := str(history_entry.get("team", "")); var historical_id := str(team_id_by_name.get(_name_key(historical_name), ""))
				if team_lookup.has(historical_id) and str(team_lookup[historical_id].get("team_type", "CLUB")) == "CLUB": team_id = historical_id; current_team = historical_name; break
		var player_id := "pubg_player_%s" % _source_id(source.get("id", ""))
		var player := _normalize_pubg_player(source, stats, player_id, team_id, current_team, overall, combat_score, survival_score, placement_score)
		player.national_team_id = national_team_id
		players.append(player)
		if team_lookup.has(team_id):
			team_lookup[team_id].roster_ids.append(player_id)
			team_rating_totals[team_id] = int(team_rating_totals.get(team_id, 0)) + overall
			var country := str(player.get("nationality", "Unknown")).strip_edges()
			if not team_country_counts.has(team_id): team_country_counts[team_id] = {}
			team_country_counts[team_id][country] = int(team_country_counts[team_id].get(country, 0)) + 1
	for team in teams:
		var roster: Array = team.get("roster_ids", [])
		var total := int(team_rating_totals.get(str(team.id), 0))
		team.ranking.power = clampi(roundi(float(total) / maxi(1, roster.size())), 35, 96)
		team.tier = "A" if int(team.ranking.power) >= 82 else "B" if int(team.ranking.power) >= 72 else "C" if int(team.ranking.power) >= 60 else "D"
		if str(team.get("team_type", "CLUB")) == "NATIONAL":
			team.country = str(team.name)
		else:
			var counts: Dictionary = team_country_counts.get(str(team.id), {})
			var best_country := "Unknown"; var best_count := 0
			for country in counts:
				if int(counts[country]) > best_count: best_country = str(country); best_count = int(counts[country])
			team.country = best_country

func _normalize_pubg_player(source: Dictionary, stats: Dictionary, player_id: String, team_id: String, current_team: String, overall: int, combat_score: int, survival_score: int, placement_score: int) -> Dictionary:
	var nickname := str(source.get("nickname", "Player"))
	var role := "Fragger" if combat_score >= survival_score + 8 else "Anchor" if survival_score >= combat_score + 8 else "Flex"
	return {
		"id":player_id, "team_id":team_id, "current_team_name":current_team, "handle":nickname, "display_name":str(source.get("real_name", nickname)),
		"nickname":nickname, "nationality":str(source.get("nationality", "Unknown")), "age":22, "role":role, "secondary_role":"Flex", "status":"active", "tier":"A" if overall >= 82 else "B" if overall >= 72 else "C" if overall >= 60 else "D",
		"image_file":str(source.get("image_file", "")), "avatar_asset_id":_database_asset_path(str(source.get("image_file", ""))), "source_url":str(source.get("source_url", "")), "latest_tournament":str(source.get("latest_tournament", "")), "team_history":source.get("team_history", []).duplicate(true),
		"latest_stats":{"avg_rank":stats.get("avg_rank", null), "avg_kill":stats.get("avg_kill", null), "avg_damage":stats.get("avg_damage", null), "avg_survive_time":str(stats.get("avg_survive_time", "-"))},
		"ratings":{"overall":overall, "potential":clampi(overall + 4, overall, 99), "form":clampi(roundi((combat_score + placement_score) * 0.5), 35, 99), "energy":80, "morale":70},
		"combat":{"aim":combat_score, "clutch":clampi(roundi(combat_score * 0.55 + placement_score * 0.45), 30, 99), "utility_timing":clampi(roundi((survival_score + placement_score) * 0.5), 30, 99), "long_range":combat_score},
		"awareness":{"game_sense":placement_score, "vision":clampi(roundi((combat_score + survival_score) * 0.5), 30, 99), "hearing":survival_score, "reaction":combat_score},
		"teamplay":{"teamwork":clampi(roundi((placement_score + survival_score) * 0.5), 30, 99), "communication":placement_score, "leadership":placement_score, "discipline":survival_score, "composure":survival_score},
		"macro":{"driving":survival_score, "zone_reading":placement_score, "loot_efficiency":combat_score, "risk_assessment":survival_score},
		"physical":{"fatigue_resistance":survival_score}, "stealth":{"concealment":survival_score},
		"contract":{"monthly_salary":overall * 140, "market_value":overall * overall * 140, "months_remaining":24, "release_clause":overall * overall * 280}, "career":{}, "preferred":{}
	}

func _number(value: Variant, fallback: float) -> float:
	return fallback if value == null else float(value)

func _source_id(value: Variant) -> String:
	return str(int(value)) if value is float else str(value)

func _survive_minutes(value: String) -> float:
	if value == "-" or not value.contains(":"): return 17.0
	var parts := value.split(":"); return float(parts[0]) + float(parts[1]) / 60.0

func _database_asset_path(value: String) -> String:
	return "res://database/%s" % value.replace("\\", "/") if not value.is_empty() else ""

func _name_key(value: String) -> String:
	return value.to_lower().strip_edges().replace(" ", "").replace("-", "").replace("_", "")

func _team_tag(value: String) -> String:
	var words := value.split(" ", false); var result := ""
	for word in words: result += str(word).left(1).to_upper()
	return result.left(4) if not result.is_empty() else value.left(3).to_upper()

func _team_type(value: String) -> String:
	var national_names := ["VIETNAM", "TURKIYE", "TÜRKIYE", "KOREA", "CHINA", "THAILAND", "JAPAN", "UNITED KINGDOM", "USA", "CANADA", "AUSTRALIA", "BRAZIL", "GERMANY", "FINLAND", "NORWAY", "TAIWAN"]
	return "NATIONAL" if value.to_upper().strip_edges() in national_names else "CLUB"

func career_opponents(excluded_team_id := "mekong_reapers") -> Array:
	var result: Array = []
	for team in teams:
		var team_id := str(team.get("id", ""))
		if team_id == excluded_team_id:
			continue
		var ranking: Dictionary = team.get("ranking", {})
		result.append({
			"database_id": team_id,
			"logo_asset_id": str(team.get("logo_asset_id", "")),
			"name": str(team.get("name", team_id)),
			"tag": str(team.get("tag", "")),
			"region": str(team.get("region", "Unknown")),
			"country": str(team.get("country", "Unknown")),
			"tier": str(team.get("tier", "D")),
		"power": int(ranking.get("power", 50)),
		"baseline_power": int(ranking.get("power", 50)),
		"form": int(team.get("performance", {}).get("consistency", 50)),
		"trend": 0,
			"points": 0,
			"roster_ids": team.get("roster_ids", []).duplicate()
		})
		if result.size() >= 15: break
	return result

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if teams.is_empty(): errors.append("PUBG team database is empty")
	if players.is_empty(): errors.append("PUBG player database is empty")
	var allowed_tiers: Array = rules.get("tiers", {}).keys()
	var required_groups := ["ratings", "combat", "awareness", "teamplay", "macro", "physical", "stealth"]
	for team in teams:
		var team_id := str(team.get("id", ""))
		var roster: Array = team.get("roster_ids", [])
		var ranking: Dictionary = team.get("ranking", {})
		if not allowed_tiers.has(str(team.get("tier", ""))): errors.append("Team %s has invalid tier" % team_id)
		if not ranking.has("power"): errors.append("Team %s missing ranking.power" % team_id)
		for player_id in roster:
			var player := get_player(str(player_id))
			if player.is_empty(): errors.append("Team %s references missing player %s" % [team_id, player_id])
			elif str(player.get("team_id", "")) != team_id: errors.append("Player %s has wrong team_id" % player_id)
	for player in players:
		var player_id := str(player.get("id", ""))
		if not str(player.get("team_id", "")).is_empty() and get_team(str(player.get("team_id", ""))).is_empty(): errors.append("Player %s references missing team" % player_id)
		if not allowed_tiers.has(str(player.get("tier", ""))): errors.append("Player %s has invalid tier" % player_id)
		for group in required_groups:
			if not player.get(group, {}) is Dictionary or player.get(group, {}).is_empty(): errors.append("Player %s missing %s stats" % [player_id, group])
	var active := get_active_tournament()
	if active.is_empty():
		errors.append("Active tournament is missing")
	for tournament in tournaments:
		var team_count := int(tournament.get("team_count", 0)); var team_size := int(tournament.get("players_per_team", 0)); var max_players := int(tournament.get("max_players", 0))
		if not str(tournament.get("tournament_type", "")) in ["NATIONAL", "DOMESTIC", "INTERNATIONAL"]: errors.append("Tournament %s has invalid tournament_type" % tournament.get("id", ""))
		if not str(tournament.get("participant_type", "")) in ["CLUB", "NATIONAL_TEAM"]: errors.append("Tournament %s has invalid participant_type" % tournament.get("id", ""))
		if team_count < 2 or team_count > 25: errors.append("Tournament %s team_count must be 2..25" % tournament.get("id", ""))
		if team_size != 4 or max_players != team_count * team_size or max_players > 100: errors.append("Tournament %s has invalid player capacity" % tournament.get("id", ""))
	return errors

func _read_collection(collections: Dictionary, key: String, errors: PackedStringArray) -> Variant:
	if not collections.has(key):
		errors.append("Manifest missing collection: %s" % key)
		return {}
	return _read_json(str(collections[key].get("path", "")), errors)

func _read_json(path: String, errors: PackedStringArray) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("Missing database file: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		errors.append("Invalid JSON: %s" % path)
		return {}
	return parsed

func _as_array(value: Variant) -> Array:
	return value if value is Array else []

func _index(source: Array, target: Dictionary, label: String, errors: PackedStringArray) -> void:
	target.clear()
	for entry in source:
		var id := str(entry.get("id", ""))
		if id.is_empty(): errors.append("%s has empty id" % label)
		elif target.has(id): errors.append("Duplicate %s id: %s" % [label, id])
		else: target[id] = entry
