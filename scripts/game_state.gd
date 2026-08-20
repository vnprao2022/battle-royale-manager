class_name GameState
extends RefCounted

const SAVE_VERSION := 10
const SAVE_PATH := "user://save_slot_01.json"
const SAVE_SLOT_COUNT := 3
const ROLES := ["IGL", "Entry", "Support", "Fragger", "Anchor", "Flex"]
const FIRST_NAMES := ["Minh", "Khai", "Jett", "Nova", "Rin", "Leo", "Sora", "Mika", "Zero", "Vex", "Bao", "Kiro", "Lynx", "Ares"]
const LAST_NAMES := ["Storm", "Tran", "Kim", "Nguyen", "Park", "Ray", "Chen", "Phan", "Fox", "Moon", "Vu", "Tan"]
const REGIONS := ["SEA", "EU", "NA", "LATAM", "MENA", "China", "Japan", "Korea"]
const TEAM_NAMES := ["Crimson Owls", "Neon Tigers", "Astra Nine", "Iron Pulse", "Silent Wave", "Titan Forge", "Azure Foxes", "Quantum Raid", "Solar Vipers", "Night Lotus", "Vertex", "Ember Crown", "Polar Ace", "Orbit Seven", "Rift Kings", "Echo Prime", "Mekong Stars", "Seoul Phoenix", "Tokyo Ronin"]
const SEASON_START_DATE := "2026-01-05"
const DATABASE_SCRIPT := preload("res://scripts/game_database.gd")

var data: Dictionary = {}
var save_path := SAVE_PATH
var _generated_player_ids: Dictionary = {}
var _generated_player_names: Dictionary = {}
var _generated_player_handles: Dictionary = {}

func difficulty_rules() -> Dictionary:
	var difficulty := str(data.get("difficulty", "Normal")).to_upper()
	return {
		"EASY":{"economy":1.10,"training_chance":0.05,"scouting":2,"inbound_interest":4},
		"HARD":{"economy":0.90,"training_chance":-0.05,"scouting":-2,"inbound_interest":-4}
	}.get(difficulty, {"economy":1.0,"training_chance":0.0,"scouting":0,"inbound_interest":0})

func organization_player_count() -> int:
	return data.get("roster", []).size() + data.get("loaned_players", []).size()

func facility_benefit_summary(name: String, level := -1) -> String:
	var current_level := int(data.get("facilities", {}).get(name, 0)) if level < 0 else level
	match name:
		"Training Room": return "+%d percentage points to weekly growth chance" % (current_level * 4)
		"Analytics Lab": return "+%d scout confidence per scouting update" % (current_level * 2)
		"Medical Room": return "+%d weekly energy • +%d energy per manual rest" % [current_level * 2, current_level * 4]
		"Streaming Room": return "$%s weekly media income" % money(current_level * 4800)
	return "No confirmed gameplay modifier"

func training_plan_preview(schedule := "") -> Dictionary:
	var selected := str(data.get("schedule", "Cân bằng")) if schedule.is_empty() else schedule
	var recovery_level := int(data.get("facilities", {}).get("Medical Room", 1))
	var training_level := int(data.get("facilities", {}).get("Training Room", 1))
	var fatigue_resistance := 60
	if not data.get("roster", []).is_empty():
		fatigue_resistance = roundi(float(data.roster.reduce(func(total, player): return int(total) + int(player.get("fatigue_resistance",60)), 0)) / data.roster.size())
	var energy_change := 7 + recovery_level * 2 if selected == "Nghỉ & hồi phục" else (-8 + fatigue_resistance / 25 if selected == "Cường độ cao" else 1 + recovery_level)
	var head_coach_bonus := 0.0
	for staff in data.get("staff", []):
		if str(staff.get("id", "")) == "head_coach": head_coach_bonus = roundi(float(staff.get("rating",50)) / 10.0) / 100.0; break
	var growth_chance := (0.34 if selected == "Cường độ cao" else 0.16) + training_level * 0.04 + head_coach_bonus + float(difficulty_rules().training_chance)
	return {"schedule":selected,"energy_change":energy_change,"growth_chance":clampf(growth_chance,0.0,1.0),"form_rule":"+2 when energy remains above 55" if selected=="Cường độ cao" else "-1 when energy falls below 35" if selected!="Nghỉ & hồi phục" else "No automatic form gain","facility_level":training_level}

func current_media_story() -> Dictionary:
	_ensure_media_story()
	var story_id := "media:S%d:W%d" % [int(data.get("season", 1)), int(data.get("week", 1))]
	for story in data.get("media_stories", []):
		if str(story.get("id", "")) == story_id: return story
	return {}

func progression_summary(limit := 5) -> Array:
	return data.get("progression_log", []).slice(0, mini(limit, data.get("progression_log", []).size()))

func career_world_rank() -> int:
	var database = DATABASE_SCRIPT.new()
	if not database.load_all().is_empty(): return 0
	var power_rows: Array = []
	for team in database.teams:
		power_rows.append({"id":str(team.get("id", "")), "power":roundi(get_team_power()) if str(team.get("id", "")) == str(data.get("organization_id", "")) else int(team.get("ranking", {}).get("power", 0))})
	power_rows.sort_custom(func(a, b): return int(a.power) > int(b.power))
	for index in power_rows.size():
		if str(power_rows[index].id) == str(data.get("organization_id", "")): return index + 1
	return 0

func _next_record_id(prefix: String) -> String:
	var sequence := int(data.get("next_record_sequence", 1))
	data.next_record_sequence = sequence + 1
	return "%s:%s:%d" % [prefix, str(data.get("career_id", "career")), sequence]

func _record_progression(kind: String, title: String, detail: String, values: Dictionary = {}) -> void:
	var log: Array = data.get("progression_log", [])
	log.push_front({"id":_next_record_id("progression"),"type":kind,"date":str(data.get("current_date", SEASON_START_DATE)),"title":title,"detail":detail,"values":values.duplicate(true)})
	if log.size() > 40: log.resize(40)
	data.progression_log = log

func _ensure_media_story() -> void:
	if not data.has("media_stories"): data.media_stories = []
	var story_id := "media:S%d:W%d" % [int(data.get("season", 1)), int(data.get("week", 1))]
	if data.media_stories.any(func(story): return str(story.get("id", "")) == story_id): return
	data.media_stories.push_front({"id":story_id,"season":int(data.get("season",1)),"week":int(data.get("week",1)),"created_date":str(data.get("current_date",SEASON_START_DATE)),"status":"AVAILABLE","prompt":"Expectations rise before the next lobby.","answered_date":"","tone":"","message":"","effects":{}})
	if data.media_stories.size() > 24: data.media_stories.resize(24)

func new_career(org_name: String, background: String, region: String, options: Dictionary = {}) -> void:
	var requested_slot := clampi(int(options.get("slot_id", _slot_from_path(save_path))), 1, SAVE_SLOT_COUNT)
	if options.has("slot_id") or save_path == SAVE_PATH: save_path = slot_path(requested_slot)
	seed(20260804)
	_generated_player_ids.clear(); _generated_player_names.clear(); _generated_player_handles.clear()
	var game_database = DATABASE_SCRIPT.new()
	var database_errors: PackedStringArray = game_database.load_all()
	var roster: Array = []
	var market: Array = []
	var default_team_id := "mekong_reapers"
	if database_errors.is_empty():
		for database_team in game_database.teams:
			if game_database.get_team_players(str(database_team.get("id", ""))).size() >= 4:
				default_team_id = str(database_team.get("id", "")); break
	var selected_team_id := str(options.get("team_id", default_team_id))
	var selected_team: Dictionary = game_database.get_team(selected_team_id) if database_errors.is_empty() else {}
	if database_errors.is_empty() and (selected_team.is_empty() or game_database.get_team_players(selected_team_id).size() < 4):
		selected_team_id = default_team_id; selected_team = game_database.get_team(selected_team_id)
	if database_errors.is_empty():
		var selected_sources: Array = game_database.get_team_players(selected_team_id)
		for source in selected_sources.slice(0, mini(6, selected_sources.size())):
			roster.append(_player_from_database(source, true))
		for source in game_database.players:
			if roster.any(func(player): return str(player.get("id", "")) == str(source.get("id", ""))): continue
			market.append(_player_from_database(source, false))
		market.sort_custom(func(a, b): return int(a.get("value", 0)) < int(b.get("value", 0)))
		# Careers keep a 60-player active scouting pool; the complete 637-player
		# source remains queryable through GameDatabase without bloating every save.
		market = market.slice(0, mini(60, market.size()))
	else:
		for i in 6: roster.append(_make_player(62 + i * 2, ROLES[i], true))
		for i in 18: market.append(_make_player(randi_range(55, 84), ROLES[i % ROLES.size()], false))
	var teams: Array = game_database.career_opponents(selected_team_id) if database_errors.is_empty() else []
	var initial_scrims: Array = _initial_scrim_requests(game_database, selected_team_id) if database_errors.is_empty() else []
	if not database_errors.is_empty():
		push_warning("Game database invalid; using legacy opponents: %s" % "; ".join(database_errors))
		for i in 15:
			teams.append({"name": TEAM_NAMES[i], "region": REGIONS[i % REGIONS.size()], "power": randi_range(58, 88), "points": 0})
	var starting_tier := str(options.get("starting_tier", selected_team.get("tier", "D"))).to_upper()
	var tier_profile: Dictionary = {"D":{"budget":250000,"fans":2500,"reputation":18,"expectation":"Develop talent"},"C":{"budget":450000,"fans":6000,"reputation":32,"expectation":"Regional contender"},"B":{"budget":700000,"fans":11000,"reputation":50,"expectation":"Qualify for finals"},"A":{"budget":1000000,"fans":20000,"reputation":68,"expectation":"Challenge for titles"}}.get(starting_tier, {"budget":250000,"fans":2500,"reputation":18,"expectation":"Develop talent"})
	var official_name := str(selected_team.get("name", org_name))
	var career_mode := str(options.get("team_mode", "existing"))
	var resolved_name := org_name if career_mode in ["new", "replace"] else official_name
	var resolved_logo := str(options.get("logo_asset_id", selected_team.get("logo_asset_id", "team.mekong_reapers.logo")))
	data = {
		"save_version": SAVE_VERSION, "slot_id":requested_slot, "career_id":"career-%d-%d" % [requested_slot, Time.get_unix_time_from_system()], "organization_id":selected_team_id, "org_name": resolved_name, "org_logo_asset_id": resolved_logo, "background": background, "region": str(selected_team.get("region", region)),
		"season": 1, "week": 1, "budget": int(tier_profile.budget), "fans": int(tier_profile.fans), "reputation": int(tier_profile.reputation), "difficulty":str(options.get("difficulty", "Normal")), "starting_tier":starting_tier, "board_expectation":str(tier_profile.expectation),
		"career_type":str(options.get("career_type", "normal")), "team_mode":career_mode, "career_overrides":{}, "content_lock":options.get("content_lock", []).duplicate(true),
		"created_at":Time.get_datetime_string_from_system(), "last_saved_at":"", "playtime_seconds":0,
		"current_date": SEASON_START_DATE, "calendar_month_offset": 0,
		"morale": 72, "chemistry": 61, "training_focus": "Cân bằng", "schedule": "Cân bằng",
		"weekly_training_plan":["Aim Training","Strategy Review","Scrim Preparation","Recovery","Team Chemistry","VOD Review","Rest"], "individual_training":{},
		"tactics": {"early": "Rotate sớm", "mid": "Kiểm soát trung tâm", "late": "Fight for zone"},
		"coach_plan": {"drop_policy":"ADAPTIVE", "zone_macro":"CENTER", "formation":"TWO_TWO", "engagement":"SELECTIVE", "positioning":"CENTER_HOLD", "spacing":"NORMAL", "flank":"NONE", "focus_fire":"FOCUS", "target_priority":"LOWEST_HP", "combat_range":"ADAPTIVE", "information":"INFO_FIRST", "resource":"MINIMAL"}, "map_tactics":{}, "match_decisions":{"EARLY":"ROTATE","MID":"HOLD","END":"FIGHT"},
		"facilities": {"Training Room": 1, "Analytics Lab": 1, "Medical Room": 1, "Streaming Room": 1}, "facility_projects": [],
		"roster": roster, "market": market, "teams": teams, "inbox": [], "history": [], "last_match": {}, "match_replays": [], "tournament_results": {}, "previous_team_power": 0, "ranking_trend": 0,
		"days_elapsed":0, "progression_log":[], "season_history":[], "season_transition":{}, "season_start_budget":int(tier_profile.budget), "next_record_sequence":1,
		"loaned_players":[], "loan_records":[], "inbound_offers":[], "transferred_out_players":[], "media_stories":[],
		"scrim_requests":initial_scrims, "scrim_history":[], "tactical_familiarity":0,
		"tournament_registrations":{"gsi_2026_s1":{"status":"REGISTERED","registered_at":SEASON_START_DATE}},
		"sponsors": game_database.career_content.get("sponsors", []), "active_sponsor_id": "", "sponsor_status":{"progress":0,"state":"HEALTHY","last_review_week":1}, "finance_ledger": [{"id":"finance:opening","week":1,"type":"opening","label":"Opening budget","amount":int(tier_profile.budget)}],
		"staff":[{"id":"head_coach","name":"Head Coach","role":"Head Coach","rating":62,"salary":4200,"contract":24,"effect":"+6 percentage points to weekly growth chance"},{"id":"analyst","name":"Match Analyst","role":"Analyst","rating":60,"salary":3600,"contract":24,"effect":"Produces post-match telemetry reports"},{"id":"scout","name":"Lead Scout","role":"Scout","rating":58,"salary":3200,"contract":24,"effect":"+6 scout confidence per scouting update"},{"id":"mental_coach","name":"Mental Coach","role":"Mental Coach","rating":57,"salary":3000,"contract":24,"effect":"+5 weekly player happiness"}], "transfer_offers":[],
		"developer_mode":false, "simulation_overrides":{}, "telemetry":[], "meta_state":{"version":1,"weapon_usage":{},"weapon_performance":{},"tiers":{},"patch_history":[]},
		"event_history":[], "pending_events":[], "player_memories":{}, "role_promises":[], "relationships":{}, "organization_dna":{"development":50,"discipline":50,"ambition":50,"community":50}, "coach_philosophy":"Balanced", "board_confidence":65, "investor_confidence":60, "fan_sentiment":65, "crisis_week":false, "rivalries":{},
		"management_context":"CLUB", "national_team_id":"", "national_roster_ids":[], "national_tactics":{"drop_policy":"ADAPTIVE","zone_macro":"CENTER","engagement":"SELECTIVE"}, "national_camp":{"active":false,"weeks":0},
		"next_player_id": 100, "database_version": str(game_database.manifest.get("database_version", "legacy")),
		"active_tournament_id": str(game_database.manifest.get("active_tournament_id", "")),
		"active_tournament_name": str(game_database.get_active_tournament().get("name", "Global Survival Invitational")),
		"active_tournament_logo_asset_id": str(game_database.get_active_tournament().get("logo_asset_id", "")),
		"active_tournament_prize_pool": int(game_database.get_active_tournament().get("prize_pool", 0)),
		"active_tournament_team_count": int(game_database.get_active_tournament().get("team_count", 16)),
		"active_tournament_player_count": int(game_database.get_active_tournament().get("player_count", 64)),
		"tournaments": [], "competitions": [], "facility_definitions": game_database.career_content.get("facilities", {}), "calendar_events": []
	}
	data.tournaments = _tournament_catalog()
	data.competitions = data.tournaments
	data.calendar_events = _build_season_calendar(SEASON_START_DATE)
	data.calendar_events.append({"id":"training-day-1","date":SEASON_START_DATE,"time":"10:00","priority":50,"requires_player_action":true,"completed":false,"status":"scheduled","type":"training","tournament":"TEAM TRAINING","round":"Training session"})
	if not initial_scrims.is_empty(): data.calendar_events.append({"id":str(initial_scrims[0].id),"date":str(initial_scrims[0].date),"time":str(initial_scrims[0].time),"priority":60,"requires_player_action":true,"completed":false,"status":"scheduled","type":"scrim","tournament":str(initial_scrims[0].cluster_name),"round":"Cluster session"})
	data.calendar_events.sort_custom(func(a,b): return str(a.get("date",""))+str(a.get("time","")) < str(b.get("date",""))+str(b.get("time","")))
	_ensure_personality_and_relationships()
	_ensure_media_story()
	if career_mode == "replace": data.career_overrides[selected_team_id] = {"replacement_team_id":"career:%s" % data.career_id, "name":resolved_name, "logo_asset_id":resolved_logo}
	_add_news("Welcome to %s" % org_name, "The board expects a top-eight finish in your first season.")
	_add_news("The new season begins", "Balance training, morale and finances before matchday.")
	save_game()

