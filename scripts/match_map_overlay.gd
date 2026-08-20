class_name MatchMapOverlay
extends Control

signal player_selected(index: int)
signal world_player_selected(team_index: int, member_index: int)
signal zoom_requested(local_position: Vector2, step: float)
signal pan_requested(relative: Vector2)
signal editor_item_moved(kind: String, index: int, normalized_position: Vector2)
signal editor_item_selected(kind: String, index: int)
signal editor_brush_completed(kind: String, normalized_path: Array, brush_width: float)
signal editor_rect_completed(normalized_rect: Rect2)

var state: Dictionary = {}
var map_data: Dictionary = {}
var _dragging := false
var editor_enabled := false
var design_layers_visible := false
var editor_selection := {"kind":"","index":-1}
var _editor_drag_kind := ""
var _editor_drag_index := -1
var editor_tool := "select"
var editor_brush_width := 0.04
var _brush_path: Array = []
var _rect_start := Vector2.ZERO
var _rect_current := Vector2.ZERO

func enable_editor(value:bool=true)->void:
	editor_enabled=value; design_layers_visible=value or design_layers_visible; queue_redraw()

func set_design_layers_visible(value:bool=true)->void:
	design_layers_visible=value; queue_redraw()

func set_editor_tool(tool: String, brush_width: float) -> void:
	editor_tool=tool; editor_brush_width=clampf(brush_width,0.008,0.18); _brush_path.clear(); queue_redraw()

func set_state(value: Dictionary) -> void:
	state = value
	queue_redraw()

func set_map(value: Dictionary) -> void:
	map_data = value
	queue_redraw()

func _p(normalized: Variant) -> Vector2:
	return Vector2(float(normalized[0]) * size.x, float(normalized[1]) * size.y)

