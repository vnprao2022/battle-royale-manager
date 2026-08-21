class_name MapCatalog
extends RefCounted

const MAP_PATHS := {
	"verdant_reach": "res://data/maps/verdant_reach.json",
	"sunscorch_basin": "res://data/maps/sunscorch_basin.json",
	"tactical_island": "res://data/maps/tactical_island.json",
	"frostline_valley": "res://data/maps/frostline_valley.json",
	"coastal_breakwater": "res://data/maps/coastal_breakwater.json",
	"highland_reserve": "res://data/maps/highland_reserve.json"
}
const OVERRIDE_DIR := "user://map_overrides"
var override_dir := OVERRIDE_DIR

func load_map(map_id: String) -> Dictionary:
	var id := map_id if MAP_PATHS.has(map_id) else "verdant_reach"
	var override_path := "%s/%s.json" % [override_dir, id]
	if FileAccess.file_exists(override_path):
		var override = JSON.parse_string(FileAccess.get_file_as_string(override_path))
		if override is Dictionary and validate(override): return _with_editor_layers(override)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATHS[id]))
	return _with_editor_layers(parsed) if parsed is Dictionary and validate(parsed) else {}

func _with_editor_layers(data: Dictionary) -> Dictionary:
	var result := data.duplicate(true)
	if not result.has("terrain_strokes"): result.terrain_strokes = []
	if not result.has("buildings"): result.buildings = []
	# Older descriptors stored rivers as full-map rectangles. Normalize them into
	# editable center-line strokes before discarding the duplicate legacy layer.
	for water_zone in result.get("water_zones",[]):
		var legacy_id:="legacy_%s"%str(water_zone.get("id","water"))
		if _find_by_id(result.terrain_strokes,legacy_id).is_empty():
			var rect:Array=water_zone.get("rect",[])
			if rect.size()==4:
				var horizontal:=float(rect[2])>=float(rect[3]); var center_x:=float(rect[0])+float(rect[2])*0.5; var center_y:=float(rect[1])+float(rect[3])*0.5
				var path:Array=[[float(rect[0]),center_y],[float(rect[0])+float(rect[2]),center_y]] if horizontal else [[center_x,float(rect[1])],[center_x,float(rect[1])+float(rect[3])]]
				result.terrain_strokes.append({"id":legacy_id,"name":str(water_zone.get("name","River")),"terrain":"water","path":path,"width":float(rect[3]) if horizontal else float(rect[2]),"movement_multiplier":0.5,"vision_multiplier":0.9,"detection_multiplier":0.92,"hearing_modifier":1.0,"cover_modifier":0.0,"density":0.0,"swim_allowed":true,"vehicle_allowed":false})
	# Once normalized, the stroke is the single source of truth. Keeping the old
	# rectangles would make a deleted/moved river silently reappear on reload.
	result.water_zones=[]
	if not result.has("loot_zones"):
		result.loot_zones=[]
		for compound in result.get("compounds",[]):
			var poi:=_find_by_id(result.get("regions",[]),str(compound.get("poi_id",""))); var source_type:="military" if str(poi.get("poi_type",""))=="military_base" else "standard"
			result.loot_zones.append({"id":"zone_%s"%str(compound.id),"name":str(compound.name),"position":compound.position.duplicate(),"radius":float(compound.get("radius",0.04)),"source_type":source_type,"loot_multiplier":float(compound.get("loot_multiplier",1.0)),"loot_slots":maxi(4,int(compound.get("building_count",2))*2),"hotness":float(compound.get("hotness",0.5)),"allowed_categories":[],"excluded_categories":[],"category_weights":{},"item_weights":{},"rarity_multiplier":1.0,"enabled":true})
	if not result.has("loot_nodes"):
		result.loot_nodes=[]
		for point in result.get("points",[]): result.loot_nodes.append({"id":"node_%s"%str(point.id),"name":str(point.name),"position":point.position.duplicate(),"radius":float(point.get("radius",0.025)),"source_type":"village","loot_multiplier":float(point.get("loot_multiplier",0.45)),"loot_slots":int(point.get("loot_slots",3)),"safety":float(point.get("safety",0.8)),"allowed_categories":[],"excluded_categories":[],"category_weights":{},"item_weights":{},"rarity_multiplier":0.75,"enabled":bool(point.get("enabled",true))})
	for stroke in result.terrain_strokes:
		var is_water:=str(stroke.get("terrain","forest"))=="water"; stroke.movement_multiplier=float(stroke.get("movement_multiplier",0.5 if is_water else 0.82)); stroke.vision_multiplier=float(stroke.get("vision_multiplier",0.9 if is_water else 0.68)); stroke.detection_multiplier=float(stroke.get("detection_multiplier",0.92 if is_water else 0.62)); stroke.hearing_modifier=float(stroke.get("hearing_modifier",1.0 if is_water else 0.86)); stroke.cover_modifier=float(stroke.get("cover_modifier",0.0 if is_water else 0.16)); stroke.density=float(stroke.get("density",0.0 if is_water else 0.7)); stroke.swim_allowed=bool(stroke.get("swim_allowed",is_water)); stroke.vehicle_allowed=bool(stroke.get("vehicle_allowed",false))
	for building in result.buildings:
		building.cover_rating=float(building.get("cover_rating",0.25)); building.concealment_rating=float(building.get("concealment_rating",0.22)); building.detection_multiplier=float(building.get("detection_multiplier",0.72)); building.los_blocking=bool(building.get("los_blocking",false)); building.occupancy_capacity=int(building.get("occupancy_capacity",4)); building.loot_enabled=bool(building.get("loot_enabled",false))
	return result

