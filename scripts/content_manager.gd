class_name ContentManager
extends RefCounted

const FORMAT_VERSION := 1
const LIBRARY_ROOT := "user://custom_content"
const STAGING_ROOT := "user://custom_content_staging"
const ALLOWED_JSON := ["manifest.json", "teams.json", "players.json", "organizations.json", "tournaments.json", "leagues.json", "rulesets.json", "maps.json"]
const ALLOWED_IMAGE_EXTENSIONS := ["png", "jpg", "jpeg", "webp"]
const MAX_PACKAGE_BYTES := 268435456
const MAX_FILE_BYTES := 16777216
const MAX_FILES := 2048

func list_packages() -> Array:
	_ensure_directory(LIBRARY_ROOT)
	var result: Array = []
	var directory := DirAccess.open(LIBRARY_ROOT)
	if directory == null: return result
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if directory.current_is_dir():
			var manifest := _read_json("%s/%s/manifest.json" % [LIBRARY_ROOT, name])
			if not manifest.is_empty():
				manifest["installed_path"] = "%s/%s" % [LIBRARY_ROOT, name]
				result.append(manifest)
		name = directory.get_next()
	directory.list_dir_end()
	result.sort_custom(func(a, b): return str(a.get("name", "")) < str(b.get("name", "")))
	return result

func inspect_package(package_path: String) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	if not FileAccess.file_exists(package_path): return {"ok":false, "errors":["Package file does not exist."]}
	if FileAccess.get_file_as_bytes(package_path).size() > MAX_PACKAGE_BYTES: return {"ok":false, "errors":["Package exceeds the 256 MB limit."]}
	var zip := ZIPReader.new()
	var open_error := zip.open(package_path)
	if open_error != OK: return {"ok":false, "errors":["Package is not a readable .brm archive."]}
	var files := zip.get_files()
	if files.size() > MAX_FILES: errors.append("Package contains too many files.")
	var normalized: Dictionary = {}
	for source_path in files:
		var path := str(source_path).replace("\\", "/")
		if not _safe_relative_path(path): errors.append("Unsafe archive path: %s" % path); continue
		var key := path.to_lower()
		if normalized.has(key): errors.append("Duplicate case-insensitive path: %s" % path)
		normalized[key] = true
		var bytes := zip.read_file(source_path)
		if bytes.size() > MAX_FILE_BYTES: errors.append("File exceeds 16 MB: %s" % path)
		if not _allowed_file(path): errors.append("Unsupported or executable file: %s" % path)
	if not normalized.has("manifest.json"): errors.append("manifest.json is required.")
	var manifest: Dictionary = {}
	if errors.is_empty():
		var parsed = JSON.parse_string(zip.read_file("manifest.json").get_string_from_utf8())
		if parsed is Dictionary: manifest = parsed
		else: errors.append("manifest.json is invalid JSON.")
	_validate_manifest(manifest, errors, warnings)
	var entities: Dictionary = {}
	for json_name in ALLOWED_JSON:
		if json_name == "manifest.json" or not normalized.has(json_name): continue
		var parsed = JSON.parse_string(zip.read_file(json_name).get_string_from_utf8())
		if not parsed is Dictionary and not parsed is Array: errors.append("%s must contain a JSON object or array." % json_name)
		else: entities[json_name.trim_suffix(".json")] = parsed
	_validate_entities(entities, errors)
	zip.close()
	return {"ok":errors.is_empty(), "manifest":manifest, "entities":entities, "errors":errors, "warnings":warnings, "file_count":files.size()}

