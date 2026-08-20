extends SceneTree

const OUTPUT_DIR:="res://tests/output/precareer"
var captures:=0

func _init()->void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	DisplayServer.window_set_size(Vector2i(1280,720)); root.content_scale_size=Vector2i(1280,720); root.size=Vector2i(1280,720)
	for frame in 3: await process_frame
	var scene=load("res://main.tscn").instantiate(); scene.game.save_path="user://codex_precareer_ui_test.json"; root.add_child(scene)
	for frame in 4: await process_frame
	assert(not scene.sidebar.visible and not scene.topbar.visible,"Pre-career shell still reserves sidebar or topbar space")
	assert(is_equal_approx(scene.shell_main.offset_left,0.0),"Pre-career content is shifted to the right")
	await _capture("main_menu")
	scene._show_custom_content(); await _settle(); assert(_find_button(scene,"BACK TO MAIN MENU")!=null,"Custom Content has no back control"); await _capture("custom_content")
	scene._show_start_settings(); await _settle(); assert(_find_label(scene,"MASTER VOLUME")!=null and _find_label(scene,"WINDOW MODE")!=null and _find_label(scene,"WINDOWED RESOLUTION")!=null,"Startup settings controls are incomplete"); await _capture("settings")
	scene.career_step=4; scene.career_draft.team_mode="new"; scene.career_draft.journey_mode="story"; scene.career_draft.org_name="Northstar"; scene._show_new_career(); await _settle(); assert(_find_label(scene,"MANAGER NAME")!=null and _find_label(scene,"OR BUILD FROM A LOGO PATTERN")!=null,"Career identity controls are incomplete"); await _capture("career_identity")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://codex_precareer_ui_test.json")); print("PRECAREER_UI_TEST_OK captures=%d"%captures); quit(0)

func _capture(name:String)->void:
	await _settle(); var image:=root.get_viewport().get_texture().get_image(); if image.get_size()!=Vector2i(1280,720): image.resize(1280,720,Image.INTERPOLATE_LANCZOS)
	assert(image.save_png("%s/%s.png"%[OUTPUT_DIR,name])==OK); captures+=1

func _settle()->void:
	for frame in 6: await process_frame

func _find_button(node:Node,text:String)->Button:
	if node is Button and node.is_visible_in_tree() and str(node.text).contains(text): return node
	for child in node.get_children(): var found:=_find_button(child,text); if found!=null: return found
	return null

func _find_label(node:Node,text:String)->Label:
	if node is Label and node.is_visible_in_tree() and str(node.text).contains(text): return node
	for child in node.get_children(): var found:=_find_label(child,text); if found!=null: return found
	return null