func _find_by_id(items:Array,id:String)->Dictionary:
	for item in items:
		if str(item.get("id",""))==id: return item
	return {}

func save_override(map_data: Dictionary) -> bool:
	if not validate(map_data): return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(override_dir))
	var file := FileAccess.open("%s/%s.json" % [override_dir, map_data.id], FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(map_data, "  "))
	return true

func reset_override(map_id: String) -> void:
	var path := ProjectSettings.globalize_path("%s/%s.json" % [override_dir, map_id])
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

func validate(data: Dictionary) -> bool:
	if int(data.get("schema_version", 0)) != 2: return false
	if not data.get("map_size_km", []) is Array or data.map_size_km.size() != 2: return false
	if float(data.map_size_km[0]) != float(data.map_size_km[1]) or float(data.map_size_km[0]) not in [4.0, 5.0, 6.0]: return false
	for key in ["regions", "compounds", "points", "roads", "transport_nodes"]:
		if not data.get(key, []) is Array: return false
	if data.regions.size() < 4 or data.compounds.size() < data.regions.size() or data.roads.size() < 3: return false
	var poi_ids := {}
	for region in data.regions:
		if not _valid_positioned_item(region) or float(region.get("loot_multiplier", -1.0)) < 0.0: return false
		poi_ids[str(region.id)] = true
	for compound in data.compounds:
		if not _valid_positioned_item(compound) or int(compound.get("building_count", 0)) < 1: return false
		if str(compound.get("poi_id", "")) != "" and not poi_ids.has(str(compound.poi_id)): return false
	for road in data.roads:
		if not road.has("id") or str(road.get("road_class", "")) not in ["highway", "secondary", "dirt"]: return false
		if not road.get("path", []) is Array or road.path.size() < 2: return false
	for node in data.transport_nodes:
		if not _valid_positioned_item(node): return false
	for stroke in data.get("terrain_strokes", []):
		if str(stroke.get("terrain", "")) not in ["water", "forest"] or not stroke.get("path", []) is Array or stroke.path.size() < 2: return false
		if float(stroke.get("width", 0.0)) <= 0.0: return false
	for building in data.get("buildings", []):
		if not building.has("id") or not building.get("rect", []) is Array or building.rect.size() != 4: return false
		if float(building.rect[2]) <= 0.0 or float(building.rect[3]) <= 0.0: return false
	for zone in data.get("loot_zones",[]):
		if not _valid_positioned_item(zone) or float(zone.get("radius",0.0))<=0.0 or int(zone.get("loot_slots",0))<1: return false
	for node in data.get("loot_nodes",[]):
		if not _valid_positioned_item(node) or int(node.get("loot_slots",0))<1: return false
	return true

