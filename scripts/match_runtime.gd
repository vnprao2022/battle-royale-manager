class_name MatchRuntime
extends RefCounted

signal updated(snapshot: Dictionary)
signal event_emitted(event: Dictionary)
signal match_finished(result: Dictionary)

const MapCatalogScript = preload("res://scripts/map_catalog.gd")
const GameDatabaseScript = preload("res://scripts/game_database.gd")
const TACTICS_PATH := "res://data/tactics/coach_presets.json"
const DEFAULT_TEAM_COUNT := 16
const MAX_TEAM_COUNT := 25
const TEAM_SIZE := 4
const PARACHUTE_MAX_RANGE := 0.34
const REVIVE_RANGE := 0.028
const WEAPONS := ["M416","SCAR-L","AUG","QBZ","Beryl M762","AKM","ACE32","Groza","UMP45","Vector","MP5K","Micro Uzi","Mini14","Mk12","SLR","SKS","Dragunov","VSS","M24","Kar98k","AWM","M249","MG3","DP-28","S12K","DBS","S686","P92","Deagle","R1895","G36C","FAMAS","M16A4","Mutant","Tommy Gun","PP-19 Bizon","S1897","O12","P18C","Lynx AMR"]
const WEAPON_PROFILES := {
	"UMP45":{"category":"SMG","ideal_min":0.0,"ideal_max":0.055,"accuracy":0.82,"damage":31}, "Vector":{"category":"SMG","ideal_min":0.0,"ideal_max":0.045,"accuracy":0.85,"damage":30}, "MP5K":{"category":"SMG","ideal_min":0.0,"ideal_max":0.06,"accuracy":0.84,"damage":33}, "Micro Uzi":{"category":"SMG","ideal_min":0.0,"ideal_max":0.04,"accuracy":0.78,"damage":26},
	"M416":{"category":"AR","ideal_min":0.025,"ideal_max":0.16,"accuracy":0.86,"damage":41}, "SCAR-L":{"category":"AR","ideal_min":0.025,"ideal_max":0.15,"accuracy":0.84,"damage":41}, "AUG":{"category":"AR","ideal_min":0.03,"ideal_max":0.17,"accuracy":0.88,"damage":42}, "QBZ":{"category":"AR","ideal_min":0.02,"ideal_max":0.15,"accuracy":0.83,"damage":42},
	"Beryl M762":{"category":"AR","ideal_min":0.02,"ideal_max":0.13,"accuracy":0.80,"damage":48}, "AKM":{"category":"AR","ideal_min":0.025,"ideal_max":0.14,"accuracy":0.78,"damage":48}, "ACE32":{"category":"AR","ideal_min":0.03,"ideal_max":0.15,"accuracy":0.82,"damage":46}, "Groza":{"category":"AR","ideal_min":0.0,"ideal_max":0.12,"accuracy":0.87,"damage":49},
	"Mini14":{"category":"DMR","ideal_min":0.09,"ideal_max":0.34,"accuracy":0.88,"damage":51}, "Mk12":{"category":"DMR","ideal_min":0.1,"ideal_max":0.34,"accuracy":0.88,"damage":51}, "SLR":{"category":"DMR","ideal_min":0.10,"ideal_max":0.32,"accuracy":0.84,"damage":56}, "SKS":{"category":"DMR","ideal_min":0.10,"ideal_max":0.30,"accuracy":0.80,"damage":53}, "Dragunov":{"category":"DMR","ideal_min":0.12,"ideal_max":0.36,"accuracy":0.86,"damage":58}, "VSS":{"category":"DMR","ideal_min":0.06,"ideal_max":0.22,"accuracy":0.80,"damage":44},
	"M24":{"category":"SR","ideal_min":0.16,"ideal_max":0.46,"accuracy":0.90,"damage":79}, "Kar98k":{"category":"SR","ideal_min":0.14,"ideal_max":0.42,"accuracy":0.87,"damage":75}, "AWM":{"category":"SR","ideal_min":0.18,"ideal_max":0.52,"accuracy":0.94,"damage":105},
	"M249":{"category":"LMG","ideal_min":0.04,"ideal_max":0.20,"accuracy":0.78,"damage":43}, "MG3":{"category":"LMG","ideal_min":0.03,"ideal_max":0.18,"accuracy":0.77,"damage":40}, "DP-28":{"category":"LMG","ideal_min":0.05,"ideal_max":0.22,"accuracy":0.80,"damage":51},
	"S12K":{"category":"SHOTGUN","ideal_min":0.0,"ideal_max":0.04,"accuracy":0.79,"damage":88}, "DBS":{"category":"SHOTGUN","ideal_min":0.0,"ideal_max":0.045,"accuracy":0.84,"damage":92}, "S686":{"category":"SHOTGUN","ideal_min":0.0,"ideal_max":0.035,"accuracy":0.82,"damage":96},
	"P92":{"category":"PISTOL","ideal_min":0.0,"ideal_max":0.035,"accuracy":0.72,"damage":34}, "Deagle":{"category":"PISTOL","ideal_min":0.0,"ideal_max":0.05,"accuracy":0.76,"damage":62}, "R1895":{"category":"PISTOL","ideal_min":0.0,"ideal_max":0.045,"accuracy":0.74,"damage":55}
}
const LEGACY_WEAPON_PROFILES := {
	"G36C":{"category":"AR","ideal_min":0.02,"ideal_max":0.15,"accuracy":0.85,"damage":41}, "FAMAS":{"category":"AR","ideal_min":0.02,"ideal_max":0.14,"accuracy":0.86,"damage":42}, "M16A4":{"category":"AR","ideal_min":0.04,"ideal_max":0.20,"accuracy":0.80,"damage":43}, "Mutant":{"category":"AR","ideal_min":0.04,"ideal_max":0.18,"accuracy":0.82,"damage":44},
	"Tommy Gun":{"category":"SMG","ideal_min":0.0,"ideal_max":0.06,"accuracy":0.76,"damage":40}, "PP-19 Bizon":{"category":"SMG","ideal_min":0.0,"ideal_max":0.07,"accuracy":0.80,"damage":35}, "S1897":{"category":"SHOTGUN","ideal_min":0.0,"ideal_max":0.04,"accuracy":0.78,"damage":91}, "O12":{"category":"SHOTGUN","ideal_min":0.0,"ideal_max":0.05,"accuracy":0.81,"damage":84}, "P18C":{"category":"PISTOL","ideal_min":0.0,"ideal_max":0.04,"accuracy":0.74,"damage":29}, "Lynx AMR":{"category":"SR","ideal_min":0.20,"ideal_max":0.54,"accuracy":0.92,"damage":118}
}
const WEAPON_RANGE_RULES := {
	"SHOTGUN":{"optimal_m":12.0,"max_m":40.0,"falloff_floor":0.34,"display_rounds":5},
	"SMG":{"optimal_m":60.0,"max_m":180.0,"falloff_floor":0.44,"display_rounds":30},
	"AR":{"optimal_m":180.0,"max_m":450.0,"falloff_floor":0.52,"display_rounds":30},
	"LMG":{"optimal_m":220.0,"max_m":520.0,"falloff_floor":0.52,"display_rounds":50},
	"DMR":{"optimal_m":380.0,"max_m":850.0,"falloff_floor":0.62,"display_rounds":10},
	"SR":{"optimal_m":700.0,"max_m":1250.0,"falloff_floor":0.72,"display_rounds":5},
	"PISTOL":{"optimal_m":45.0,"max_m":120.0,"falloff_floor":0.42,"display_rounds":15}
}
const HEAL_ITEMS := {
	"Bandage":{"heal":10,"cap":75,"use_time":4.0},
	"First Aid Kit":{"heal_to":75,"cap":75,"use_time":6.0},
	"Med Kit":{"heal_to":100,"cap":100,"use_time":8.0}
}
const BOOST_ITEMS := {
	"Energy Drink":{"boost":40,"use_time":4.0},
	"Painkiller":{"boost":60,"use_time":6.0},
	"Adrenaline Syringe":{"boost":100,"use_time":10.0}
}
const ZONES := [
	{"number":1,"reveal":80.0,"shrink_start":130.0,"shrink_end":260.0,"radius":0.38,"damage":1,"severity":"RẤT THẤP"},
	{"number":2,"reveal":260.0,"shrink_start":310.0,"shrink_end":450.0,"radius":0.25,"damage":2,"severity":"THẤP"},
	{"number":3,"reveal":450.0,"shrink_start":490.0,"shrink_end":610.0,"radius":0.15,"damage":4,"severity":"TRUNG BÌNH"},
	{"number":4,"reveal":610.0,"shrink_start":645.0,"shrink_end":750.0,"radius":0.08,"damage":8,"severity":"KHÁ CAO"},
	{"number":5,"reveal":750.0,"shrink_start":780.0,"shrink_end":900.0,"radius":0.0,"damage":18,"severity":"CAO"}
]

var catalog := MapCatalogScript.new()
var map_data: Dictionary = {}
var map_id := "verdant_reach"
var running := false
var paused := false
var speed := 1.0
var elapsed := 0.0
var duration := 900.0
var phase := "FLIGHT"
var zone_number := 0
var blue_radius := 0.78
var zone_center := Vector2(0.5, 0.5)
var shrink_origin_center := Vector2(0.5, 0.5)
var target_zone_center := Vector2(0.5, 0.5)
var target_zone_radius := 0.0
var blue_damage := 0
var zone_severity := "AN TOÀN"
var flight_path := [Vector2(0.0, 0.2), Vector2(1.0, 0.8)]
var plane_progress := 0.0
var lobby_team_count := DEFAULT_TEAM_COUNT
var match_scoring: Dictionary = {}
var teams_alive := DEFAULT_TEAM_COUNT
var players_alive := DEFAULT_TEAM_COUNT * TEAM_SIZE
var placement := 0
var kills := 0
var damage := 0
var morale := 72
var formation := "2-2-1"
var strategy := "Đang phân tích đường bay"
var next_event_at := 18.0
var roster: Array = []
var team_positions: Array = []
var resources := {"ammo":0,"heal":0,"throwables":0,"armor":0,"boost":0,"fuel":64,"vehicle_hp":100}
var timeline: Array = []
const TACTICAL_DEFAULTS := {"drop_policy":"ADAPTIVE","zone_macro":"CENTER","formation":"TWO_TWO","engagement":"SELECTIVE","positioning":"CENTER_HOLD","spacing":"NORMAL","flank":"NONE","focus_fire":"FOCUS","target_priority":"LOWEST_HP","combat_range":"ADAPTIVE","information":"INFO_FIRST","resource":"MINIMAL"}
var coach_plan := TACTICAL_DEFAULTS.duplicate(true)
var tactics_data: Dictionary = {}
var contacts: Array = []
var detection_attempts := 0
var confirmed_contacts := 0
var kill_feed: Array = []
var effects: Array = []
var bullet_trails: Array = []
var scoreboard: Array = []
var game_database = GameDatabaseScript.new()
var next_action_check := 82.0
var next_proximity_check := 82.0
var loot_stock: Dictionary = {}
var winner: Dictionary = {}
var replay_version := 1
var match_seed := 0
var match_id := ""
var event_sequence := 0
var red_zone := {"active":false,"center":Vector2(0.5,0.5),"radius":0.0,"ends_at":0.0,"next_at":155.0,"shells":0}
var next_airdrop_at := 285.0
var airdrops_spawned := 0
var simulation_overrides: Dictionary = {}