func _player_from_database(source:Dictionary, owned:bool) -> Dictionary:
	var ratings:Dictionary = source.get("ratings", {})
	var combat:Dictionary = source.get("combat", {})
	var awareness:Dictionary = source.get("awareness", {})
	var teamplay:Dictionary = source.get("teamplay", {})
	var macro:Dictionary = source.get("macro", {})
	var physical:Dictionary = source.get("physical", {})
	var contract:Dictionary = source.get("contract", {})
	var career:Dictionary = source.get("career", {})
	var player := {
		"id":str(source.get("id", "")), "team_id":str(source.get("team_id", "")), "current_team_name":str(source.get("current_team_name", "Free Agent")), "handle":str(source.get("handle", "player")), "name":str(source.get("display_name", source.get("handle", "Player"))), "avatar_asset_id":str(source.get("avatar_asset_id", "player.avatar.fallback")),
		"age":int(source.get("age", 18)), "region":str(source.get("nationality", "Unknown")), "role":str(source.get("role", "Flex")), "secondary_role":str(source.get("secondary_role", "Flex")), "status":str(source.get("status", "active")),
		"overall":int(ratings.get("overall", 60)), "potential":int(ratings.get("potential", 65)), "form":int(ratings.get("form", 60)), "energy":int(ratings.get("energy", 75)), "morale":int(ratings.get("morale", 65)),
		"aim":int(combat.get("aim", 60)), "clutch":int(combat.get("clutch", 60)), "game_sense":int(awareness.get("game_sense", 60)), "vision":int(awareness.get("vision", 60)), "hearing":int(awareness.get("hearing", 60)), "reaction":int(awareness.get("reaction", 60)),
		"teamwork":int(teamplay.get("teamwork", 60)), "communication":int(teamplay.get("communication", 60)), "leadership":int(teamplay.get("leadership", 60)), "discipline":int(teamplay.get("discipline", 60)), "composure":int(teamplay.get("composure", 60)),
		"stealth":int(source.get("stealth", {}).get("concealment", 60)), "utility":int(combat.get("utility_timing", 60)), "driving":int(macro.get("driving", 60)), "zone_reading":int(macro.get("zone_reading", 60)), "loot_efficiency":int(macro.get("loot_efficiency", 60)), "adaptability":int(macro.get("risk_assessment", 60)),
		"fatigue_resistance":int(physical.get("fatigue_resistance", 60)), "salary":int(contract.get("monthly_salary", 0)), "value":int(contract.get("market_value", 0)), "contract":int(contract.get("months_remaining", 0)), "release_clause":int(contract.get("release_clause", 0)),
		"career":career.duplicate(true), "preferred":source.get("preferred", {}).duplicate(true), "team_history":source.get("team_history", []).duplicate(true), "latest_stats":source.get("latest_stats", {}).duplicate(true), "latest_tournament":str(source.get("latest_tournament", "")), "source_url":str(source.get("source_url", "")), "owned":owned, "scouted":owned, "confidence":100 if owned else 25 + absi(str(source.get("id", "")).hash()) % 51,
		"happiness":int(ratings.get("morale", 65)), "squad_role":"starter" if owned else "transfer_target", "trait":"Professional"
	}
	_ensure_player_personality(player)
	return player

func _ensure_player_personality(player: Dictionary) -> void:
	var identity := str(player.get("id", player.get("handle", "player")))
	var noise := func(salt: String) -> int: return absi((identity + salt).hash()) % 13 - 6
	var traits: Dictionary = player.get("personality_traits", {})
	if traits.is_empty():
		traits = {
			"aggressive":clampi(roundi((int(player.get("aim",60)) + int(player.get("clutch",60)) + int(player.get("adaptability",60))) / 3.0) + noise.call("aggressive"), 25, 90),
			"tactical":clampi(roundi((int(player.get("game_sense",60)) + int(player.get("zone_reading",60)) + int(player.get("leadership",60))) / 3.0) + noise.call("tactical"), 25, 90),
			"big_game":clampi(roundi((int(player.get("clutch",60)) + int(player.get("composure",60)) + int(player.get("form",60))) / 3.0) + noise.call("big_game"), 25, 90)
		}
	player.personality_traits = traits
	var primary := "Aggressive" if int(traits.get("aggressive",0)) >= int(traits.get("tactical",0)) and int(traits.get("aggressive",0)) >= int(traits.get("big_game",0)) else "Tactical" if int(traits.get("tactical",0)) >= int(traits.get("big_game",0)) else "Big Game Player"
	player.trait = primary

func _relationship_key(player_a: String, player_b: String) -> String:
	return player_a + "|" + player_b if player_a < player_b else player_b + "|" + player_a

func _relationship_type(value: int) -> String:
	return "Friend" if value >= 35 else "Rival" if value <= -25 and value > -55 else "Conflict" if value <= -55 else "Neutral"

func _ensure_personality_and_relationships() -> void:
	for player in data.get("roster", []) + data.get("market", []): _ensure_player_personality(player)
	var graph: Dictionary = data.get("relationships", {})
	var roster: Array = data.get("roster", [])
	for first in roster.size():
		for second in range(first + 1, roster.size()):
			var a: Dictionary = roster[first]; var b: Dictionary = roster[second]; var key := _relationship_key(str(a.id), str(b.id))
			if graph.has(key): continue
			var compatibility := roundi((int(a.get("teamwork",60)) + int(a.get("communication",60)) + int(b.get("teamwork",60)) + int(b.get("communication",60))) / 4.0) - 50
			var variance := absi(key.hash()) % 21 - 10
			var value := clampi(compatibility + variance, -30, 45)
			graph[key] = {"player_a":str(a.id),"player_b":str(b.id),"value":value,"type":_relationship_type(value),"updated_week":int(data.get("week",1))}
	data.relationships = graph

func get_player_relationships(player_id: String) -> Array:
	var result: Array = []
	for record in data.get("relationships", {}).values():
		if str(record.get("player_a", "")) != player_id and str(record.get("player_b", "")) != player_id: continue
		var teammate_id := str(record.get("player_b", "")) if str(record.get("player_a", "")) == player_id else str(record.get("player_a", ""))
		var teammate: Dictionary = data.get("roster", []).filter(func(player): return str(player.get("id", "")) == teammate_id)[0] if data.get("roster", []).any(func(player): return str(player.get("id", "")) == teammate_id) else {}
		result.append({"player_id":teammate_id,"name":str(teammate.get("name","Former teammate")),"value":int(record.get("value",0)),"type":str(record.get("type","Neutral")),"updated_week":int(record.get("updated_week",1))})
	result.sort_custom(func(a,b): return int(a.get("value",0)) > int(b.get("value",0)))
	return result

func adjust_relationship(player_a: String, player_b: String, delta: int, memory := "") -> Dictionary:
	if player_a == player_b: return {"ok":false,"error":"A player cannot have a relationship with themselves."}
	var key := _relationship_key(player_a, player_b); var graph: Dictionary = data.get("relationships", {})
	if not graph.has(key): graph[key] = {"player_a":player_a,"player_b":player_b,"value":0,"type":"Neutral","updated_week":int(data.get("week",1))}
	var record: Dictionary = graph[key]; record.value = clampi(int(record.get("value",0)) + delta, -100, 100); record.type = _relationship_type(int(record.value)); record.updated_week = int(data.get("week",1)); graph[key] = record; data.relationships = graph
	if not memory.is_empty(): data.player_memories[key] = {"week":int(data.get("week",1)),"note":memory,"delta":delta}
	var chemistry_delta := signi(delta) if abs(delta) >= 6 else 0; data.chemistry = clampi(int(data.get("chemistry",60)) + chemistry_delta, 20, 95)
	return {"ok":true,"record":record.duplicate(true)}

func player_profile_from_database(player_id: String) -> Dictionary:
	var database = DATABASE_SCRIPT.new()
	var errors: PackedStringArray = database.load_all()
	if not errors.is_empty(): return {}
	var source: Dictionary = database.get_player(player_id)
	return _player_from_database(source, false) if not source.is_empty() else {}

func scouting_pool(query := "", role := "") -> Array:
	var database = DATABASE_SCRIPT.new(); var errors: PackedStringArray = database.load_all()
	if not errors.is_empty(): return []
	var result: Array = []
	for source in database.search_players(query, "", "" if role in ["", "ALL", "U23", "HIGH POTENTIAL"] else role.capitalize()):
		var player := _player_from_database(source, false)
		if role == "U23" and int(player.get("age", 99)) >= 23: continue
		if role == "HIGH POTENTIAL" and int(player.get("potential", 0)) < 78: continue
		result.append(player)
	return result

func eligible_national_players(national_team_id: String) -> Array:
	var database = DATABASE_SCRIPT.new(); var errors: PackedStringArray = database.load_all()
	if not errors.is_empty(): return []
	var national_team: Dictionary = database.get_team(national_team_id)
	if national_team.is_empty() or str(national_team.get("team_type", "")) != "NATIONAL": return []
	var nationality_key := _nationality_key(str(national_team.get("name", "")))
	var result: Array = []
	for source in database.players:
		if _nationality_key(str(source.get("nationality", ""))) != nationality_key: continue
		var profile := _player_from_database(source, false); profile.called_up = str(profile.id) in data.get("national_roster_ids", []); result.append(profile)
	return result

func select_national_team(team_id: String) -> Dictionary:
	var database = DATABASE_SCRIPT.new(); var errors: PackedStringArray = database.load_all(); var team: Dictionary = database.get_team(team_id)
	if not errors.is_empty() or team.is_empty() or str(team.get("team_type", "")) != "NATIONAL": return {"ok":false,"error":"National team is invalid"}
	data.national_team_id = team_id; data.management_context = "NATIONAL"; save_game(); return {"ok":true,"team_id":team_id}

func set_management_context(context: String) -> Dictionary:
	if context == "NATIONAL" and str(data.get("national_team_id", "")).is_empty(): return {"ok":false,"error":"Select a national team first"}
	if not context in ["CLUB","NATIONAL"]: return {"ok":false,"error":"Invalid management context"}
	data.management_context = context; save_game(); return {"ok":true,"context":context}

func call_up_player(player_id: String) -> Dictionary:
	var eligible := eligible_national_players(str(data.get("national_team_id", "")))
	if not eligible.any(func(player): return str(player.id) == player_id): return {"ok":false,"error":"Player is not eligible for this national team"}
	var roster: Array = data.get("national_roster_ids", [])
	if player_id in roster: return {"ok":false,"error":"Player is already called up"}
	if roster.size() >= 6: return {"ok":false,"error":"National roster is full"}
	roster.append(player_id); data.national_roster_ids = roster; save_game(); return {"ok":true,"player_id":player_id}

func release_national_player(player_id: String) -> Dictionary:
	var roster: Array = data.get("national_roster_ids", [])
	if not player_id in roster: return {"ok":false,"error":"Player is not in national roster"}
	roster.erase(player_id); data.national_roster_ids = roster; save_game(); return {"ok":true,"player_id":player_id}

func _initial_scrim_requests(database, selected_team_id: String) -> Array:
	var participants: Array = []
	for team in database.teams:
		if str(team.get("id", "")) == selected_team_id or str(team.get("team_type", "CLUB")) != "CLUB" or team.get("roster_ids", []).size() < 4: continue
		participants.append({"team_id":str(team.id),"team_name":str(team.name),"logo_asset_id":str(team.get("logo_asset_id","")),"power":int(team.get("ranking",{}).get("power",50))})
		if participants.size() >= 15: break
	if participants.is_empty(): return []
	return [{"id":"scrim-cluster-a-w1","cluster_id":"A","cluster_name":"SCRIM CLUSTER A","participants":participants,"available_slots":maxi(0,16-participants.size()),"status":"pending","week":1,"date":_add_days(SEASON_START_DATE,2),"time":"15:00"}]

func accept_scrim(request_id: String, options: Dictionary = {}) -> Dictionary:
	var requests: Array = data.get("scrim_requests", []); var request: Dictionary = {}
	for candidate in requests:
		if str(candidate.get("id", "")) == request_id: request = candidate; break
	if request.is_empty() or str(request.get("status", "")) != "pending": return {"ok":false,"error":"Scrim request is unavailable"}
	var match_count := clampi(int(options.get("matches", 3)), 1, 7); var map_id := str(options.get("map", "verdant_reach")); var objective := str(options.get("objective", "TACTICAL_FAMILIARITY"))
	if not map_id in ["verdant_reach","sunscorch_basin"]: return {"ok":false,"error":"Unsupported scrim map"}
	if not objective in ["TACTICAL_FAMILIARITY","CHEMISTRY","PLAYER_FORM","OPPONENT_ANALYSIS"]: return {"ok":false,"error":"Unsupported tactical objective"}
	var seed_value := absi((request_id + str(data.get("week",1))).hash()); var placement := 1 + seed_value % maxi(2, int(data.get("active_tournament_team_count",16)))
	var chemistry_gain := 2 if objective == "CHEMISTRY" else 1; var familiarity_gain := mini(5, match_count + (2 if objective == "TACTICAL_FAMILIARITY" else 0))
	data.chemistry = clampi(int(data.get("chemistry",50)) + chemistry_gain, 0, 100); data.tactical_familiarity = clampi(int(data.get("tactical_familiarity",0)) + familiarity_gain, 0, 100)
	if objective == "PLAYER_FORM":
		for player in data.get("roster", []).slice(0,4): player.form = clampi(int(player.form) + 1, 0, 99); player.energy = clampi(int(player.energy) - match_count, 0, 100)
	var record := {"id":"scrim-%d" % Time.get_unix_time_from_system(),"cluster_id":str(request.get("cluster_id","A")),"cluster_name":str(request.get("cluster_name","SCRIM CLUSTER A")),"participants":request.get("participants",[]).duplicate(true),"week":int(data.get("week",1)),"matches":match_count,"map":map_id,"objective":objective,"placement":placement,"chemistry_gain":chemistry_gain,"familiarity_gain":familiarity_gain,"official_ranking_impact":0}
	data.scrim_history.push_front(record); requests.erase(request); data.scrim_requests = requests; acknowledge_calendar_event(request_id); save_game(); return {"ok":true,"result":record}

func reject_scrim(request_id: String) -> Dictionary:
	var requests: Array = data.get("scrim_requests", [])
	for request in requests:
		if str(request.get("id", "")) == request_id: requests.erase(request); data.scrim_requests = requests; acknowledge_calendar_event(request_id); save_game(); return {"ok":true,"request_id":request_id}
	return {"ok":false,"error":"Scrim request is unavailable"}

func _nationality_key(value: String) -> String:
	return value.to_upper().replace(" NATIONAL TEAM", "").replace(" (THE REPUBLIC OF)", "").replace("TÜRKIYE", "TURKIYE").strip_edges()

func sign_database_player(player_id: String) -> String:
	for player in data.get("roster", []):
		if str(player.get("id", "")) == player_id: return "Player is already in your roster."
	var profile := player_profile_from_database(player_id)
	if profile.is_empty(): return "Player not found in world database."
	data.market.append(profile)
	return sign_player(data.market.size() - 1)