func _draw() -> void:
	if map_data.is_empty(): return
	var font:=ThemeDB.fallback_font; var design_data:Dictionary=map_data if design_layers_visible or editor_enabled else {}
	for stroke in design_data.get("terrain_strokes", []):
		var path := PackedVector2Array(); for point in stroke.get("path",[]): path.append(_p(point))
		var terrain := str(stroke.get("terrain","forest")); var color := Color(0.12,0.55,0.92,0.52) if terrain=="water" else Color(0.08,0.42,0.18,0.42)
		if path.size()>=2: draw_polyline(path,color,float(stroke.get("width",0.05))*minf(size.x,size.y),true)
	for road in design_data.get("roads", []):
		var path := PackedVector2Array()
		for point in road.get("path", []): path.append(_p(point))
		var road_class := str(road.get("road_class", "secondary"))
		var width := float(road.get("width",0.0))*minf(size.x,size.y) if float(road.get("width",0.0))>0.0 else 5.0 if road_class == "highway" else 3.0 if road_class == "secondary" else 1.5
		var color := Color(0.92,0.85,0.62,0.72) if road_class == "highway" else Color(0.78,0.82,0.84,0.62) if road_class == "secondary" else Color(0.63,0.48,0.28,0.58)
		if path.size() >= 2: draw_polyline(path,color,width,true)
	for building_index in design_data.get("buildings", []).size():
		var building: Dictionary=design_data.buildings[building_index]; var rect_data:Array=building.get("rect",[])
		if rect_data.size()!=4 or not bool(building.get("enabled",true)): continue
		var rect:=Rect2(float(rect_data[0])*size.x,float(rect_data[1])*size.y,float(rect_data[2])*size.x,float(rect_data[3])*size.y)
		var selected:bool=editor_enabled and str(editor_selection.kind)=="building" and int(editor_selection.index)==building_index
		draw_rect(rect,Color(0.08,0.12,0.15,0.7),true); draw_rect(rect,Color("2ee6b1") if selected else Color(0.95,0.95,0.88,0.82),false,3.0 if selected else 1.4)
		if editor_enabled: draw_string(font,rect.position+Vector2(4,12),str(building.get("name","House")),HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-8,9,Color.WHITE)
	for region_index in design_data.get("regions", []).size():
		var region:Dictionary=design_data.regions[region_index]
		var center := _p(region.position)
		var radius := float(region.get("radius", 0.06)) * minf(size.x, size.y)
		var loot := float(region.get("loot_multiplier", 1.0))
		draw_circle(center, radius, Color(1.0, 0.72, 0.08, 0.08 + loot * 0.05))
		draw_arc(center, radius, 0.0, TAU, 48, Color("2ee6b1") if editor_enabled and editor_selection.kind=="region" and int(editor_selection.index)==region_index else Color(1.0, 0.78, 0.16, 0.62),3.0 if editor_enabled and editor_selection.kind=="region" and int(editor_selection.index)==region_index else 1.5)
		if editor_enabled: draw_circle(center,6.0,Color("2ee6b1")); draw_string(font,center+Vector2(9,-7),str(region.get("name","Region")),HORIZONTAL_ALIGNMENT_LEFT,140,11,Color.WHITE)
	for compound_index in design_data.get("compounds", []).size():
		var compound: Dictionary = design_data.compounds[compound_index]
		var center := _p(compound.position); var radius := float(compound.get("radius",0.04))*minf(size.x,size.y)
		var selected: bool = editor_enabled and str(editor_selection.kind)=="compound" and int(editor_selection.index)==compound_index
		draw_rect(Rect2(center-Vector2(radius*0.72,radius*0.55),Vector2(radius*1.44,radius*1.1)),Color(0.95,0.66,0.14,0.12),true)
		draw_rect(Rect2(center-Vector2(radius*0.72,radius*0.55),Vector2(radius*1.44,radius*1.1)),Color("2ee6b1") if selected else Color(0.96,0.72,0.24,0.72),false,2.5 if selected else 1.2)
		if editor_enabled: draw_string(font,center+Vector2(7,-5),str(compound.get("name","Compound")),HORIZONTAL_ALIGNMENT_LEFT,125,9,Color(1,0.86,0.55,0.95))
	for point_index in design_data.get("points", []).size():
		var point:Dictionary=design_data.points[point_index]
		if bool(point.get("enabled", true)):
			var pos := _p(point.position)
			var selected:bool=editor_enabled and str(editor_selection.kind)=="point" and int(editor_selection.index)==point_index
			draw_rect(Rect2(pos - Vector2(6 if selected else 4, 6 if selected else 4), Vector2(12 if selected else 8,12 if selected else 8)),Color("2ee6b1") if selected else Color("ffd34e"),true)
			if editor_enabled: draw_string(font,pos+Vector2(8,12),str(point.get("name","Node")),HORIZONTAL_ALIGNMENT_LEFT,120,10,Color("ffd34e"))
	for node in design_data.get("transport_nodes", []):
		var pos := _p(node.position)
		draw_circle(pos,5.5,Color(0.18,0.78,1.0,0.86)); draw_circle(pos,2.0,Color(0.02,0.08,0.12,1.0))
		if editor_enabled: draw_string(font,pos+Vector2(8,-7),str(node.get("name","Vehicle")),HORIZONTAL_ALIGNMENT_LEFT,120,9,Color(0.4,0.85,1.0,0.95))
	if editor_enabled and _brush_path.size()>=2:
		var preview:=PackedVector2Array(); for point in _brush_path: preview.append(_p(point))
		var preview_color:=Color(0.12,0.65,1.0,0.72) if editor_tool=="river" else Color(0.15,0.62,0.24,0.65) if editor_tool=="forest" else Color(1.0,0.72,0.22,0.8)
		draw_polyline(preview,preview_color,editor_brush_width*minf(size.x,size.y),true)
	if editor_enabled and editor_tool=="building" and _rect_start!=_rect_current:
		var preview_rect:=Rect2(_p([minf(_rect_start.x,_rect_current.x),minf(_rect_start.y,_rect_current.y)]),Vector2(absf(_rect_current.x-_rect_start.x)*size.x,absf(_rect_current.y-_rect_start.y)*size.y))
		draw_rect(preview_rect,Color(0.1,0.9,0.7,0.22),true); draw_rect(preview_rect,Color("2ee6b1"),false,2.0)
	if state.is_empty(): return
	var flight: Array = state.get("flight_path", [])
	if flight.size() == 2 and float(state.get("plane_progress",0.0))<1.0:
		var a := _p(flight[0]); var b := _p(flight[1])
		draw_dashed_line(a, b, Color(1, 1, 1, 0.9), 3.0, 12.0)
		var plane := a.lerp(b, float(state.get("plane_progress", 0.0)))
		draw_colored_polygon(PackedVector2Array([plane + Vector2(15, 0), plane + Vector2(-9, -8), plane + Vector2(-5, 0), plane + Vector2(-9, 8)]), Color("f4f7f5"))
	var zone_center := _p(state.get("zone_center", [0.5, 0.5]))
	var next_center := _p(state.get("target_zone_center", [0.5, 0.5]))
	var short_side := minf(size.x, size.y)
	if int(state.get("zone_number", 0)) > 0:
		draw_arc(zone_center, float(state.get("blue_radius", 1.0)) * short_side, 0, TAU, 96, Color(0.28, 0.55, 1.0, 0.95), 3.0)
		if float(state.get("target_zone_radius", 0.0)) > 0.0:
			draw_arc(next_center, float(state.target_zone_radius) * short_side, 0, TAU, 96, Color(1, 1, 1, 0.95), 2.5)
	for trail in state.get("bullet_trails", []):
		var trail_color:=Color(0.72,0.78,0.82,clampf(float(trail.ttl),0.18,1.0)) if str(trail.get("outcome","HIT"))=="MISS" else Color(1.0,0.82,0.28,clampf(float(trail.ttl),0.18,1.0)); draw_line(_p(trail.from),_p(trail.to),trail_color,1.4 if str(trail.get("outcome","HIT"))=="MISS" else 2.2)
	for effect in state.get("effects", []):
		var color := Color(0.78,0.82,0.84,0.34) if effect.type=="smoke" else Color(1.0,0.55,0.10,0.45) if effect.type=="frag" else Color(1.0,0.18,0.08,0.48) if effect.type in ["molotov","red_shell"] else Color(0.9,0.92,1.0,0.36); var radius := float(effect.radius)*minf(size.x,size.y); draw_circle(_p(effect.position),radius,color); draw_arc(_p(effect.position),radius,0,TAU,32,Color(color,0.9),2.0)
	for team_index in state.get("team_positions", []).size():
		var team: Dictionary = state.team_positions[team_index]
		if str(team.tag)=="MR": continue
		if not bool(state.get("visible_team_tags",{}).get(str(team.tag),true)): continue
		var color := Color.from_hsv(float(team.color) / 16.0, 0.72, 0.95)
		for member_index in team.members.size():
			var member:Dictionary=team.members[member_index]
			if str(member.state)=="DEAD" and not bool(state.get("show_dead",false)): continue
			var pos := _p(member.position); var member_color := Color("ff647c") if member.state=="DEAD" else Color("ffc857") if member.state=="AIRBORNE" else Color("52c7ff") if member.state=="DRIVING" else color
			if team_index==int(state.get("selected_team",-1)) and member_index==int(state.get("selected_player",-1)):
				_draw_selection(pos,member)
			draw_circle(pos,7.0,Color(0.01,0.02,0.04,0.86)); draw_circle(pos,5.0,member_color)
			if size.x>=700 and (team_index==int(state.get("selected_team",-1)) or member_index==0): draw_string(font,pos+Vector2(8,4),"%s  %s" % [team.tag,member.name] if team_index==int(state.get("selected_team",-1)) else str(team.tag),HORIZONTAL_ALIGNMENT_LEFT,110,10,Color(1,1,1,0.9))
			_draw_status_icon(pos,str(member.state),color)
	for index in state.get("roster", []).size():
		var player: Dictionary = state.roster[index]
		if not bool(state.get("visible_team_tags",{}).get("MR",true)): continue
		if str(player.state)=="DEAD" and not bool(state.get("show_dead",false)): continue
		var pos := _p(player.position)
		var color := Color("ff647c") if player.state == "DEAD" else Color("ffc857") if player.state == "AIRBORNE" else Color("52c7ff") if player.state=="DRIVING" else Color("2ee6b1")
		if int(state.get("selected_team",-1))==0 and index==int(state.get("selected_player",-1)):
			_draw_selection(pos,player)
		draw_circle(pos, 7.5, Color(0, 0, 0, 0.8))
		draw_circle(pos, 5.0, color)
		if size.x>=700 and (int(state.get("selected_team",-1))==0 or index==0): draw_string(font,pos+Vector2(8,4),"MR  %s" % player.name if int(state.get("selected_team",-1))==0 else "MR",HORIZONTAL_ALIGNMENT_LEFT,120,11,Color.WHITE)
		_draw_status_icon(pos,str(player.state),Color("2ee6b1"))