func start_match(game_data: Dictionary, requested_map := "verdant_reach", requested_plan: Dictionary = {}, requested_seed: int = -1) -> void:
	var seed_source := "%s|%s|%s" % [str(game_data.get("active_match_event_id", game_data.get("week", 1))), requested_map, str(game_data.get("season", 1))]
	match_seed = requested_seed if requested_seed >= 0 else absi(seed_source.hash())
	seed(match_seed)
	match_id = "%s-%s" % [str(game_data.get("active_match_event_id", "career")), str(match_seed)]
	event_sequence = 0
	map_id = requested_map
	map_data = catalog.load_map(map_id)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(TACTICS_PATH)); tactics_data = parsed if parsed is Dictionary else {}
	game_database.load_all()
	simulation_overrides = game_data.get("simulation_overrides", {}).duplicate(true) if bool(game_data.get("developer_mode", false)) else {}
	coach_plan = game_data.get("coach_plan", coach_plan).duplicate(true); for key in TACTICAL_DEFAULTS: if not coach_plan.has(key): coach_plan[key] = TACTICAL_DEFAULTS[key]
	for key in requested_plan: coach_plan[key] = requested_plan[key]
	formation = {"STACK":"4 Stack","TWO_TWO":"2-2 Split","ONE_THREE":"1-3 Scout","FOUR_WAY":"4-way Split","ANCHOR_THREE":"Anchor + 3"}.get(str(coach_plan.formation),"2-2 Split")
	running = true; paused = false; speed = 1.0; elapsed = 0.0; phase = "FLIGHT"
	zone_number = 0; blue_radius = 0.78; target_zone_radius = 0.0; blue_damage = 0; zone_severity="AN TOÀN"
	_make_flight_path(); _make_first_zone()
	next_airdrop_at = 285.0
	airdrops_spawned = 0
	lobby_team_count = clampi(int(game_data.get("active_match_team_count", game_data.get("active_tournament_team_count", DEFAULT_TEAM_COUNT))), 2, MAX_TEAM_COUNT)
	match_scoring = game_data.get("active_match_scoring", {}).duplicate(true)
	teams_alive = lobby_team_count; players_alive = lobby_team_count * TEAM_SIZE; placement = 0; kills = 0; damage = 0
	morale = int(game_data.get("morale", 72)); strategy = _macro_name()
	roster.clear(); timeline.clear(); team_positions.clear(); contacts.clear(); kill_feed.clear(); effects.clear(); bullet_trails.clear(); scoreboard.clear(); loot_stock.clear(); winner.clear(); detection_attempts = 0; confirmed_contacts = 0
	red_zone = {"active":false,"center":Vector2(0.5,0.5),"radius":0.0,"ends_at":0.0,"next_at":randf_range(145.0,190.0),"shells":0}
	var regions: Array = map_data.get("regions", [])
	_initialize_loot_stock()
	for i in mini(TEAM_SIZE, game_data.get("roster", []).size()):
		var source: Dictionary = game_data.roster[i]
		var choice := _choose_drop_style(source, i)
		var destination := _choose_destination(choice, regions, i)
		var drop_accuracy := int(source.get("drop_accuracy",source.get("adaptability",60))); var landing_speed := int(source.get("landing_speed",source.get("reaction",60))); var loot_efficiency := int(source.get("loot_efficiency",source.get("game_sense",60)))
		roster.append({"player_id":source.get("id", ""),"name":source.name,"role":source.role,"team":"MR","tactical_resource":str(coach_plan.resource),"health":100,"boost":0.0,"state":"IN_PLANE","action":"","action_end":0.0,"action_item":"","kills":0,"damage":0,"energy":source.energy,"aim":source.get("aim",60),"game_sense":source.get("game_sense",60),"vision":source.get("vision",60),"hearing":source.get("hearing",60),"reaction":source.get("reaction",60),"communication":source.get("communication",60),"leadership":source.get("leadership",60),"discipline":source.get("discipline",60),"composure":source.get("composure",60),"stealth":source.get("stealth",60),"utility":source.get("utility",60),"zone_reading":source.get("zone_reading",60),"drop_accuracy":drop_accuracy,"landing_speed":landing_speed,"loot_efficiency":loot_efficiency,"early_combat":int(source.get("aim",60)),"adaptability":int(source.get("adaptability",60)),"map_knowledge":int(source.get("zone_reading",60)),"drop_style":choice,"destination":_apply_drop_error(destination,drop_accuracy),"position":flight_path[0],"jump_position":flight_path[0],"move_target":destination,"jump_time":18.0 + i * 4.5,"land_time":0.0,"transport":"foot","vehicle_until":0.0,"vehicle_fuel":100.0,"vehicle_durability":100.0,"loadout":_make_loadout(i,loot_efficiency)})
	var team_names: Array = [str(game_data.get("org_name","Mekong Reapers"))]
	for team in game_data.get("teams", []).slice(0, lobby_team_count - 1): team_names.append(str(team.name))
	for i in lobby_team_count:
		var acronym := "MR" if i == 0 else _acronym(team_names[i] if i < team_names.size() else "Team %d" % i)
		var target := _team_drop_target(regions,i); var members: Array = []; var ai_plan := _ai_plan_for_team(i)
		var database_team_id := "mekong_reapers" if i == 0 else str(game_data.get("teams", [])[i - 1].get("database_id", "")) if i - 1 < game_data.get("teams", []).size() else ""
		var database_players: Array = game_database.get_team_players(database_team_id)
		for member in TEAM_SIZE:
			var player_name := str(database_players[member].get("handle", "%s_%d" % [acronym, member + 1])) if member < database_players.size() else "%s_%d" % [acronym,member+1]
			var destination := target + _formation_offset(member, i)
			var profile: Dictionary = database_players[member] if member < database_players.size() else {}; var combat: Dictionary=profile.get("combat",{}); var awareness: Dictionary=profile.get("awareness",{}); var macro: Dictionary=profile.get("macro",{}); var teamplay: Dictionary=profile.get("teamplay",{})
			var drop_accuracy:=int(macro.get("scouting",60)); var landing_speed:=int(awareness.get("reaction",60)); var loot_efficiency:=int(macro.get("loot_efficiency",60))
			members.append({"name":player_name,"role":str(profile.get("role",["IGL","Entry","Support","Fragger"][member])),"team":acronym,"tactical_resource":str(ai_plan.resource),"position":flight_path[0],"state":"IN_PLANE","action":"","action_end":0.0,"action_item":"","health":100,"boost":0.0,"kills":0,"aim":int(combat.get("aim",60)),"game_sense":int(awareness.get("game_sense",60)),"reaction":int(awareness.get("reaction",60)),"communication":int(teamplay.get("communication",60)),"discipline":int(teamplay.get("discipline",60)),"composure":int(teamplay.get("composure",60)),"drop_accuracy":drop_accuracy,"landing_speed":landing_speed,"loot_efficiency":loot_efficiency,"early_combat":int(combat.get("close_range",60)),"adaptability":int(macro.get("risk_assessment",60)),"map_knowledge":int(macro.get("zone_reading",60)),"jump_time":10.0+randf_range(0.0,52.0)+member*0.8,"land_time":0.0,"jump_position":flight_path[0],"destination":_apply_drop_error(destination,drop_accuracy),"move_target":destination,"transport":"foot","vehicle_until":0.0,"vehicle_fuel":100.0,"vehicle_durability":100.0,"route_target":destination,"route_risk":0.0,"loadout":_make_loadout((i+member)%WEAPONS.size(),loot_efficiency)})
		team_positions.append({"name":team_names[i] if i < team_names.size() else "Team %d" % i,"tag":acronym,"position":flight_path[0],"drop":randf_range(0.08,0.92),"target":target,"color":i,"ai_plan":ai_plan,"members":members,"alive":TEAM_SIZE,"kills":0})
		scoreboard.append({"rank":i+1,"name":team_names[i] if i < team_names.size() else "Team %d" % i,"tag":acronym,"alive":TEAM_SIZE,"kills":0,"points":0,"color":i,"eliminated_at":-1.0})
	team_positions[0].members=roster
	team_positions[0].alive=roster.size()
	resources = {"ammo":0,"heal":0,"throwables":0,"armor":0,"boost":0,"fuel":roundi(64.0 * catalog.vehicle_need_factor(map_data)),"vehicle_hp":100}
	next_event_at = 92.0
	next_action_check = 82.0; next_proximity_check=82.0
	_emit_event("flight", "Đường bay ngẫu nhiên đã xác lập. IGL đang chọn điểm thả.", "FLIGHT")
	updated.emit(snapshot())

func tick(delta: float) -> void:
	if not running or paused: return
	elapsed += delta * speed
	var scaled_delta := delta * speed
	_update_deployment(scaled_delta); _update_player_movement(scaled_delta); _update_player_actions(scaled_delta); _update_effects(scaled_delta); _update_zone_state(); _apply_blue_damage(scaled_delta); _update_red_zone(scaled_delta); _update_airdrops()
	if elapsed >= next_event_at:
		_generate_event(); next_event_at = elapsed + randf_range(18.0, 32.0)
	if elapsed>=next_proximity_check: next_proximity_check=elapsed+randf_range(1.5,3.0); _check_proximity_combat()
	if teams_alive == 1: _finish()
	else: updated.emit(snapshot())

func toggle_pause() -> void: paused = not paused; updated.emit(snapshot())
func set_speed(value: float) -> void: speed = value; paused = false; updated.emit(snapshot())

func snapshot() -> Dictionary:
	return {"snapshot_version":replay_version,"snapshot_id":"%s-s%05d" % [match_id,event_sequence],"match_id":match_id,"match_seed":match_seed,"event_sequence":event_sequence,"running":running,"paused":paused,"speed":speed,"elapsed":elapsed,"duration":duration,"phase":phase,"zone_number":zone_number,"blue_radius":blue_radius,"zone_center":[zone_center.x,zone_center.y],"target_zone_center":[target_zone_center.x,target_zone_center.y],"target_zone_radius":target_zone_radius,"blue_damage":blue_damage,"red_zone":{"active":bool(red_zone.get("active",false)),"center":[Vector2(red_zone.get("center",Vector2(0.5,0.5))).x,Vector2(red_zone.get("center",Vector2(0.5,0.5))).y],"radius":float(red_zone.get("radius",0.0)),"ends_at":float(red_zone.get("ends_at",0.0)),"shells":int(red_zone.get("shells",0))},"flight_path":[[flight_path[0].x,flight_path[0].y],[flight_path[1].x,flight_path[1].y]],"plane_progress":plane_progress,"teams_alive":teams_alive,"players_alive":players_alive,"placement":placement,"kills":kills,"damage":damage,"morale":morale,"formation":formation,"strategy":strategy,"coach_plan":coach_plan.duplicate(true),"contacts":contacts.duplicate(true),"detection_attempts":detection_attempts,"confirmed_contacts":confirmed_contacts,"kill_feed":kill_feed.duplicate(true),"effects":effects.duplicate(true),"bullet_trails":bullet_trails.duplicate(true),"scoreboard":scoreboard.duplicate(true),"winner":winner.duplicate(true),"resources":resources.duplicate(true),"roster":roster.duplicate(true),"team_positions":team_positions.duplicate(true),"timeline":timeline.duplicate(true),"map_id":map_id,"map_data":map_data.duplicate(true),"map_profile":{"size_km":catalog.map_size_km(map_data),"loot_density_factor":catalog.loot_density_factor(map_data),"vehicle_need_factor":catalog.vehicle_need_factor(map_data),"loot_sources":catalog.loot_sources(map_data).size()}}

func _make_flight_path() -> void:
	var side := randi_range(0, 3); var a: Vector2; var b: Vector2
	if side == 0: a = Vector2(0, randf_range(0.08,0.92)); b = Vector2(1, randf_range(0.08,0.92))
	elif side == 1: a = Vector2(1, randf_range(0.08,0.92)); b = Vector2(0, randf_range(0.08,0.92))
	elif side == 2: a = Vector2(randf_range(0.08,0.92),0); b = Vector2(randf_range(0.08,0.92),1)
	else: a = Vector2(randf_range(0.08,0.92),1); b = Vector2(randf_range(0.08,0.92),0)
	flight_path = [a,b]

func _make_first_zone() -> void:
	zone_center = Vector2(0.5,0.5); shrink_origin_center = zone_center; target_zone_center = Vector2(randf_range(0.30,0.70),randf_range(0.30,0.70))

func _choose_drop_style(player: Dictionary, index: int) -> String:
	if coach_plan.drop_policy == "HOT_CONTEST": return "HOT_DROP"
	if coach_plan.drop_policy == "SPLIT_LOOT": return "LOOT_ROUTE" if index >= 2 else "CENTER"
	if coach_plan.drop_policy == "FIXED_SAFE": return "LOOT_ROUTE"
	if str(player.get("role", "")) in ["Entry", "Fragger"] and index < 2: return "HOT_DROP"
	if str(player.get("role", "")) in ["Scout", "Support"] or index >= 3: return "LOOT_ROUTE"
	return "CENTER"

func _choose_destination(style: String, regions: Array, index: int) -> Vector2:
	if regions.is_empty(): return Vector2(0.5,0.5)
	if style == "LOOT_ROUTE":
		var safe_points: Array = map_data.get("points", []).filter(func(point): return bool(point.get("enabled", true)))
		if not safe_points.is_empty():
			safe_points.sort_custom(func(a,b): return float(a.get("safety", 0.0)) > float(b.get("safety", 0.0)))
			var safe_point: Dictionary = safe_points[index % mini(2, safe_points.size())]
			return Vector2(float(safe_point.position[0]), float(safe_point.position[1]))
	var sorted := regions.duplicate()
	if style == "HOT_DROP": sorted.sort_custom(func(a,b): return float(a.hotness) > float(b.hotness))
	elif style == "LOOT_ROUTE": sorted.sort_custom(func(a,b): return float(a.hotness) < float(b.hotness))
	else: sorted.sort_custom(func(a,b): return Vector2(float(a.position[0]),float(a.position[1])).distance_to(Vector2(0.5,0.5)) < Vector2(float(b.position[0]),float(b.position[1])).distance_to(Vector2(0.5,0.5)))
	var chosen: Dictionary = sorted[index % mini(2, sorted.size())]
	var compounds: Array = map_data.get("compounds", []).filter(func(compound): return str(compound.get("poi_id", "")) == str(chosen.id))
	if not compounds.is_empty():
		compounds.sort_custom(func(a,b): return float(a.get("hotness", 0.0)) > float(b.get("hotness", 0.0)))
		var compound: Dictionary = compounds[index % compounds.size()]
		return Vector2(float(compound.position[0]), float(compound.position[1]))
	return Vector2(float(chosen.position[0]),float(chosen.position[1]))

