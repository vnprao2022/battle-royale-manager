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
		var initial_roads:int=scene.map_editor_data.roads.size(); scene._on_map_editor_brush_completed("road_highway",[[0.1,0.1],[0.7,0.7]],0.05); scene._on_map_editor_brush_completed("river",[[0.1,0.4],[0.8,0.4]],0.06); scene._on_map_editor_brush_completed("forest",[[0.2,0.2],[0.5,0.25]],0.1); scene._on_map_editor_rect_completed(Rect2(0.4,0.4,0.08,0.05)); await _settle()
		assert(scene.map_editor_data.roads.size()==initial_roads+1 and scene.map_editor_data.terrain_strokes.size()==2 and scene.map_editor_data.buildings.size()==1,"Brush callbacks did not create editable layers")
		assert(scene.map_catalog.validate(scene.map_editor_data),"Brush-created map is invalid")
		await _capture("%dx%d_map_manager"%[viewport_size.x,viewport_size.y])
		scene._show_page("analytics"); await _settle(); assert(_find_label(scene,"ANALYST MAP • READ ONLY")!=null,"Team Analysis has no read-only analyst map"); await _capture("%dx%d_analyst_map"%[viewport_size.x,viewport_size.y])
		scene.queue_free(); for frame in 3: await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://codex_map_lab_ui.json")); print("MAP_LAB_UI_TEST_OK captures=%d"%captures); quit(0)

func _settle()->void:
	for frame in 7: await process_frame

func _capture(name:String)->void:
	var image:=root.get_viewport().get_texture().get_image(); assert(not image.is_empty(),"Renderer returned an empty image"); assert(image.save_png("%s/%s.png"%[OUTPUT_DIR,name])==OK); captures+=1

func _find_option_with_metadata(node:Node,value:String)->OptionButton:
	if node is OptionButton and node.is_visible_in_tree():
		for index in node.item_count: if str(node.get_item_metadata(index))==value: return node
	for child in node.get_children(): var found:=_find_option_with_metadata(child,value); if found!=null: return found
	return null

func _find_label(node:Node,text:String)->Label:
	if node is Label and node.is_visible_in_tree() and str(node.text).contains(text): return node
	for child in node.get_children(): var found:=_find_label(child,text); if found!=null: return found
	return null
