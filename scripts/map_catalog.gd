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

func load_map(map_id: String) -> Dictionary:
	var id := map_id if MAP_PATHS.has(map_id) else "verdant_reach"
	var override_path := "%s/%s.json" % [OVERRIDE_DIR, id]
	var path: String = override_path if FileAccess.file_exists(override_path) else MAP_PATHS[id]
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func save_override(map_data: Dictionary) -> bool:
	if not validate(map_data): return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OVERRIDE_DIR))
	var file := FileAccess.open("%s/%s.json" % [OVERRIDE_DIR, map_data.id], FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(map_data, "  "))
	return true

func reset_override(map_id: String) -> void:
	var path := ProjectSettings.globalize_path("%s/%s.json" % [OVERRIDE_DIR, map_id])
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

func validate(data: Dictionary) -> bool:
	if int(data.get("schema_version", 0)) != 1: return false
	if not data.get("regions", []) is Array or not data.get("points", []) is Array: return false
	for region in data.regions:
		if not region.has("id") or not region.has("position") or region.position.size() != 2: return false
		if float(region.get("loot_multiplier", -1.0)) < 0.0: return false
	return true

func movement_profile(data: Dictionary, terrain: String, transport: String) -> Dictionary:
	var rule: Dictionary = data.get("terrain_rules", {}).get(terrain, {})
	var allowed := bool(rule.get("vehicle", false)) if transport == "vehicle" else bool(rule.get("walkable", true))
	var multiplier := float(rule.get("vehicle_speed", 0.0)) if transport == "vehicle" else float(rule.get("walk_speed", 1.0))
	return {"allowed": allowed and multiplier > 0.0, "speed_multiplier": multiplier}