func _update_deployment(scaled_delta: float) -> void:
	plane_progress = clampf(elapsed / 75.0,0.0,1.0)
	var plane_pos: Vector2 = flight_path[0].lerp(flight_path[1],plane_progress)
	for i in roster.size():
		var p: Dictionary = roster[i]
		if p.state == "IN_PLANE":
			p.position = plane_pos
			if elapsed >= float(p.jump_time):
				p.state = "AIRBORNE"; p.jump_position = plane_pos
				var desired: Vector2 = Vector2(p.destination); var offset := desired - plane_pos
				if offset.length() > PARACHUTE_MAX_RANGE: desired = plane_pos + offset.normalized() * PARACHUTE_MAX_RANGE
				p.destination = Vector2(clampf(desired.x,0.03,0.97),clampf(desired.y,0.03,0.97)); var flight_distance := plane_pos.distance_to(p.destination); p.land_time = elapsed + 8.0 + flight_distance * lerpf(82.0,58.0,float(p.get("landing_speed",60))/100.0)
				_emit_event("jump","%s mở dù theo plan %s — tầm bay %dm." % [p.name,p.drop_style,roundi(flight_distance*8000.0)],"DROP")
		elif p.state == "AIRBORNE":
			var total := maxf(1.0,float(p.land_time)-float(p.jump_time)); var progress := clampf(1.0-(float(p.land_time)-elapsed)/total,0.0,1.0); var eased := 1.0-pow(1.0-progress,1.65); p.position = Vector2(p.jump_position).lerp(Vector2(p.destination),eased)
			if elapsed >= float(p.land_time): p.state = "LOOTING"; p.position = p.destination; p.loot_until = elapsed + randf_range(24.0,38.0); p.next_loot_at = elapsed; _emit_event("land","%s đã tiếp đất và bắt đầu loot." % p.name,"LOOT")
		elif p.state == "LOOTING" and elapsed >= float(p.get("loot_until", elapsed + 1.0)):
			p.state = "ALIVE"; p.position = p.position.lerp(_regroup_point(), clampf((elapsed-72.0)/90.0,0.0,1.0))
		if p.state=="LOOTING" and elapsed>=float(p.get("next_loot_at",0.0)): p=_loot_player(p); p.next_loot_at=elapsed+_loot_interval(p)
		roster[i] = p
	for i in team_positions.size():
		var t: Dictionary = team_positions[i]
		if i == 0:
			for m in mini(TEAM_SIZE, roster.size()):
				t.members[m].position = roster[m].position; t.members[m].state = roster[m].state; t.members[m].health = roster[m].health; t.members[m].loadout = roster[m].loadout
		else:
			for m in t.members.size():
				var member: Dictionary = t.members[m]
				if member.state == "DEAD": continue
				if member.state == "IN_PLANE":
					member.position = plane_pos
					if elapsed >= float(member.jump_time):
						member.state = "AIRBORNE"; member.jump_position = plane_pos
						var offset: Vector2 = Vector2(member.destination) - plane_pos
						if offset.length() > PARACHUTE_MAX_RANGE: member.destination = plane_pos + offset.normalized() * PARACHUTE_MAX_RANGE
						member.land_time = elapsed + 8.0 + plane_pos.distance_to(Vector2(member.destination)) * lerpf(82.0,58.0,float(member.get("landing_speed",60))/100.0)
				elif member.state == "AIRBORNE":
					var total := maxf(1.0,float(member.land_time)-float(member.jump_time)); var progress := clampf(1.0-(float(member.land_time)-elapsed)/total,0.0,1.0)
					member.position = Vector2(member.jump_position).lerp(Vector2(member.destination),1.0-pow(1.0-progress,1.65))
					if elapsed >= float(member.land_time): member.state = "LOOTING"; member.position = member.destination; member.loot_until = elapsed + randf_range(24.0,38.0); member.next_loot_at = elapsed
				elif member.state in ["LOOTING","ALIVE","WALKING","DRIVING","SWIMMING"]:
					if member.state=="LOOTING" and elapsed < float(member.get("loot_until", elapsed + 1.0)):
						if elapsed>=float(member.get("next_loot_at",0.0)): member=_loot_player(member); member.next_loot_at=elapsed+_loot_interval(member)
						t.members[m]=member; continue
					var move_target := Vector2(member.move_target)
					if zone_number>0 and Vector2(member.position).distance_to(target_zone_center)>maxf(0.02,target_zone_radius*0.88): move_target=_tactical_zone_target(i)+_formation_offset(m,i); member.move_target=move_target
					if Vector2(member.position).distance_to(move_target) < 0.018:
						move_target = _tactical_zone_target(i) if zone_number > 0 else Vector2(t.target)
						move_target += _formation_offset(m,i) + Vector2(randf_range(-0.025,0.025),randf_range(-0.025,0.025)); member.move_target = move_target
					var use_vehicle := elapsed < float(member.get("vehicle_until",0.0)) or (elapsed > 110.0 and _can_acquire_vehicle(Vector2(member.position), 0.0008 * scaled_delta))
					if use_vehicle and elapsed >= float(member.get("vehicle_until",0.0)): member.vehicle_until=elapsed+randf_range(18.0,42.0); member.route_target=member.destination
					if use_vehicle:
						member.vehicle_fuel=maxf(0.0,float(member.get("vehicle_fuel",100.0))-scaled_delta*0.035)
						member.vehicle_durability=maxf(0.0,float(member.get("vehicle_durability",100.0))-scaled_delta*0.004*float(member.get("route_risk",0.0)+1.0))
						if member.vehicle_fuel <= 0.0 or member.vehicle_durability <= 0.0: member.vehicle_until=0.0; use_vehicle=false; _emit_event("vehicle","Vehicle route ended: fuel or durability depleted.","VEHICLE")
					member.state = "DRIVING" if use_vehicle else "WALKING"; member.transport = "vehicle" if use_vehicle else "foot"
					var member_terrain:=_nearest_terrain(Vector2(member.position)); var member_profile:Dictionary=catalog.movement_profile(map_data,member_terrain,"vehicle" if use_vehicle else "walk",Vector2(member.position)); var brush_profile:Dictionary=catalog.terrain_profile_at(map_data,Vector2(member.position)); if bool(brush_profile.inside) and not use_vehicle: member_profile.speed_multiplier=float(brush_profile.movement_multiplier)
					if not bool(member_profile.allowed): use_vehicle=false; member.state="SWIMMING" if member_terrain=="water" else "WALKING"; member.transport="swim" if member_terrain=="water" else "foot"; member_profile=catalog.movement_profile(map_data,member_terrain,"walk",Vector2(member.position)); if bool(brush_profile.inside): member_profile.speed_multiplier=float(brush_profile.movement_multiplier)
					var urgency:=1.0+float(zone_number)*0.22+(1.4 if zone_number>=5 else 0.0); var move_speed := (0.0018 if use_vehicle else 0.00068)*urgency
					member.position = Vector2(member.position).move_toward(move_target, move_speed * float(member_profile.get("speed_multiplier",1.0)) * scaled_delta)
				t.members[m] = member
		var living: Array = t.members.filter(func(member): return str(member.state) != "DEAD")
		if not living.is_empty():
			var center := Vector2.ZERO; for member in living: center += Vector2(member.position)
			t.position = center / living.size()
		t.alive = living.size(); team_positions[i] = t
	if elapsed < 75.0: phase = "FLIGHT / DROP"
	elif elapsed < 80.0: phase = "REGROUP"

func delta_for_lerp() -> float: return 0.035 * speed
func _regroup_point() -> Vector2: return Vector2(0.48,0.62)

func _ai_plan_for_team(team_index: int) -> Dictionary:
	var profiles := [
		{"positioning":"CENTER_HOLD","spacing":"TIGHT","flank":"NONE","focus_fire":"FOCUS","target_priority":"CLOSEST","combat_range":"CLOSE","information":"IMMEDIATE","resource":"MINIMAL"},
		{"positioning":"EDGE_HOLD","spacing":"WIDE","flank":"PINCER","focus_fire":"FOCUS","target_priority":"ISOLATED","combat_range":"MID","information":"INFO_FIRST","resource":"FULL"},
		{"positioning":"REAR","spacing":"NORMAL","flank":"SINGLE","focus_fire":"SPREAD","target_priority":"FRAGGER","combat_range":"LONG","information":"SCOUT_FIRST","resource":"HEAL"},
		{"positioning":"FORWARD","spacing":"WIDE","flank":"DOUBLE","focus_fire":"FOCUS","target_priority":"LOWEST_HP","combat_range":"ADAPTIVE","information":"CONFIRM_PUSH","resource":"UTILITY"}
	]
	var plan := TACTICAL_DEFAULTS.duplicate(true)
	for key in profiles[team_index % profiles.size()]: plan[key] = profiles[team_index % profiles.size()][key]
	return plan

func _plan_for_team(team_index: int) -> Dictionary:
	if team_index == 0: return coach_plan
	if team_index >= 0 and team_index < team_positions.size(): return team_positions[team_index].get("ai_plan", TACTICAL_DEFAULTS)
	return _ai_plan_for_team(team_index)

func _spacing_value(team_index: int) -> float:
	return float({"TIGHT":0.009,"NORMAL":0.018,"WIDE":0.032,"EXTREME":0.052}.get(str(_plan_for_team(team_index).get("spacing","NORMAL")),0.018))

func _formation_offset(member: int, team_index: int) -> Vector2:
	var spacing := _spacing_value(team_index)
	return [Vector2(-spacing,-spacing),Vector2(spacing,-spacing),Vector2(-spacing,spacing),Vector2(spacing,spacing)][member]

func _tactical_zone_target(team_index: int) -> Vector2:
	var plan := _plan_for_team(team_index); var center := target_zone_center
	var team_position := Vector2(team_positions[team_index].get("position", center)) if team_index >= 0 and team_index < team_positions.size() else center
	var direction := (team_position - center).normalized()
	if direction.length_squared() < 0.01: direction = Vector2.RIGHT.rotated(float(team_index) * 1.71)
	var positioning := str(plan.get("positioning","CENTER_HOLD"))
	if positioning == "EDGE_HOLD": center += direction * maxf(0.02, target_zone_radius * 0.68)
	elif positioning == "FORWARD": center -= direction * maxf(0.015, target_zone_radius * 0.30)
	elif positioning == "REAR": center += direction * maxf(0.015, target_zone_radius * 0.34)
	return Vector2(clampf(center.x,0.04,0.96),clampf(center.y,0.04,0.96))

func _update_player_movement(scaled_delta: float) -> void:
	if elapsed < 70.0: return
	for i in roster.size():
		var p: Dictionary = roster[i]
		if p.state not in ["ALIVE","LOOTING","WALKING","DRIVING","SWIMMING"]: continue
		if p.state == "LOOTING" and elapsed < float(p.get("loot_until", elapsed + 1.0)): continue
		var target: Vector2 = Vector2(p.move_target)
		if zone_number>0 and Vector2(p.position).distance_to(target_zone_center)>maxf(0.02,target_zone_radius*0.88): target=_tactical_zone_target(0)+_formation_offset(i,0); p.move_target=target
		if Vector2(p.position).distance_to(target) < 0.025:
			target = _tactical_zone_target(0) if zone_number > 0 else _regroup_point(); target += Vector2(randf_range(-0.04,0.04),randf_range(-0.04,0.04)); p.move_target = target
		var terrain := _nearest_terrain(Vector2(p.position)); var keep_vehicle := elapsed<float(p.get("vehicle_until",0.0)); var transport := "vehicle" if keep_vehicle or (int(resources.fuel)>10 and _can_acquire_vehicle(Vector2(p.position), 0.002*scaled_delta)) else "walk"; var profile: Dictionary = catalog.movement_profile(map_data,terrain,transport,Vector2(p.position)); var brush_profile:Dictionary=catalog.terrain_profile_at(map_data,Vector2(p.position)); if bool(brush_profile.inside) and transport!="vehicle": profile.speed_multiplier=float(brush_profile.movement_multiplier)
		if transport=="vehicle" and not keep_vehicle: p.vehicle_until=elapsed+randf_range(18.0,42.0)
		if transport=="vehicle" and profile.allowed: p.state="DRIVING"; p.transport="vehicle"; resources.fuel=maxi(0,int(resources.fuel)-roundi(scaled_delta*0.04))
		elif terrain=="water": p.state="SWIMMING"; p.transport="swim"
		else: p.state="WALKING"; p.transport="foot"
		var urgency:=1.0+float(zone_number)*0.22+(1.4 if zone_number>=5 else 0.0); var base_speed := (0.00075 if p.state=="WALKING" else 0.00038 if p.state=="SWIMMING" else 0.0022)*urgency
		p.position = Vector2(p.position).move_toward(target,base_speed*float(profile.get("speed_multiplier",1.0))*scaled_delta); roster[i]=p