func _make_player(overall: int, role: String, owned: bool) -> Dictionary:
	var potential := clampi(overall + randi_range(3, 18), 1, 99)
	var player_id := randi()
	while _generated_player_ids.has(str(player_id)): player_id = randi()
	var player_name := "%s %s" % [FIRST_NAMES.pick_random(), LAST_NAMES.pick_random()]
	while _generated_player_names.has(player_name): player_name = "%s %s" % [FIRST_NAMES.pick_random(), LAST_NAMES.pick_random()]
	var handle := "%s%04d" % [player_name.replace(" ", "").to_lower(), absi(player_id) % 10000]
	while _generated_player_handles.has(handle): handle = "%s%04d" % [player_name.replace(" ", "").to_lower(), randi_range(1000, 9999)]
	_generated_player_ids[str(player_id)] = true; _generated_player_names[player_name] = true; _generated_player_handles[handle] = true
	return {
		"id": player_id, "handle": handle, "name": player_name, "avatar_asset_id": "player.avatar.fallback",
		"age": randi_range(16, 28), "region": REGIONS.pick_random(), "role": role,
		"overall": overall, "potential": potential, "form": randi_range(60, 82),
		"energy": randi_range(74, 96), "morale": randi_range(65, 88),
		"aim": clampi(overall + randi_range(-8, 8), 35, 95), "game_sense": clampi(overall + randi_range(-8, 8), 35, 95),
		"teamwork": clampi(overall + randi_range(-10, 10), 35, 95), "clutch": clampi(overall + randi_range(-10, 10), 35, 95),
		"vision": clampi(overall + randi_range(-12, 10), 30, 95), "hearing": clampi(overall + randi_range(-12, 10), 30, 95),
		"reaction": clampi(overall + randi_range(-10, 10), 30, 95), "communication": clampi(overall + randi_range(-10, 10), 30, 95),
		"leadership": clampi(overall + randi_range(-15, 12), 25, 95), "discipline": clampi(overall + randi_range(-10, 12), 30, 95),
		"composure": clampi(overall + randi_range(-12, 10), 30, 95), "stealth": clampi(overall + randi_range(-10, 10), 30, 95),
		"utility": clampi(overall + randi_range(-12, 12), 30, 95), "driving": clampi(overall + randi_range(-15, 15), 25, 95),
		"zone_reading": clampi(overall + randi_range(-10, 12), 30, 95),
		"adaptability": randi_range(45, 92), "salary": overall * 115 + randi_range(500, 2400),
		"value": overall * overall * 115, "contract": randi_range(12, 36) if owned else 0,
		"scouted": owned, "confidence": 100 if owned else randi_range(25, 68), "trait": ["Professional", "Ambitious", "Loyal", "Temperamental", "Media Darling", "Streamer Soul"].pick_random()
	}

func actionable_events(date := "") -> Array:
	var target_date := str(data.get("current_date", SEASON_START_DATE)) if date.is_empty() else date
	var events: Array = data.get("calendar_events", []).filter(func(event): return str(event.get("date", "")) == target_date and str(event.get("status", "scheduled")) != "completed" and bool(event.get("requires_player_action", false)))
	for pending in data.get("pending_events", []):
		if not bool(pending.get("blocks_progression", true)): continue
		if str(pending.get("date", target_date)) == target_date and not bool(pending.get("completed", false)): events.append(pending)
	events.sort_custom(func(a, b): return int(a.get("priority", 0)) > int(b.get("priority", 0)) if int(a.get("priority", 0)) != int(b.get("priority", 0)) else str(a.get("time", "00:00")) < str(b.get("time", "00:00")))
	return events

func acknowledge_calendar_event(event_id: String) -> Dictionary:
	for event in data.get("calendar_events", []):
		if str(event.get("id", "")) != event_id: continue
		event.completed = true; event.status = "completed"; save_game()
		return {"ok":true,"event":event.duplicate(true)}
	return {"ok":false,"error":"Calendar event does not exist."}

func advance_day() -> Dictionary:
	var unresolved := actionable_events()
	if not unresolved.is_empty(): return {"ok":false,"stopped":true,"date":str(data.get("current_date",SEASON_START_DATE)),"events":unresolved,"reason":"PLAYER_ACTION_REQUIRED"}
	var target_date := _add_days(str(data.get("current_date", SEASON_START_DATE)), 1)
	data.current_date = target_date
	data.days_elapsed = int(data.get("days_elapsed", 0)) + 1
	var weekly_update := int(data.days_elapsed) > 0 and int(data.days_elapsed) % 7 == 0
	_process_facility_projects(target_date)
	_process_loan_returns(target_date)
	_expire_inbound_offers()
	var weekly_result: Dictionary = advance_week(false) if weekly_update else {}
	if not weekly_update: _record_progression("day", "Day advanced", "Career calendar advanced to %s." % target_date)
	save_game()
	var due := actionable_events(target_date)
	return {"ok":true,"stopped":not due.is_empty(),"date":target_date,"events":due,"reason":"PLAYER_ACTION_REQUIRED" if not due.is_empty() else "DAY_ADVANCED","weekly_update":weekly_update,"consequences":weekly_result.get("consequences", progression_summary(3))}

func advance_week(advance_calendar := true) -> Dictionary:
	var old_team_power := roundi(get_team_power())
	var old_budget := int(data.get("budget", 0))
	var old_energy := 0
	for player in data.get("roster", []): old_energy += int(player.get("energy", 0))
	if advance_calendar:
		data.current_date = _add_days(str(data.get("current_date", SEASON_START_DATE)), 7)
		data.days_elapsed = int(data.get("days_elapsed", 0)) + 7
		_process_facility_projects(str(data.current_date))
	data.week = int(data.week) + 1
	var payroll := 0
	var head_coach_bonus := 0.0
	var mental_bonus := 0
	for staff in data.get("staff", []):
		payroll += int(staff.get("salary", 0))
		if str(staff.get("id", "")) == "head_coach": head_coach_bonus = roundi(float(staff.get("rating", 50)) / 10.0) / 100.0
		if str(staff.get("id", "")) == "mental_coach": mental_bonus = maxi(1, roundi(float(staff.get("rating", 50)) / 12.0))
		if int(data.week) % 4 == 0: staff.contract = maxi(0, int(staff.get("contract", 0)) - 1)
	for loaned in data.get("loaned_players", []):
		var coverage := 0
		for record in data.get("loan_records", []):
			if str(record.get("player_id", "")) == str(loaned.get("id", "")) and str(record.get("status", "")) == "ACTIVE": coverage = int(record.get("salary_coverage", 0)); break
		payroll += roundi(int(loaned.get("salary", 0)) * (100 - coverage) / 100.0)
		if int(data.week) % 4 == 0: loaned.contract = maxi(0, int(loaned.get("contract", 0)) - 1)
	var expired_players:Array = []
	for p in data.roster:
		payroll += int(p.salary)
		var recovery_level := int(data.facilities.get("Medical Room", 1))
		var training_level := int(data.facilities.get("Training Room", 1))
		var fatigue_resistance := int(p.get("fatigue_resistance", 60))
		var energy_change := 7 + recovery_level * 2 if data.schedule == "Nghỉ & hồi phục" else (-8 + fatigue_resistance / 25 if data.schedule == "Cường độ cao" else 1 + recovery_level)
		p.energy = clampi(int(p.energy) + energy_change + randi_range(-1, 1), 15, 100)
		var growth_chance := (0.34 if data.schedule == "Cường độ cao" else 0.16) + float(training_level) * 0.04 + head_coach_bonus + float(difficulty_rules().training_chance)
		if randf() < growth_chance and int(p.overall) < int(p.potential) and int(p.energy) > 40:
			var focus_key := _training_stat_key(str(data.get("training_focus", "Cân bằng")), str(p.get("role", "Flex")))
			p[focus_key] = clampi(int(p.get(focus_key, p.overall)) + 1, 1, int(p.potential))
			var core_average := (int(p.aim) + int(p.game_sense) + int(p.teamwork) + int(p.clutch)) / 4
			p.overall = mini(int(p.potential), maxi(int(p.overall), roundi(core_average * 0.65 + int(p.overall) * 0.35)))
		p.form = clampi(int(p.form) + (2 if data.schedule == "Cường độ cao" and int(p.energy) > 55 else -1 if int(p.energy) < 35 else 0), 25, 99)
		var individual_focus := str(data.get("individual_training", {}).get(str(p.get("id", "")), ""))
		if not individual_focus.is_empty():
			var focus_stat: String = str({"Aim":"aim","Strategy":"game_sense","Mental":"clutch","Recovery":"energy","Teamwork":"teamwork"}.get(individual_focus,"aim"))
			p[focus_stat] = clampi(int(p.get(focus_stat, 50)) + 1, 1, 99); p.energy = clampi(int(p.energy) - (2 if individual_focus != "Recovery" else -mental_bonus), 15, 100)
		p.happiness = clampi(int(p.get("happiness", 60)) + roundi(float(mental_bonus) / 3.0), 0, 100)
		if int(data.week) % 4 == 0:
			p.contract = maxi(0, int(p.get("contract", 0)) - 1)
			if int(p.contract) == 0: expired_players.append(p)
	for expired in expired_players:
		if data.roster.size() <= 4: expired.contract = 1; _add_news("Contract decision: %s" % expired.name, "The club must resolve this renewal before next week.", "CONTRACT", "player_detail")
		else:
			expired.owned = false; expired.scouted = true; expired.confidence = 100; expired.squad_role = "free_agent"; data.market.append(expired); data.roster.erase(expired); _add_news("Contract expired: %s" % expired.name, "The player has entered free agency.", "CONTRACT", "transfer")
	data.previous_team_power = old_team_power
	data.ranking_trend = roundi(get_team_power()) - old_team_power
	for opponent in data.get("teams", []):
		var old_power := int(opponent.get("power", 50))
		var baseline := int(opponent.get("baseline_power", old_power))
		opponent.power = clampi(old_power + randi_range(-2, 2) + signi(baseline - old_power), 45, 95)
		opponent.trend = int(opponent.power) - old_power
		opponent.form = clampi(int(opponent.get("form", baseline)) + int(opponent.trend) * 3 + randi_range(-3, 3), 35, 99)
		opponent.fans = maxi(1000, int(opponent.get("fans", 10000 + baseline * 250)) + randi_range(-250, 600))
		opponent.reputation = clampi(int(opponent.get("reputation", baseline)) + signi(int(opponent.trend)), 20, 99)
		opponent.budget = maxi(50000, int(opponent.get("budget", 400000 + baseline * 5000)) + randi_range(-18000, 26000))
	var streaming_level := int(data.facilities.get("Streaming Room", 1))
	var economy_scale := float(difficulty_rules().economy)
	var merchandise_income := roundi((6500 + int(data.get("fans", 0)) / 18) * economy_scale)
	var video_income := roundi((4200 + streaming_level * 1700 + int(data.get("reputation", 0)) * 55) * economy_scale)
	var streaming_income := roundi((7800 + streaming_level * 3100) * economy_scale)
	var commercial_income := merchandise_income + video_income + streaming_income
	var sponsor_income := 0
	for sponsor in data.get("sponsors", []):
		if str(sponsor.get("id", "")) == str(data.get("active_sponsor_id", "")): sponsor_income = int(sponsor.get("weekly_income", 0)); break
	var facility_upkeep := 0
	for facility_level in data.facilities.values(): facility_upkeep += int(facility_level) * 850
	var scouting_expense := 1800 + int(data.facilities.get("Scouting Department", 1)) * 900
	var travel_expense := 4500 if not get_next_match(true).is_empty() else 0
	data.budget += commercial_income + sponsor_income - payroll - facility_upkeep - scouting_expense - travel_expense
	_add_finance_entry("Merchandise", merchandise_income)
	_add_finance_entry("Video platforms", video_income)
	_add_finance_entry("Streaming", streaming_income)
	if sponsor_income > 0: _add_finance_entry("Sponsor activation", sponsor_income)
	_add_finance_entry("Player payroll", -payroll)
	_add_finance_entry("Facility upkeep", -facility_upkeep)
	_add_finance_entry("Scouting operations", -scouting_expense)
	if travel_expense > 0: _add_finance_entry("Competition travel", -travel_expense)
	if int(data.week) % 2 == 0:
		_scout_progress()
	generate_inbound_offers(false)
	if int(data.week) % 3 == 0:
		_maybe_queue_relationship_issue()
	if int(data.week) % 4 == 0:
		_random_event()
	_review_sponsor_objective()
	if int(data.week) > 12:
		_end_season()
	_ensure_media_story()
	_process_loan_returns(str(data.get("current_date", SEASON_START_DATE)))
	_expire_inbound_offers()
	var new_energy := 0
	for player in data.get("roster", []): new_energy += int(player.get("energy", 0))
	var energy_delta := roundi(float(new_energy - old_energy) / maxi(1, data.get("roster", []).size()))
	var net_change := int(data.get("budget", 0)) - old_budget
	_record_progression("week", "Weekly management processed", "Training, contracts and organization finance were processed.", {"energy_delta":energy_delta,"budget_delta":net_change,"team_power_delta":roundi(get_team_power())-old_team_power})
	save_game()
	return {"payroll": payroll, "income":commercial_income + sponsor_income, "expenses":payroll + facility_upkeep + scouting_expense + travel_expense,"consequences":progression_summary(3)}

func _review_sponsor_objective() -> void:
	if str(data.get("active_sponsor_id", "")).is_empty(): return
	var best := 16
	for match in data.get("history", []): best = mini(best, int(match.get("placement", 16)))
	var progress := clampi(100 - (best - 1) * 7, 0, 100)
	var state := "HEALTHY" if progress >= 55 else "WARNING" if progress >= 30 else "CRITICAL"
	data.sponsor_status = {"progress":progress,"state":state,"last_review_week":int(data.get("week",1))}
	if state != "HEALTHY" and not data.get("pending_events", []).any(func(event): return str(event.get("type", "")) == "sponsor_pressure"):
		data.pending_events.append({"id":"sponsor:%d" % int(data.get("week",1)),"type":"sponsor_pressure","status":"response_required","created_week":int(data.get("week",1)),"context":{"progress":progress,"state":state},"choices":[{"id":"improve_result","label":"Commit to improve results","effects":{"board_confidence":2,"morale":-1}},{"id":"reduce_spending","label":"Reduce operating spending","effects":{"budget":8000,"fan_sentiment":-2}},{"id":"renegotiate","label":"Renegotiate expectations","effects":{"board_confidence":-1,"fan_sentiment":1}}]})

func _training_stat_key(focus:String, role:String) -> String:
	var normalized := focus.to_lower()
	var mapping := {"aim":"aim","phản xạ":"reaction","reaction":"reaction","tầm nhìn":"vision","vision":"vision","giao tiếp":"communication","communication":"communication","đọc bo":"zone_reading","zone reading":"zone_reading","game sense":"game_sense","teamwork":"teamwork","clutch":"clutch"}
	if mapping.has(normalized): return str(mapping[normalized])
	return {"IGL":"game_sense","Entry":"reaction","Fragger":"aim","Support":"teamwork","Anchor":"zone_reading","Flex":"adaptability"}.get(role,"game_sense")

