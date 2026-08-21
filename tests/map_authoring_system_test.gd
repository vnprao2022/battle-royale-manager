extends SceneTree

const MapCatalogScript=preload("res://scripts/map_catalog.gd")
const MatchRuntimeScript=preload("res://scripts/match_runtime.gd")
var checks:=0
var failures:=0

func _init()->void:
	var catalog=MapCatalogScript.new(); catalog.override_dir="user://codex_map_authoring_overrides"; var ids:=["verdant_reach","sunscorch_basin","tactical_island","frostline_valley","coastal_breakwater","highland_reserve"]
	for id in ids: catalog.reset_override(id)
	for id in ids:
		var map:Dictionary=catalog.load_map(id); _check(str(map.id)==id and not map.loot_zones.is_empty() and not map.loot_nodes.is_empty(),"Independent normalized map missing: "+id)
		_check(map.loot_zones.size()==map.compounds.size() and map.loot_nodes.size()==map.points.size(),"Legacy loot migration changed source count: "+id)
	var legacy_variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/verdant_reach.json")); var legacy:Dictionary=legacy_variant if legacy_variant is Dictionary else {}; legacy.erase("loot_zones"); legacy.erase("loot_nodes"); legacy.erase("terrain_strokes"); var migrated:Dictionary=catalog._with_editor_layers(legacy); _check(migrated.loot_zones.size()==legacy.compounds.size() and migrated.loot_nodes.size()==legacy.points.size() and not migrated.terrain_strokes.is_empty() and migrated.water_zones.is_empty(),"Legacy map descriptor migration failed")
	var map:Dictionary=catalog.load_map("verdant_reach"); var original_name:=str(map.loot_nodes[0].name); map.loot_nodes[0].name="Persistence Probe"; _check(catalog.save_override(map),"Map override save failed"); _check(str(catalog.load_map("verdant_reach").loot_nodes[0].name)=="Persistence Probe","Map override reload failed"); map.terrain_strokes=[]; _check(catalog.save_override(map) and catalog.load_map("verdant_reach").terrain_strokes.is_empty(),"Deleted legacy river reappeared after override reload"); _check(str(catalog.load_map("tactical_island").id)=="tactical_island","Editing one map changed another map"); catalog.reset_override("verdant_reach"); _check(str(catalog.load_map("verdant_reach").loot_nodes[0].name)==original_name,"Map override reset failed")
	map=catalog.load_map("verdant_reach"); map.buildings=[{"id":"cover_only","name":"Cover","rect":[0.4,0.4,0.1,0.1],"cover_rating":0.3,"concealment_rating":0.2,"detection_multiplier":0.7,"loot_enabled":false,"enabled":true}]; _check(catalog.loot_sources(map).all(func(source): return str(source.source_kind)!="building"),"Building became loot without explicit association")
	map.terrain_strokes=[{"id":"forest","terrain":"forest","path":[[0.1,0.2],[0.9,0.2]],"width":0.1,"movement_multiplier":0.81,"vision_multiplier":0.67,"detection_multiplier":0.61,"hearing_modifier":0.84,"cover_modifier":0.18},{"id":"river","terrain":"water","path":[[0.1,0.5],[0.9,0.5]],"width":0.08,"movement_multiplier":0.5,"vision_multiplier":0.9,"detection_multiplier":0.92,"hearing_modifier":1.0,"cover_modifier":0.0,"swim_allowed":true}]
	var forest:=catalog.gameplay_profile_at(map,Vector2(0.5,0.2)); var river:=catalog.gameplay_profile_at(map,Vector2(0.5,0.5)); _check(is_equal_approx(float(forest.movement_multiplier),0.81) and is_equal_approx(float(forest.detection_multiplier),0.61) and is_equal_approx(float(forest.cover_modifier),0.18),"Forest modifiers not data-driven"); _check(is_equal_approx(float(river.movement_multiplier),0.5) and bool(river.terrain.swim_allowed),"River swim modifiers not data-driven")
	var road:=catalog.road_profile(map,Vector2(float(map.roads[0].path[0][0]),float(map.roads[0].path[0][1]))); _check(not str(road.road_id).is_empty() and float(road.vehicle_spawn_chance)>0,"Road modifier/source id unavailable")
	var military_sources:=0; for id in ids: for source in catalog.loot_sources(catalog.load_map(id)): if str(source.get("source_type",""))=="military": military_sources+=1
	_check(military_sources>0,"No implemented military loot sources")
	var small:=catalog.load_map("tactical_island"); var medium:=catalog.load_map("verdant_reach"); var large:=catalog.load_map("sunscorch_basin"); _check(catalog.loot_density_factor(small)>catalog.loot_density_factor(medium) and catalog.loot_density_factor(medium)>catalog.loot_density_factor(large),"Map-size loot density progression is not connected"); _check(catalog.vehicle_need_factor(small)<catalog.vehicle_need_factor(medium) and catalog.vehicle_need_factor(medium)<catalog.vehicle_need_factor(large),"Map-size vehicle need progression is not connected")
	var runtime=MatchRuntimeScript.new(); runtime.start_match({"active_match_event_id":"authoring","season":1,"active_match_team_count":2,"roster":[{"id":"1","name":"A","role":"IGL","energy":100},{"id":"2","name":"B","role":"Entry","energy":100},{"id":"3","name":"C","role":"Support","energy":100},{"id":"4","name":"D","role":"Sniper","energy":100}],"teams":[{"name":"Enemy"}]},"verdant_reach",{},991)
	var restricted:={"source_type":"standard","allowed_categories":["SR"],"excluded_categories":[],"category_weights":{},"item_weights":{},"rarity_multiplier":1.0}; var generated:=runtime._generate_source_loot(restricted,12); _check(generated.size()==12 and generated.all(func(item): return str(item.kind)=="weapon" and str(runtime._weapon_profile(str(item.weapon)).category)=="SR"),"Allowed category restriction was not consumed")
	runtime.map_data=map; runtime._initialize_vehicle_sources(); var node_id:=str(map.transport_nodes[0].id); runtime.vehicle_sources["node:"+node_id]=true; var node_pos:=Vector2(float(map.transport_nodes[0].position[0]),float(map.transport_nodes[0].position[1])); _check(runtime._can_acquire_vehicle(node_pos,10.0) and not bool(runtime.vehicle_sources["node:"+node_id]),"Vehicle source was not acquired/consumed")
	for id in ids: catalog.reset_override(id)
	if failures>0: push_error("MAP_AUTHORING_SYSTEM_TEST_FAILED checks=%d failures=%d"%[checks,failures]); quit(1)
	else: print("MAP_AUTHORING_SYSTEM_TEST_OK checks=%d"%checks); quit(0)

func _check(condition:bool,message:String)->void:
	checks+=1
	if not condition: failures+=1; push_error("CHECK FAILED: "+message)