func _can_acquire_vehicle(position: Vector2, base_chance: float) -> bool:
	var need_factor := catalog.vehicle_need_factor(map_data) * float(simulation_overrides.get("vehicle_density_scale", 1.0))
	var road:Dictionary=catalog.road_profile(map_data,position)
	if float(road.get("distance",99.0))<=float(road.get("width",0.025))*0.6 and float(road.get("vehicle_spawn_chance",0.0))>0.0:
		if randf()<base_chance*need_factor*float(road.vehicle_spawn_chance): return true
	for node in map_data.get("transport_nodes", []):
		if position.distance_to(Vector2(float(node.position[0]), float(node.position[1]))) <= 0.065:
			return randf() < base_chance * need_factor * float(node.get("spawn_chance", 0.5))
	return false

func _update_player_actions(scaled_delta: float) -> void:
	_update_squad_actions(roster,"MR",scaled_delta)
	_resolve_squad_wipe(roster,"MR")
	for team_index in range(1,team_positions.size()):
		var team: Dictionary=team_positions[team_index]; var members: Array=team.members
		_update_squad_actions(members,str(team.tag),scaled_delta); _resolve_squad_wipe(members,str(team.tag)); team.members=members; team.alive=members.filter(func(member): return str(member.state)!="DEAD").size(); team_positions[team_index]=team
	if elapsed>=next_action_check:
		next_action_check=elapsed+randf_range(5.0,8.0)
		_decide_squad_actions(roster,"MR")
		for team_index in range(1,team_positions.size()):
			var team: Dictionary=team_positions[team_index]; var members: Array=team.members
			_decide_squad_actions(members,str(team.tag)); team.members=members; team_positions[team_index]=team

func _update_squad_actions(squad: Array, team_tag: String, scaled_delta: float) -> void:
	for player_index in squad.size():
		var player: Dictionary=squad[player_index]
		if str(player.state) in ["DEAD","IN_PLANE","AIRBORNE"]: continue
		if str(player.state)=="KNOCKED":
			player.dbno=maxf(0.0,float(player.get("dbno",100.0))-scaled_delta*0.72)
			if float(player.dbno)<=0.0: _finish_squad_member(squad,player_index,"DBNO","BLEED OUT")
			else: squad[player_index]=player
			continue
		var boost_value:=maxf(0.0,float(player.get("boost",0.0))-scaled_delta*0.16)
		if boost_value>0.0 and int(player.health)<100: player.health=mini(100,int(player.health)+roundi(scaled_delta*(0.10+boost_value/350.0)))
		player.boost=boost_value
		if str(player.get("action",""))=="REVIVING" and not _revive_target_in_range(squad,player):
			_cancel_player_action(player); squad[player_index]=player
			_emit_event("revive_interrupted","%s không còn ở cạnh đồng đội; revive bị hủy." % player.name,"REVIVE")
		elif str(player.get("action",""))!="" and elapsed>=float(player.get("action_end",0.0)):
			_complete_player_action(squad,player_index,team_tag)
		else: squad[player_index]=player

func _decide_squad_actions(squad: Array, team_tag: String) -> void:
	var knocked_indices: Array=[]
	for player_index in squad.size(): if str(squad[player_index].state)=="KNOCKED": knocked_indices.append(player_index)
	if not knocked_indices.is_empty():
		for player_index in squad.size():
			var rescuer: Dictionary=squad[player_index]
			if str(rescuer.state) not in ["ALIVE","WALKING","LOOTING","DRIVING"]: continue
			var target_index: int=knocked_indices[0]; var communication:=int(rescuer.get("communication",60)); var mistake:=_mistake_roll(rescuer,0.28)
			if Vector2(rescuer.position).distance_to(Vector2(squad[target_index].position))<=REVIVE_RANGE and (randf()<0.45+communication/220.0) and not mistake:
				_start_action(squad,player_index,"REVIVING","Revive",8.0,str(squad[target_index].name),team_tag)
				return
	for player_index in squad.size():
		var player: Dictionary=squad[player_index]
		if str(player.state) not in ["ALIVE","WALKING","LOOTING","DRIVING","SWIMMING"] or str(player.get("action",""))!="": continue
		var hp:=int(player.health); var loadout: Dictionary=player.loadout; var mistake:=_mistake_roll(player,0.24)
		if hp<100 and _try_heal(squad,player_index,team_tag,mistake): continue
		var should_boost:=float(player.get("boost",0.0))<20.0 and (elapsed>150.0 or mistake)
		if should_boost: _try_boost(squad,player_index,team_tag,mistake)

func _try_heal(squad:Array,player_index:int,team_tag:String,mistake:bool)->bool:
	var player:Dictionary=squad[player_index]; var loadout:Dictionary=player.loadout; var hp:=int(player.health); var item:=""
	if mistake and hp>=55 and int(loadout.get("first_aid",0))>0: item="First Aid Kit"
	elif hp<=35 and int(loadout.get("medkit",0))>0: item="Med Kit"
	elif hp<75 and int(loadout.get("first_aid",0))>0: item="First Aid Kit"
	elif hp<75 and int(loadout.get("bandage",0))>0: item="Bandage"
	if item.is_empty(): return false
	_start_action(squad,player_index,"HEALING",item,float(HEAL_ITEMS[item].use_time),"",team_tag)
	return true

func _try_boost(squad:Array,player_index:int,team_tag:String,mistake:bool)->bool:
	var loadout:Dictionary=squad[player_index].loadout; var item:=""
	if mistake and elapsed<150.0 and int(loadout.get("adrenaline",0))>0: item="Adrenaline Syringe"
	elif int(loadout.get("energy_drink",0))>0: item="Energy Drink"
	elif int(loadout.get("painkiller",0))>0: item="Painkiller"
	elif int(loadout.get("adrenaline",0))>0: item="Adrenaline Syringe"
	if item.is_empty(): return false
	_start_action(squad,player_index,"BOOSTING",item,float(BOOST_ITEMS[item].use_time),"",team_tag)
	return true

func _start_action(squad:Array,player_index:int,state_name:String,item:String,use_time:float,target:String,team_tag:String)->void:
	var player:Dictionary=squad[player_index]; player.previous_state=player.state; player.state=state_name; player.action=state_name; player.action_item=item; player.action_target=target; player.action_end=elapsed+use_time; squad[player_index]=player
	_emit_event("player_action","%s %s: %s%s." % [team_tag,player.name,item," → "+target if not target.is_empty() else ""],"ACTION")

func _complete_player_action(squad:Array,player_index:int,team_tag:String)->void:
	var player:Dictionary=squad[player_index]; var action:=str(player.action); var item:=str(player.action_item); var loadout:Dictionary=player.loadout
	if action=="HEALING":
		var rule:Dictionary=HEAL_ITEMS[item]
		if rule.has("heal_to"): player.health=maxi(int(player.health),int(rule.heal_to))
		else: player.health=mini(int(rule.cap),int(player.health)+int(rule.heal))
		player.health_float=float(player.health); var heal_key: String=str({"Bandage":"bandage","First Aid Kit":"first_aid","Med Kit":"medkit"}[item]); loadout[heal_key]=maxi(0,int(loadout.get(heal_key,0))-1)
	elif action=="BOOSTING":
		player.boost=minf(100.0,float(player.boost)+float(BOOST_ITEMS[item].boost)); var boost_key: String=str({"Energy Drink":"energy_drink","Painkiller":"painkiller","Adrenaline Syringe":"adrenaline"}[item]); loadout[boost_key]=maxi(0,int(loadout.get(boost_key,0))-1)
	elif action=="REVIVING":
		for target_index in squad.size():
			if str(squad[target_index].name)==str(player.action_target) and str(squad[target_index].state)=="KNOCKED" and Vector2(player.position).distance_to(Vector2(squad[target_index].position))<=REVIVE_RANGE: squad[target_index].state="ALIVE"; squad[target_index].health=20; squad[target_index].health_float=20.0; squad[target_index].dbno=0.0; squad[target_index].action=""; _emit_event("revive","%s cứu thành công %s." % [player.name,squad[target_index].name],"REVIVE")
	player.loadout=loadout; player.state="ALIVE" if str(player.get("previous_state","ALIVE")) not in ["LOOTING","WALKING"] else player.previous_state; player.action=""; player.action_item=""; player.action_target=""; squad[player_index]=player

func _revive_target_in_range(squad:Array,player:Dictionary)->bool:
	for target in squad:
		if str(target.get("name",""))==str(player.get("action_target","")):
			return str(target.get("state",""))=="KNOCKED" and Vector2(player.position).distance_to(Vector2(target.position))<=REVIVE_RANGE
	return false

func _cancel_player_action(player:Dictionary)->void:
	player.state="ALIVE" if str(player.get("previous_state","ALIVE")) not in ["LOOTING","WALKING"] else player.previous_state
	player.action=""; player.action_item=""; player.action_target=""; player.action_end=0.0

func _mistake_roll(player:Dictionary,base_chance:float)->bool:
	var decision_score:float=(float(player.get("discipline",60))+float(player.get("game_sense",60))+float(player.get("loot_efficiency",60)))/3.0
	return randf()<clampf(base_chance-decision_score*0.0022,0.025,0.20)

func _update_effects(scaled_delta: float) -> void:
	for i in range(effects.size()-1,-1,-1): effects[i].ttl=float(effects[i].ttl)-scaled_delta; if float(effects[i].ttl)<=0.0: effects.remove_at(i)
	for i in range(bullet_trails.size()-1,-1,-1): bullet_trails[i].ttl=float(bullet_trails[i].ttl)-scaled_delta; if float(bullet_trails[i].ttl)<=0.0: bullet_trails.remove_at(i)

func _update_airdrops() -> void:
	if elapsed < next_airdrop_at or teams_alive <= 2: return
	airdrops_spawned += 1
	next_airdrop_at = elapsed + randf_range(210.0, 280.0)
	var radius := maxf(0.035, blue_radius * 0.72)
	var drop_position := zone_center + Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * sqrt(randf()) * radius
	drop_position = Vector2(clampf(drop_position.x, 0.04, 0.96), clampf(drop_position.y, 0.04, 0.96))
	effects.append({"type":"airdrop","position":drop_position,"radius":0.018,"ttl":150.0,"owner":"AIRDROP","index":airdrops_spawned})
	_emit_event("airdrop", "Airdrop #%d landed inside the active circle." % airdrops_spawned, "AIRDROP")
	var nearest_player: Dictionary = {}
	var nearest_distance := 999.0
	for player in roster:
		if str(player.get("state", "")) in ["DEAD","KNOCKED","IN_PLANE","AIRBORNE"]: continue
		var distance := Vector2(player.position).distance_to(drop_position)
		if distance < nearest_distance: nearest_distance = distance; nearest_player = player
	if not nearest_player.is_empty() and nearest_distance <= 0.13 and str(coach_plan.get("engagement", "SELECTIVE")) != "AVOID":
		var loadout: Dictionary = nearest_player.loadout
		loadout.primary = "AWM"; loadout.primary_ammo = 3; loadout.helmet = "Lv.3"; loadout.vest = "Lv.3"; loadout.helmet_durability = 90.0; loadout.vest_durability = 120.0; nearest_player.loadout = loadout
		_store_team_member(team_positions[0], nearest_player); roster = team_positions[0].members
		_emit_event("airdrop_loot", "%s secured AWM and level-3 armor from airdrop #%d." % [nearest_player.name, airdrops_spawned], "AIRDROP")

func _update_zone_state() -> void:
	var active_index := -1
	for i in ZONES.size(): if elapsed >= float(ZONES[i].reveal): active_index = i
	if active_index < 0: return
	var z: Dictionary = ZONES[active_index]
	if zone_number != int(z.number):
		zone_number = int(z.number); target_zone_radius = float(z.radius); blue_damage = int(z.damage); zone_severity=str(z.severity)
		if zone_number > 1:
			zone_center = target_zone_center
			var margin := maxf(0.0, blue_radius - target_zone_radius)
			target_zone_center = zone_center + Vector2(randf_range(-margin,margin),randf_range(-margin,margin)) * 0.45
			target_zone_center.x = clampf(target_zone_center.x,0.08,0.92); target_zone_center.y = clampf(target_zone_center.y,0.08,0.92)
		shrink_origin_center = zone_center
		_emit_event("zone_reveal","Bo %d xuất hiện. Blue zone chờ trước khi co." % zone_number,"ZONE")
	var start_radius := 0.78 if active_index == 0 else float(ZONES[active_index-1].radius)
	if elapsed < float(z.shrink_start): blue_radius = start_radius; phase = "ZONE %d — WAIT" % zone_number
	else:
		var progress := clampf((elapsed-float(z.shrink_start))/(float(z.shrink_end)-float(z.shrink_start)),0.0,1.0)
		blue_radius = lerpf(start_radius,target_zone_radius,progress); zone_center = shrink_origin_center.lerp(target_zone_center, progress); phase = "ZONE %d — SHRINK %d%%" % [zone_number,roundi(progress*100.0)]
		if progress >= 1.0 and zone_number < 5: phase = "ZONE %d CLOSED" % zone_number
		elif progress >= 1.0: phase = "BLUE ZONE — 100% MAP"

