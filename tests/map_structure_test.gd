extends SceneTree

const MapCatalogScript = preload("res://scripts/map_catalog.gd")
const MatchRuntimeScript = preload("res://scripts/match_runtime.gd")
var checks := 0
var failures := 0

func _init() -> void:
	var catalog = MapCatalogScript.new()
	var sizes := {}
	for map_id in ["verdant_reach","sunscorch_basin","tactical_island","frostline_valley","coastal_breakwater","highland_reserve"]:
		var data: Dictionary = catalog.load_map(map_id)
		_check(catalog.validate(data), "%s does not satisfy map schema v2" % map_id)
		_check(float(data.map_size_km[0]) == float(data.map_size_km[1]), "%s is not square" % map_id)
		_check(data.regions.size() >= 4 and data.compounds.size() >= data.regions.size() * 2, "%s does not split POIs into compounds" % map_id)
		var road_classes := {}
		for road in data.roads: road_classes[str(road.road_class)] = true
		_check(road_classes.has("highway") and road_classes.has("secondary") and road_classes.has("dirt"), "%s road hierarchy is incomplete" % map_id)
		_check(not data.points.is_empty() and data.points.all(func(point): return float(point.get("loot_multiplier",1.0)) < 0.7 and float(point.get("safety",0.0)) >= 0.75), "%s isolated safe-loot layer is invalid" % map_id)
		_check(not data.transport_nodes.is_empty(), "%s has no transport nodes" % map_id)
		var size := int(catalog.map_size_km(data)); sizes[size] = data
		var sources := catalog.loot_sources(data)
		_check(sources.size() == data.compounds.size() + data.points.size(), "%s loot sources are not connected to runtime" % map_id)
	_check(catalog.loot_density_factor(sizes[4]) > catalog.loot_density_factor(sizes[5]) and catalog.loot_density_factor(sizes[5]) > catalog.loot_density_factor(sizes[6]), "Loot density does not fall from 4x4 to 6x6")
	_check(catalog.vehicle_need_factor(sizes[4]) < catalog.vehicle_need_factor(sizes[5]) and catalog.vehicle_need_factor(sizes[5]) < catalog.vehicle_need_factor(sizes[6]), "Vehicle need does not rise from 4x4 to 6x6")
	var runtime = MatchRuntimeScript.new()
	var game_data := {"active_match_event_id":"map-test","season":1,"active_match_team_count":2,"roster":[{"id":"p1","name":"P1","role":"IGL","energy":100},{"id":"p2","name":"P2","role":"Entry","energy":100},{"id":"p3","name":"P3","role":"Support","energy":100},{"id":"p4","name":"P4","role":"Fragger","energy":100}],"teams":[{"name":"Test Opponent"}]}
	runtime.start_match(game_data,"tactical_island",{},7711)
	_check(runtime.loot_stock.size() == runtime.map_data.compounds.size() + runtime.map_data.points.size(), "Runtime loot stock does not use compound and isolated-point layers")
	_check(float(runtime.snapshot().map_profile.loot_density_factor) == 1.25, "Runtime snapshot omits map density profile")
	if failures > 0: push_error("MAP_STRUCTURE_TEST_FAILED checks=%d failures=%d" % [checks,failures]); quit(1)
	else: print("MAP_STRUCTURE_TEST_OK checks=%d" % checks); quit(0)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures += 1; push_error("CHECK FAILED: " + message)