func apply_match_runtime_result(runtime_result: Dictionary, event: Dictionary = {}) -> Dictionary:
	if runtime_result.is_empty() or not runtime_result.has("scoreboard") or not runtime_result.has("player_stats"):
		return {"ok":false, "error":"Invalid match result payload"}
	var target_event := event.duplicate(true)
	if target_event.is_empty(): target_event = get_playable_match()
	if target_event.is_empty(): return {"ok":false, "error":"No playable calendar event"}
	var event_id := str(target_event.get("id", ""))
	var transaction_id := str(runtime_result.get("match_id", event_id))
	if str(data.get("last_match", {}).get("transaction_id", "")) == transaction_id:
		return {"ok":true, "duplicate":true, "event_id":event_id}
	var standings: Array = runtime_result.get("scoreboard", [])
	var players: Array = runtime_result.get("player_stats", [])
	if standings.is_empty() or players.is_empty(): return {"ok":false, "error":"Empty standings/player stats"}
	var lobby_size := standings.size()
	var committed := runtime_result.duplicate(true)
	committed.source = "match_runtime"; committed.transaction_id = transaction_id; committed.event_id = event_id
	committed.tournament = target_event.get("tournament", data.get("active_tournament_name", "")); committed.date = target_event.get("date", data.get("current_date", ""))
	var own_row: Dictionary = {}
	for row in standings:
		if str(row.get("tag", "")) == "MR" or str(row.get("name", "")) == str(data.get("org_name", "")): own_row = row; break
	var previous_data := data.duplicate(true)
	var next_data := data.duplicate(true)
	next_data.last_match = committed
	var tournament_results: Dictionary = next_data.get("tournament_results", {})
	var tournament_id := str(target_event.get("tournament_id", ""))
	var results_for_tournament: Array = tournament_results.get(tournament_id, [])
	results_for_tournament.append({"event_id":event_id, "scoreboard":standings.duplicate(true)})
	tournament_results[tournament_id] = results_for_tournament
	next_data.tournament_results = tournament_results
	var history: Array = next_data.get("history", [])
	history.push_front({"event_id":event_id,"season":int(next_data.get("season",1)),"tournament_id":tournament_id,"tournament":committed.tournament,"date":committed.date,"placement":int(committed.get("placement", own_row.get("rank", lobby_size))),"kills":int(committed.get("kills", 0)),"points":int(own_row.get("points", 0)),"prize":int(own_row.get("points",0))*5000,"source":"match_runtime"})
	if history.size() > 30: history.resize(30)
	next_data.history = history
	var events: Array = next_data.get("calendar_events", [])
	for item in events:
		if str(item.get("id", "")) == event_id:
			item.status = "completed"; item.result = {"placement":int(committed.get("placement", lobby_size)),"kills":int(committed.get("kills", 0)),"points":int(own_row.get("points", 0)),"transaction_id":transaction_id}
	next_data.calendar_events = events
	var placement := int(committed.get("placement", own_row.get("rank", lobby_size)))
	var points := int(own_row.get("points", 0))
	var prize_income := points * 5000
	next_data.budget = int(next_data.get("budget", 0)) + prize_income
	next_data.fans = maxi(0, int(next_data.get("fans", 0)) + maxi(100, points * 120))
	next_data.reputation = clampi(int(next_data.get("reputation", 0)) + (3 if placement <= 3 else 1 if placement <= 8 else -1), 0, 100)
	next_data.morale = clampi(int(next_data.get("morale", 50)) + (5 if placement <= 4 else -2), 0, 100)
	var ledger:Array = next_data.get("finance_ledger", [])
	ledger.push_front({"week":int(next_data.get("week", 1)),"type":"income","label":"Match prize • %s" % str(committed.tournament),"amount":prize_income,"transaction_id":transaction_id})
	if ledger.size() > 24: ledger.resize(24)
	next_data.finance_ledger = ledger
	var own_player_stats:Array = players.filter(func(stat): return str(stat.get("team", "")) == "MR")
	var mvp:Dictionary = {}
	for stat in own_player_stats:
		var player_id := str(stat.get("player_id", ""))
		for player in next_data.get("roster", []):
			if str(player.get("id", "")) != player_id: continue
			var career:Dictionary = player.get("career", {})
			career.matches = int(career.get("matches", 0)) + 1
			career.kills = int(career.get("kills", 0)) + int(stat.get("kills", 0))
			career.damage = int(career.get("damage", 0)) + int(stat.get("damage", 0))
			career.revives = int(career.get("revives", 0)) + int(stat.get("revives", 0))
			career.earnings = int(career.get("earnings", 0)) + roundi(float(prize_income) / maxi(1, own_player_stats.size()))
			if placement == 1: career.titles = int(career.get("titles", 0)) + 1
			career.shots = int(career.get("shots", 0)) + int(stat.get("shots", 0))
			career.hits = int(career.get("hits", 0)) + int(stat.get("hits", 0))
			player.career = career
			player.form = clampi(int(player.get("form", 60)) + int(stat.get("kills", 0)) * 2 + (2 if bool(stat.get("survived", false)) else -2), 25, 99)
			player.energy = clampi(int(player.get("energy", 75)) - 8 - int(stat.get("damage", 0)) / 250, 5, 100)
			player.morale = clampi(int(player.get("morale", 60)) + (4 if placement <= 4 else -2), 10, 100)
		var mvp_score := int(stat.get("kills", 0)) * 300 + int(stat.get("damage", 0)) + int(stat.get("revives", 0)) * 120 + (150 if bool(stat.get("survived", false)) else 0)
		if mvp.is_empty() or mvp_score > int(mvp.get("score", -1)): mvp = {"player_id":player_id,"name":str(stat.get("name", "")),"score":mvp_score,"kills":int(stat.get("kills", 0)),"damage":int(stat.get("damage", 0))}
	committed.mvp = mvp
	next_data.last_match = committed
	var replays:Array = next_data.get("match_replays", [])
	replays.push_front(committed.duplicate(true))
	if replays.size() > 12: replays.resize(12)
	next_data.match_replays = replays
	var inbox:Array = next_data.get("inbox", [])
	inbox.push_front({"id":"MATCH-%s" % transaction_id,"title":"Result: placement #%d" % placement,"body":"The squad scored %d kills and %d points. MVP: %s." % [int(committed.get("kills", 0)),points,str(mvp.get("name", "—"))],"week":int(next_data.get("week", 1)),"category":"COMPETITION","action_page":"tournament","read":false})
	if inbox.size() > 10: inbox.resize(10)
	next_data.inbox = inbox
	var telemetry_record := {"match_id":transaction_id,"date":committed.date,"map":str(committed.get("map", target_event.get("map", ""))),"placement":placement,"kills":int(committed.get("kills", 0)),"points":points,"player_stats":own_player_stats.duplicate(true),"weapon_stats":committed.get("weapon_stats", {}).duplicate(true),"zone_events":committed.get("zone_events", []).duplicate(true),"decisions":committed.get("decisions", []).duplicate(true)}
	var telemetry:Array = next_data.get("telemetry", []); telemetry.push_front(telemetry_record); if telemetry.size() > 100: telemetry.resize(100); next_data.telemetry = telemetry
	var sentiment_delta := 5 if placement <= 3 else 2 if placement <= 8 else -5
	next_data.fan_sentiment = clampi(int(next_data.get("fan_sentiment", 65)) + sentiment_delta, 0, 100)
	next_data.board_confidence = clampi(int(next_data.get("board_confidence", 65)) + (3 if placement <= 4 else -3 if placement > 12 else 0), 0, 100)
	next_data.investor_confidence = clampi(int(next_data.get("investor_confidence", 60)) + (2 if points >= 8 else -1), 0, 100)
	var event_type := "victory_interview" if placement == 1 else "defeat_interview" if placement > 10 else "post_match_interview"
	var pending:Array = next_data.get("pending_events", [])
	pending.append({"id":"%s:%s" % [event_type, transaction_id],"type":event_type,"status":"response_required","created_week":int(next_data.get("week", 1)),"context":{"match_id":transaction_id,"placement":placement,"kills":int(committed.get("kills", 0)),"mvp":mvp.duplicate(true)},"choices":[{"id":"protect_players","label":"Protect the players","effects":{"morale":4,"board_confidence":-2,"fan_sentiment":1}},{"id":"demand_more","label":"Demand improvement","effects":{"morale":-4,"board_confidence":3,"discipline":3}},{"id":"stay_measured","label":"Stay measured","effects":{"morale":1,"board_confidence":1,"fan_sentiment":1}}]})
	next_data.pending_events = pending
	data = next_data
	_record_progression("match", "Match result committed", "Placement #%d • %d kills • %d points." % [placement, int(committed.get("kills",0)), points], {"placement":placement,"kills":int(committed.get("kills",0)),"points":points,"prize":prize_income})
	if not save_game():
		data = previous_data
		return {"ok":false,"error":"Failed to save match result transaction; changes rolled back"}
	return {"ok":true, "duplicate":false, "event_id":event_id, "transaction_id":transaction_id}

func set_developer_mode(enabled: bool) -> void:
	data.developer_mode = enabled
	if not enabled: data.simulation_overrides = {}
	save_game()

func set_simulation_override(key: String, value: Variant) -> Dictionary:
	if not bool(data.get("developer_mode", false)) or str(data.get("career_type", "normal")) != "sandbox": return {"ok":false,"error":"Simulation overrides require a Sandbox career with Developer Mode enabled."}
	var allowed := ["weapon_damage_scale","loot_density_scale","zone_damage_scale","ai_aggression_scale","vehicle_density_scale"]
	if not key in allowed: return {"ok":false,"error":"Unsupported simulation override."}
	data.simulation_overrides[key] = clampf(float(value), 0.25, 4.0)
	save_game(); return {"ok":true,"key":key,"value":data.simulation_overrides[key]}

func reset_simulation_overrides() -> void:
	data.simulation_overrides = {}; save_game()

func analyze_meta() -> Dictionary:
	var weapon_usage: Dictionary = {}; var weapon_performance: Dictionary = {}
	for match_record in data.get("telemetry", []):
		for weapon in match_record.get("weapon_stats", {}):
			var stats: Dictionary = match_record.weapon_stats[weapon]
			weapon_usage[weapon] = int(weapon_usage.get(weapon, 0)) + int(stats.get("shots", stats.get("uses", 0)))
			weapon_performance[weapon] = int(weapon_performance.get(weapon, 0)) + int(stats.get("kills", 0)) * 100 + int(stats.get("damage", 0))
	var tiers: Dictionary = {}
	var ordered:Array = weapon_performance.keys(); ordered.sort_custom(func(a,b): return int(weapon_performance[a]) > int(weapon_performance[b]))
	for index in ordered.size(): tiers[ordered[index]] = "S" if index < maxi(1, ordered.size()/10) else "A" if index < ordered.size()*35/100 else "B" if index < ordered.size()*70/100 else "C"
	data.meta_state.weapon_usage = weapon_usage; data.meta_state.weapon_performance = weapon_performance; data.meta_state.tiers = tiers; data.meta_state.last_analyzed_week = int(data.get("week",1)); save_game()
	return data.meta_state.duplicate(true)

func apply_meta_patch(changes: Dictionary, note := "Manual balance patch") -> Dictionary:
	if not bool(data.get("developer_mode", false)) or str(data.get("career_type", "normal")) != "sandbox": return {"ok":false,"error":"Meta patches require Sandbox Developer Mode."}
	var normalized: Dictionary = {}
	for key in changes:
		var value := clampf(float(changes[key]), 0.5, 1.5); normalized[str(key)] = value
	var patch := {"id":"patch-%d" % Time.get_unix_time_from_system(),"week":int(data.get("week",1)),"changes":normalized,"note":note}
	data.meta_state.patch_history.append(patch); data.simulation_overrides["weapon_modifiers"] = normalized; save_game(); return {"ok":true,"patch":patch}

func resolve_event(event_id: String, choice_id: String) -> Dictionary:
	for event in data.get("pending_events", []):
		if str(event.get("id", "")) != event_id: continue
		for choice in event.get("choices", []):
			if str(choice.get("id", "")) != choice_id: continue
			var effects: Dictionary = choice.get("effects", {})
			for key in effects:
				if key == "transfer_offer":
					var transfer_result := resolve_transfer_offer(str(effects[key].get("id", "")), str(effects[key].get("action", "reject")))
					if not bool(transfer_result.get("ok", false)): return transfer_result
				elif key == "inbound_offer":
					var inbound_result := resolve_inbound_offer(str(effects[key].get("id", "")), str(effects[key].get("action", "reject")))
					if not bool(inbound_result.get("ok", false)): return inbound_result
				elif key == "relationships":
					for relationship_effect in effects[key]: adjust_relationship(str(relationship_effect.get("player_a","")), str(relationship_effect.get("player_b","")), int(relationship_effect.get("delta",0)), str(relationship_effect.get("memory","")))
				elif key == "player_happiness":
					for player_id in effects[key]:
						for player in data.get("roster", []):
							if str(player.get("id", "")) == str(player_id): player.happiness = clampi(int(player.get("happiness",60)) + int(effects[key][player_id]), 0, 100); player.morale = clampi(int(player.get("morale",60)) + int(effects[key][player_id]), 0, 100)
				elif key == "discipline": data.organization_dna.discipline = clampi(int(data.organization_dna.get("discipline",50)) + int(effects[key]),0,100)
				elif data.has(key): data[key] = clampi(int(data.get(key, 0)) + int(effects[key]), 0, 100)
			event.status = "resolved"; event.selected_choice = choice_id; event.resolved_week = int(data.get("week",1)); event.applied_effects = effects.duplicate(true)
			data.event_history.push_front(event.duplicate(true)); data.pending_events.erase(event); save_game(); return {"ok":true,"effects":effects}
		return {"ok":false,"error":"Choice does not exist."}
	return {"ok":false,"error":"Event does not exist."}

func queue_relationship_conflict(player_a: String, player_b: String, topic := "drop strategy") -> Dictionary:
	var relationship := adjust_relationship(player_a, player_b, -8, "Disagreed about %s" % topic)
	if not bool(relationship.get("ok", false)): return relationship
	var roster: Array = data.get("roster", [])
	var a: Dictionary = roster.filter(func(player): return str(player.get("id", "")) == player_a)[0] if roster.any(func(player): return str(player.get("id", "")) == player_a) else {}
	var b: Dictionary = roster.filter(func(player): return str(player.get("id", "")) == player_b)[0] if roster.any(func(player): return str(player.get("id", "")) == player_b) else {}
	if a.is_empty() or b.is_empty(): return {"ok":false,"error":"Both players must be in the active roster."}
	var event_id := "relationship:%s:%s:%d" % [player_a, player_b, int(data.get("week",1))]
	if data.get("pending_events", []).any(func(event): return str(event.get("id", "")) == event_id): return {"ok":true,"duplicate":true}
	var happiness_a := {}; happiness_a[player_a] = 5; happiness_a[player_b] = -2
	var happiness_b := {}; happiness_b[player_a] = -2; happiness_b[player_b] = 5
	var happiness_meeting := {}; happiness_meeting[player_a] = 2; happiness_meeting[player_b] = 2
	data.pending_events.append({"id":event_id,"type":"relationship_conflict","status":"response_required","created_week":int(data.get("week",1)),"deadline_week":int(data.get("week",1))+1,"context":{"player_a":player_a,"player_b":player_b,"topic":topic},"choices":[{"id":"support_a","label":"Support %s" % str(a.name),"effects":{"player_happiness":happiness_a,"relationships":[{"player_a":player_a,"player_b":player_b,"delta":-6,"memory":"Management backed %s" % str(a.name)}]}},{"id":"support_b","label":"Support %s" % str(b.name),"effects":{"player_happiness":happiness_b,"relationships":[{"player_a":player_a,"player_b":player_b,"delta":-6,"memory":"Management backed %s" % str(b.name)}]}},{"id":"hold_meeting","label":"Hold a tactical meeting","effects":{"player_happiness":happiness_meeting,"relationships":[{"player_a":player_a,"player_b":player_b,"delta":10,"memory":"Resolved disagreement through a tactical meeting"}]}}]})
	return {"ok":true,"event_id":event_id}

func create_custom_player(fields: Dictionary) -> Dictionary:
	if data.is_empty(): return {"ok":false,"error":"No active career."}
	var name := str(fields.get("name", "")).strip_edges(); var handle := str(fields.get("handle", "")).strip_edges()
	if name.length() < 2 or handle.length() < 2: return {"ok":false,"error":"Player name and nickname are required."}
	for player in data.get("roster", []) + data.get("market", []):
		if str(player.get("handle", "")).to_lower() == handle.to_lower(): return {"ok":false,"error":"Player nickname must be unique."}
	var overall := clampi(int(fields.get("overall", 55)), 35, 85)
	var player := _make_player(overall, str(fields.get("role", "Flex")), true)
	player.id = "career:%s:player:%d" % [str(data.get("career_id", "custom")), int(data.get("next_player_id", 100))]
	data.next_player_id = int(data.get("next_player_id", 100)) + 1; player.name = name; player.handle = handle; player.region = str(fields.get("nationality", data.get("region", "Unknown"))); player.avatar_asset_id = str(fields.get("avatar_asset_id", "player.avatar.fallback")); player.personality = str(fields.get("personality", "Professional")); player.team_id = str(data.get("organization_id", "")); player.squad_role = "substitute" if data.roster.size() >= 4 else "starter"
	_ensure_player_personality(player); data.roster.append(player); _ensure_personality_and_relationships(); save_game(); return {"ok":true,"player":player.duplicate(true)}

func set_custom_team_identity(name: String, short_name: String, logo_asset_id := "") -> Dictionary:
	if str(data.get("team_mode", "existing")) == "existing": return {"ok":false,"error":"Official team identity is read-only in this career."}
	var clean_name := name.strip_edges(); var clean_short := short_name.strip_edges().to_upper()
	if clean_name.length() < 2 or clean_short.length() < 2 or clean_short.length() > 5: return {"ok":false,"error":"Team name and a 2–5 character short name are required."}
	data.org_name = clean_name; data.org_short_name = clean_short
	if not logo_asset_id.is_empty(): data.org_logo_asset_id = logo_asset_id
	var source_id := str(data.get("organization_id", ""))
	if str(data.get("team_mode", "")) == "replace": data.career_overrides[source_id] = {"replacement_team_id":"career:%s" % str(data.career_id),"name":clean_name,"tag":clean_short,"logo_asset_id":str(data.org_logo_asset_id)}
	save_game(); return {"ok":true}