func import_package(package_path: String) -> Dictionary:
	var report := inspect_package(package_path)
	if not bool(report.get("ok", false)): return report
	var manifest: Dictionary = report.manifest
	var package_id := str(manifest.package_id)
	var folder_name := _safe_id(package_id)
	var destination := "%s/%s" % [LIBRARY_ROOT, folder_name]
	var staging := "%s/%s_%d" % [STAGING_ROOT, folder_name, Time.get_ticks_msec()]
	_ensure_directory(staging)
	var zip := ZIPReader.new()
	if zip.open(package_path) != OK: return {"ok":false, "errors":["Package could not be reopened."]}
	for source_path in zip.get_files():
		var relative := str(source_path).replace("\\", "/")
		if relative.ends_with("/"): _ensure_directory("%s/%s" % [staging, relative]); continue
		var output_path := "%s/%s" % [staging, relative]
		_ensure_directory(output_path.get_base_dir())
		var output := FileAccess.open(output_path, FileAccess.WRITE)
		if output == null:
			zip.close(); _remove_tree(staging)
			return {"ok":false, "errors":["Could not stage %s." % relative]}
		output.store_buffer(zip.read_file(source_path))
	zip.close()
	_ensure_directory(LIBRARY_ROOT)
	var backup := destination + ".backup"
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(backup)): _remove_tree(backup)
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(destination)):
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(destination), ProjectSettings.globalize_path(backup)) != OK:
			_remove_tree(staging); return {"ok":false, "errors":["Existing package could not be prepared for update."]}
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(staging), ProjectSettings.globalize_path(destination)) != OK:
		if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(backup)): DirAccess.rename_absolute(ProjectSettings.globalize_path(backup), ProjectSettings.globalize_path(destination))
		_remove_tree(staging); return {"ok":false, "errors":["Package installation failed and was rolled back."]}
	_remove_tree(backup)
	return {"ok":true, "package_id":package_id, "version":manifest.version, "installed_path":destination, "warnings":report.warnings}

func delete_package(package_id: String, referenced_by_careers: Array = []) -> Dictionary:
	if not referenced_by_careers.is_empty(): return {"ok":false, "error":"Package is referenced by career saves.", "careers":referenced_by_careers}
	var path := "%s/%s" % [LIBRARY_ROOT, _safe_id(package_id)]
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)): return {"ok":false, "error":"Package is not installed."}
	_remove_tree(path)
	return {"ok":true}

func export_package(package_id: String, destination_path: String) -> Dictionary:
	if destination_path.get_extension().to_lower() != "brm": return {"ok":false,"error":"Export destination must use the .brm extension."}
	var source := "%s/%s" % [LIBRARY_ROOT, _safe_id(package_id)]
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(source)): return {"ok":false,"error":"Package is not installed."}
	var writer := ZIPPacker.new()
	if writer.open(destination_path) != OK: return {"ok":false,"error":"Export archive could not be created."}
	var files: Array[String] = []; _collect_files(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(source), files)
	for relative in files:
		if writer.start_file(relative.replace("\\", "/")) != OK: writer.close(); return {"ok":false,"error":"Could not add %s to export." % relative}
		writer.write_file(FileAccess.get_file_as_bytes(source.path_join(relative)))
		writer.close_file()
	writer.close()
	return {"ok":true,"path":destination_path,"file_count":files.size()}

func create_local_package(manifest: Dictionary, collections: Dictionary = {}) -> Dictionary:
	var errors: Array[String] = []; var warnings: Array[String] = []; _validate_manifest(manifest, errors, warnings); _validate_entities(collections, errors)
	if not errors.is_empty(): return {"ok":false,"errors":errors}
	var destination := "%s/%s" % [LIBRARY_ROOT, _safe_id(str(manifest.package_id))]
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(destination)): return {"ok":false,"errors":["Package ID is already installed. Duplicate it with a new ID."]}
	_ensure_directory(destination)
	var manifest_file := FileAccess.open(destination.path_join("manifest.json"), FileAccess.WRITE)
	if manifest_file == null: _remove_tree(destination); return {"ok":false,"errors":["Package draft could not be created."]}
	manifest_file.store_string(JSON.stringify(manifest, "  "))
	for kind in collections:
		var collection_file := FileAccess.open(destination.path_join("%s.json" % kind), FileAccess.WRITE)
		if collection_file == null: _remove_tree(destination); return {"ok":false,"errors":["Collection %s could not be written." % kind]}
		collection_file.store_string(JSON.stringify(collections[kind], "  "))
	return {"ok":true,"package_id":manifest.package_id,"installed_path":destination,"warnings":warnings}