func _draw_selection(pos:Vector2,player:Dictionary)->void:
	var pulse:=0.55+sin(float(Time.get_ticks_msec())*0.008)*0.22
	draw_circle(pos,13.0,Color(0.18,0.9,0.72,pulse),false,2.0)
	if player.has("move_target"):
		draw_dashed_line(pos,_p(player.move_target),Color(0.18,0.9,0.72,0.58),1.5,7.0)
	if str(player.get("state","")) in ["REVIVING","HEALING","BOOSTING"]:
		var remaining:=maxf(0.0,float(player.get("action_end",0.0))-float(state.get("elapsed",0.0)))
		var duration:=10.0 if str(player.state)=="REVIVING" else 8.0
		draw_arc(pos,17.0,-PI/2.0,-PI/2.0+TAU*(1.0-clampf(remaining/duration,0.0,1.0)),28,Color("57df8a"),3.0)

func _draw_status_icon(pos:Vector2,status:String,team_color:Color)->void:
	var white:=Color(1,1,1,0.96); var dark:=Color(0.01,0.02,0.04,0.9); var icon_pos:=pos-Vector2(0,10)
	draw_circle(icon_pos,6.5,dark)
	match status:
		"AIRBORNE":
			draw_arc(icon_pos-Vector2(0,1),6,PI,TAU,16,white,1.8); draw_line(icon_pos+Vector2(-5,-1),icon_pos+Vector2(0,5),white,1.2); draw_line(icon_pos+Vector2(5,-1),icon_pos+Vector2(0,5),white,1.2)
		"DRIVING":
			draw_arc(icon_pos,5,0,TAU,16,white,1.8); draw_circle(icon_pos,1.7,team_color); draw_line(icon_pos+Vector2(-4,0),icon_pos+Vector2(4,0),white,1.2)
		"HEALING":
			draw_rect(Rect2(icon_pos-Vector2(1.3,4.5),Vector2(2.6,9)),Color("57df8a"),true); draw_rect(Rect2(icon_pos-Vector2(4.5,1.3),Vector2(9,2.6)),Color("57df8a"),true)
		"BOOSTING":
			var bolt:=PackedVector2Array([icon_pos+Vector2(1,-5),icon_pos+Vector2(-3,1),icon_pos+Vector2(0,1),icon_pos+Vector2(-1,5),icon_pos+Vector2(4,-1),icon_pos+Vector2(1,-1)]); draw_colored_polygon(bolt,Color("ffc857"))
		"KNOCKED":
			draw_line(icon_pos+Vector2(-4,-4),icon_pos+Vector2(4,4),Color("ff647c"),2.0); draw_line(icon_pos+Vector2(4,-4),icon_pos+Vector2(-4,4),Color("ff647c"),2.0)
		"REVIVING":
			draw_circle(icon_pos+Vector2(-2,-1),2.2,team_color); draw_circle(icon_pos+Vector2(3,2),2.2,white); draw_line(icon_pos+Vector2(-1,0),icon_pos+Vector2(2,1),Color("57df8a"),2.0)
		"DEAD":
			draw_line(icon_pos+Vector2(-4,-4),icon_pos+Vector2(4,4),Color("ff647c"),1.6); draw_line(icon_pos+Vector2(4,-4),icon_pos+Vector2(-4,4),Color("ff647c"),1.6)
		_:
			draw_circle(icon_pos,3.0,team_color)

