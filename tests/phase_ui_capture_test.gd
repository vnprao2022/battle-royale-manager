extends SceneTree

const OUTPUT_DIR:="res://tests/output/phase_ui"
const SIZES:=[Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1080)]
var captures:=0
var checks:=0

func _init()->void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for viewport_size in SIZES:
		var viewport:=SubViewport.new(); viewport.size=viewport_size; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
		var scene=load("res://main.tscn").instantiate(); scene.game.save_path="user://phase_ui_%dx%d.json"%[viewport_size.x,viewport_size.y]; viewport.add_child(scene); await _settle()
		scene.game.new_career("Resolution QA","Manager","SEA"); scene.game.set_developer_mode(true); scene._enter_game(); await _settle()
		for page in ["dashboard","match","settings"]: scene._show_page(page); await _settle(); await _capture(viewport,"%dx%d_%s"%[viewport_size.x,viewport_size.y,page])
		scene.map_editor_data=scene.map_catalog.load_map("verdant_reach"); scene._show_page("map_manager"); await _settle(); _assert_control_in_view(scene,"SAVE OVERRIDE",viewport_size); _assert_control_in_view(scene,"ADD LOOT ZONE",viewport_size); await _capture(viewport,"%dx%d_map_lab"%[viewport_size.x,viewport_size.y])
		scene._show_page("analytics"); await _settle(); await _capture(viewport,"%dx%d_analyst_map"%[viewport_size.x,viewport_size.y])
		scene.match_runtime.start_match(scene.game.data,"verdant_reach",{},8812); scene.match_ui_mode="observer"; scene._show_page("match_lab"); await _settle(); await _capture(viewport,"%dx%d_match_observer"%[viewport_size.x,viewport_size.y]); scene._set_match_ui_mode("lab"); await _settle(); await _capture(viewport,"%dx%d_match_lab"%[viewport_size.x,viewport_size.y])
		if viewport_size==Vector2i(1920,1080): await _capture_map_states(scene,viewport)
		scene.queue_free(); viewport.queue_free(); for frame in 4: await process_frame; DirAccess.remove_absolute(ProjectSettings.globalize_path("user://phase_ui_%dx%d.json"%[viewport_size.x,viewport_size.y]))
	print("PHASE_UI_CAPTURE_TEST_OK checks=%d captures=%d"%[checks,captures]); quit(0)

func _capture_map_states(scene,viewport:SubViewport)->void:
	scene.map_editor_data=scene.map_catalog.load_map("verdant_reach"); scene.map_editor_tool="river"; scene._show_page("map_manager"); await _settle(); await _capture(viewport,"1920x1080_map_brush")
	scene._add_map_loot_zone(); await _settle(); await _capture(viewport,"1920x1080_loot_zone")
	scene._add_map_loot_node(); await _settle(); await _capture(viewport,"1920x1080_loot_node")
	scene._on_map_editor_rect_completed(Rect2(0.42,0.42,0.09,0.06)); scene._show_page("map_manager"); await _settle(); await _capture(viewport,"1920x1080_building")
	scene.map_editor_selected_kind="transport_node"; scene.map_editor_selected_index=0; scene._show_page("map_manager"); await _settle(); await _capture(viewport,"1920x1080_vehicle_node")

func _assert_control_in_view(node:Node,text_value:String,viewport_size:Vector2i)->void:
	var control:=_find_text_control(node,text_value); assert(control!=null,"Missing control: "+text_value); var rect:Rect2=control.get_global_rect(); assert(rect.intersects(Rect2(Vector2.ZERO,viewport_size)),"Control outside first viewport: "+text_value); checks+=1

func _find_text_control(node:Node,text_value:String)->Control:
	if node is Button and str(node.text).contains(text_value) and node.is_visible_in_tree(): return node
	for child in node.get_children(): var found:=_find_text_control(child,text_value); if found!=null: return found
	return null

func _settle()->void:
	for frame in 7: await process_frame

func _capture(viewport:SubViewport,name:String)->void:
	var image:=viewport.get_texture().get_image(); assert(image.get_size()==viewport.size,"Capture size mismatch"); assert(image.save_png("%s/%s.png"%[OUTPUT_DIR,name])==OK); captures+=1
