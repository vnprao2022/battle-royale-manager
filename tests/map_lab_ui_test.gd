extends SceneTree

const OUTPUT_DIR:="res://tests/output/map_lab"
var captures:=0

func _init()->void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for viewport_size in [Vector2i(1280,720),Vector2i(1920,1080)]:
		DisplayServer.window_set_size(viewport_size); root.content_scale_size=viewport_size; root.size=viewport_size
		for frame in 3: await process_frame
		var scene=load("res://main.tscn").instantiate(); scene.game.save_path="user://codex_map_lab_ui.json"; root.add_child(scene); for frame in 4: await process_frame
		scene.game.new_career("Map Lab","Analyst","SEA"); scene.game.set_developer_mode(true); scene._enter_game(); scene.map_editor_data=scene.map_catalog.load_map("verdant_reach"); scene._show_page("map_manager"); await _settle()
		assert(_find_option_with_metadata(scene,"river")!=null,"Map Manager has no river brush")
		assert(_find_option_with_metadata(scene,"building")!=null,"Map Manager has no building rectangle tool")
		var overlay=scene.match_lab_nodes.map_editor_overlay; assert(overlay.size.x>0.0 and is_equal_approx(overlay.size.x,overlay.size.y),"Map editor canvas is not a rendered square")
		var initial_roads:int=scene.map_editor_data.roads.size(); var initial_strokes:int=scene.map_editor_data.terrain_strokes.size(); var initial_buildings:int=scene.map_editor_data.buildings.size()
		_paint(overlay,"road_highway",Vector2(0.08,0.08),[Vector2(0.22,0.16),Vector2(0.42,0.24),Vector2(0.70,0.42)]); _paint(overlay,"river",Vector2(0.08,0.64),[Vector2(0.22,0.57),Vector2(0.45,0.61),Vector2(0.76,0.52)]); _paint(overlay,"forest",Vector2(0.08,0.92),[Vector2(0.17,0.92),Vector2(0.27,0.90)]); _paint_rect(overlay,Vector2(0.73,0.78),Vector2(0.82,0.85)); await _settle()
		assert(scene.map_editor_data.roads.size()==initial_roads+1 and scene.map_editor_data.terrain_strokes.size()==initial_strokes+2 and scene.map_editor_data.buildings.size()==initial_buildings+1,"Real pointer gestures did not create road, river, forest and building layers")
		var previous_width:float=scene.map_editor_brush_width; overlay.set_editor_tool("forest",previous_width); overlay._gui_input(_key(KEY_BRACKETRIGHT)); assert(scene.map_editor_brush_width>previous_width,"Keyboard brush resize was not connected")
		overlay.set_editor_tool("erase",scene.map_editor_brush_width); overlay._gui_input(_mouse_button(Vector2(0.17,0.92)*overlay.size,true)); await _settle(); assert(scene.map_editor_data.terrain_strokes.size()==initial_strokes+1,"Eraser did not remove the painted forest stroke")
		var after_erase:int=scene.map_editor_data.terrain_strokes.size(); scene._map_editor_undo_action(); await _settle(); assert(scene.map_editor_data.terrain_strokes.size()==after_erase+1,"Undo did not restore erased editor data"); scene._map_editor_redo_action(); await _settle(); assert(scene.map_editor_data.terrain_strokes.size()==after_erase,"Redo did not reapply erase")
		assert(scene.map_catalog.validate(scene.map_editor_data),"Brush-created map is invalid")
		await _capture("%dx%d_map_manager"%[viewport_size.x,viewport_size.y])
		scene._show_page("analytics"); await _settle(); assert(_find_label(scene,"ANALYST MAP • READ ONLY")!=null,"Team Analysis has no read-only analyst map"); assert(scene.match_lab_nodes.has("analyst_overlay") and not scene.match_lab_nodes.analyst_overlay.editor_enabled and scene.match_lab_nodes.analyst_overlay.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Analyst Map accepts editor mutation input"); await _capture("%dx%d_analyst_map"%[viewport_size.x,viewport_size.y])
		scene.queue_free(); for frame in 3: await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://codex_map_lab_ui.json")); print("MAP_LAB_UI_TEST_OK captures=%d"%captures); quit(0)

func _settle()->void:
	for frame in 7: await process_frame

func _capture(name:String)->void:
	var image:=root.get_viewport().get_texture().get_image(); assert(not image.is_empty(),"Renderer returned an empty image"); assert(image.save_png("%s/%s.png"%[OUTPUT_DIR,name])==OK); captures+=1

func _paint(overlay:Control,tool:String,start:Vector2,points:Array)->void:
	overlay.set_editor_tool(tool,0.05); overlay._gui_input(_mouse_button(start*overlay.size,true))
	for point in points: overlay._gui_input(_motion(Vector2(point)*overlay.size,true))
	overlay._gui_input(_mouse_button(Vector2(points[-1])*overlay.size,false))

func _paint_rect(overlay:Control,start:Vector2,finish:Vector2)->void:
	overlay.set_editor_tool("building",0.05); overlay._gui_input(_mouse_button(start*overlay.size,true)); overlay._gui_input(_motion(finish*overlay.size,true)); overlay._gui_input(_mouse_button(finish*overlay.size,false))

func _mouse_button(position:Vector2,pressed:bool)->InputEventMouseButton:
	var event:=InputEventMouseButton.new(); event.position=position; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; return event

func _motion(position:Vector2,left_pressed:bool)->InputEventMouseMotion:
	var event:=InputEventMouseMotion.new(); event.position=position; event.button_mask=MOUSE_BUTTON_MASK_LEFT if left_pressed else 0; return event

func _key(code:Key)->InputEventKey:
	var event:=InputEventKey.new(); event.keycode=code; event.pressed=true; return event

func _find_option_with_metadata(node:Node,value:String)->OptionButton:
	if node is OptionButton and node.is_visible_in_tree():
		for index in node.item_count: if str(node.get_item_metadata(index))==value: return node
	for child in node.get_children(): var found:=_find_option_with_metadata(child,value); if found!=null: return found
	return null

func _find_label(node:Node,text:String)->Label:
	if node is Label and node.is_visible_in_tree() and str(node.text).contains(text): return node
	for child in node.get_children(): var found:=_find_label(child,text); if found!=null: return found
	return null