func _gui_input(event: InputEvent) -> void:
	if editor_enabled:
		if editor_tool!="select":
			if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
				var normalized:=Vector2(clampf(event.position.x/maxf(size.x,1.0),0.0,1.0),clampf(event.position.y/maxf(size.y,1.0),0.0,1.0))
				if event.pressed:
					if editor_tool=="building": _rect_start=normalized; _rect_current=normalized
					else: _brush_path=[[normalized.x,normalized.y]]
				else:
					if editor_tool=="building":
						var rect:=Rect2(minf(_rect_start.x,_rect_current.x),minf(_rect_start.y,_rect_current.y),absf(_rect_current.x-_rect_start.x),absf(_rect_current.y-_rect_start.y)); if rect.size.x>=0.012 and rect.size.y>=0.012: editor_rect_completed.emit(rect)
						_rect_start=Vector2.ZERO; _rect_current=Vector2.ZERO
					elif _brush_path.size()>=2: editor_brush_completed.emit(editor_tool,_brush_path.duplicate(true),editor_brush_width); _brush_path.clear()
					queue_redraw()
				accept_event(); return
			if event is InputEventMouseMotion:
				var normalized:=Vector2(clampf(event.position.x/maxf(size.x,1.0),0.0,1.0),clampf(event.position.y/maxf(size.y,1.0),0.0,1.0))
				if editor_tool=="building" and _rect_start!=Vector2.ZERO: _rect_current=normalized; queue_redraw(); accept_event(); return
				if not _brush_path.is_empty():
					var previous:=Vector2(float(_brush_path[-1][0]),float(_brush_path[-1][1])); if previous.distance_to(normalized)>=0.008: _brush_path.append([normalized.x,normalized.y]); queue_redraw()
					accept_event(); return
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				var hit:=_editor_hit_test(event.position); _editor_drag_kind=str(hit.kind); _editor_drag_index=int(hit.index)
				if _editor_drag_index>=0: editor_selection=hit; editor_item_selected.emit(_editor_drag_kind,_editor_drag_index); accept_event()
			else: _editor_drag_kind=""; _editor_drag_index=-1; accept_event()
			return
		if event is InputEventMouseMotion and _editor_drag_index>=0:
			var normalized:=Vector2(clampf(event.position.x/maxf(size.x,1.0),0.0,1.0),clampf(event.position.y/maxf(size.y,1.0),0.0,1.0)); editor_item_moved.emit(_editor_drag_kind,_editor_drag_index,normalized); accept_event(); return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_WHEEL_UP and event.pressed:
		zoom_requested.emit(event.position,0.25); accept_event(); return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		zoom_requested.emit(event.position,-0.25); accept_event(); return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_MIDDLE:
		_dragging=event.pressed; accept_event(); return
	if event is InputEventMouseMotion and _dragging:
		pan_requested.emit(event.relative); accept_event(); return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		for i in state.get("roster", []).size():
			if _p(state.roster[i].position).distance_to(event.position)<=18.0: player_selected.emit(i); accept_event(); return
		for team_index in state.get("team_positions", []).size():
			if team_index == 0: continue
			if not bool(state.get("visible_team_tags",{}).get(str(state.team_positions[team_index].tag),true)): continue
			for member_index in state.team_positions[team_index].members.size():
				if str(state.team_positions[team_index].members[member_index].state)=="DEAD" and not bool(state.get("show_dead",false)): continue
				if _p(state.team_positions[team_index].members[member_index].position).distance_to(event.position)<=18.0: world_player_selected.emit(team_index,member_index); accept_event(); return

func _editor_hit_test(position:Vector2)->Dictionary:
	var best:={"kind":"","index":-1}; var best_distance:=24.0
	for building_index in map_data.get("buildings",[]).size():
		var rect:Array=map_data.buildings[building_index].get("rect",[])
		if rect.size()==4 and Rect2(float(rect[0])*size.x,float(rect[1])*size.y,float(rect[2])*size.x,float(rect[3])*size.y).has_point(position): return {"kind":"building","index":building_index}
	for compound_index in map_data.get("compounds",[]).size():
		var distance:=_p(map_data.compounds[compound_index].position).distance_to(position)
		if distance<best_distance: best={"kind":"compound","index":compound_index}; best_distance=distance
	for point_index in map_data.get("points",[]).size():
		var distance:=_p(map_data.points[point_index].position).distance_to(position)
		if distance<best_distance: best={"kind":"point","index":point_index}; best_distance=distance
	for region_index in map_data.get("regions",[]).size():
		var center:=_p(map_data.regions[region_index].position); var radius:=float(map_data.regions[region_index].get("radius",0.06))*minf(size.x,size.y); var distance:=center.distance_to(position)
		if distance<best_distance or absf(distance-radius)<10.0: best={"kind":"region","index":region_index}; best_distance=distance
	return best