func _valid_positioned_item(item: Dictionary) -> bool:
	return item.has("id") and item.get("position", []) is Array and item.position.size() == 2

func map_size_km(data: Dictionary) -> float:
	return float(data.get("map_size_km", [5.0, 5.0])[0])

func loot_density_factor(data: Dictionary) -> float:
	var size := map_size_km(data)
	return float(data.get("loot_profile", {}).get("size_density_factor", 1.25 if size <= 4.0 else 0.82 if size >= 6.0 else 1.0))

func vehicle_need_factor(data: Dictionary) -> float:
	var size := map_size_km(data)
	return float(data.get("transport_profile", {}).get("vehicle_need_factor", 0.72 if size <= 4.0 else 1.35 if size >= 6.0 else 1.0))

func loot_sources(data: Dictionary) -> Array:
	var sources: Array = []
	for zone in data.get("loot_zones", []):
		if not bool(zone.get("enabled",true)): continue
		var source: Dictionary = zone.duplicate(true)
		source["source_kind"] = "loot_zone"
		source["effective_multiplier"] = float(zone.get("loot_multiplier", 1.0)) * loot_density_factor(data)
		sources.append(source)
	for node in data.get("loot_nodes", []):
		if not bool(node.get("enabled", true)): continue
		var source: Dictionary = node.duplicate(true)
		source["source_kind"] = "loot_node"
		source["radius"] = float(node.get("radius", 0.025))
		source["effective_multiplier"] = float(node.get("loot_multiplier", 0.45)) * loot_density_factor(data)
		sources.append(source)
	for building in data.get("buildings", []):
		if not bool(building.get("enabled", true)) or not bool(building.get("loot_enabled",false)): continue
		var source: Dictionary = building.duplicate(true)
		var rect: Array = building.get("rect", [0.45,0.45,0.1,0.1])
		source["position"] = [float(rect[0]) + float(rect[2]) * 0.5, float(rect[1]) + float(rect[3]) * 0.5]
		source["radius"] = maxf(float(rect[2]), float(rect[3])) * 0.55
		source["source_kind"] = "building"
		source["effective_multiplier"] = float(building.get("loot_multiplier", 0.75)) * loot_density_factor(data)
		sources.append(source)
	return sources

func road_profile(data: Dictionary, position: Vector2) -> Dictionary:
	var best := {"road_id":"","road_class":"offroad", "speed_multiplier":1.0, "vehicle_spawn_chance":0.0, "width":0.025, "distance":99.0}
	for road in data.get("roads", []):
		var path: Array = road.get("path", [])
		for index in range(path.size() - 1):
			var distance := _distance_to_segment(position, Vector2(float(path[index][0]), float(path[index][1])), Vector2(float(path[index + 1][0]), float(path[index + 1][1])))
			if distance < float(best.distance):
				var road_class:=str(road.get("road_class","secondary")); var default_spawn:=0.45 if road_class=="highway" else 0.25 if road_class=="secondary" else 0.08
				best = {"road_id":str(road.get("id","")),"road_class":road_class, "speed_multiplier":float(road.get("vehicle_speed", 1.0)), "vehicle_spawn_chance":float(road.get("vehicle_spawn_chance", default_spawn)), "width":float(road.get("width", 0.025)), "distance":distance}
	return best

