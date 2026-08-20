class_name UserSettings
extends RefCounted

const SETTINGS_PATH := "user://settings.json"
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]

var values: Dictionary = {}

func _init() -> void:
	values = defaults()

static func defaults() -> Dictionary:
	return {
		"master_volume":80,
		"music_volume":70,
		"sfx_volume":80,
		"display_mode":"BORDERLESS",
		"resolution":"1920x1080",
		"vsync":true,
		"ui_scale":100,
		"reduce_motion":false,
		"high_contrast":false,
		"autosave":true
	}

func load_settings() -> void:
	values = defaults()
	if not FileAccess.file_exists(SETTINGS_PATH): return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	if not parsed is Dictionary: return
	for key in values:
		if parsed.has(key): values[key] = parsed[key]

func save_settings() -> bool:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(values, "  "))
	file.close()
	return true

func set_value(key: String, value: Variant, window: Window = null) -> void:
	if not defaults().has(key): return
	values[key] = value
	save_settings()
	apply_runtime(window)

func apply_runtime(window: Window = null) -> void:
	_ensure_audio_bus("Music")
	_ensure_audio_bus("SFX")
	_set_bus_volume("Master", int(values.get("master_volume", 80)))
	_set_bus_volume("Music", int(values.get("music_volume", 70)))
	_set_bus_volume("SFX", int(values.get("sfx_volume", 80)))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(values.get("vsync", true)) else DisplayServer.VSYNC_DISABLED)
	if window == null: return
	window.content_scale_factor = clampf(float(values.get("ui_scale", 100)) / 100.0, 0.80, 1.30)
	var mode := str(values.get("display_mode", "BORDERLESS"))
	if mode == "FULLSCREEN":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif mode == "BORDERLESS":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		DisplayServer.window_set_position(Vector2i.ZERO)
		DisplayServer.window_set_size(DisplayServer.screen_get_size())
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_size(resolution_value())
		var screen_size := DisplayServer.screen_get_size()
		DisplayServer.window_set_position((screen_size - resolution_value()) / 2)

func resolution_value() -> Vector2i:
	var parts := str(values.get("resolution", "1920x1080")).split("x")
	if parts.size() != 2: return Vector2i(1920, 1080)
	return Vector2i(maxi(960, int(parts[0])), maxi(540, int(parts[1])))

func reset(window: Window = null) -> void:
	values = defaults()
	save_settings()
	apply_runtime(window)

func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0: return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)

func _set_bus_volume(bus_name: String, percent: int) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0: return
	var normalized := clampf(float(percent) / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(index, normalized <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.001, normalized)))