func set_player_portrait(player_id: String, asset_id: String) -> Dictionary:
	for player in data.get("roster", []):
		if str(player.get("id", "")) == player_id: player.avatar_asset_id = asset_id if not asset_id.is_empty() else "player.avatar.fallback"; save_game(); return {"ok":true}
	return {"ok":false,"error":"Player does not exist in this career."}

func sign_player(index: int) -> String:
	if index < 0 or index >= data.market.size(): return "Player not found."
	var p: Dictionary = data.market[index]
	if organization_player_count() >= 7: return "The organization has reached its seven-player limit, including players on loan."
	var transfer_fee := 0 if str(p.get("squad_role", "")) == "free_agent" else int(p.value)
	if int(data.budget) < transfer_fee: return "The transfer budget is too low for this deal."
	var interest := int(data.reputation) + int(p.get("confidence", 0)) / 4 + (12 if int(p.get("overall", 99)) <= roundi(get_team_power()) + 4 else 0)
	if interest < 40: return "%s declined: the club reputation and proposed role are not attractive enough." % p.name
	var source_team_id := str(p.get("team_id", ""))
	data.budget -= transfer_fee
	p.contract = 24
	p.team_id = str(data.get("organization_id", "mekong_reapers"))
	p.owned = true
	p.scouted = true
	p.confidence = 100
	p.squad_role = "substitute" if data.roster.size() >= 4 else "starter"
	data.roster.append(p)
	data.market.remove_at(index)
	for team in data.get("teams", []):
		if str(team.get("database_id", "")) == source_team_id: team.roster_ids.erase(str(p.id)); break
	data.chemistry = maxi(25, int(data.chemistry) - 5)
	_add_finance_entry("Transfer • %s" % p.name, -transfer_fee)
	_add_news("New signing: %s" % p.name, "A 24-month contract was completed for $%s." % money(transfer_fee), "TRANSFER", "roster")
	save_game()
	return "Signed %s." % p.name

func create_transfer_offer(player_id: String, terms: Dictionary = {}) -> Dictionary:
	var candidate: Dictionary = {}
	for player in data.get("market", []):
		if str(player.get("id", "")) == player_id: candidate = player; break
	if candidate.is_empty(): return {"ok":false,"error":"Player is no longer available on the market."}
	if data.get("transfer_offers", []).any(func(offer): return str(offer.get("player_id", "")) == player_id and str(offer.get("status", "")) in ["PENDING","COUNTERED"]): return {"ok":false,"error":"An offer is already active for this player."}
	var salary := maxi(int(candidate.get("salary", 0)), int(terms.get("salary", candidate.get("salary", 0))))
	var months := clampi(int(terms.get("months", 24)), 12, 48); var role := str(terms.get("role", "ROTATION")); var starter := bool(terms.get("starter_guarantee", false))
	var interest := int(data.get("reputation", 0)) + int(candidate.get("confidence", 0)) / 4 + (10 if starter else 0) + clampi((salary - int(candidate.get("salary", 0))) / 450, -8, 16)
	var response := "ACCEPT" if interest >= 62 else "COUNTER" if interest >= 42 else "REJECT"
	var offer_id := "offer:%s:%d" % [player_id, Time.get_unix_time_from_system()]
	if organization_player_count() >= 7: return {"ok":false,"error":"The organization has reached its seven-player limit, including players on loan."}
	if int(data.get("budget", 0)) < int(candidate.get("value", 0)): return {"ok":false,"error":"The transfer budget cannot cover the required fee."}
	var offer := {"id":offer_id,"player_id":player_id,"player_name":str(candidate.get("name","Player")),"fee":int(candidate.get("value",0)),"salary":salary,"months":months,"role":role,"starter_guarantee":starter,"status":"PENDING","response":response,"created_week":int(data.get("week",1)),"counter_salary":salary+1000,"counter_months":mini(48,months+12)}
	data.transfer_offers.append(offer)
	var choices: Array = [{"id":"reject","label":"Reject offer","effects":{"transfer_offer":{"id":offer_id,"action":"reject"}}}]
	if response == "ACCEPT": choices.push_front({"id":"accept","label":"Accept terms","effects":{"transfer_offer":{"id":offer_id,"action":"accept"}}})
	elif response == "COUNTER": choices.push_front({"id":"counter","label":"Accept counter offer","effects":{"transfer_offer":{"id":offer_id,"action":"counter"}}})
	data.pending_events.append({"id":"transfer:%s" % offer_id,"type":"transfer_offer","status":"response_required","created_week":int(data.get("week",1)),"deadline_week":int(data.get("week",1))+1,"context":{"offer_id":offer_id,"player_name":str(candidate.get("name","Player")),"response":response,"salary":salary,"months":months},"choices":choices})
	save_game(); return {"ok":true,"offer":offer.duplicate(true)}

func resolve_transfer_offer(offer_id: String, action: String) -> Dictionary:
	for offer in data.get("transfer_offers", []):
		if str(offer.get("id", "")) != offer_id: continue
		if action == "reject": offer.status = "REJECTED"; _add_news("Transfer offer rejected", "%s will remain on the market.", "TRANSFER", "transfers"); save_game(); return {"ok":true,"status":"REJECTED"}
		var accepted := action == "accept" and str(offer.get("response", "")) == "ACCEPT" or action == "counter" and str(offer.get("response", "")) == "COUNTER"
		if not accepted: return {"ok":false,"error":"The player has not accepted these terms."}
		var index := -1
		for i in data.get("market", []).size(): if str(data.market[i].get("id", "")) == str(offer.get("player_id", "")): index = i; break
		if index < 0: return {"ok":false,"error":"Player is no longer available."}
		if organization_player_count() >= 7 or int(data.budget) < int(offer.get("fee", 0)): return {"ok":false,"error":"Roster capacity or budget prevents this transfer."}
		var player: Dictionary = data.market[index]; data.budget -= int(offer.fee); player.salary = int(offer.get("counter_salary",offer.salary)) if action=="counter" else int(offer.salary); player.contract = int(offer.get("counter_months",offer.months)) if action=="counter" else int(offer.months); player.owned=true; player.scouted=true; player.confidence=100; player.team_id=str(data.get("organization_id","")); data.market.remove_at(index)
		if bool(offer.get("starter_guarantee",false)) and data.roster.size() >= 4: data.roster.insert(3, player)
		else: data.roster.append(player)
		for roster_index in data.roster.size(): data.roster[roster_index].squad_role = "starter" if roster_index < 4 else "substitute"
		_ensure_personality_and_relationships(); data.chemistry=maxi(25,int(data.chemistry)-4); offer.status="SIGNED"; _add_finance_entry("Transfer • %s" % str(player.name),-int(offer.fee)); _add_news("New signing: %s" % str(player.name),"Contract finalized through negotiation.","TRANSFER","roster"); save_game(); return {"ok":true,"status":"SIGNED"}
	return {"ok":false,"error":"Offer does not exist."}

func set_individual_training(player_id: String, focus: String) -> Dictionary:
	var allowed := ["Aim","Strategy","Mental","Recovery","Teamwork"]
	if not focus in allowed: return {"ok":false,"error":"Unsupported individual training focus."}
	data.individual_training[player_id] = focus; save_game(); return {"ok":true}

func set_team_training_schedule(schedule: String) -> Dictionary:
	if not schedule in ["Cân bằng", "Cường độ cao", "Nghỉ & hồi phục"]: return {"ok":false,"error":"Unsupported training schedule."}
	data.schedule = schedule; save_game(); return {"ok":true,"schedule":schedule}

func set_player_role(player_id: String, role: String) -> Dictionary:
	var normalized := role.to_upper()
	if not normalized in ["FRAGGER","ANCHOR","SCOUT","SUPPORT","IGL","FLEX","ENTRY"]: return {"ok":false,"error":"Unsupported player role."}
	for player in data.get("roster", []):
		if str(player.get("id", "")) == player_id:
			player.role = normalized.capitalize() if normalized != "IGL" else "IGL"; save_game(); return {"ok":true,"player_id":player_id,"role":player.role}
	return {"ok":false,"error":"Player not found."}

func set_transfer_listed(player_id: String, listed: bool) -> Dictionary:
	for player in data.get("roster", []):
		if str(player.get("id", "")) != player_id: continue
		player.transfer_listed = listed
		if not listed:
			for offer in data.get("inbound_offers", []):
				if str(offer.get("player_id", "")) == player_id and str(offer.get("status", "")) in ["PENDING","COUNTERED"]: offer.status = "WITHDRAWN"
			_expire_inbound_offers()
		_record_progression("transfer_list", "Transfer-list status changed", "%s was %s the transfer list." % [str(player.get("name","Player")), "added to" if listed else "removed from"])
		save_game(); return {"ok":true,"listed":listed}
	return {"ok":false,"error":"Only an owned active-roster player can be transfer listed."}

func set_player_salary(player_id: String, salary: int) -> Dictionary:
	if salary <= 0: return {"ok":false,"error":"Salary must be positive."}
	for player in data.get("roster", []):
		if str(player.get("id", "")) == player_id:
			player.salary = salary; save_game(); return {"ok":true,"player_id":player_id,"salary":salary}
	return {"ok":false,"error":"Player not found."}

func move_roster_player(player_id: String, to_starter: bool) -> Dictionary:
	var roster: Array = data.get("roster", []); var index := -1
	for i in roster.size():
		if str(roster[i].get("id", "")) == player_id: index = i; break
	if index < 0: return {"ok":false,"error":"Player not found."}
	if to_starter:
		if index < 4: return {"ok":true,"unchanged":true}
		if roster.size() < 4: return {"ok":false,"error":"Roster has no starter slot."}
		var replaced_starter: Dictionary = roster[3]; roster[3] = roster[index]; roster[index] = replaced_starter
	else:
		if index >= 4: return {"ok":true,"unchanged":true}
		if roster.size() <= 4: return {"ok":false,"error":"A four-player active squad is required."}
		var replaced_substitute: Dictionary = roster[4]; roster[4] = roster[index]; roster[index] = replaced_substitute
	for i in roster.size(): roster[i].squad_role = "starter" if i < 4 else "substitute"
	save_game(); return {"ok":true,"player_id":player_id,"starter":to_starter}

func set_coach_plan_values(values: Dictionary) -> Dictionary:
	var allowed := ["drop_policy","zone_macro","formation","engagement","positioning","spacing","flank","focus_fire","target_priority","combat_range","information","resource"]
	for key in values:
		if not str(key) in allowed: return {"ok":false,"error":"Unsupported tactical field: %s" % key}
		data.coach_plan[str(key)] = values[key]
	save_game(); return {"ok":true,"coach_plan":data.coach_plan.duplicate(true)}

func record_media_response(tone: String, message: String, story_id := "") -> Dictionary:
	if not tone in ["POSITIVE","NEUTRAL","NEGATIVE"]: return {"ok":false,"error":"Unsupported media tone."}
	var story := current_media_story()
	if not story_id.is_empty() and str(story.get("id", "")) != story_id: return {"ok":false,"error":"This media story is no longer active."}
	if story.is_empty(): return {"ok":false,"error":"No media story is available."}
	if str(story.get("status", "AVAILABLE")) != "AVAILABLE": return {"ok":false,"error":"This media story has already been answered."}
	var effects: Dictionary = {"POSITIVE":{"fan_sentiment":2,"board_confidence":-1},"NEUTRAL":{"fan_sentiment":0,"board_confidence":1},"NEGATIVE":{"fan_sentiment":-2,"board_confidence":-1}}[tone]
	data.fan_sentiment = clampi(int(data.get("fan_sentiment",65)) + int(effects.fan_sentiment), 0, 100)
	data.board_confidence = clampi(int(data.get("board_confidence",65)) + int(effects.board_confidence), 0, 100)
	story.status = "ANSWERED"; story.answered_date = str(data.get("current_date", SEASON_START_DATE)); story.tone = tone; story.message = message; story.effects = effects.duplicate(true)
	data.event_history.append({"id":str(story.get("id", "media")),"type":"media_response","tone":tone,"message":message,"week":int(data.get("week",1)),"date":str(data.get("current_date",SEASON_START_DATE)),"effects":effects.duplicate(true)})
	_record_progression("media", "Media response recorded", "%s response changed supporter and board sentiment." % tone.capitalize(), effects)
	save_game(); return {"ok":true,"effects":effects}

func set_match_decision(phase: String, decision: String) -> Dictionary:
	if not phase in ["EARLY","MID","END"] or not decision in ["FIGHT","ROTATE","HOLD"]: return {"ok":false,"error":"Unsupported match decision."}
	data.match_decisions[phase] = decision; save_game(); return {"ok":true}

func effective_match_plan() -> Dictionary:
	var plan: Dictionary = data.get("coach_plan", {}).duplicate(true); var decisions: Dictionary = data.get("match_decisions", {})
	if str(decisions.get("EARLY","")) == "FIGHT": plan.engagement="AGGRESSIVE"
	elif str(decisions.get("EARLY","")) == "ROTATE": plan.drop_policy="FIXED_SAFE"
	if str(decisions.get("MID","")) == "ROTATE": plan.zone_macro="FAST"
	elif str(decisions.get("MID","")) == "HOLD": plan.zone_macro="CENTER"
	if str(decisions.get("END","")) == "HOLD": plan.engagement="AVOID"
	return plan

func renew_contract(player_id:String, months:int = 24) -> String:
	for player in data.get("roster", []):
		if str(player.get("id", "")) != player_id: continue
		var signing_fee := int(player.get("salary", 0)) * 2
		if int(data.budget) < signing_fee: return "The budget is too low to renew this contract."
		data.budget -= signing_fee; player.contract = maxi(int(player.get("contract", 0)), 0) + months; player.happiness = clampi(int(player.get("happiness", 60)) + 8, 0, 100)
		_add_finance_entry("Renewal • %s" % player.name, -signing_fee); _add_news("Contract renewed: %s" % player.name, "The contract was extended by %d months." % months, "CONTRACT", "player_detail"); save_game(); return "Renewed %s." % player.name
	return "Player not found."

func recover_player(player_id:String) -> String:
	for player in data.get("roster", []):
		if str(player.get("id", "")) != player_id: continue
		var gain := 8 + int(data.facilities.get("Medical Room", 1)) * 4
		player.energy = clampi(int(player.get("energy", 0)) + gain, 0, 100); player.form = maxi(25, int(player.get("form", 60)) - 1); save_game(); return "%s recovered %d energy." % [player.name, gain]
	return "Player not found."

func loan_destinations() -> Array:
	var destinations: Array = []
	for team in data.get("teams", []):
		var team_id := str(team.get("database_id", team.get("id", "")))
		if team_id.is_empty() or team_id == str(data.get("organization_id", "")): continue
		destinations.append({"id":team_id,"name":str(team.get("name", team.get("team_name", "Partner club"))),"power":int(team.get("power", 50))})
	if destinations.is_empty(): destinations.append({"id":"loan_partner","name":"Regional Development Club","power":50})
	destinations.sort_custom(func(a, b): return str(a.get("name", "")) < str(b.get("name", "")))
	return destinations

