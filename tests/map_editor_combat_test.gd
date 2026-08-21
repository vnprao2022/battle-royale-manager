extends SceneTree

const MapCatalogScript=preload("res://scripts/map_catalog.gd")
const MatchRuntimeScript=preload("res://scripts/match_runtime.gd")
var checks:=0
var failures:=0

func _init()->void:
	var catalog=MapCatalogScript.new(); var map_data:Dictionary=catalog.load_map("verdant_reach")
	map_data.terrain_strokes=[{"id":"test_river","name":"Test River","terrain":"water","width":0.08,"movement_multiplier":0.5,"vision_multiplier":0.9,"path":[[0.1,0.5],[0.9,0.5]]},{"id":"test_forest","name":"Test Forest","terrain":"forest","width":0.1,"movement_multiplier":0.82,"vision_multiplier":0.55,"path":[[0.1,0.2],[0.9,0.2]]}]
	map_data.buildings=[{"id":"test_house","name":"Test House","building_type":"house","rect":[0.4,0.4,0.1,0.1],"cover_rating":0.3,"concealment_rating":0.2,"detection_multiplier":0.7,"loot_enabled":false,"enabled":true}]
	_check(catalog.validate(map_data),"Editable brush/building schema was rejected")
	_check(str(catalog.terrain_profile_at(map_data,Vector2(0.5,0.5)).terrain)=="water" and float(catalog.terrain_profile_at(map_data,Vector2(0.5,0.5)).movement_multiplier)==0.5,"River brush does not produce swimming speed")
	_check(float(catalog.terrain_profile_at(map_data,Vector2(0.5,0.2)).vision_multiplier)==0.55,"Forest brush does not reduce vision")
	_check(float(catalog.building_profile_at(map_data,Vector2(0.45,0.45)).cover_rating)==0.3,"Building rectangle does not provide cover")
	var building_sources:=catalog.loot_sources(map_data).filter(func(source): return str(source.get("source_kind",""))=="building")
	_check(building_sources.is_empty(),"Building incorrectly became a loot source by default")
	map_data.buildings[0].loot_enabled=true; map_data.buildings[0].loot_slots=3; map_data.buildings[0].loot_multiplier=0.75; building_sources=catalog.loot_sources(map_data).filter(func(source): return str(source.get("source_kind",""))=="building")
	_check(building_sources.size()==1 and catalog.loot_slot_count(building_sources[0])==3,"Explicit building loot association is not connected")
	var road:=catalog.road_profile(map_data,Vector2(0.3,0.3)); _check(float(road.get("vehicle_spawn_chance",0.0))>0.0,"Road vehicle spawning is not available")

	var runtime=MatchRuntimeScript.new(); runtime.map_data=map_data
	_check(runtime.display_ammo_for_weapon("M416",2)==60 and runtime.display_ammo_for_weapon("M24",2)==10,"Simulation shots do not convert to category UI ammo")
	_check(runtime._weapon_damage_at_distance("M416",440.0)<runtime._weapon_damage_at_distance("M416",100.0),"Rifle damage has no distance falloff")
	var armored:=[{"name":"Armored","state":"ALIVE","health":100,"loadout":runtime._make_loadout(0)}]; armored[0].loadout.vest="Lv.1"; armored[0].loadout.vest_durability=50.0
	var armor_result:Dictionary=runtime._apply_damage(armored,0,80.0,"WEAPON","Shooter","T","M416",false,120.0)
	_check(int(armor_result.absorbed)==50 and int(armored[0].health)==70 and float(armored[0].loadout.vest_durability)==0.0,"Armor is not acting as durability-based virtual HP")
	var unarmored:=[{"name":"Unarmored","state":"ALIVE","health":100,"loadout":runtime._make_loadout(0)}]
	runtime._apply_damage(unarmored,0,105.0,"WEAPON","Sniper","T","M24",false,600.0)
	_check(str(unarmored[0].state)=="KNOCKED" and int(runtime.kill_feed[0].distance_m)==600,"Unarmored sniper lethality or kill-feed distance is missing")
	var sniper:={"role":"Sniper","loadout":runtime._make_loadout(0)}; var offers:=[{"kind":"weapon","weapon":"UMP45"},{"kind":"weapon","weapon":"M24"}]
	_check(runtime._choose_loot_item(sniper,offers)==1,"Sniper role did not prefer SR loot")
	if failures>0: push_error("MAP_EDITOR_COMBAT_TEST_FAILED checks=%d failures=%d"%[checks,failures]); quit(1)
	else: print("MAP_EDITOR_COMBAT_TEST_OK checks=%d"%checks); quit(0)

func _check(condition:bool,message:String)->void:
	checks+=1
	if not condition: failures+=1; push_error("CHECK FAILED: "+message)