func terrain_profile_at(data: Dictionary, position: Vector2) -> Dictionary:
	var profile := {"terrain":"", "movement_multiplier":1.0, "vision_multiplier":1.0,"detection_multiplier":1.0,"hearing_modifier":1.0,"cover_modifier":0.0,"swim_allowed":false,"vehicle_allowed":true,"inside":false}
	for zone in data.get("water_zones", []):
		var rect: Array = zone.get("rect", [])
		if rect.size() == 4 and Rect2(float(rect[0]),float(rect[1]),float(rect[2]),float(rect[3])).has_point(position):
			profile = {"terrain":"water", "movement_multiplier":0.5, "vision_multiplier":0.9,"detection_multiplier":0.92,"hearing_modifier":1.0,"cover_modifier":0.0,"swim_allowed":true,"vehicle_allowed":false,"inside":true}
	for stroke in data.get("terrain_strokes", []):
		var path: Array = stroke.get("path", [])
		for index in range(path.size() - 1):
			if _distance_to_segment(position, Vector2(float(path[index][0]),float(path[index][1])), Vector2(float(path[index + 1][0]),float(path[index + 1][1]))) <= float(stroke.get("width",0.05)) * 0.5:
				profile = {"terrain":str(stroke.terrain),"movement_multiplier":float(stroke.get("movement_multiplier",1.0)),"vision_multiplier":float(stroke.get("vision_multiplier",1.0)),"detection_multiplier":float(stroke.get("detection_multiplier",1.0)),"hearing_modifier":float(stroke.get("hearing_modifier",1.0)),"cover_modifier":float(stroke.get("cover_modifier",0.0)),"swim_allowed":bool(stroke.get("swim_allowed",str(stroke.terrain)=="water")),"vehicle_allowed":bool(stroke.get("vehicle_allowed",false)),"inside":true}
				break
	return profile

func building_profile_at(data: Dictionary, position: Vector2) -> Dictionary:
	for building in data.get("buildings", []):
		var rect: Array = building.get("rect", [])
		if bool(building.get("enabled",true)) and rect.size()==4 and Rect2(float(rect[0]),float(rect[1]),float(rect[2]),float(rect[3])).has_point(position): return building
	return {}

func loot_slot_count(source: Dictionary) -> int:
	if source.has("loot_slots"): return maxi(1,int(source.loot_slots))
	if str(source.get("source_kind","")) in ["loot_node","building"]: return 3
	return maxi(4, int(source.get("building_count",1)) * 2)

func gameplay_profile_at(data:Dictionary,position:Vector2)->Dictionary:
	var terrain:=terrain_profile_at(data,position); var building:=building_profile_at(data,position)
	return {"terrain":terrain,"building":building,"movement_multiplier":float(terrain.get("movement_multiplier",1.0)),"vision_multiplier":float(terrain.get("vision_multiplier",1.0)),"detection_multiplier":float(terrain.get("detection_multiplier",1.0))*float(building.get("detection_multiplier",1.0)),"hearing_modifier":float(terrain.get("hearing_modifier",1.0)),"cover_modifier":clampf(float(terrain.get("cover_modifier",0.0))+float(building.get("cover_rating",0.0)),0.0,0.9),"concealment_rating":float(building.get("concealment_rating",0.0)),"los_blocking":bool(building.get("los_blocking",false)),"occupancy_id":str(building.get("id",""))}

func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var delta := finish - start
	if delta.length_squared() <= 0.000001: return point.distance_to(start)
	var progress := clampf((point - start).dot(delta) / delta.length_squared(), 0.0, 1.0)
	return point.distance_to(start + delta * progress)

func movement_profile(data: Dictionary, terrain: String, transport: String, position := Vector2(-1.0, -1.0)) -> Dictionary:
	var rule: Dictionary = data.get("terrain_rules", {}).get(terrain, {})
	var allowed := bool(rule.get("vehicle", false)) if transport == "vehicle" else bool(rule.get("walkable", true))
	var multiplier := float(rule.get("vehicle_speed", 0.0)) if transport == "vehicle" else float(rule.get("walk_speed", 1.0))
	var road := road_profile(data, position) if position.x >= 0.0 else {"road_class":"offroad", "speed_multiplier":1.0, "distance":99.0}
	var on_road:=float(road.distance)<=float(road.get("width",0.025))*0.6
	if transport == "vehicle" and on_road: multiplier *= float(road.speed_multiplier)
	return {"allowed": allowed and multiplier > 0.0, "speed_multiplier": multiplier, "road_class":road.road_class, "on_road":on_road}