func create_loan(player_id: String, destination_id := "", duration_weeks := 8, salary_coverage := 50) -> Dictionary:
	if data.get("roster", []).size() <= 4: return {"ok":false,"error":"A player cannot leave on loan while only four active players remain."}
	if data.get("loan_records", []).any(func(record): return str(record.get("player_id", "")) == player_id and str(record.get("status", "")) == "ACTIVE"): return {"ok":false,"error":"This player already has an active loan."}
	var player: Dictionary = {}
	for candidate in data.get("roster", []):
		if str(candidate.get("id", "")) == player_id: player = candidate; break
	if player.is_empty(): return {"ok":false,"error":"Only an owned active-roster player can be loaned."}
	var destinations := loan_destinations()
	var destination: Dictionary = destinations[0]
	for candidate in destinations:
		if str(candidate.get("id", "")) == destination_id: destination = candidate; break
	var weeks := clampi(duration_weeks, 4, 12)
	var coverage := clampi(salary_coverage, 0, 100)
	var return_date := _add_days(str(data.get("current_date", SEASON_START_DATE)), weeks * 7)
	var loan_id := "loan:S%d:W%d:%s" % [int(data.get("season",1)), int(data.get("week",1)), player_id]
	var record := {"id":loan_id,"player_id":player_id,"player_name":str(player.get("name","Player")),"destination_team_id":str(destination.get("id","")),"destination_team_name":str(destination.get("name","Partner club")),"duration_weeks":weeks,"salary_coverage":coverage,"start_date":str(data.get("current_date",SEASON_START_DATE)),"return_date":return_date,"status":"ACTIVE"}
	data.roster.erase(player); player.loaned = true; player.loan_id = loan_id; player.squad_role = "on_loan"; player.current_team_name = str(destination.get("name","Partner club"))
	data.loaned_players.append(player); data.loan_records.append(record)
	data.calendar_events.append({"id":"loan-return:%s" % loan_id,"date":return_date,"time":"09:00","priority":45,"requires_player_action":false,"completed":false,"status":"scheduled","type":"loan_return","tournament":"PLAYER LOAN","round":"%s RETURNS" % str(player.get("name","PLAYER")),"player_id":player_id,"loan_id":loan_id})
	_add_news("Loan agreed: %s" % str(player.name), "%s joined %s until %s. The club retains %d%% of salary cost." % [str(player.name), str(destination.get("name","Partner club")), return_date, 100-coverage], "TRANSFER", "roster")
	_record_progression("loan", "Player loan started", "%s joined %s until %s." % [str(player.name), str(destination.get("name","Partner club")), return_date], {"player_id":player_id,"salary_coverage":coverage})
	save_game(); return {"ok":true,"record":record.duplicate(true)}

func loan_player(player_id: String) -> String:
	var result := create_loan(player_id)
	return "%s is now on loan." % str(result.get("record", {}).get("player_name", "Player")) if bool(result.get("ok", false)) else str(result.get("error", "Loan failed."))

func _process_loan_returns(current_date: String) -> Array:
	var returned: Array = []
	for record in data.get("loan_records", []):
		if str(record.get("status", "")) != "ACTIVE" or str(record.get("return_date", "")) > current_date: continue
		var player: Dictionary = {}
		for candidate in data.get("loaned_players", []):
			if str(candidate.get("id", "")) == str(record.get("player_id", "")): player = candidate; break
		if player.is_empty(): record.status = "RETURN_ERROR"; continue
		data.loaned_players.erase(player); player.loaned = false; player.erase("loan_id"); player.squad_role = "substitute"; player.current_team_name = str(data.get("org_name", "Organization")); data.roster.append(player)
		record.status = "RETURNED"; record.returned_date = current_date; returned.append(record.duplicate(true))
		for event in data.get("calendar_events", []):
			if str(event.get("loan_id", "")) == str(record.get("id", "")): event.status = "completed"; event.completed = true
		_add_news("Loan return: %s" % str(player.name), "%s has returned from %s and is available as a substitute." % [str(player.name), str(record.get("destination_team_name","loan"))], "TRANSFER", "roster")
		_record_progression("loan_return", "Player returned from loan", "%s rejoined the active roster." % str(player.name), {"player_id":str(player.get("id",""))})
	return returned

func terminate_player_contract(player_id: String) -> String:
	if data.get("roster", []).size() <= 4: return "A contract cannot be terminated while only four players remain."
	for player in data.get("roster", []):
		if str(player.get("id", "")) != player_id: continue
		var fee := int(player.get("salary", 0)) * maxi(1, int(player.get("contract", 0)))
		data.budget = maxi(0, int(data.get("budget", 0)) - fee); data.roster.erase(player)
		player.owned = false; player.squad_role = "free_agent"; data.market.append(player)
		_add_finance_entry("Termination • %s" % str(player.name), -fee); _add_news("Contract terminated: %s" % str(player.name), "Player released after termination fee.", "CONTRACT", "transfer")
		save_game(); return "Contract terminated for %s." % str(player.name)
	return "Player not found."

func release_player(player_id: String) -> String:
	if data.get("roster", []).size() <= 4: return "A player cannot be released while only four players remain."
	for player in data.get("roster", []):
		if str(player.get("id", "")) != player_id: continue
		data.roster.erase(player); player.owned = false; player.squad_role = "free_agent"; data.market.append(player)
		_add_news("Player released: %s" % str(player.name), "The player is now a free agent.", "CONTRACT", "transfer")
		save_game(); return "%s released to free agency." % str(player.name)
	return "Player not found."

func accept_sponsor(sponsor_id: String) -> String:
	if not str(data.get("active_sponsor_id", "")).is_empty(): return "An active sponsor contract already exists."
	for sponsor in data.get("sponsors", []):
		if str(sponsor.get("id", "")) != sponsor_id: continue
		if int(data.get("reputation", 0)) < int(sponsor.get("reputation_required", 0)): return "Club reputation is too low for this offer."
		data.active_sponsor_id = sponsor_id
		data.budget = int(data.budget) + int(sponsor.get("signing_bonus", 0))
		data.fans = int(data.fans) + int(sponsor.get("fan_bonus", 0))
		_add_finance_entry("%s signing bonus" % str(sponsor.get("name", "Sponsor")), int(sponsor.get("signing_bonus", 0)))
		_add_news("Sponsor signed: %s" % str(sponsor.get("name", "Sponsor")), "A new commercial partner has joined the organization.")
		save_game()
		return "Signed %s." % str(sponsor.get("name", "Sponsor"))
	return "Sponsor not found."

func _default_sponsors() -> Array:
	return _career_content().get("sponsors", [])

func _add_finance_entry(label: String, amount: int) -> void:
	var ledger: Array = data.get("finance_ledger", [])
	ledger.push_front({"id":_next_record_id("finance"),"week":int(data.get("week", 1)),"type":"income" if amount >= 0 else "expense","label":label,"amount":amount})
	if ledger.size() > 24: ledger.resize(24)
	data.finance_ledger = ledger

func upgrade_facility(name: String) -> String:
	for project in data.get("facility_projects", []):
		if str(project.get("facility", "")) == name and str(project.get("status", "")) == "UPGRADING": return "%s is already upgrading." % name
	var level: int = data.facilities[name]
	var definition: Dictionary = data.get("facility_definitions", {}).get(name, {})
	var max_level := int(definition.get("max_level", definition.get("levels", []).size()))
	if level >= max_level: return "%s has reached the maximum level." % name
	var cost := int(definition.get("base_upgrade_cost", 60000)) * (level + 1)
	if int(data.budget) < cost: return "Insufficient budget. $%s required." % money(cost)
	var duration_days := maxi(2, int(definition.get("construction_days", 3 + level * 2)))
	var completion_date := _add_days(str(data.get("current_date", SEASON_START_DATE)), duration_days)
	data.budget -= cost
	var project := {"id":"facility-%s-%d" % [name.to_lower().replace(" ","-"), Time.get_unix_time_from_system()],"facility":name,"from_level":level,"target_level":level+1,"cost":cost,"start_date":str(data.get("current_date",SEASON_START_DATE)),"completion_date":completion_date,"duration_days":duration_days,"status":"UPGRADING"}
	data.facility_projects.append(project)
	data.calendar_events.append({"id":project.id,"date":completion_date,"time":"09:00","priority":90,"requires_player_action":true,"completed":false,"status":"scheduled","type":"facility","tournament":"FACILITY","round":"%s UPGRADE COMPLETE" % name,"facility":name})
	save_game()
	return "%s upgrade started • Level %d • %d days." % [name, level + 1, duration_days]

func _process_facility_projects(current_date: String) -> void:
	for project in data.get("facility_projects", []):
		if str(project.get("status", "")) != "UPGRADING" or str(project.get("completion_date", "")) > current_date: continue
		var facility := str(project.get("facility", ""))
		data.facilities[facility] = int(project.get("target_level", data.facilities.get(facility, 1)))
		project.status = "COMPLETE"
		_add_news("Facility upgrade complete", "%s reached Level %d." % [facility, int(data.facilities[facility])], "FACILITY", "facilities")
		_record_progression("facility", "Facility upgrade complete", "%s reached Level %d. %s." % [facility, int(data.facilities[facility]), facility_benefit_summary(facility)], {"facility":facility,"level":int(data.facilities[facility])})

func get_team_power() -> float:
	if data.is_empty() or data.roster.is_empty(): return 0.0
	var total := 0.0
	for p in data.roster.slice(0, mini(4, data.roster.size())):
		total += float(p.overall) * 0.55 + float(p.form) * 0.18 + float(p.energy) * 0.12 + float(p.teamwork) * 0.15
	return total / mini(4, data.roster.size()) + float(data.chemistry) * 0.08

func _scout_progress() -> void:
	var staff_bonus := 0
	for staff in data.get("staff", []):
		if str(staff.get("id", "")) == "scout": staff_bonus = maxi(1, roundi(float(staff.get("rating", 50)) / 10.0)); break
	for p in data.market:
		p.confidence = mini(100, int(p.confidence) + randi_range(8, 16) + int(data.facilities["Analytics Lab"]) * 2 + staff_bonus + int(difficulty_rules().scouting))

func generate_inbound_offers(force := false) -> Array:
	var created: Array = []
	if data.get("roster", []).size() <= 4: return created
	var destinations := loan_destinations()
	for player in data.get("roster", []):
		if not bool(player.get("transfer_listed", false)): continue
		var player_id := str(player.get("id", ""))
		if data.get("inbound_offers", []).any(func(offer): return str(offer.get("player_id", "")) == player_id and str(offer.get("status", "")) in ["PENDING","COUNTERED"]): continue
		var age_score := clampi(28 - int(player.get("age", 24)), -4, 10)
		var demand := clampi((int(player.get("overall", 60)) - 55) + age_score + int(player.get("form", 60)) / 10 + int(difficulty_rules().inbound_interest), 5, 48)
		var roll := absi((str(data.get("career_id", "career")) + player_id + str(data.get("season",1)) + str(data.get("week",1))).hash()) % 100
		if not force and roll >= demand: continue
		var buyer: Dictionary = destinations[absi((player_id + str(data.get("week",1))).hash()) % destinations.size()]
		var value_scale := 88 + absi((player_id + str(buyer.get("id",""))).hash()) % 21
		var amount := maxi(int(player.get("salary", 0)) * 3, roundi(int(player.get("value", 0)) * value_scale / 100.0))
		var offer_id := "inbound:S%d:W%d:%s" % [int(data.get("season",1)), int(data.get("week",1)), player_id]
		var offer := {"id":offer_id,"player_id":player_id,"player_name":str(player.get("name","Player")),"buyer_team_id":str(buyer.get("id","")),"buyer_name":str(buyer.get("name","Club")),"amount":amount,"original_amount":amount,"status":"PENDING","created_week":int(data.get("week",1)),"deadline_week":int(data.get("week",1))+1}
		data.inbound_offers.push_front(offer); created.append(offer.duplicate(true))
		data.pending_events.append({"id":"event:%s" % offer_id,"type":"inbound_transfer_offer","status":"response_required","blocks_progression":false,"created_week":int(data.get("week",1)),"deadline_week":int(data.get("week",1))+1,"context":{"offer_id":offer_id,"player_id":player_id,"player_name":str(player.get("name","Player")),"buyer_name":str(buyer.get("name","Club")),"amount":amount},"choices":[{"id":"accept","label":"Accept $%s" % money(amount),"effects":{"inbound_offer":{"id":offer_id,"action":"accept"}}},{"id":"counter","label":"Counter +10%","effects":{"inbound_offer":{"id":offer_id,"action":"counter"}}},{"id":"reject","label":"Reject offer","effects":{"inbound_offer":{"id":offer_id,"action":"reject"}}}]})
		_add_news("Inbound offer: %s" % str(player.get("name","Player")), "%s submitted a $%s offer. A response is required in Inbox." % [str(buyer.get("name","Club")), money(amount)], "TRANSFER", "inbox")
	if not created.is_empty(): save_game()
	return created

func resolve_inbound_offer(offer_id: String, action: String) -> Dictionary:
	var offer: Dictionary = {}
	for candidate in data.get("inbound_offers", []):
		if str(candidate.get("id", "")) == offer_id: offer = candidate; break
	if offer.is_empty(): return {"ok":false,"error":"Inbound offer does not exist."}
	if not str(offer.get("status", "")) in ["PENDING","COUNTERED"]: return {"ok":false,"error":"Inbound offer is no longer active."}
	if action == "reject":
		offer.status = "REJECTED"; offer.resolved_week = int(data.get("week",1)); _record_progression("transfer", "Inbound offer rejected", "%s remains with the organization." % str(offer.get("player_name","Player"))); save_game(); return {"ok":true,"status":"REJECTED"}
	if action == "counter":
		var counter_amount := roundi(int(offer.get("amount",0)) * 1.10)
		var buyer_limit := roundi(int(offer.get("original_amount",offer.get("amount",0))) * 1.15)
		if counter_amount > buyer_limit: offer.status = "REJECTED"; offer.resolved_week = int(data.get("week",1)); save_game(); return {"ok":true,"status":"REJECTED","reason":"COUNTER_DECLINED"}
		offer.amount = counter_amount; offer.status = "COUNTERED"
		data.pending_events.append({"id":"event:%s:counter" % offer_id,"type":"inbound_transfer_offer","status":"response_required","blocks_progression":false,"created_week":int(data.get("week",1)),"deadline_week":int(data.get("week",1))+1,"context":{"offer_id":offer_id,"player_id":str(offer.get("player_id","")),"player_name":str(offer.get("player_name","Player")),"buyer_name":str(offer.get("buyer_name","Club")),"amount":counter_amount,"response":"COUNTER ACCEPTED"},"choices":[{"id":"accept","label":"Complete $%s sale" % money(counter_amount),"effects":{"inbound_offer":{"id":offer_id,"action":"accept"}}},{"id":"reject","label":"Withdraw","effects":{"inbound_offer":{"id":offer_id,"action":"reject"}}}]})
		save_game(); return {"ok":true,"status":"COUNTERED","amount":counter_amount}
	if action != "accept": return {"ok":false,"error":"Unsupported inbound-offer action."}
	if data.get("roster", []).size() <= 4: return {"ok":false,"error":"The sale would leave fewer than four active players."}
	var player: Dictionary = {}
	for candidate in data.get("roster", []):
		if str(candidate.get("id", "")) == str(offer.get("player_id", "")): player = candidate; break
	if player.is_empty(): return {"ok":false,"error":"Player is no longer in the active roster."}
	data.roster.erase(player); player.owned = false; player.transfer_listed = false; player.squad_role = "transferred"; player.team_id = str(offer.get("buyer_team_id","")); player.current_team_name = str(offer.get("buyer_name","Club")); data.transferred_out_players.push_front(player)
	for roster_index in data.roster.size(): data.roster[roster_index].squad_role = "starter" if roster_index < 4 else "substitute"
	data.budget = int(data.get("budget",0)) + int(offer.get("amount",0)); offer.status = "ACCEPTED"; offer.resolved_week = int(data.get("week",1)); offer.resolved_date = str(data.get("current_date",SEASON_START_DATE))
	_add_finance_entry("Player sale • %s" % str(player.get("name","Player")), int(offer.get("amount",0))); _add_news("Player sold: %s" % str(player.get("name","Player")), "%s completed a $%s transfer." % [str(offer.get("buyer_name","Club")), money(int(offer.get("amount",0)))], "TRANSFER", "roster")
	_record_progression("transfer", "Player transfer completed", "%s joined %s for $%s." % [str(player.get("name","Player")), str(offer.get("buyer_name","Club")), money(int(offer.get("amount",0)))], {"amount":int(offer.get("amount",0)),"player_id":str(player.get("id",""))})
	save_game(); return {"ok":true,"status":"ACCEPTED","amount":int(offer.get("amount",0))}

func _expire_inbound_offers() -> void:
	for offer in data.get("inbound_offers", []):
		if str(offer.get("status", "")) in ["PENDING","COUNTERED"] and int(offer.get("deadline_week", 999)) < int(data.get("week",1)): offer.status = "EXPIRED"
	data.pending_events = data.get("pending_events", []).filter(func(event):
		if str(event.get("type", "")) != "inbound_transfer_offer": return true
		var offer_id := str(event.get("context", {}).get("offer_id", ""))
		return data.get("inbound_offers", []).any(func(offer): return str(offer.get("id", "")) == offer_id and str(offer.get("status", "")) in ["PENDING","COUNTERED"]))