func _apply_blue_damage(scaled_delta: float) -> void:
	if zone_number == 0 or elapsed < float(ZONES[zone_number-1].shrink_start): return
	_apply_blue_to_squad(roster,"MR",scaled_delta)
	_resolve_squad_wipe(roster,"MR")
	for team_index in range(1,team_positions.size()):
		var team:Dictionary=team_positions[team_index]; var members:Array=team.members
		_apply_blue_to_squad(members,str(team.tag),scaled_delta); _resolve_squad_wipe(members,str(team.tag)); team.members=members; team.alive=members.filter(func(member): return str(member.state)!="DEAD").size(); team_positions[team_index]=team
	if not team_positions.is_empty(): team_positions[0].alive=roster.filter(func(member): return str(member.state)!="DEAD").size()
	teams_alive=team_positions.filter(func(team): return int(team.alive)>0).size()
	if teams_alive==0: _resolve_final_tick_tie()
	_update_scoreboard()

func _resolve_final_tick_tie()->void:
	if team_positions.is_empty(): return
	var winner_index := -1; var best_score := -INF
	for team_index in team_positions.size():
		var team: Dictionary = team_positions[team_index]; var combat_score := float(team.get("kills", 0)) * 8.0
		for member in team.get("members", []): combat_score += float(member.get("damage", 0)) * 0.008 + float(member.get("aim", 60)) * 0.025 + float(member.get("game_sense", 60)) * 0.02
		combat_score += randf_range(0.0, 220.0)
		if combat_score > best_score: best_score = combat_score; winner_index = team_index
	if winner_index < 0: return
	if winner_index==0 and not roster.is_empty(): roster[0].state="ALIVE"; roster[0].health=1; roster[0].dbno=0.0; team_positions[0].alive=1
	else: team_positions[winner_index].members[0].state="ALIVE"; team_positions[winner_index].members[0].health=1; team_positions[winner_index].members[0].dbno=0.0; team_positions[winner_index].alive=1
	teams_alive=1; players_alive=maxi(1,players_alive); _emit_event("final_tiebreak","Final Blue tick đồng thời: ưu tiên đội có nhiều kill hơn để xác định top 1.","RESULT")

func _apply_blue_to_squad(squad:Array,team_tag:String,scaled_delta:float)->void:
	var zone_scale := float(simulation_overrides.get("zone_damage_scale", 1.0))
	for player_index in squad.size():
		var player:Dictionary=squad[player_index]
		if str(player.state) in ["DEAD","IN_PLANE","AIRBORNE"]: continue
		if Vector2(player.position).distance_to(zone_center)<=blue_radius: continue
		if str(player.state)=="KNOCKED":
			player.dbno=maxf(0.0,float(player.get("dbno",100.0))-float(blue_damage)*zone_scale*scaled_delta*0.42)
			if float(player.dbno)<=0.0: _finish_squad_member(squad,player_index,"BLUE ZONE","BLUE")
			else: squad[player_index]=player
		else:
			var health_float:=float(player.get("health_float",player.health))-float(blue_damage)*zone_scale*scaled_delta*0.55; player.health_float=health_float; player.health=maxi(0,ceili(health_float))
			if str(player.state)=="REVIVING" and int(player.health)<75: player.state="ALIVE"; player.action=""; player.action_item=""; _emit_event("revive_interrupted","%s bị Blue Zone ngắt revive." % player.name,"BLUE")
			squad[player_index]=player
			if int(player.health)<=0: _knock_squad_member(squad,player_index,"BLUE ZONE",team_tag,"BLUE")

func _update_red_zone(_scaled_delta: float) -> void:
	if not bool(red_zone.get("active", false)):
		if elapsed < float(red_zone.get("next_at", 9999.0)) or teams_alive <= 2: return
		# The artillery area must sit inside the active circle. This keeps the
		# gameplay hazard and the observer geometry aligned instead of spawning a
		# disconnected red ellipse at an arbitrary map coordinate.
		var red_radius := minf(randf_range(0.075,0.14), maxf(0.035, blue_radius * 0.42))
		var max_offset := maxf(0.0, blue_radius - red_radius - 0.012)
		var direction := Vector2.RIGHT.rotated(randf_range(0.0, TAU))
		var distance := sqrt(randf()) * max_offset
		red_zone.active = true; red_zone.center = zone_center + direction * distance; red_zone.radius = red_radius; red_zone.ends_at = elapsed + randf_range(24.0,38.0); red_zone.shells = 0
		_emit_event("red_zone_start", "RED ZONE xuất hiện — tránh khu vực pháo kích.", "RED_ZONE")
	if elapsed >= float(red_zone.get("ends_at", 0.0)):
		red_zone.active = false; red_zone.next_at = elapsed + randf_range(135.0,210.0); _emit_event("red_zone_end", "Red Zone kết thúc.", "RED_ZONE"); return
	if randf() > 0.10: return
	red_zone.shells = int(red_zone.get("shells", 0)) + 1
	var center := Vector2(red_zone.get("center", Vector2(0.5,0.5))) + Vector2(randf_range(-0.045,0.045), randf_range(-0.045,0.045))
	effects.append({"type":"red_shell","position":center,"radius":0.008,"ttl":0.65,"owner":"RED ZONE"})
	for team_index in team_positions.size():
		var team: Dictionary = team_positions[team_index]
		for player_index in team.members.size():
			var player: Dictionary = team.members[player_index]
			if str(player.get("state", "")) in ["DEAD", "IN_PLANE", "AIRBORNE"] or Vector2(player.position).distance_to(center) > 0.032: continue
			_apply_damage(team.members,player_index,140.0,"RED_ZONE","RED ZONE",str(team.tag),"RED ZONE")
			if team_index == 0: roster = team.members
		team.alive = team.members.filter(func(member): return str(member.state) != "DEAD").size(); team_positions[team_index] = team
	_update_scoreboard()

func _knock_squad_member(squad:Array,player_index:int,actor:String,team_tag:String,weapon:String="—",distance_m:float=-1.0)->void:
	var player:Dictionary=squad[player_index]
	if str(player.state) in ["KNOCKED","DEAD"]: return
	player.health=0; player.health_float=0.0; player.dbno=100.0; player.state="KNOCKED"; player.action=""; player.action_item=""; player.knocked_at=elapsed; player.knocked_distance_m=distance_m; squad[player_index]=player
	_push_kill_feed(actor,str(player.name),weapon,"KNOCK",distance_m); _emit_event("knock","%s [%s] knock %s%s." % [actor,weapon,player.name," ở %dm"%roundi(distance_m) if distance_m>=0.0 else ""],"KILLFEED")

func _finish_squad_member(squad:Array,player_index:int,actor:String,cause:String="FLUSH",weapon:String="—",distance_m:float=-1.0)->void:
	var player:Dictionary=squad[player_index]
	if str(player.state)=="DEAD": return
	player.health=0; player.health_float=0.0; player.dbno=0.0; player.state="DEAD"; player.action=""; squad[player_index]=player; players_alive=maxi(0,players_alive-1)
	if distance_m<0.0: distance_m=float(player.get("knocked_distance_m",-1.0))
	_push_kill_feed(actor,str(player.name),weapon,cause,distance_m); _emit_event("finish","%s bị loại hoàn toàn (%s%s)." % [player.name,cause," • %dm"%roundi(distance_m) if distance_m>=0.0 else ""],"KILLFEED")

func _apply_damage(squad:Array,player_index:int,amount:float,cause:String,actor:String,team_tag:String,weapon:String="—",headshot:bool=false,distance_m:float=-1.0)->Dictionary:
	if player_index < 0 or player_index >= squad.size(): return {"applied":0,"absorbed":0,"knocked":false,"eliminated":false}
	var player:Dictionary=squad[player_index]
	if cause == "WEAPON":
		amount *= float(simulation_overrides.get("weapon_damage_scale", 1.0))
		amount *= float(simulation_overrides.get("weapon_modifiers", {}).get(weapon, 1.0))
	if str(player.get("state", "")) in ["DEAD","IN_PLANE","AIRBORNE"]: return {"applied":0,"absorbed":0,"knocked":false,"eliminated":false}
	if str(player.state)=="KNOCKED":
		player.dbno=maxf(0.0,float(player.get("dbno",100.0))-amount); squad[player_index]=player
		if float(player.dbno)<=0.0 or cause in ["VEHICLE","FRAG","FIRE","RED_ZONE"]: _finish_squad_member(squad,player_index,actor,cause,weapon,distance_m); return {"applied":roundi(amount),"absorbed":0,"knocked":false,"eliminated":true}
		return {"applied":roundi(amount),"absorbed":0,"knocked":false,"eliminated":false}
	var loadout:Dictionary=player.get("loadout", {})
	var armor_key := "helmet" if headshot else "vest"
	var durability_key := "helmet_durability" if headshot else "vest_durability"
	var durability := float(loadout.get(durability_key, 0.0))
	var armor_level := str(loadout.get(armor_key, "None"))
	var absorbed := minf(amount,durability) if armor_level!="None" and durability>0.0 else 0.0
	loadout[durability_key]=maxf(0.0,durability-absorbed)
	if float(loadout[durability_key])<=0.0 and armor_level!="None": loadout[armor_key]="Broken"
	var hp_damage:=maxf(0.0,amount-absorbed)
	var before_hp:=float(player.get("health_float",player.get("health",100)))
	player.health_float=maxf(0.0,before_hp-hp_damage); player.health=ceili(player.health_float); player.loadout=loadout
	player.last_damage={"time":elapsed,"cause":cause,"actor":actor,"weapon":weapon,"raw":roundi(amount),"absorbed":roundi(absorbed),"applied":roundi(hp_damage),"distance_m":roundi(distance_m)}
	if str(player.get("action", ""))!="": _cancel_player_action(player)
	squad[player_index]=player
	_emit_event("damage","%s gây %d damage lên %s bằng %s (%d armor)." % [actor,roundi(hp_damage),player.name,weapon,roundi(absorbed)],"COMBAT")
	if int(player.health)<=0: _knock_squad_member(squad,player_index,actor,team_tag,weapon,distance_m); return {"applied":roundi(hp_damage),"absorbed":roundi(absorbed),"knocked":true,"eliminated":false}
	return {"applied":roundi(hp_damage),"absorbed":roundi(absorbed),"knocked":false,"eliminated":false}

func _resolve_squad_wipe(squad:Array,team_tag:String)->void:
	var standing:=squad.filter(func(member): return str(member.state) not in ["DEAD","KNOCKED"])
	if not standing.is_empty(): return
	for player_index in squad.size():
		if str(squad[player_index].state)=="KNOCKED": _finish_squad_member(squad,player_index,team_tag,"SQUAD WIPE")

func _generate_event() -> void:
	if elapsed < 80.0: return
	var roll := randf()
	if roll < 0.26: _loot_event()
	elif roll < 0.48: _rotation_event()
	elif roll < 0.78: _contact_event()
	elif roll < 0.92: _combat_event()
	else: _utility_event()
	if randf() < 0.42 and teams_alive > 2:
		_eliminate_world_players(randi_range(1,3))
	if teams_alive > 2 and int(team_positions[0].get("alive", 0)) > 0 and randf() < 0.68:
		var pressure_teams: Array = []
		for team_index in range(1, team_positions.size()):
			if int(team_positions[team_index].get("alive", 0)) > 0: pressure_teams.append(team_index)
		if not pressure_teams.is_empty():
			var pressure_team: int = int(pressure_teams.pick_random())
			_world_fire_between(pressure_team, 0)
			if int(team_positions[0].get("alive", 0)) > 0: _world_fire_between(pressure_team, 0)

func _loot_event() -> void:
	var sources := catalog.loot_sources(map_data)
	if sources.is_empty(): return
	var source: Dictionary = sources.pick_random(); var multiplier := float(source.get("effective_multiplier",1.0))
	resources.ammo += roundi(randf_range(22,48)*multiplier); resources.heal += roundi(randf_range(0.5,2.0)*multiplier); resources.throwables += roundi(randf_range(0.0,1.5)*multiplier); resources.armor = mini(100,int(resources.armor)+roundi(18*multiplier))
	_emit_event("loot","Loot %s (%s) ×%.2f: cập nhật tài nguyên đội." % [source.name,source.source_kind,multiplier],"LOOT")

func _rotation_event() -> void:
	strategy = _macro_name()
	for i in roster.size():
		if roster[i].state in ["ALIVE","LOOTING"]: roster[i].position = Vector2(roster[i].position).lerp(target_zone_center, 0.22)
	resources.fuel = maxi(0,int(resources.fuel)-randi_range(3,8)); _emit_event("rotation","%s; fuel còn %d%%." % [strategy,resources.fuel],"MACRO")

func _combat_event() -> void:
	var live_indices: Array = []
	for team_index in team_positions.size():
		if int(team_positions[team_index].get("alive", 0)) > 0: live_indices.append(team_index)
	if live_indices.size() < 2: return
	var attacker_index: int = int(live_indices.pick_random()); var victim_indices: Array = live_indices.filter(func(index): return int(index) != attacker_index)
	if victim_indices.is_empty(): return
	_world_fire_between(attacker_index, int(victim_indices.pick_random()))