func resolve_enabled(package_ids: Array) -> Dictionary:
	var available: Dictionary = {}
	for package in list_packages(): available[str(package.get("package_id", ""))] = package
	var errors: Array[String] = []
	var resolved: Array = []
	for package_id in package_ids:
		if not available.has(str(package_id)): errors.append("Missing package: %s" % package_id); continue
		var package: Dictionary = available[str(package_id)]
		for dependency in package.get("dependencies", []):
			var dependency_id := str(dependency.get("package_id", dependency) if dependency is Dictionary else dependency)
			if not available.has(dependency_id): errors.append("%s requires %s" % [package_id, dependency_id])
		resolved.append(package)
	return {"ok":errors.is_empty(), "packages":resolved, "errors":errors}

func _validate_manifest(manifest: Dictionary, errors: Array[String], warnings: Array[String]) -> void:
	for field in ["format_version", "package_id", "name", "version", "author"]:
		if not manifest.has(field) or str(manifest.get(field, "")).strip_edges().is_empty(): errors.append("Manifest field is required: %s" % field)
	if int(manifest.get("format_version", 0)) != FORMAT_VERSION: errors.append("Unsupported package format version.")
	var package_id := str(manifest.get("package_id", ""))
	if package_id != _safe_id(package_id): errors.append("package_id may only contain letters, numbers, dot, underscore and hyphen.")
	if not manifest.has("license"): warnings.append("Package does not declare a license.")

func _validate_entities(collections: Dictionary, errors: Array[String]) -> void:
	var ids: Dictionary = {}
	for kind in collections:
		var value = collections[kind]
		var rows: Array = value if value is Array else value.get(kind, [])
		for row in rows:
			if not row is Dictionary: errors.append("%s contains a non-object entry." % kind); continue
			var id := str(row.get("id", ""))
			if id.is_empty(): errors.append("%s entity has an empty id." % kind)
			elif ids.has(id): errors.append("Duplicate entity id: %s" % id)
			else: ids[id] = kind
	for team_value in [collections.get("teams", [])]:
		var teams: Array = team_value if team_value is Array else team_value.get("teams", [])
		for team in teams:
			for player_id in team.get("roster_ids", []):
				if not ids.has(str(player_id)): errors.append("Team %s references missing player %s." % [team.get("id", ""), player_id])

func _allowed_file(path: String) -> bool:
	var lower := path.to_lower()
	if lower in ALLOWED_JSON or lower == "thumbnail.png": return true
	if lower.begins_with("assets/") or lower.begins_with("localization/"):
		return lower.get_extension() in ALLOWED_IMAGE_EXTENSIONS or (lower.begins_with("localization/") and lower.get_extension() == "json")
	return false

func _safe_relative_path(path: String) -> bool:
	if path.is_empty() or path.begins_with("/") or path.contains(":"): return false
	for component in path.split("/"):
		if component == ".." or component == ".": return false
	return true

func _safe_id(value: String) -> String:
	var result := ""
	for character in value.to_lower():
		if character in "abcdefghijklmnopqrstuvwxyz0123456789._-": result += character
	return result

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func _ensure_directory(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))

func _remove_tree(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute): return
	var directory := DirAccess.open(absolute)
	if directory == null: return
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		var child := absolute.path_join(name)
		if directory.current_is_dir(): _remove_tree(child)
		else: DirAccess.remove_absolute(child)
		name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute)

func _collect_files(root_absolute: String, current_absolute: String, result: Array[String]) -> void:
	var directory := DirAccess.open(current_absolute)
	if directory == null: return
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		var child := current_absolute.path_join(name)
		if directory.current_is_dir(): _collect_files(root_absolute, child, result)
		else: result.append(child.trim_prefix(root_absolute).trim_prefix("/").trim_prefix("\\"))
		name = directory.get_next()
	directory.list_dir_end()