func _random_event() -> void:
	var events := [
		["Successful fan event", "The local community responded enthusiastically.", 18000, 900, 3],
		["Player burnout warning", "The intensive training schedule is affecting squad morale.", -5000, 0, -7],
		["Performance bonus awarded", "A sponsor issued an additional performance payment.", 45000, 300, 2],
		["New meta emerging", "Center-control play is gaining popularity.", 0, 0, -2]
	]
	var e: Array = events.pick_random()
	data.budget += e[2]
	if int(e[2]) != 0: _add_finance_entry(str(e[0]), int(e[2]))
	data.fans += e[3]
	data.morale = clampi(int(data.morale) + e[4], 10, 100)
	_add_news(e[0], e[1])

func _maybe_queue_relationship_issue() -> void:
	var lowest: Dictionary = {}
	for record in data.get("relationships", {}).values():
		if lowest.is_empty() or int(record.get("value", 0)) < int(lowest.get("value", 101)): lowest = record
	if lowest.is_empty() or int(lowest.get("value", 0)) > -12: return
	queue_relationship_conflict(str(lowest.get("player_a", "")), str(lowest.get("player_b", "")), "drop strategy")

func _end_season() -> void:
	var completed_season := int(data.get("season", 1))
	var season_matches: Array = data.get("history", []).filter(func(match): return int(match.get("season", completed_season)) == completed_season)
	var best_placement := 0
	var total_kills := 0
	var total_points := 0
	var prize_earnings := 0
	for match in season_matches:
		var placement := int(match.get("placement", 0)); if placement > 0 and (best_placement == 0 or placement < best_placement): best_placement = placement
		total_kills += int(match.get("kills", 0)); total_points += int(match.get("points", 0)); prize_earnings += int(match.get("prize", 0))
	var renewal_income := 180000 + int(data.get("reputation", 0)) * 4000
	var closing_budget := int(data.get("budget", 0))
	var opening_budget := int(data.get("season_start_budget", closing_budget))
	var summary := {"season":completed_season,"completed_date":str(data.get("current_date",SEASON_START_DATE)),"matches":season_matches.size(),"best_placement":best_placement,"kills":total_kills,"points":total_points,"prize_earnings":prize_earnings,"reputation":int(data.get("reputation",0)),"world_rank":career_world_rank(),"opening_budget":opening_budget,"closing_budget":closing_budget,"financial_result":closing_budget-opening_budget,"renewal_income":renewal_income,"status":"AVAILABLE"}
	data.season_history.push_front(summary); data.season_transition = summary.duplicate(true)
	data.season = completed_season + 1
	data.week = 1
	data.tournament_results = {}
	data.tournament_registrations = {}
	for offer in data.get("inbound_offers", []):
		if str(offer.get("status", "")) in ["PENDING", "COUNTERED"]: offer.status = "EXPIRED"; offer.resolved_week = 12; offer.resolution = "SEASON_END"
	for offer in data.get("transfer_offers", []):
		if str(offer.get("status", "")) in ["PENDING", "COUNTERED"]: offer.status = "EXPIRED"
	for pending in data.get("pending_events", []):
		pending.status = "expired"; pending.resolution = "SEASON_END"; data.event_history.push_front(pending.duplicate(true))
	data.pending_events = []
	data.scrim_requests = []
	for tournament in data.get("tournaments", []):
		if bool(tournament.get("auto_registered", false)): data.tournament_registrations[str(tournament.get("id",""))] = {"status":"REGISTERED","registered_at":str(data.get("current_date",SEASON_START_DATE))}
	data.calendar_events = _build_season_calendar(str(data.current_date))
	data.budget += renewal_income
	_add_finance_entry("Season %d renewal income" % int(data.season), renewal_income)
	data.season_start_budget = int(data.budget)
	for t in data.teams: t.power = clampi(int(t.power) + randi_range(-3, 3), 48, 94)
	_ensure_media_story()
	_record_progression("season", "Season %d completed" % completed_season, "%d matches • best placement #%s • %d points." % [season_matches.size(), str(best_placement) if best_placement > 0 else "—", total_points], summary)
	_add_news("Season %d begins" % data.season, "Season %d was archived. Renewal income of $%s was added to the budget." % [completed_season, money(renewal_income)], "COMPETITION", "trophies")

func acknowledge_season_transition() -> Dictionary:
	var transition: Dictionary = data.get("season_transition", {})
	if transition.is_empty(): return {"ok":false,"error":"No season summary is available."}
	if str(transition.get("status", "AVAILABLE")) == "ACKNOWLEDGED": return {"ok":false,"error":"Season summary was already acknowledged."}
	transition.status = "ACKNOWLEDGED"
	save_game()
	return {"ok":true,"season":int(transition.get("season", 0))}

func _add_news(title: String, body: String, category := "SYSTEM", action_page := "") -> void:
	data.inbox.push_front({"id":_next_record_id("inbox"), "title": title, "body": body, "week": data.get("week", 1), "category":category, "action_page":action_page, "read":false})
	if data.inbox.size() > 10: data.inbox.resize(10)

func save_game() -> bool:
	if data.is_empty(): return false
	data.save_version = SAVE_VERSION
	data.last_saved_at = Time.get_datetime_string_from_system()
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data, "  "))
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(save_path): return false
	var parser:=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(save_path)) != OK: return false
	var parsed = parser.data
	if not parsed is Dictionary: return false
	data = parsed
	_migrate_save()
	save_game()
	return true

func _migrate_save() -> void:
	data.save_version = SAVE_VERSION
	if not data.has("slot_id"): data.slot_id = _slot_from_path(save_path)
	if not data.has("career_id"): data.career_id = "legacy-%d-%s" % [int(data.slot_id), str(data.get("organization_id", "career"))]
	if not data.has("created_at"): data.created_at = ""
	if not data.has("last_saved_at"): data.last_saved_at = ""
	if not data.has("playtime_seconds"): data.playtime_seconds = 0
	if not data.has("difficulty"): data.difficulty = "Normal"
	if not data.has("starting_tier"): data.starting_tier = "D"
	if not data.has("board_expectation"): data.board_expectation = "Develop talent"
	if not data.has("career_type"): data.career_type = "normal"
	if not data.has("team_mode"): data.team_mode = "existing"
	if not data.has("career_overrides"): data.career_overrides = {}
	if not data.has("content_lock"): data.content_lock = []
	if not data.has("developer_mode"): data.developer_mode = false
	if not data.has("simulation_overrides"): data.simulation_overrides = {}
	if not data.has("telemetry"): data.telemetry = []
	if not data.has("meta_state"): data.meta_state = {"version":1,"weapon_usage":{},"weapon_performance":{},"tiers":{},"patch_history":[]}
	if not data.has("event_history"): data.event_history = []
	if not data.has("pending_events"): data.pending_events = []
	if not data.has("days_elapsed"):
		data.days_elapsed = maxi(0, roundi((Time.get_unix_time_from_datetime_string(str(data.get("current_date",SEASON_START_DATE)) + "T00:00:00") - Time.get_unix_time_from_datetime_string(SEASON_START_DATE + "T00:00:00")) / 86400.0))
	if not data.has("next_record_sequence"): data.next_record_sequence = data.get("inbox", []).size() + data.get("finance_ledger", []).size() + data.get("progression_log", []).size() + 1
	if not data.has("season_start_budget"): data.season_start_budget = int(data.get("budget", 0))
	if not data.has("progression_log"): data.progression_log = []
	if not data.has("season_history"): data.season_history = []
	if not data.has("season_transition"): data.season_transition = {}
	if not data.has("loaned_players"): data.loaned_players = []
	if not data.has("loan_records"): data.loan_records = []
	if not data.has("inbound_offers"): data.inbound_offers = []
	if not data.has("transferred_out_players"): data.transferred_out_players = []
	if not data.has("media_stories"): data.media_stories = []
	if not data.has("player_memories"): data.player_memories = {}
	if not data.has("role_promises"): data.role_promises = []
	if not data.has("relationships"): data.relationships = {}
	if not data.has("organization_dna"): data.organization_dna = {"development":50,"discipline":50,"ambition":50,"community":50}
	if not data.has("coach_philosophy"): data.coach_philosophy = "Balanced"
	if not data.has("board_confidence"): data.board_confidence = 65
	if not data.has("investor_confidence"): data.investor_confidence = 60
	if not data.has("fan_sentiment"): data.fan_sentiment = 65
	if not data.has("crisis_week"): data.crisis_week = false
	if not data.has("rivalries"): data.rivalries = {}
	if not data.has("management_context"): data.management_context = "CLUB"
	if not data.has("national_team_id"): data.national_team_id = ""
	if not data.has("national_roster_ids"): data.national_roster_ids = []
	if not data.has("national_tactics"): data.national_tactics = {"drop_policy":"ADAPTIVE","zone_macro":"CENTER","engagement":"SELECTIVE"}
	if not data.has("national_camp"): data.national_camp = {"active":false,"weeks":0}
	if not data.has("scrim_requests"): data.scrim_requests = []
	if not data.has("scrim_history"): data.scrim_history = []
	if not data.has("tactical_familiarity"): data.tactical_familiarity = 0
	if not data.has("facility_projects"): data.facility_projects = []
	if data.get("scrim_requests", []).size() > 1 and data.get("scrim_requests", []).all(func(item): return item.has("team_id")):
		var legacy_participants: Array = []
		for item in data.scrim_requests: legacy_participants.append({"team_id":str(item.get("team_id","")),"team_name":str(item.get("team_name","Team")),"logo_asset_id":str(item.get("logo_asset_id","")),"power":int(item.get("power",50))})
		data.scrim_requests = [{"id":"scrim-cluster-a-migrated","cluster_id":"A","cluster_name":"SCRIM CLUSTER A","participants":legacy_participants,"available_slots":maxi(0,16-legacy_participants.size()),"status":"pending","week":int(data.get("week",1)),"date":str(data.get("current_date",SEASON_START_DATE)),"time":"15:00"}]
	if not data.has("organization_id"): data.organization_id = "mekong_reapers"
	data.season = int(data.get("season", 1))
	data.week = int(data.get("week", 1))
	for key in ["budget","fans","reputation","morale","chemistry","next_player_id"]:
		data[key] = int(data.get(key, 0))
	if not data.has("current_date"):
		data.current_date = _add_days(SEASON_START_DATE, (int(data.week) - 1) * 7)
	if not data.has("calendar_month_offset"): data.calendar_month_offset = 0
	if not data.has("active_tournament_name"): data.active_tournament_name = "Global Survival Invitational"
	if not data.has("org_logo_asset_id"): data.org_logo_asset_id = "team.mekong_reapers.logo"
	if not data.has("active_tournament_logo_asset_id"): data.active_tournament_logo_asset_id = "tournament.global_survival_circuit.logo"
	if not data.has("active_tournament_prize_pool"): data.active_tournament_prize_pool = 300000
	if not data.has("active_tournament_team_count"): data.active_tournament_team_count = 16
	if not data.has("active_tournament_player_count"): data.active_tournament_player_count = 64
	if not data.has("tournament_results"): data.tournament_results = {}
	if not data.has("match_replays"): data.match_replays = []
	if not data.has("sponsors"): data.sponsors = _career_content().get("sponsors", [])
	if not data.has("active_sponsor_id"): data.active_sponsor_id = ""
	if not data.has("sponsor_status"): data.sponsor_status = {"progress":0,"state":"HEALTHY","last_review_week":int(data.get("week",1))}
	if not data.has("staff"): data.staff = [{"id":"head_coach","name":"Head Coach","role":"Head Coach","rating":62,"salary":4200,"contract":24,"effect":"+6 percentage points to weekly growth chance"},{"id":"analyst","name":"Match Analyst","role":"Analyst","rating":60,"salary":3600,"contract":24,"effect":"Produces post-match telemetry reports"},{"id":"scout","name":"Lead Scout","role":"Scout","rating":58,"salary":3200,"contract":24,"effect":"+6 scout confidence per scouting update"},{"id":"mental_coach","name":"Mental Coach","role":"Mental Coach","rating":57,"salary":3000,"contract":24,"effect":"+5 weekly player happiness"}]
	for staff in data.get("staff", []):
		match str(staff.get("id", "")):
			"head_coach": staff.effect = "+6 percentage points to weekly growth chance"
			"analyst": staff.effect = "Produces post-match telemetry reports"
			"scout": staff.effect = "+6 scout confidence per scouting update"
			"mental_coach": staff.effect = "+5 weekly player happiness"
	if not data.has("transfer_offers"): data.transfer_offers = []
	if not data.has("weekly_training_plan"): data.weekly_training_plan = ["Aim Training","Strategy Review","Scrim Preparation","Recovery","Team Chemistry","VOD Review","Rest"]
	if not data.has("individual_training"): data.individual_training = {}
	if not data.has("map_tactics"): data.map_tactics = {}
	if not data.has("match_decisions"): data.match_decisions = {"EARLY":"ROTATE","MID":"HOLD","END":"FIGHT"}
	if not data.has("finance_ledger"): data.finance_ledger = [{"week":int(data.get("week", 1)),"type":"opening","label":"Opening budget","amount":int(data.get("budget", 0))}]
	for ledger_entry in data.get("finance_ledger", []):
		if not ledger_entry.has("id"): ledger_entry.id = _next_record_id("finance")
	for pending_event in data.get("pending_events", []):
		if str(pending_event.get("type", "")) == "inbound_transfer_offer": pending_event.blocks_progression = false
	if not data.has("tournament_registrations"): data.tournament_registrations = {"gsi_2026_s1":{"status":"REGISTERED","registered_at":str(data.get("current_date",SEASON_START_DATE))}}
	var obsolete_catalog: bool = not data.has("tournaments") or data.get("tournaments", []).any(func(item): return int(item.get("team_count", 0)) > 25 or str(item.get("id", "")) in ["sea_survival_league_s1","continental_cup","weekly_cup_s1"])
	if obsolete_catalog: data.tournaments = _tournament_catalog()
	data.competitions = data.tournaments
	if not data.has("facility_definitions"): data.facility_definitions = _career_content().get("facilities", {})
	if not data.has("calendar_events"): data.calendar_events = _build_season_calendar(SEASON_START_DATE)
	if not data.has("coach_plan"): data.coach_plan = {}
	var coach_defaults := {"drop_policy":"ADAPTIVE","zone_macro":"CENTER","formation":"TWO_TWO","engagement":"SELECTIVE","positioning":"CENTER_HOLD","spacing":"NORMAL","flank":"NONE","focus_fire":"FOCUS","target_priority":"LOWEST_HP","combat_range":"ADAPTIVE","information":"INFO_FIRST","resource":"MINIMAL"}
	for key in coach_defaults:
		if not data.coach_plan.has(key): data.coach_plan[key] = coach_defaults[key]
	if not data.has("previous_team_power"): data.previous_team_power = roundi(get_team_power())
	if not data.has("ranking_trend"): data.ranking_trend = 0
	for team in data.get("teams", []):
		if not team.has("baseline_power"): team.baseline_power = int(team.get("power", 50))
		if not team.has("form"): team.form = int(team.get("power", 50))
		if not team.has("trend"): team.trend = 0
	for match_record in data.get("history", []):
		if not match_record.has("season"): match_record.season = int(data.get("season", 1))
	for p in data.get("roster", []) + data.get("market", []) + data.get("loaned_players", []):
		if not p.has("handle"): p.handle = "%s%04d" % [str(p.get("name", "player")).replace(" ", "").to_lower(), absi(int(p.get("id", 0))) % 10000]
		if not p.has("avatar_asset_id"): p.avatar_asset_id = "player.avatar.fallback"
		var base := int(p.get("overall", 60))
		for stat in ["vision","hearing","reaction","communication","leadership","discipline","composure","stealth","utility","driving","zone_reading"]:
			if not p.has(stat): p[stat] = clampi(base, 25, 95)
		if not p.has("team_id"): p.team_id = "mekong_reapers" if p in data.get("roster", []) else ""
		if not p.has("owned"): p.owned = p in data.get("roster", [])
		if not p.has("release_clause"): p.release_clause = int(p.get("value", 0)) * 2
		if not p.has("career"): p.career = {"matches":0,"kills":0,"damage":0,"revives":0,"earnings":0,"titles":0}
		if not p.has("happiness"): p.happiness = int(p.get("morale", 60))
		if not p.has("squad_role"): p.squad_role = "starter" if p in data.get("roster", []).slice(0,4) else "substitute" if p in data.get("roster", []) else "transfer_target"
	_ensure_personality_and_relationships()
	_ensure_media_story()
	_expire_inbound_offers()