func _utility_event() -> void:
	var user: Dictionary = roster.filter(func(p): return p.state not in ["DEAD","IN_PLANE","AIRBORNE"]).pick_random() if not roster.filter(func(p): return p.state not in ["DEAD","IN_PLANE","AIRBORNE"]).is_empty() else {}
	if int(resources.throwables)>0 and not user.is_empty():
		resources.throwables-=1; var kind: String = str(["smoke","frag","molotov","flash"][randi_range(0,3)]); var pos := Vector2(user.position)+Vector2(randf_range(-0.035,0.035),randf_range(-0.035,0.035)); effects.append({"type":kind,"position":pos,"radius":0.045 if kind=="smoke" else 0.035 if kind=="molotov" else 0.026,"ttl":18.0 if kind=="smoke" else 12.0 if kind=="molotov" else 3.0,"owner":user.name}); _emit_event("utility","%s dùng %s." % [user.name,kind.to_upper()],"UTILITY")
		if kind in ["frag","molotov"]: _resolve_throwable_damage(user, pos, kind)
	else: _emit_event("scout","Scout cập nhật mật độ đối thủ trên route.","INFO")

func _resolve_throwable_damage(user: Dictionary, _position: Vector2, kind: String) -> void:
	var candidate_indices: Array = []
	for index in team_positions.size(): if str(team_positions[index].tag) != "MR" and int(team_positions[index].alive) > 0: candidate_indices.append(index)
	if candidate_indices.is_empty(): return
	var victim_index: int = int(candidate_indices.pick_random()); var victim: Dictionary = team_positions[victim_index]; var targets: Array = victim.members.filter(func(member): return str(member.state) not in ["DEAD", "IN_PLANE", "AIRBORNE"])
	if targets.is_empty(): return
	var target: Dictionary = targets.pick_random(); var target_index: int = victim.members.find(target)
	if target_index < 0: return
	var dealt := 90.0 if kind == "frag" else 64.0
	var outcome:=_apply_damage(victim.members,target_index,dealt,"FRAG" if kind=="frag" else "FIRE",str(user.name),str(victim.tag),kind.to_upper())
	user.damage = int(user.get("damage",0)) + int(outcome.applied)
	if bool(outcome.eliminated): user.kills = int(user.get("kills",0)) + 1
	victim.alive = victim.members.filter(func(member): return str(member.state) != "DEAD").size(); _store_team_member(team_positions[0], user); _commit_combat_team(0, team_positions[0]); team_positions[victim_index] = victim; _update_scoreboard()

func _push_kill_feed(actor: String, target: String, weapon: String, outcome: String, distance_m:float=-1.0) -> void:
	kill_feed.push_front({"time":elapsed,"actor":actor,"target":target,"weapon":weapon,"outcome":outcome,"distance_m":roundi(distance_m)}); if kill_feed.size()>30: kill_feed.resize(30)

func _sync_team(changed: Dictionary) -> void:
	for i in team_positions.size(): if str(team_positions[i].tag)==str(changed.tag): team_positions[i]=changed

func _eliminate_world_players(amount: int) -> void:
	for n in amount:
		var live_indices:Array=[]
		for team_index in team_positions.size():
			if int(team_positions[team_index].alive)>0: live_indices.append(team_index)
		if live_indices.size()<2: break
		var attacker_index:int=live_indices.pick_random(); var victim_choices:Array=live_indices.filter(func(index): return int(index)!=attacker_index)
		_world_fire_between(attacker_index,int(victim_choices.pick_random()))
	teams_alive = team_positions.filter(func(t): return int(t.alive)>0).size(); _update_scoreboard()

func _check_proximity_combat()->void:
	if elapsed<82.0: return
	for first_index in team_positions.size():
		var first:Dictionary=team_positions[first_index]
		if int(first.alive)<=0: continue
		for second_index in range(first_index+1,team_positions.size()):
			var second:Dictionary=team_positions[second_index]
			if int(second.alive)<=0: continue
			var distance:=Vector2(first.position).distance_to(Vector2(second.position))
			if distance>0.105: continue
			var contact_chance:=clampf((0.76-distance*4.0)*float(simulation_overrides.get("ai_aggression_scale",1.0)),0.08,0.96)
			if randf()<contact_chance: _world_fire_between(first_index,second_index)

func _select_combat_target(attacker: Dictionary, victim: Dictionary, standing: Array, knocked: Array, attacker_index: int) -> Dictionary:
	if not knocked.is_empty() and str(_plan_for_team(attacker_index).get("focus_fire","FOCUS")) == "FOCUS" and randf() < 0.64: return knocked.pick_random()
	if standing.is_empty(): return knocked.pick_random()
	if str(_plan_for_team(attacker_index).get("focus_fire","FOCUS")) == "SPREAD": return standing.pick_random()
	var priority := str(_plan_for_team(attacker_index).get("target_priority","LOWEST_HP")); var selected: Dictionary = standing[0]; var best_score := -INF
	for candidate in standing:
		var score := 0.0
		if priority == "LOWEST_HP": score = 100.0 - float(candidate.get("health",100))
		elif priority == "FRAGGER": score = float(candidate.get("aim",60)) + float(candidate.get("kills",0)) * 16.0
		elif priority == "ISOLATED": score = Vector2(candidate.position).distance_to(Vector2(victim.position)) * 100.0
		else: score = -Vector2(candidate.position).distance_to(Vector2(attacker.position)) * 100.0
		if score > best_score: best_score = score; selected = candidate
	return selected

func _combat_plan_bonus(team_index: int, distance: float) -> float:
	var plan := _plan_for_team(team_index); var range_plan := str(plan.get("combat_range","ADAPTIVE")); var bonus := 0.0
	if range_plan == "CLOSE" and distance < 0.055: bonus += 0.055
	elif range_plan == "MID" and distance >= 0.04 and distance <= 0.11: bonus += 0.045
	elif range_plan == "LONG" and distance > 0.095: bonus += 0.055
	elif range_plan == "ADAPTIVE": bonus += 0.025
	bonus += {"NONE":0.0,"SINGLE":0.025,"DOUBLE":0.045,"PINCER":0.07}.get(str(plan.get("flank","NONE")),0.0)
	return bonus

func _world_fire_between(attacker_index:int,victim_index:int)->void:
	var attacker:Dictionary=team_positions[attacker_index]; var victim:Dictionary=team_positions[victim_index]
	if attacker_index==0: attacker.members=roster; attacker.alive=roster.filter(func(member): return str(member.state)!="DEAD").size()
	if victim_index==0: victim.members=roster; victim.alive=roster.filter(func(member): return str(member.state)!="DEAD").size()
	var shooters:Array=attacker.members.filter(func(member): return str(member.state) not in ["DEAD","KNOCKED","IN_PLANE","AIRBORNE"] and str(member.loadout.primary)!="Unarmed")
	var knocked:Array=victim.members.filter(func(member): return str(member.state)=="KNOCKED"); var standing:Array=victim.members.filter(func(member): return str(member.state) not in ["DEAD","KNOCKED","IN_PLANE","AIRBORNE"])
	if shooters.is_empty() or (standing.is_empty() and knocked.is_empty()): return
	var shooter:Dictionary=shooters.pick_random(); shooter.shots=int(shooter.get("shots",0))+1; var target:Dictionary=_select_combat_target(attacker,victim,standing,knocked,attacker_index); var distance:=Vector2(shooter.position).distance_to(Vector2(target.position)); var distance_m:=distance*float(map_data.get("world_size_m",5000)); var weapon:=_select_combat_weapon(shooter,distance); shooter=_consume_weapon_ammo(shooter,weapon)
	var vehicle_impact:=str(shooter.get("state",""))=="DRIVING" and randf()<0.16
	if vehicle_impact:
		for target_index in victim.members.size():
			if str(victim.members[target_index].name)!=str(target.name): continue
			var outcome:=_apply_damage(victim.members,target_index,120.0,"VEHICLE",str(shooter.name),str(victim.tag),"VEHICLE",false,distance_m)
			shooter.damage=int(shooter.get("damage",0))+int(outcome.applied)
			if bool(outcome.eliminated): attacker.kills=int(attacker.kills)+1; shooter.kills=int(shooter.get("kills",0))+1
		_store_team_member(attacker,shooter)
		_resolve_squad_wipe(victim.members,str(victim.tag)); victim.alive=victim.members.filter(func(member): return str(member.state)!="DEAD").size(); _commit_combat_team(attacker_index,attacker); _commit_combat_team(victim_index,victim); _update_scoreboard(); return
	var weapon_accuracy:=float(_weapon_profile(weapon).get("accuracy",0.72)); var range_rule:=_weapon_range_rule(weapon); var max_range:=float(range_rule.max_m); var range_accuracy:=clampf(1.0-distance_m/maxf(max_range,1.0)*0.58,0.18,1.0); var target_building:=catalog.building_profile_at(map_data,Vector2(target.position)); var cover_penalty:=float(target_building.get("cover_rating",0.0))*0.38; var competitive_modifier := 0.07 if victim_index==0 else -0.035 if attacker_index==0 else 0.0; var hit_chance:=0.01 if distance_m>max_range else clampf(float(shooter.get("aim",60))/115.0*weapon_accuracy*range_accuracy+competitive_modifier+_combat_plan_bonus(attacker_index,distance)-cover_penalty,0.05,0.84); var shot_hit:=randf()<hit_chance
	bullet_trails.append({"from":shooter.position,"to":target.position,"ttl":3.5,"weapon":weapon,"outcome":"HIT" if shot_hit else "MISS"})
	if not shot_hit: _store_team_member(attacker,shooter); _commit_combat_team(attacker_index,attacker); _emit_event("shot_miss","%s [%s] bắn hụt %s." % [shooter.name,weapon,target.name],"COMBAT"); return
	shooter.hits=int(shooter.get("hits",0))+1
	for target_index in victim.members.size():
		if str(victim.members[target_index].name)!=str(target.name): continue
		var category:=str(_weapon_profile(weapon).get("category","AR")); var raw_damage:=float(_weapon_profile(weapon).get("damage", 40))*randf_range(0.82,1.18)*_weapon_damage_at_distance(weapon,distance_m); if category in ["SHOTGUN","SR"] and distance_m<=float(range_rule.optimal_m): raw_damage=maxf(raw_damage,105.0)
		var headshot:=randf()<0.16; if headshot: raw_damage*=1.5
		var outcome:=_apply_damage(victim.members,target_index,raw_damage,"WEAPON",str(shooter.name),str(victim.tag),weapon,headshot,distance_m)
		shooter.damage=int(shooter.get("damage",0))+int(outcome.applied)
		if bool(outcome.eliminated): attacker.kills=int(attacker.kills)+1; shooter.kills=int(shooter.get("kills",0))+1
		elif not bool(outcome.knocked): _emit_event("shot_hit","%s [%s] hit %s (%d HP)." % [shooter.name,weapon,target.name,victim.members[target_index].health],"COMBAT")
	_store_team_member(attacker,shooter); _resolve_squad_wipe(victim.members,str(victim.tag)); victim.alive=victim.members.filter(func(member): return str(member.state)!="DEAD").size(); _commit_combat_team(attacker_index,attacker); _commit_combat_team(victim_index,victim); _update_scoreboard()

func _commit_combat_team(team_index:int,team:Dictionary)->void:
	team.alive=team.members.filter(func(member): return str(member.state)!="DEAD").size()
	if team_index==0:
		roster=team.members
		kills=0; damage=0
		for member in roster: kills+=int(member.get("kills",0)); damage+=int(member.get("damage",0))
		team.kills=kills
	team_positions[team_index]=team

func _weapon_profile(weapon: String) -> Dictionary:
	return WEAPON_PROFILES.get(weapon, LEGACY_WEAPON_PROFILES.get(weapon, {"ideal_min":0.0,"ideal_max":0.12,"accuracy":0.70,"damage":30}))

func _weapon_range_rule(weapon:String)->Dictionary:
	return WEAPON_RANGE_RULES.get(str(_weapon_profile(weapon).get("category","AR")),WEAPON_RANGE_RULES.AR)

func _weapon_damage_at_distance(weapon:String,distance_m:float)->float:
	var rule:=_weapon_range_rule(weapon); var optimal:=float(rule.optimal_m); var maximum:=float(rule.max_m)
	if distance_m<=optimal: return 1.0
	if distance_m>=maximum: return float(rule.falloff_floor)
	return lerpf(1.0,float(rule.falloff_floor),(distance_m-optimal)/maxf(1.0,maximum-optimal))

func display_ammo_for_weapon(weapon:String,simulation_shots:int)->int:
	if weapon in ["Unarmed","—",""]: return 0
	return simulation_shots*int(_weapon_range_rule(weapon).get("display_rounds",30))

func _attachment_slot(attachment:String) -> String:
	if attachment in ["Red Dot","2x","3x","4x","6x","8x"]: return "scope"
	if attachment in ["Compensator","Suppressor","Flash Hider"]: return "muzzle"
	if attachment in ["Extended Mag","Quickdraw Mag"]: return "magazine"
	if attachment in ["Vertical Grip","Angled Grip","Lightweight Grip"]: return "grip"
	if attachment in ["Tactical Stock","Cheek Pad"]: return "stock"
	return ""

