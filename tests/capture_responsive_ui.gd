extends SceneTree

const SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1080)]
const PAGES := ["dashboard", "roster", "player_detail", "scouting", "transfers", "contracts", "training", "tactics", "calendar", "match", "tournament", "rankings", "team_profile", "analytics", "player_stats", "inbox", "media", "finance", "national_team", "facilities", "trophies", "settings"]

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/output/responsive"))
	for viewport_size in SIZES:
		DisplayServer.window_set_size(viewport_size)
		root.content_scale_size = viewport_size
		root.size = viewport_size
		await process_frame
		await process_frame
		var scene = load("res://main.tscn").instantiate()
		scene.game.save_path = "user://codex_capture_responsive.json"
		root.add_child(scene)
		await process_frame
		scene.game.new_career("Mekong Reapers", "Analyst trẻ", "SEA")
		scene._enter_game()
		scene.selected_world_team_id = str(scene.game.data.organization_id)
		for page in PAGES:
			scene._show_page(page)
			for frame in 5:
				await process_frame
			var image := root.get_viewport().get_texture().get_image()
			if image.get_size() != viewport_size:
				image.resize(viewport_size.x, viewport_size.y, Image.INTERPOLATE_LANCZOS)
			var filename := "%dx%d_%s.png" % [viewport_size.x, viewport_size.y, page]
			assert(image.save_png("res://tests/output/responsive/" + filename) == OK)
		scene.assets.clear_cache()
		scene.queue_free()
		for i in 4: await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://codex_capture_responsive.json"))
	print("RESPONSIVE_CAPTURE_OK sizes=%d screens=%d" % [SIZES.size(), PAGES.size()])
	quit(0)