func _tournament_catalog() -> Array:
	var database = DATABASE_SCRIPT.new()
	if not database.load_all().is_empty(): return []
	var result: Array = []
	for source in database.tournaments:
		var tournament: Dictionary = source.duplicate(true)
		tournament.team_count = clampi(int(tournament.get("team_count", 16)), 2, 25)
		tournament.players_per_team = 4
		tournament.max_players = int(tournament.team_count) * 4
		tournament.participants = _select_tournament_participants(tournament, database)
		tournament.prize = int(tournament.get("prize_pool", 0))
		tournament.match_days = int(tournament.get("days", 1))
		tournament.competition_type = str(tournament.get("tournament_type", "INTERNATIONAL"))
		tournament.region = str(tournament.get("country", "International"))
		tournament.format = "%d matches • %d per day" % [int(tournament.get("total_matches", 1)), int(tournament.get("matches_per_day", 1))]
		result.append(tournament)
	return result

func _select_tournament_participants(tournament: Dictionary, database) -> Array:
	var participant_type := str(tournament.get("participant_type", "CLUB"))
	var pool: Array = database.teams.filter(func(team): return str(team.get("team_type", "CLUB")) == ("NATIONAL" if participant_type == "NATIONAL_TEAM" else "CLUB") and (participant_type == "NATIONAL_TEAM" or team.get("roster_ids", []).size() >= 4))
	pool.sort_custom(func(a, b): return int(a.get("ranking", {}).get("power", 0)) > int(b.get("ranking", {}).get("power", 0)))
	var selected: Array = []
	var organization_id := str(data.get("organization_id", "")); var organization: Dictionary = database.get_team(organization_id)
	if participant_type == "CLUB" and bool(tournament.get("auto_registered", false)) and not organization.is_empty(): selected.append(organization_id)
	var tournament_type := str(tournament.get("tournament_type", "INTERNATIONAL")); var country := str(tournament.get("country", ""))
	if tournament_type in ["NATIONAL", "DOMESTIC"]: pool = pool.filter(func(team): return _nationality_key(str(team.get("country", ""))) == _nationality_key(country))
	var slots: Dictionary = tournament.get("international_slots", {})
	if tournament_type == "INTERNATIONAL" and participant_type == "CLUB" and not slots.is_empty():
		for slot_country in slots:
			if str(slot_country) == "Other": continue
			var candidates := pool.filter(func(team): return _nationality_key(str(team.get("country", ""))) == _nationality_key(str(slot_country)))
			for team in candidates.slice(0, int(slots[slot_country])):
				if not str(team.id) in selected: selected.append(str(team.id))
	for team in pool:
		if selected.size() >= int(tournament.team_count): break
		if not str(team.id) in selected: selected.append(str(team.id))
	return selected.slice(0, mini(int(tournament.team_count), selected.size()))

func get_competition(tournament_id: String) -> Dictionary:
	for competition in data.get("tournaments", []):
		if str(competition.get("id", "")) == tournament_id: return competition
	return {}

func tournament_registration_status(tournament_id: String) -> Dictionary:
	var tournament := get_competition(tournament_id)
	if tournament.is_empty(): return {"status":"NOT_FOUND","eligible":false,"conflicts":[],"reasons":["Tournament is missing"]}
	var registrations: Dictionary = data.get("tournament_registrations", {})
	if registrations.has(tournament_id) and str(registrations[tournament_id].get("status", "")) == "REGISTERED": return {"status":"REGISTERED","eligible":true,"conflicts":[],"reasons":[]}
	var reasons: Array = []; var conflicts: Array = []
	var context_type := "NATIONAL_TEAM" if str(data.get("management_context", "CLUB")) == "NATIONAL" else "CLUB"
	if str(tournament.get("participant_type", "CLUB")) != context_type: reasons.append("Tournament participant type does not match management context")
	var database = DATABASE_SCRIPT.new(); database.load_all()
	var team_id := str(data.get("national_team_id", "")) if context_type == "NATIONAL_TEAM" else str(data.get("organization_id", "")); var team: Dictionary = database.get_team(team_id)
	var required_country := str(tournament.get("qualification_rules", {}).get("country", ""))
	if not required_country.is_empty() and _nationality_key(str(team.get("country", ""))) != _nationality_key(required_country): reasons.append("Team country is not eligible")
	var start_date := str(tournament.get("start_date", "")); var end_date := str(tournament.get("end_date", start_date))
	for event in data.get("calendar_events", []):
		if str(event.get("tournament_id", "")) == tournament_id or str(event.get("status", "scheduled")) == "completed": continue
		var event_date := str(event.get("date", ""))
		if event_date >= start_date and event_date <= end_date and (bool(event.get("requires_player_action", true)) or str(event.get("type", "")) in ["match","scrim","training","important_event"]): conflicts.append(str(event.get("id", "")))
	if not conflicts.is_empty(): return {"status":"SCHEDULE_CONFLICT","eligible":false,"conflicts":conflicts,"reasons":reasons}
	return {"status":"NOT_ELIGIBLE" if not reasons.is_empty() else "AVAILABLE","eligible":reasons.is_empty(),"conflicts":conflicts,"reasons":reasons}

func register_tournament(tournament_id: String) -> Dictionary:
	var evaluation := tournament_registration_status(tournament_id)
	if not bool(evaluation.get("eligible", false)) or str(evaluation.get("status", "")) == "REGISTERED": return {"ok":false,"status":evaluation.get("status", "NOT_ELIGIBLE"),"reasons":evaluation.get("reasons", []),"conflicts":evaluation.get("conflicts", [])}
	var registrations: Dictionary = data.get("tournament_registrations", {}); registrations[tournament_id] = {"status":"REGISTERED","registered_at":str(data.get("current_date", SEASON_START_DATE))}; data.tournament_registrations = registrations
	var tournament := get_competition(tournament_id); var team_id := str(data.get("national_team_id", "")) if str(tournament.get("participant_type", "CLUB")) == "NATIONAL_TEAM" else str(data.get("organization_id", ""))
	if not team_id.is_empty() and not team_id in tournament.participants:
		if tournament.participants.size() >= int(tournament.team_count): tournament.participants.pop_back()
		tournament.participants.push_front(team_id)
	data.calendar_events.append_array(_calendar_events_for_tournament(tournament, str(data.get("current_date", SEASON_START_DATE))))
	data.calendar_events.sort_custom(func(a, b): return str(a.get("date", "")) < str(b.get("date", "")))
	save_game(); return {"ok":true,"status":"REGISTERED","tournament_id":tournament_id}

func unregister_tournament(tournament_id: String) -> Dictionary:
	var registrations: Dictionary = data.get("tournament_registrations", {})
	if not registrations.has(tournament_id): return {"ok":false,"error":"Tournament is not registered"}
	registrations.erase(tournament_id); data.tournament_registrations = registrations
	data.calendar_events = data.get("calendar_events", []).filter(func(event): return str(event.get("tournament_id", "")) != tournament_id or str(event.get("status", "scheduled")) == "completed")
	save_game(); return {"ok":true,"status":"AVAILABLE","tournament_id":tournament_id}

func prepare_match_context(event: Dictionary) -> Dictionary:
	var competition := get_competition(str(event.get("tournament_id", "")))
	if competition.is_empty(): return {"ok":false,"error":"Competition is missing"}
	var participants: Array = competition.get("participants", [])
	if participants.size() < 2: return {"ok":false,"error":"Competition has insufficient participants"}
	var database = DATABASE_SCRIPT.new(); var errors: PackedStringArray = database.load_all()
	if not errors.is_empty(): return {"ok":false,"error":"World database is invalid"}
	var opponents: Array = []
	for team_id in participants:
		if str(team_id) == str(data.get("organization_id", "")): continue
		var team: Dictionary = database.get_team(str(team_id))
		if team.is_empty(): continue
		opponents.append({"database_id":str(team.id),"name":str(team.name),"tag":str(team.tag),"region":str(team.region),"power":int(team.get("ranking",{}).get("power",50)),"form":int(team.get("performance",{}).get("consistency",50)),"logo_asset_id":str(team.get("logo_asset_id","")),"roster_ids":team.get("roster_ids",[]).duplicate()})
	data.teams = opponents; data.active_match_team_count = participants.size(); data.active_match_participants = participants.duplicate(); data.active_match_scoring = competition.get("scoring", {}).duplicate(true)
	return {"ok":true,"team_count":participants.size(),"participants":participants.duplicate()}

func _career_content() -> Dictionary:
	var database = DATABASE_SCRIPT.new()
	if not database.load_all().is_empty(): return {}
	return database.career_content.duplicate(true)

func _build_season_calendar(start_date: String) -> Array:
	var events: Array = []
	for tournament in data.get("tournaments", []):
		if bool(tournament.get("auto_registered", false)) or data.get("tournament_registrations", {}).has(str(tournament.get("id", ""))): events.append_array(_calendar_events_for_tournament(tournament, start_date))
	events.sort_custom(func(a, b): return str(a.get("date", "")) < str(b.get("date", "")))
	return events

func _calendar_events_for_tournament(tournament: Dictionary, start_date: String) -> Array:
	var events: Array = []; var offsets: Array = tournament.get("calendar_offsets", []); var maps: Array = tournament.get("map_rotation", ["Verdant Reach"])
	for i in offsets.size():
		events.append({"id":"S%d-%s-D%02d" % [int(data.get("season",1)),str(tournament.get("id","tournament")),i+1],"date":_add_days(start_date,int(offsets[i])),"time":"10:00","priority":100,"requires_player_action":true,"completed":false,"type":"match","tournament_id":str(tournament.get("id","")),"tournament":str(tournament.get("name","Competition")),"round":"Matchday %d" % (i+1),"map":str(maps[i % maxi(1,maps.size())]),"teams":int(tournament.get("team_count",16)),"players_per_team":int(tournament.get("players_per_team",4)),"max_players":int(tournament.get("max_players",64)),"participant_ids":tournament.get("participants",[]).duplicate(),"matches_in_matchday":int(tournament.get("matches_per_day",1)),"status":"scheduled","result":{}})
	return events

func get_next_match(include_today := true) -> Dictionary:
	var today := str(data.get("current_date", SEASON_START_DATE))
	var candidates: Array = data.get("calendar_events", []).filter(func(event): return str(event.get("type", "match")) == "match" and str(event.get("status", "scheduled")) == "scheduled" and (str(event.get("date", "")) >= today if include_today else str(event.get("date", "")) > today))
	candidates.sort_custom(func(a, b): return str(a.get("date", "")) < str(b.get("date", "")))
	return candidates[0] if not candidates.is_empty() else {}

func get_playable_match() -> Dictionary:
	var today := str(data.get("current_date", SEASON_START_DATE))
	var candidates: Array = data.get("calendar_events", []).filter(func(event): return str(event.get("type", "match")) == "match" and str(event.get("status", "scheduled")) == "scheduled" and str(event.get("date", "")) <= today)
	candidates.sort_custom(func(a, b): return str(a.get("date", "")) < str(b.get("date", "")))
	return candidates[0] if not candidates.is_empty() else {}

func get_tournament_standings(tournament_id: String) -> Array:
	var rows: Array = []
	var competition := get_competition(tournament_id); var database = DATABASE_SCRIPT.new(); database.load_all()
	for team_id in competition.get("participants", []):
		var team: Dictionary = database.get_team(str(team_id)); if team.is_empty(): continue
		var is_player := str(team_id) == str(data.get("organization_id", ""))
		rows.append({"team_id":str(team_id),"tag":"MR" if is_player else str(team.get("tag", str(team.get("name", "TEAM")).left(3).to_upper())), "name":str(data.get("org_name", team.name)) if is_player else str(team.name), "logo_asset_id":str(data.get("org_logo_asset_id", "")) if is_player else str(team.get("logo_asset_id", "")), "matches":0, "wins":0, "kills":0, "placement_points":0, "points":0, "is_player":is_player})
	var completed: Array = data.get("tournament_results", {}).get(tournament_id, [])
	for match_result in completed:
		for standing in match_result.get("scoreboard", []):
			for row in rows:
				if str(row.tag) == str(standing.get("tag", "")):
					row.matches = int(row.matches) + 1; row.kills = int(row.kills) + int(standing.get("kills", 0)); row.placement_points = int(row.placement_points) + int(standing.get("placement_points", 0)); row.points = int(row.points) + int(standing.get("points", 0)); row.wins = int(row.wins) + (1 if int(standing.get("rank", 999)) == 1 else 0)
	rows.sort_custom(func(a, b): return int(a.points) > int(b.points) if int(a.points) != int(b.points) else int(a.kills) > int(b.kills))
	for i in rows.size(): rows[i].rank = i + 1
	return rows

func get_month_events(year: int, month: int) -> Array:
	var prefix := "%04d-%02d-" % [year,month]
	return data.get("calendar_events", []).filter(func(event): return str(event.date).begins_with(prefix))

func advance_to_next_match() -> Dictionary:
	var next := get_next_match(true)
	while not next.is_empty() and str(data.current_date) < str(next.date):
		var result := advance_day()
		if not bool(result.get("ok", false)): break
	return get_playable_match()

static func _add_days(date: String, days: int) -> String:
	var unix := Time.get_unix_time_from_datetime_string(date + "T00:00:00") + days * 86400
	var value := Time.get_datetime_dict_from_unix_time(unix)
	return "%04d-%02d-%02d" % [value.year,value.month,value.day]

func has_save() -> bool:
	return FileAccess.file_exists(save_path)

func select_slot(slot_id: int) -> void:
	save_path = slot_path(slot_id)

func load_slot(slot_id: int) -> bool:
	select_slot(slot_id)
	return load_game()

func delete_slot(slot_id: int) -> bool:
	var path := slot_path(slot_id)
	if not FileAccess.file_exists(path): return true
	var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if error == OK and int(data.get("slot_id", 0)) == slot_id: data = {}
	return error == OK

func list_save_slots() -> Array:
	var slots: Array = []
	for slot_id in range(1, SAVE_SLOT_COUNT + 1):
		var path := slot_path(slot_id)
		var metadata := {"slot_id":slot_id, "empty":true, "path":path}
		if FileAccess.file_exists(path):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				metadata = {"slot_id":slot_id,"empty":false,"path":path,"career_id":str(parsed.get("career_id", "")),"organization_id":str(parsed.get("organization_id", "")),"org_name":str(parsed.get("org_name", "Unknown Organization")),"season":int(parsed.get("season", 1)),"week":int(parsed.get("week", 1)),"tournament":str(parsed.get("active_tournament_name", "")),"tier":str(parsed.get("starting_tier", "D")),"difficulty":str(parsed.get("difficulty", "Normal")),"playtime_seconds":int(parsed.get("playtime_seconds", 0)),"last_saved_at":str(parsed.get("last_saved_at", "")),"thumbnail":str(parsed.get("save_thumbnail", "")),"valid":true}
			else: metadata = {"slot_id":slot_id,"empty":false,"path":path,"valid":false,"error":"Save data is malformed."}
		slots.append(metadata)
	return slots

func most_recent_slot() -> int:
	var best_slot := 0
	var best_time := ""
	for metadata in list_save_slots():
		if bool(metadata.get("empty", true)) or not bool(metadata.get("valid", true)): continue
		var saved_at := str(metadata.get("last_saved_at", ""))
		if best_slot == 0 or saved_at > best_time: best_slot = int(metadata.slot_id); best_time = saved_at
	return best_slot

static func slot_path(slot_id: int) -> String:
	return "user://save_slot_%02d.json" % clampi(slot_id, 1, SAVE_SLOT_COUNT)

static func _slot_from_path(path: String) -> int:
	var file_name := path.get_file().get_basename()
	var suffix := file_name.trim_prefix("save_slot_")
	return clampi(int(suffix), 1, SAVE_SLOT_COUNT) if suffix.is_valid_int() else 1

static func money(value: int) -> String:
	var raw := str(absi(value))
	var out := ""
	while raw.length() > 3:
		out = "," + raw.right(3) + out
		raw = raw.left(raw.length() - 3)
	return ("-" if value < 0 else "") + raw + out