func _can_equip_attachment(weapon:String,attachment:String) -> bool:
	var slot:=_attachment_slot(attachment)
	if slot.is_empty() or weapon in ["Unarmed","—",""]: return false
	var category:=str(_weapon_profile(weapon).get("category", ""))
	if slot=="scope": return category not in ["PISTOL"] and (attachment in ["Red Dot","2x"] or category not in ["SHOTGUN","SMG"])
	if slot=="grip": return category in ["AR","SMG"]
	if slot=="stock": return category in ["AR","SMG","DMR","SR"]
	return category in ["AR","SMG","DMR","SR","LMG"]

func _equip_attachment(loadout:Dictionary,weapon_slot:String,attachment:String) -> bool:
	var weapon:=str(loadout.get(weapon_slot, ""))
	if not _can_equip_attachment(weapon,attachment): return false
	var attachments:Array=loadout.get("attachments", [])
	var slot:=_attachment_slot(attachment)
	for existing in attachments.duplicate():
		if str(existing.get("weapon_slot", ""))==weapon_slot and str(existing.get("slot", ""))==slot: attachments.erase(existing)
	attachments.append({"weapon_slot":weapon_slot,"slot":slot,"item":attachment})
	loadout.attachments=attachments
	if slot=="scope" and weapon_slot=="primary": loadout.scope=attachment
	return true

func _select_combat_weapon(player:Dictionary,distance:float)->String:
	var loadout:Dictionary=player.get("loadout",{})
	var candidates:Array=[{"weapon":str(loadout.get("primary","Unarmed")),"slot":"primary","ammo":int(loadout.get("primary_ammo",loadout.get("ammo",0)))},{"weapon":str(loadout.get("secondary","—")),"slot":"secondary","ammo":int(loadout.get("secondary_ammo",0))}]
	var best_weapon:="Unarmed"; var best_score:=-999.0
	for candidate in candidates:
		var weapon:=str(candidate.weapon)
		if weapon in ["Unarmed","—",""]: continue
		if int(candidate.ammo) <= 0 or elapsed < float(loadout.get(str(candidate.slot)+"_reload_until", 0.0)): continue
		var profile:Dictionary=_weapon_profile(weapon); var distance_m:=distance*float(map_data.get("world_size_m",5000)); var rule:=_weapon_range_rule(weapon); var maximum:=float(rule.max_m); var optimal:=float(rule.optimal_m)
		var range_penalty:=0.0 if distance_m<=optimal else (distance_m-optimal)/maxf(1.0,maximum-optimal)
		if distance_m>maximum: range_penalty+=2.0
		var score:=float(profile.accuracy)-range_penalty
		if str(candidate.slot)=="secondary": score+=0.035
		if score>best_score: best_score=score; best_weapon=weapon; loadout.active_slot=str(candidate.slot)
	loadout.active_weapon=best_weapon; player.loadout=loadout
	return best_weapon

func _consume_weapon_ammo(player: Dictionary, weapon: String) -> Dictionary:
	var loadout: Dictionary = player.get("loadout", {})
	var key := "secondary_ammo" if weapon == str(loadout.get("secondary", "—")) else "primary_ammo"
	loadout[key] = maxi(0, int(loadout.get(key, 0)) - 1)
	loadout.ammo = int(loadout.get("primary_ammo", 0)) + int(loadout.get("secondary_ammo", 0))
	player.loadout = loadout
	return player

func _store_team_member(team:Dictionary,player:Dictionary)->void:
	for member_index in team.members.size():
		if str(team.members[member_index].name)==str(player.name): team.members[member_index]=player; return

func _update_scoreboard() -> void:
	for i in scoreboard.size():
		var previous_alive:=int(scoreboard[i].alive)
		for team in team_positions:
			if str(team.tag)==str(scoreboard[i].tag): scoreboard[i].alive=team.alive; scoreboard[i].kills=team.kills
		if str(scoreboard[i].tag)=="MR": scoreboard[i].alive=roster.filter(func(p): return p.state!="DEAD").size(); scoreboard[i].kills=kills
		if previous_alive>0 and int(scoreboard[i].alive)==0: scoreboard[i].eliminated_at=elapsed
	scoreboard.sort_custom(func(a,b): return int(a.alive)>int(b.alive) if int(a.alive)!=int(b.alive) else float(a.get("eliminated_at",-1.0))>float(b.get("eliminated_at",-1.0)) if int(a.alive)==0 and float(a.get("eliminated_at",-1.0))!=float(b.get("eliminated_at",-1.0)) else int(a.kills)>int(b.kills))
	for i in scoreboard.size():
		scoreboard[i].rank = i + 1
		var placement_table: Dictionary = match_scoring.get("placement_points", {})
		var placement_points := int(placement_table.get(str(i + 1), maxi(0, lobby_team_count + 1 - (i + 1))))
		var kill_points := int(scoreboard[i].kills) * int(match_scoring.get("kill_point", 1))
		scoreboard[i].placement_points = placement_points; scoreboard[i].kill_points = kill_points; scoreboard[i].bonus_points = 0; scoreboard[i].points = placement_points + kill_points

func _make_loadout(index: int, loot_efficiency := 60) -> Dictionary:
	return {"primary":"Unarmed","secondary":"—","scope":"—","ammo":0,"primary_ammo":0,"secondary_ammo":0,"helmet":"None","helmet_durability":0.0,"vest":"None","vest_durability":0.0,"backpack":"None","backpack_capacity":50,"weight":0.0,"bandage":0,"first_aid":0,"medkit":0,"energy_drink":0,"painkiller":0,"adrenaline":0,"smoke":0,"frag":0,"molotov":0,"flash":0,"loot_stage":0,"weapon_seed":index,"loot_efficiency":loot_efficiency,"attachments":[],"discarded":[]}

func _initialize_loot_stock()->void:
	var custom_loot_scale := float(simulation_overrides.get("loot_density_scale", 1.0))
	for source in catalog.loot_sources(map_data):
		var key := "%s:%s" % [str(source.source_kind), str(source.id)]
		var slots:=maxi(1,roundi(catalog.loot_slot_count(source)*float(source.get("effective_multiplier",1.0))*custom_loot_scale)); var items:=_generate_source_loot(source,slots)
		loot_stock[key] = {"remaining":items.size(),"items":items,"multiplier":float(source.effective_multiplier),"source_kind":str(source.source_kind),"name":str(source.name),"slots":slots}

func _generate_source_loot(source:Dictionary,slots:int)->Array:
	var items:Array=[]
	for index in slots:
		if index==0: items.append({"kind":"weapon","weapon":_roll_loot_weapon(float(source.get("effective_multiplier",1.0)))})
		elif index==1: items.append({"kind":"ammo","shots":randi_range(1,3)})
		else:
			var roll:=randf()
			if roll<0.24: items.append({"kind":"weapon","weapon":_roll_loot_weapon(float(source.get("effective_multiplier",1.0)))})
			elif roll<0.46: items.append({"kind":"ammo","shots":randi_range(1,3)})
			elif roll<0.58: items.append({"kind":"armor","slot":"vest","level":1 if randf()<0.76 else 2})
			elif roll<0.68: items.append({"kind":"armor","slot":"helmet","level":1 if randf()<0.8 else 2})
			elif roll<0.82: items.append({"kind":"heal","item":"bandage" if randf()<0.62 else "first_aid"})
			elif roll<0.91: items.append({"kind":"boost","item":"energy_drink" if randf()<0.74 else "painkiller"})
			else: items.append({"kind":"throwable","item":["smoke","frag","molotov","flash"].pick_random()})
	return items

func _roll_loot_weapon(source_multiplier:float)->String:
	var roll:=randf(); var category:="SMG"
	if roll<0.30: category="SMG"
	elif roll<0.60: category="AR"
	elif roll<0.73: category="SHOTGUN"
	elif roll<0.88: category="DMR"
	elif roll<0.94: category="LMG"
	elif roll<0.985: category="PISTOL"
	else: category="SR"
	if source_multiplier>=1.45 and randf()<0.035: category="SR"
	var pool:=WEAPONS.filter(func(weapon): return str(_weapon_profile(str(weapon)).get("category",""))==category and str(weapon) not in ["AWM","Lynx AMR"])
	return str(pool.pick_random()) if not pool.is_empty() else "M416"

func _role_weapon_score(player:Dictionary,weapon:String)->float:
	var category:=str(_weapon_profile(weapon).get("category","AR")); var role:=str(player.get("role","Flex")).to_upper(); var preferred:Array
	if "SNIP" in role or "SCOUT" in role: preferred=["SR","DMR","AR"]
	elif "ENTRY" in role or "FRAG" in role: preferred=["SMG","SHOTGUN","AR"]
	elif "SUPPORT" in role: preferred=["DMR","AR","LMG"]
	else: preferred=["AR","DMR","SMG"]
	var rank:=preferred.find(category); return 3.0-float(rank) if rank>=0 else 0.35

func _choose_loot_item(player:Dictionary,items:Array)->int:
	var loadout:Dictionary=player.loadout; var resource_plan:=str(player.get("tactical_resource","MINIMAL")); var best_index:=-1; var best_score:=-999.0
	for index in items.size():
		var item:Dictionary=items[index]; var score:=0.0; var kind:=str(item.kind)
		if kind=="weapon":
			score=_role_weapon_score(player,str(item.weapon))*2.0
			if str(loadout.primary)=="Unarmed": score+=8.0
			elif str(loadout.secondary)=="—": score+=3.0
			else: score-= _role_weapon_score(player,str(loadout.primary))
		elif kind=="ammo": score=4.0 if int(loadout.get("ammo",0))<8 else 0.8
		elif kind=="armor":
			var current_level:=int(str(loadout.get(str(item.slot),"None")).trim_prefix("Lv.")) if str(loadout.get(str(item.slot),"None")).begins_with("Lv.") else 0; score=5.0 if int(item.level)>current_level else -1.0
		elif kind=="heal": score=3.0 if int(loadout.get(str(item.item),0))<4 else -0.5
		elif kind=="boost": score=2.2 if int(loadout.get(str(item.item),0))<3 else -0.5
		elif kind=="throwable": score=1.8 if int(loadout.get(str(item.item),0))<3 else -0.5
		if resource_plan=="HEAL" and kind in ["heal","boost"]: score+=4.0
		elif resource_plan=="UTILITY" and kind=="throwable": score+=4.0
		elif resource_plan=="FULL": score+=0.5
		if score>best_score: best_score=score; best_index=index
	return best_index if best_score>0.0 else -1

func _loot_interval(player:Dictionary)->float:
	var efficiency:=clampf(float(player.get("loot_efficiency",60))/60.0,0.65,1.45); var resource_plan:=str(player.get("tactical_resource","MINIMAL")); var plan_multiplier:=1.3 if resource_plan=="MINIMAL" else 0.75 if resource_plan=="FULL" else 1.0
	return randf_range(5.0,8.0)*plan_multiplier/efficiency

func _pickup_loot_item(player:Dictionary,item:Dictionary)->Dictionary:
	var loadout:Dictionary=player.loadout; var kind:=str(item.kind)
	if kind=="weapon":
		var weapon:=str(item.weapon)
		if str(loadout.primary)=="Unarmed" or _role_weapon_score(player,weapon)>_role_weapon_score(player,str(loadout.primary)): loadout.secondary=loadout.primary if str(loadout.primary)!="Unarmed" else loadout.secondary; loadout.secondary_ammo=loadout.primary_ammo if str(loadout.primary)!="Unarmed" else loadout.secondary_ammo; loadout.primary=weapon; loadout.primary_ammo=maxi(1,int(loadout.get("primary_ammo",0)))
		elif str(loadout.secondary)=="—": loadout.secondary=weapon; loadout.secondary_ammo=1
	elif kind=="ammo":
		if str(loadout.primary)!="Unarmed": loadout.primary_ammo=int(loadout.primary_ammo)+int(item.shots)
		elif str(loadout.secondary)!="—": loadout.secondary_ammo=int(loadout.secondary_ammo)+int(item.shots)
	elif kind=="armor":
		var level:=int(item.level); loadout[str(item.slot)]="Lv.%d"%level; loadout[str(item.slot)+"_durability"]=[0,35,60,90][level] if str(item.slot)=="helmet" else [0,50,80,120][level]
	elif kind in ["heal","boost","throwable"]: loadout[str(item.item)]=int(loadout.get(str(item.item),0))+1
	loadout.ammo=int(loadout.get("primary_ammo",0))+int(loadout.get("secondary_ammo",0)); loadout.loot_stage=int(loadout.get("loot_stage",0))+1; player.loadout=loadout; _enforce_loadout_capacity(player); return player

