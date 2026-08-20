class_name AssetRegistry
extends RefCounted

const MANIFEST_PATH := "res://assets/asset_manifest.json"
const GENERATED_MANIFEST_PATH := "res://assets/generated/branding/generated_manifest.json"
const GENERATED_WEAPON_MANIFEST_PATH := "res://assets/generated/weapons/weapon_manifest.json"
const CUSTOM_INDEX_PATH := "user://custom_content/assets_index.json"
var _descriptors: Dictionary = {}
var _cache: Dictionary = {}
var schema_version := 0

func initialize() -> bool:
	if not FileAccess.file_exists(MANIFEST_PATH): return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary or not parsed.has("assets"): return false
	schema_version = int(parsed.get("schema_version", 0))
	_descriptors = parsed.assets
	for generated_path in [GENERATED_MANIFEST_PATH, GENERATED_WEAPON_MANIFEST_PATH]:
		if not FileAccess.file_exists(generated_path): continue
		var generated: Variant = JSON.parse_string(FileAccess.get_file_as_string(generated_path))
		if generated is Dictionary:
			for id in generated.get("assets", {}): _descriptors[id] = generated.assets[id]
	if FileAccess.file_exists(CUSTOM_INDEX_PATH):
		var custom = JSON.parse_string(FileAccess.get_file_as_string(CUSTOM_INDEX_PATH))
		if custom is Dictionary:
			for id in custom.get("assets", {}): _descriptors[id] = custom.assets[id]
	return schema_version >= 2

func has_asset(id: String) -> bool:
	return _descriptors.has(id)

func weapon_asset_id(weapon_name: String, variant := "inventory") -> String:
	# Generated weapons are individual PNG assets. Resolve by a normalized key so
	# names from legacy saves ("DP-28", "SCAR L") and current runtime names
	# ("DP-28", "SCAR-L") reach the same specific asset instead of a category icon.
	var key := _weapon_key(weapon_name)
	for id in _descriptors:
		var asset_id := str(id)
		if not asset_id.begins_with("weapon.generated."): continue
		var generated_key := _weapon_key(asset_id.trim_prefix("weapon.generated.").trim_suffix(".inventory"))
		if generated_key == key: return asset_id
	var category := "smg_9mm"
	if key in ["akm","berylm762","groza","ace32","m16a4","mutant"]: category="ar_762"
	elif key in ["m416","scarl","aug","qbz","g36c","famas"]: category="ar_556"
	elif key in ["mini14","slr","sks","mk12","dragunov"]: category="dmr_762"
	elif key in ["m24","awm","kar98k","lynxamr"]: category="sniper_bolt"
	elif key in ["mg3","m249"]: category="lmg_556"
	elif key in ["s1897","s12k","dbs","o12"]: category="shotgun_12g"
	elif key in ["p92","p18c","deagle","r1895"]: category="pistol_9mm"
	elif key == "vss": category="vss_9x39"
	return "weapon.%s.%s" % [category, "kill_feed" if variant == "kill_feed" else "inventory"]

func _weapon_key(value: String) -> String:
	return value.to_lower().replace(" ", "").replace("-", "").replace("_", "").replace(".", "")

func descriptor(id: String) -> Dictionary:
	return _descriptors.get(id, {})

func texture(id: String) -> Texture2D:
	if _cache.has(id): return _cache[id]
	if id.begins_with("res://") and ResourceLoader.exists(id):
		var direct = load(id)
		if direct is Texture2D: _cache[id] = direct; return direct
	var info: Dictionary = descriptor(id)
	if info.is_empty(): return null
	var path := str(info.get("path", ""))
	if path.begins_with("user://"):
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null and not image.is_empty():
			var custom_texture := ImageTexture.create_from_image(image); _cache[id] = custom_texture; return custom_texture
	if path.is_empty() or not ResourceLoader.exists(path): return null
	var resource = load(path)
	if resource is Texture2D:
		_cache[id] = resource
		return resource
	return null

func unload(id: String) -> void:
	_cache.erase(id)

func clear_cache() -> void:
	_cache.clear()

func cached_count() -> int:
	return _cache.size()

func import_custom_image(source_path: String, asset_id: String, domain: String, max_dimensions := Vector2i(1024, 1024), max_bytes := 5242880) -> Dictionary:
	if source_path.is_empty() or not FileAccess.file_exists(source_path): return {"ok":false,"error":"Image file does not exist."}
	var extension := source_path.get_extension().to_lower()
	if not extension in ["png","jpg","jpeg","webp"]: return {"ok":false,"error":"Only PNG, JPG and WEBP images are supported."}
	var bytes := FileAccess.get_file_as_bytes(source_path)
	if bytes.size() > max_bytes: return {"ok":false,"error":"Image exceeds the file-size limit."}
	var image := Image.new()
	var load_error := image.load(source_path)
	if load_error != OK or image.is_empty(): return {"ok":false,"error":"Image could not be decoded."}
	if image.get_width() > max_dimensions.x or image.get_height() > max_dimensions.y: return {"ok":false,"error":"Image dimensions exceed %dx%d." % [max_dimensions.x,max_dimensions.y]}
	var safe_id := _safe_custom_id(asset_id)
	if safe_id.is_empty(): return {"ok":false,"error":"Asset ID is invalid."}
	var destination_dir := "user://custom_content/assets/%s" % _safe_custom_id(domain)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination_dir))
	var destination := "%s/%s.png" % [destination_dir,safe_id]
	if image.save_png(destination) != OK: return {"ok":false,"error":"Normalized image could not be saved."}
	_descriptors[asset_id] = {"path":destination,"domain":"custom.%s" % domain,"source":"player_content"}
	var index := {"schema_version":1,"assets":{}}
	if FileAccess.file_exists(CUSTOM_INDEX_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(CUSTOM_INDEX_PATH)); if parsed is Dictionary: index = parsed
	index.assets[asset_id] = _descriptors[asset_id]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CUSTOM_INDEX_PATH.get_base_dir()))
	var file := FileAccess.open(CUSTOM_INDEX_PATH, FileAccess.WRITE)
	if file == null: return {"ok":false,"error":"Custom asset index could not be written."}
	file.store_string(JSON.stringify(index, "  ")); _cache.erase(asset_id)
	return {"ok":true,"asset_id":asset_id,"path":destination,"width":image.get_width(),"height":image.get_height()}

func remove_custom_asset(asset_id: String) -> Dictionary:
	var descriptor_value: Dictionary = _descriptors.get(asset_id, {})
	if str(descriptor_value.get("source", "")) != "player_content": return {"ok":false,"error":"Only player-created assets can be removed."}
	var path := str(descriptor_value.get("path", "")); if path.begins_with("user://") and FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_descriptors.erase(asset_id); _cache.erase(asset_id)
	var index := {"schema_version":1,"assets":{}}
	for id in _descriptors:
		if str(_descriptors[id].get("source", "")) == "player_content": index.assets[id] = _descriptors[id]
	var file := FileAccess.open(CUSTOM_INDEX_PATH, FileAccess.WRITE); if file != null: file.store_string(JSON.stringify(index, "  "))
	return {"ok":true}

func _safe_custom_id(value: String) -> String:
	var result := ""
	for character in value.to_lower():
		if character in "abcdefghijklmnopqrstuvwxyz0123456789._-": result += character
	return result