func _loot_player(player:Dictionary)->Dictionary:
	var candidates:Array=[]; var position:=Vector2(player.position)
	for source in catalog.loot_sources(map_data):
		var inside:=position.distance_to(Vector2(float(source.position[0]),float(source.position[1])))<=float(source.get("radius",0.035))
		if str(source.get("source_kind",""))=="building":
			var rect:Array=source.get("rect",[]); inside=rect.size()==4 and Rect2(float(rect[0]),float(rect[1]),float(rect[2]),float(rect[3])).has_point(position)
		if inside:
			candidates.append({"key":"%s:%s" % [str(source.source_kind),str(source.id)],"multiplier":float(source.effective_multiplier),"source_kind":str(source.source_kind),"name":str(source.name)})
	if candidates.is_empty(): return player
	candidates.sort_custom(func(a,b): return float(a.multiplier)>float(b.multiplier))
	var source:Dictionary=candidates[0]; var stock:Dictionary=loot_stock.get(source.key,{"remaining":0,"items":[],"multiplier":0.0}); var items:Array=stock.get("items",[])
	if items.is_empty(): return player
	var item_index:=_choose_loot_item(player,items); if item_index<0: return player
	var item:Dictionary=items[item_index]; items.remove_at(item_index); stock.items=items; stock.remaining=items.size(); loot_stock[source.key]=stock
	player=_pickup_loot_item(player,item); player.loadout.last_loot_source=source.get("name",source.key); player.loadout.last_loot_source_kind=source.get("source_kind",""); player.loadout.last_loot_offer=item.duplicate(true); return player

func _recalculate_loadout_weight(loadout: Dictionary) -> void:
	var weight := float(loadout.get("ammo", 0)) * 0.02
	for key in ["bandage","first_aid","medkit","energy_drink","painkiller","adrenaline","smoke","frag","molotov","flash"]: weight += float(loadout.get(key, 0)) * 0.25
	weight += 2.0 if str(loadout.get("primary", "Unarmed")) != "Unarmed" else 0.0
	weight += 2.0 if str(loadout.get("secondary", "—")) != "—" else 0.0
	weight += 2.0 if str(loadout.get("vest", "None")) != "None" else 0.0
	weight += 1.0 if str(loadout.get("helmet", "None")) != "None" else 0.0
	loadout.weight = snappedf(weight, 0.1)

func _enforce_loadout_capacity(player: Dictionary) -> void:
	var loadout: Dictionary = player.get("loadout", {})
	var capacity := 50 if str(loadout.get("backpack", "None")) == "None" else 150 if str(loadout.get("backpack", "None")) == "Lv.1" else 220 if str(loadout.get("backpack", "None")) == "Lv.2" else 270
	loadout.backpack_capacity = capacity
	_recalculate_loadout_weight(loadout)
	while float(loadout.weight) > capacity and int(loadout.get("bandage", 0)) > 0:
		loadout.bandage = int(loadout.bandage) - 1; loadout.discarded.append("Bandage"); _recalculate_loadout_weight(loadout)
	while float(loadout.weight) > capacity and int(loadout.get("ammo", 0)) > 0:
		loadout.ammo = maxi(0, int(loadout.ammo) - 10); loadout.discarded.append("Ammo"); _recalculate_loadout_weight(loadout)

func _team_drop_target(regions:Array,team_index:int)->Vector2:
	if regions.is_empty(): return Vector2(0.5,0.5)
	var region:Dictionary=regions[team_index%regions.size()]
	var region_compounds: Array = map_data.get("compounds", []).filter(func(compound): return str(compound.get("poi_id", "")) == str(region.id))
	var center:=Vector2(float(region.position[0]),float(region.position[1]))
	if not region_compounds.is_empty():
		var compound: Dictionary = region_compounds[team_index % region_compounds.size()]
		center = Vector2(float(compound.position[0]), float(compound.position[1]))
	var radius:=float(region.get("radius",0.06))*0.18
	var target:=center+Vector2.from_angle(float(team_index)*2.399)*radius
	return Vector2(clampf(target.x,0.04,0.96),clampf(target.y,0.04,0.96))

func _apply_drop_error(destination: Vector2, drop_accuracy: int) -> Vector2:
	var error_chance:=clampf(0.42-float(drop_accuracy)*0.0038,0.035,0.32)
	if randf()>=error_chance: return destination
	var error_radius:=lerpf(0.075,0.018,float(drop_accuracy)/100.0)
	return Vector2(clampf(destination.x+randf_range(-error_radius,error_radius),0.03,0.97),clampf(destination.y+randf_range(-error_radius,error_radius),0.03,0.97))

func _acronym(value: String) -> String:
	var words := value.split(" ")
	var result := ""
	for word in words:
		if not word.is_empty(): result+=word.left(1).to_upper()
	return result.left(3) if result.length()>1 else value.left(3).to_upper()

func _contact_event() -> void:
	var observers := roster.filter(func(p): return p.state in ["ALIVE","LOOTING"])
	if observers.is_empty(): return
	var enemy_teams:=team_positions.filter(func(team): return str(team.tag)!="MR" and int(team.alive)>0)
	if enemy_teams.is_empty(): return
	var observer: Dictionary = observers.pick_random(); var enemy: Dictionary = enemy_teams.pick_random(); var distance: float = Vector2(observer.position).distance_to(Vector2(enemy.position)); var terrain: String = _nearest_terrain(Vector2(observer.position)); var terrain_profile:Dictionary=catalog.terrain_profile_at(map_data,Vector2(observer.position)); var vision_multiplier:=float(terrain_profile.get("vision_multiplier",0.55 if terrain=="forest" else 1.0)); var concealment: float = 0.28 if terrain in ["forest","urban"] else 0.12 if terrain in ["rock","industrial"] else 0.04
	var formation_vision: float = float({"STACK":-0.08,"TWO_TWO":0.12,"ONE_THREE":0.18,"FOUR_WAY":0.28,"ANCHOR_THREE":0.14}.get(str(coach_plan.formation),0.0))
	var noise: float = randf_range(0.0,0.35) + (0.22 if randf()<0.25 else 0.0)
	var information_plan := str(coach_plan.get("information","INFO_FIRST")); var information_bonus: float = float({"INFO_FIRST":0.08,"SCOUT_FIRST":0.13,"CONFIRM_PUSH":0.10,"IMMEDIATE":-0.03}.get(information_plan,0.0))
	var our_score: float = float(observer.vision)/100.0*0.46*vision_multiplier + float(observer.hearing)/100.0*0.16 + float(observer.game_sense)/100.0*0.18 + formation_vision + information_bonus + noise - distance*0.42 - concealment
	var enemy_score: float = randf_range(0.32,0.82) + noise*0.35 - float(observer.stealth)/100.0*0.28 - distance*0.30
	var ours := randf() < clampf(our_score,0.04,0.94); var theirs := randf() < clampf(enemy_score,0.04,0.92); detection_attempts += 1; if ours: confirmed_contacts += 1
	var contact := {"time":elapsed,"observer":observer.name,"distance":roundi(distance*float(map_data.get("world_size_m",5000))),"ours_detected":ours,"enemy_detected":theirs,"confidence":clampf(our_score,0.0,1.0),"terrain":terrain,"noise":noise}; contacts.push_front(contact); if contacts.size()>12: contacts.resize(12)
	var outcome := "hai đội chưa xác nhận nhau"
	if ours and theirs: outcome = "hai đội phát hiện lẫn nhau"
	elif ours: outcome = "ta phát hiện trước, địch chưa thấy"
	elif theirs: outcome = "địch phát hiện trước, ta chưa xác nhận"
	_emit_event("contact","%s: %s ở %dm (%s)." % [observer.name,outcome,contact.distance,terrain],"VISION")

func _nearest_terrain(position: Vector2) -> String:
	var painted:Dictionary=catalog.terrain_profile_at(map_data,position)
	if bool(painted.get("inside",false)): return str(painted.terrain)
	var best := "field"; var best_distance := 99.0
	for region in map_data.get("regions",[]):
		var p := Vector2(float(region.position[0]),float(region.position[1])); var d := position.distance_to(p)
		if d < best_distance: best_distance=d; best=str(region.terrain)
	return best

func _initiative_score(player: Dictionary, contact: Dictionary) -> float:
	var information := 0.30 if bool(contact.ours_detected) and not bool(contact.enemy_detected) else -0.18 if bool(contact.enemy_detected) and not bool(contact.ours_detected) else 0.0
	return information + float(player.reaction)/250.0 + float(player.communication)/400.0

func _macro_name() -> String:
	return {"EDGE":"Edge Play / Gate Keep","CENTER":"Center Control / Compound Hold","FAST":"Fast Rotation","LATE":"Late Rotation / Information Play"}.get(str(coach_plan.zone_macro),"Adaptive Macro")

func _emit_event(type:String,text:String,channel:String) -> void:
	event_sequence += 1
	var event := {"schema_version":replay_version,"event_id":"%s-e%05d" % [match_id,event_sequence],"match_id":match_id,"sequence":event_sequence,"time":elapsed,"type":type,"event_type":type,"channel":channel,"text":text,"phase":phase,"team_id":"","player_id":"","actor":"","target":"","region":"","position":[],"weapon":"","item":"","outcome":"","decision_type":type if type in ["rotation","contact","decision","utility","vehicle"] else "","reason":text,"utility_score":0.0,"context":{"zone":zone_number,"teams_alive":teams_alive,"players_alive":players_alive,"strategy":strategy},"result":"pending" if type in ["rotation","contact","decision","utility","vehicle"] else "observed"}
	timeline.push_front(event); if timeline.size()>50: timeline.resize(50); event_emitted.emit(event)

func _finish() -> void:
	running=false; paused=true; _update_scoreboard()
	var own_row:Dictionary={}; var winning_row:Dictionary={}
	for row in scoreboard:
		if int(row.rank)==1: winning_row=row
		if str(row.tag)=="MR": own_row=row
	placement=int(own_row.get("rank", lobby_team_count)); winner=winning_row.duplicate(true)
	var team_stats:Array=[]; var player_stats:Array=[]
	for row in scoreboard:
		var source_team:Dictionary={}
		for team in team_positions: if str(team.tag)==str(row.tag): source_team=team; break
		var members:Array=roster if str(row.tag)=="MR" else source_team.get("members",[])
		var team_damage:=0
		for member in members:
			var member_damage:=int(member.get("damage",0)); team_damage+=member_damage
			var shots := int(member.get("shots", 0)); var hits := int(member.get("hits", 0)); var accuracy := roundi(float(hits) * 100.0 / float(maxi(1, shots)))
			player_stats.append({"player_id":member.get("player_id", ""),"team":row.tag,"name":member.name,"role":member.get("role","Player"),"kills":member.get("kills",0),"damage":member_damage,"shots":shots,"hits":hits,"accuracy":accuracy,"revives":member.get("revives",0),"survived":str(member.state)!="DEAD","state":member.state})
		team_stats.append({"rank":row.rank,"name":row.name,"tag":row.tag,"alive":row.alive,"kills":row.kills,"damage":team_damage,"placement_points":row.get("placement_points",0),"kill_points":row.get("kill_points",row.kills),"bonus_points":row.get("bonus_points",0),"points":row.points})
	_emit_event("result","WINNER: %s • %d kills. Đội của bạn hạng #%d." % [winning_row.get("name",winning_row.get("tag","—")),winning_row.get("kills",0),placement],"RESULT")
	var chronological_timeline:=timeline.duplicate(true); chronological_timeline.reverse()
	var own_players:Array=player_stats.filter(func(stat): return str(stat.get("team", "")) == "MR")
	var loot_statistics:Array=[]
	for member in roster:
		loot_statistics.append({"player_id":member.get("player_id", ""),"name":member.get("name", ""),"loot_stage":int(member.get("loadout", {}).get("loot_stage", 0)),"last_source":member.get("loadout", {}).get("last_loot_source", ""),"last_source_kind":member.get("loadout", {}).get("last_loot_source_kind", ""),"weight":float(member.get("loadout", {}).get("weight", 0.0)),"capacity":int(member.get("loadout", {}).get("backpack_capacity", 50)),"discarded":member.get("loadout", {}).get("discarded", []).duplicate()})
	var combat_events:=chronological_timeline.filter(func(event): return str(event.get("type", "")) in ["combat","knock","kill","flush","damage"])
	var zone_events:=chronological_timeline.filter(func(event): return str(event.get("type", "")) in ["zone","red_zone_start","red_zone_hit","red_zone_end"])
	var vehicle_events:=chronological_timeline.filter(func(event): return str(event.get("type", "")) == "vehicle")
	var utility_events:=chronological_timeline.filter(func(event): return str(event.get("type", "")) in ["utility","heal","boost","revive"])
	var decision_log:=chronological_timeline.filter(func(event): return str(event.get("type", "")) in ["rotation","contact","decision","utility","vehicle"])
	var airdrop_events:=chronological_timeline.filter(func(event): return str(event.get("type", "")) in ["airdrop","airdrop_loot"])
	var result={"replay_version":replay_version,"match_id":match_id,"match_seed":match_seed,"winner":winner.duplicate(true),"placement":placement,"kills":kills,"damage":damage,"duration":elapsed,"scoreboard":team_stats,"player_stats":player_stats,"own_player_stats":own_players,"loot_statistics":loot_statistics,"combat_events":combat_events,"zone_events":zone_events,"vehicle_events":vehicle_events,"utility_events":utility_events,"airdrop_events":airdrop_events,"decision_log":decision_log,"kill_feed":kill_feed.duplicate(true),"timeline":chronological_timeline,"final_snapshot":snapshot()}
	updated.emit(snapshot()); match_finished.emit(result)
