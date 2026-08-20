extends SceneTree

const ROOT := "res://assets"
const C_CLEAR := Color(0, 0, 0, 0)
const C_BG := Color("0b1117")
const C_PANEL := Color("121b24")
const C_PANEL_2 := Color("192631")
const C_LINE := Color("2b3c49")
const C_TEXT := Color("e8f0ef")
const C_MUTED := Color("8da0a8")
const C_TEAL := Color("20d6aa")
const C_AMBER := Color("f5b82e")
const C_RED := Color("f05252")
const C_BLUE := Color("3188ff")
const C_GREEN := Color("45c46a")

var entries: Dictionary = {}

func _init() -> void:
	_make_ui_surfaces()
	_make_icons()
	_make_match_visuals()
	_make_match_hud_library()
	_make_inventory()
	_make_weapon_surfaces()
	_write_manifest()
	print("PNG_BUILD_OK generated=%d" % entries.size())
	quit(0)

func _make_ui_surfaces() -> void:
	_surface("ui/panels/panel.png", Vector2i(480, 280), C_PANEL, C_LINE, "nine_patch", 16)
	_surface("ui/panels/panel_elevated.png", Vector2i(480, 280), C_PANEL_2, C_TEAL.darkened(0.55), "nine_patch", 16)
	_surface("ui/panels/modal.png", Vector2i(640, 400), C_BG.lightened(0.03), C_TEAL.darkened(0.25), "nine_patch", 20)
	_surface("ui/panels/tooltip.png", Vector2i(320, 96), Color("101820"), C_LINE, "nine_patch", 12)
	_surface("ui/panels/toast.png", Vector2i(400, 56), Color("27394b"), C_TEAL.darkened(0.45), "nine_patch", 12)
	_surface("ui/panels/table_row.png", Vector2i(960, 44), C_PANEL, C_LINE.darkened(0.35), "stretch", 4)
	_surface("ui/panels/table_row_selected.png", Vector2i(960, 44), C_TEAL.darkened(0.78), C_TEAL, "stretch", 4)
	_surface("ui/panels/stat_card.png", Vector2i(280, 132), C_PANEL_2, C_LINE, "nine_patch", 14)
	_surface("ui/panels/match_hud.png", Vector2i(480, 320), Color("0d1419"), C_LINE, "nine_patch", 10)
	_button("primary", C_TEAL, Color("071511"))
	_button("secondary", C_PANEL_2, C_TEXT)
	_button("danger", C_RED, C_TEXT)
	_button("success", C_GREEN, C_BG)
	_button("disabled", C_LINE.darkened(0.35), C_MUTED.darkened(0.25))
	_surface("ui/controls/input.png", Vector2i(360, 48), C_BG.lightened(0.025), C_LINE, "nine_patch", 8)
	_surface("ui/controls/input_focus.png", Vector2i(360, 48), C_BG.lightened(0.04), C_TEAL, "nine_patch", 8)
	_surface("ui/controls/progress_track.png", Vector2i(320, 16), C_BG, C_LINE, "stretch", 6)
	_surface("ui/controls/progress_fill.png", Vector2i(320, 16), C_TEAL.darkened(0.15), C_TEAL, "stretch", 6)

func _button(name: String, fill: Color, ink: Color) -> void:
	var path := "ui/buttons/%s.png" % name
	var image := Image.create(240, 48, false, Image.FORMAT_RGBA8)
	image.fill(C_CLEAR)
	_rect(image, Rect2i(1, 1, 238, 46), fill)
	_outline(image, Rect2i(1, 1, 238, 46), fill.lightened(0.2), 2)
	_line(image, Vector2i(10, 5), Vector2i(52, 5), ink, 2)
	_line(image, Vector2i(188, 42), Vector2i(230, 42), ink, 2)
	_save(path, image, {"kind":"nine_patch", "margins":[10,10,10,10], "state":name})

func _surface(path: String, size: Vector2i, fill: Color, stroke: Color, kind: String, margin: int) -> void:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(C_CLEAR)
	_rect(image, Rect2i(1, 1, size.x - 2, size.y - 2), fill)
	_outline(image, Rect2i(1, 1, size.x - 2, size.y - 2), stroke, 2)
	_line(image, Vector2i(14, 8), Vector2i(mini(size.x - 14, 120), 8), C_TEAL, 2)
	_save(path, image, {"kind":kind, "margins":[margin,margin,margin,margin]})

func _make_icons() -> void:
	_app_icon()
	var defs := {
		"navigation/home":"home", "navigation/roster":"people", "navigation/scout":"search",
		"navigation/tactics":"route", "navigation/match":"crosshair", "navigation/facilities":"building",
		"navigation/inbox":"mail", "navigation/settings":"gear", "navigation/save":"save",
		"navigation/next":"arrow", "navigation/back":"back", "navigation/close":"close",
		"status/morale":"heart", "status/chemistry":"link", "status/reputation":"crown",
		"status/fans":"people", "status/budget":"coin", "status/energy":"bolt",
		"combat/kill":"skull", "combat/knock":"down", "combat/damage":"burst",
		"combat/heal":"plus", "combat/revive":"revive", "combat/assist":"link",
		"replay/play":"play", "replay/pause":"pause", "replay/stop":"stop",
		"replay/previous":"back", "replay/next":"arrow", "replay/rotation":"route",
		"replay/loot":"crate", "replay/utility":"grenade", "replay/zone":"zone",
		"equipment/helmet":"helmet", "equipment/vest":"vest", "equipment/backpack":"bag",
		"equipment/scope":"scope", "equipment/ammo":"ammo", "equipment/vehicle":"vehicle",
		"utility/smoke":"smoke", "utility/frag":"grenade", "utility/molotov":"fire", "utility/flash":"flash"
	}
	for id in defs:
		var color := C_RED if id.begins_with("combat/") else (C_AMBER if id.begins_with("equipment/") else C_TEAL)
		_icon("icons/%s.png" % id, defs[id], color)

func _app_icon() -> void:
	var im := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	im.fill(C_BG)
	_circle_outline(im, Vector2i(128, 128), 92, C_TEAL, 12)
	_circle_outline(im, Vector2i(128, 128), 55, C_AMBER, 7)
	_line(im, Vector2i(128, 16), Vector2i(128, 76), C_TEXT, 8)
	_line(im, Vector2i(128, 180), Vector2i(128, 240), C_TEXT, 8)
	_line(im, Vector2i(16, 128), Vector2i(76, 128), C_TEXT, 8)
	_line(im, Vector2i(180, 128), Vector2i(240, 128), C_TEXT, 8)
	_circle(im, Vector2i(128, 128), 18, C_RED)
	_save("branding/app_icon.png", im, {"kind":"branding", "size":[256,256]})

func _icon(path: String, glyph: String, color: Color) -> void:
	var im := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	im.fill(C_CLEAR)
	match glyph:
		"home": _poly(im,[Vector2i(12,31),Vector2i(32,13),Vector2i(52,31),Vector2i(47,31),Vector2i(47,52),Vector2i(37,52),Vector2i(37,39),Vector2i(27,39),Vector2i(27,52),Vector2i(17,52),Vector2i(17,31)],color)
		"people": _circle(im,Vector2i(24,24),8,color); _circle(im,Vector2i(43,27),6,color); _rect(im,Rect2i(12,36,25,15),color); _rect(im,Rect2i(38,38,14,13),color)
		"search": _circle_outline(im,Vector2i(28,27),14,color,4); _line(im,Vector2i(39,38),Vector2i(53,52),color,5)
		"route": _circle(im,Vector2i(15,47),5,color); _circle(im,Vector2i(49,16),5,color); _line(im,Vector2i(18,44),Vector2i(29,32),color,4); _line(im,Vector2i(29,32),Vector2i(40,38),color,4); _line(im,Vector2i(40,38),Vector2i(47,21),color,4)
		"crosshair": _circle_outline(im,Vector2i(32,32),17,color,3); _circle(im,Vector2i(32,32),4,color); _line(im,Vector2i(32,8),Vector2i(32,19),color,3); _line(im,Vector2i(32,45),Vector2i(32,56),color,3); _line(im,Vector2i(8,32),Vector2i(19,32),color,3); _line(im,Vector2i(45,32),Vector2i(56,32),color,3)
		"building": _rect(im,Rect2i(14,18,36,35),color); _rect(im,Rect2i(20,25,7,7),C_BG); _rect(im,Rect2i(37,25,7,7),C_BG); _rect(im,Rect2i(28,39,9,14),C_BG)
		"mail": _outline(im,Rect2i(10,17,44,32),color,4); _line(im,Vector2i(12,20),Vector2i(32,36),color,3); _line(im,Vector2i(52,20),Vector2i(32,36),color,3)
		"save": _rect(im,Rect2i(13,11,38,42),color); _rect(im,Rect2i(20,14,23,13),C_BG); _rect(im,Rect2i(21,36,22,17),C_BG)
		"arrow": _line(im,Vector2i(14,32),Vector2i(48,32),color,5); _line(im,Vector2i(36,20),Vector2i(49,32),color,5); _line(im,Vector2i(49,32),Vector2i(36,44),color,5)
		"back": _line(im,Vector2i(50,32),Vector2i(16,32),color,5); _line(im,Vector2i(28,20),Vector2i(15,32),color,5); _line(im,Vector2i(15,32),Vector2i(28,44),color,5)
		"close": _line(im,Vector2i(16,16),Vector2i(48,48),color,5); _line(im,Vector2i(48,16),Vector2i(16,48),color,5)
		"heart": _poly(im,[Vector2i(32,52),Vector2i(12,32),Vector2i(12,20),Vector2i(20,13),Vector2i(29,16),Vector2i(32,21),Vector2i(35,16),Vector2i(44,13),Vector2i(52,20),Vector2i(52,32)],color)
		"link": _circle_outline(im,Vector2i(23,32),12,color,4); _circle_outline(im,Vector2i(41,32),12,color,4); _rect(im,Rect2i(23,29,18,6),color)
		"crown": _poly(im,[Vector2i(11,20),Vector2i(22,31),Vector2i(32,16),Vector2i(42,31),Vector2i(53,20),Vector2i(48,49),Vector2i(16,49)],color)
		"coin": _circle(im,Vector2i(32,32),21,color); _circle_outline(im,Vector2i(32,32),14,C_BG,3)
		"bolt": _poly(im,[Vector2i(35,8),Vector2i(17,35),Vector2i(30,35),Vector2i(27,56),Vector2i(48,27),Vector2i(35,27)],color)
		"play": _poly(im,[Vector2i(20,13),Vector2i(52,32),Vector2i(20,51)],color)
		"pause": _rect(im,Rect2i(17,13,10,38),color); _rect(im,Rect2i(37,13,10,38),color)
		"stop": _rect(im,Rect2i(16,16,32,32),color)
		"plus": _rect(im,Rect2i(26,11,12,42),color); _rect(im,Rect2i(11,26,42,12),color)
		"zone": _circle_outline(im,Vector2i(32,32),22,color,5); _circle_outline(im,Vector2i(32,32),12,color.lightened(.2),2)
		"scope": _circle_outline(im,Vector2i(32,32),20,color,4); _line(im,Vector2i(32,9),Vector2i(32,55),color,2); _line(im,Vector2i(9,32),Vector2i(55,32),color,2)
		"helmet": _circle(im,Vector2i(32,32),21,color); _rect(im,Rect2i(11,32,42,20),C_CLEAR); _rect(im,Rect2i(32,32,22,7),color)
		"vest": _poly(im,[Vector2i(18,13),Vector2i(28,18),Vector2i(36,18),Vector2i(46,13),Vector2i(53,51),Vector2i(11,51)],color); _rect(im,Rect2i(27,18,10,14),C_BG)
		"bag": _rect(im,Rect2i(15,21,34,34),color); _circle_outline(im,Vector2i(32,22),13,color,5)
		"ammo": _rect(im,Rect2i(16,13,8,39),color); _rect(im,Rect2i(29,8,8,44),color); _rect(im,Rect2i(42,18,8,34),color)
		"vehicle": _rect(im,Rect2i(12,27,40,18),color); _poly(im,[Vector2i(20,27),Vector2i(27,18),Vector2i(43,18),Vector2i(49,27)],color); _circle(im,Vector2i(21,48),7,C_BG); _circle(im,Vector2i(45,48),7,C_BG)
		"crate": _rect(im,Rect2i(12,16,40,37),color); _line(im,Vector2i(14,18),Vector2i(50,51),C_BG,4); _line(im,Vector2i(50,18),Vector2i(14,51),C_BG,4)
		"grenade": _circle(im,Vector2i(31,37),17,color); _rect(im,Rect2i(27,12,10,12),color); _line(im,Vector2i(36,15),Vector2i(48,22),color,4)
		"fire": _poly(im,[Vector2i(32,8),Vector2i(43,25),Vector2i(40,35),Vector2i(51,28),Vector2i(49,45),Vector2i(39,55),Vector2i(22,53),Vector2i(14,42),Vector2i(20,25),Vector2i(26,34)],color)
		"flash": _poly(im,[Vector2i(32,7),Vector2i(38,23),Vector2i(55,18),Vector2i(44,32),Vector2i(57,43),Vector2i(39,40),Vector2i(32,57),Vector2i(25,40),Vector2i(7,43),Vector2i(20,32),Vector2i(9,18),Vector2i(26,23)],color)
		"skull": _circle(im,Vector2i(32,27),18,color); _rect(im,Rect2i(22,40,20,13),color); _circle(im,Vector2i(25,26),4,C_BG); _circle(im,Vector2i(39,26),4,C_BG)
		"down": _line(im,Vector2i(12,16),Vector2i(48,49),color,6); _line(im,Vector2i(48,49),Vector2i(48,34),color,5); _line(im,Vector2i(48,49),Vector2i(33,49),color,5)
		"burst": _poly(im,[Vector2i(32,7),Vector2i(38,24),Vector2i(54,16),Vector2i(45,32),Vector2i(57,38),Vector2i(40,40),Vector2i(36,57),Vector2i(28,42),Vector2i(12,51),Vector2i(20,34),Vector2i(7,25),Vector2i(25,24)],color)
		"revive": _circle_outline(im,Vector2i(32,32),21,color,5); _line(im,Vector2i(32,18),Vector2i(32,46),color,5); _line(im,Vector2i(18,32),Vector2i(46,32),color,5)
		"smoke": for y in range(16,53,10): _circle(im,Vector2i(20+(y%20),y),9,color.lightened(float(y)/180.0))
		_: _circle_outline(im,Vector2i(32,32),20,color,4); _circle(im,Vector2i(32,32),6,color)
	_save(path, im, {"kind":"icon", "size":[64,64]})

func _make_match_visuals() -> void:
	_ring("match/overlays/safe_zone_ring.png", C_TEXT, 4)
	_ring("match/overlays/blue_zone_ring.png", C_BLUE, 9)
	_ring("match/overlays/red_zone_ring.png", C_RED, 7)
	_marker("match/markers/player.png", C_TEAL, false)
	_marker("match/markers/team.png", C_AMBER, true)
	_marker("match/markers/knocked.png", C_RED, false)
	_marker("match/markers/death.png", C_MUTED, true)
	_icon("match/events/ping.png", "crosshair", C_AMBER)
	_icon("match/events/vehicle.png", "vehicle", C_TEAL)
	_icon("match/events/airdrop.png", "crate", C_BLUE)
	_effect("match/effects/smoke.png", C_MUTED)
	_effect("match/effects/explosion.png", C_AMBER)
	_effect("match/effects/molotov.png", C_RED)

func _make_match_hud_library() -> void:
	var top := {"current_phase":Vector2i(180,64), "alive":Vector2i(120,64), "teams_alive":Vector2i(140,64), "current_time":Vector2i(140,64), "replay_speed":Vector2i(96,64), "zone_timer":Vector2i(140,64), "match_number":Vector2i(150,64), "map_name":Vector2i(180,64), "day_week":Vector2i(150,64)}
	for name in top:
		_hud_surface("match.hud.top.%s.default" % name, "match/hud/top/%s_default.png" % name, top[name], "metric", C_TEAL)
	var feeds := {"kill_feed":C_RED, "damage_feed":C_AMBER, "event_feed":C_BLUE, "combat_feed":C_TEAL}
	for name in feeds:
		_hud_surface("match.hud.left.%s.default" % name, "match/hud/left/%s_default.png" % name, Vector2i(320,44), "feed", feeds[name])
	_hud_surface("match.hud.left.feed_container.default", "match/hud/left/feed_container_default.png", Vector2i(336,360), "container", C_LINE)
	var right := {"selected_team":Vector2i(320,72), "selected_player":Vector2i(320,96), "inventory":Vector2i(320,220), "player_stats":Vector2i(320,180), "vehicle":Vector2i(320,100), "equipment":Vector2i(320,150), "health_bar":Vector2i(320,24), "boost_bar":Vector2i(320,24), "ammo_bar":Vector2i(320,24), "utility_bar":Vector2i(320,24)}
	for name in right:
		_hud_surface("match.hud.right.%s.default" % name, "match/hud/right/%s_default.png" % name, right[name], "inspector", C_AMBER if name in ["equipment","ammo_bar","utility_bar"] else C_TEAL)
	_hud_surface("match.hud.bottom.timeline.default", "match/hud/bottom/timeline_default.png", Vector2i(920,72), "timeline", C_TEAL)
	for name in ["play","pause","stop","previous","next"]:
		_hud_surface("match.hud.bottom.%s.default" % name, "match/hud/bottom/%s_default.png" % name, Vector2i(52,44), "control", C_TEAL)
	for name in ["speed_025","speed_05","speed_1","speed_2","speed_4","speed_8"]:
		_hud_surface("match.hud.bottom.%s.default" % name, "match/hud/bottom/%s_default.png" % name, Vector2i(64,40), "speed", C_AMBER if name == "speed_1" else C_LINE)
	for name in ["filters","live"]:
		_hud_surface("match.hud.bottom.%s.default" % name, "match/hud/bottom/%s_default.png" % name, Vector2i(90,40), "control", C_RED if name == "live" else C_TEAL)

func _hud_surface(id: String, path: String, size: Vector2i, role: String, accent: Color) -> void:
	var im := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	im.fill(C_CLEAR)
	_rect(im, Rect2i(1,1,size.x-2,size.y-2), Color("0d151b"))
	_outline(im, Rect2i(1,1,size.x-2,size.y-2), C_LINE, 2)
	match role:
		"metric":
			_rect(im, Rect2i(1,1,5,size.y-2), accent)
			_line(im, Vector2i(16,18), Vector2i(size.x-18,18), C_MUTED.darkened(.35), 2)
		"feed":
			_rect(im, Rect2i(8,8,28,28), accent.darkened(.35))
			_circle_outline(im, Vector2i(22,22), 9, accent, 2)
			_line(im, Vector2i(48,13), Vector2i(size.x-12,13), accent.darkened(.25), 2)
			_line(im, Vector2i(48,29), Vector2i(size.x-60,29), C_LINE, 2)
		"container":
			_line(im, Vector2i(14,38), Vector2i(size.x-14,38), C_LINE, 2)
		"inspector":
			_rect(im, Rect2i(1,1,size.x-2,6), accent)
			if size.y >= 90:
				_line(im, Vector2i(14,45), Vector2i(size.x-14,45), C_LINE, 2)
				_line(im, Vector2i(size.x/2,54), Vector2i(size.x/2,size.y-12), C_LINE.darkened(.25), 1)
		"timeline":
			_line(im, Vector2i(24,36), Vector2i(size.x-24,36), C_MUTED, 2)
			for x in range(32,size.x-24,72): _line(im, Vector2i(x,29), Vector2i(x,43), C_LINE.lightened(.2), 2)
			_circle(im, Vector2i(size.x*2/3,36), 7, accent)
		"speed": _rect(im, Rect2i(1,size.y-5,size.x-2,4), accent)
		"control": _rect(im, Rect2i(1,1,4,size.y-2), accent)
	_save_as(id, path, im, {"kind":"match_hud", "role":role, "size":[size.x,size.y], "margins":[8,8,8,8]})

func _ring(path: String, color: Color, thickness: int) -> void:
	var im := Image.create(256,256,false,Image.FORMAT_RGBA8); im.fill(C_CLEAR); _circle_outline(im,Vector2i(128,128),116,color,thickness); _save(path,im,{"kind":"overlay","anchor":[0.5,0.5]})

func _marker(path: String, color: Color, square: bool) -> void:
	var im := Image.create(48,48,false,Image.FORMAT_RGBA8); im.fill(C_CLEAR)
	if square: _rect(im,Rect2i(10,10,28,28),color); _outline(im,Rect2i(10,10,28,28),C_TEXT,2)
	else: _circle(im,Vector2i(24,24),15,color); _circle_outline(im,Vector2i(24,24),15,C_TEXT,2)
	_save(path,im,{"kind":"marker","anchor":[0.5,0.5]})

func _effect(path: String, color: Color) -> void:
	var im := Image.create(128,128,false,Image.FORMAT_RGBA8); im.fill(C_CLEAR)
	for r in range(52,4,-5):
		var alpha := float(58-r)/64.0
		_circle(im,Vector2i(64+(r%9)-4,64-(r%7)),r,Color(color.r,color.g,color.b,alpha*.24))
	_save(path,im,{"kind":"effect","frames":1,"loop":false,"hold_last":false})

func _make_inventory() -> void:
	var ammo := {"556":Color("c9b46d"),"762":Color("9f7654"),"9mm":Color("d0c0a0"),"9x39":Color("81765f"),"45":Color("bfa36f"),"300_magnum":C_AMBER,"12g":C_RED,"bolt":C_MUTED}
	for id in ammo:
		var im := Image.create(96,96,false,Image.FORMAT_RGBA8); im.fill(C_CLEAR)
		for i in 3:
			_rect(im,Rect2i(21+i*19,25-i*4,11,47),ammo[id]); _rect(im,Rect2i(21+i*19,20-i*4,11,9),ammo[id].lightened(.25)); _rect(im,Rect2i(19+i*19,69-i*4,15,6),ammo[id].darkened(.25))
		_save("inventory/ammo/%s.png" % id,im,{"kind":"item","category":"ammo","caliber":id})
	for pair in [["bandage","plus",C_TEXT],["med_kit","plus",C_RED],["energy_drink","bolt",C_BLUE],["painkiller","plus",C_AMBER],["adrenaline","bolt",C_RED],["frag_grenade","grenade",C_GREEN],["smoke_grenade","smoke",C_MUTED],["molotov","fire",C_RED],["flash_grenade","flash",C_AMBER]]:
		_icon("inventory/items/%s.png" % pair[0],pair[1],pair[2])
	for scope in [1,2,3,4,6,8]: _scope_asset(scope)
	for attachment in ["compensator","suppressor","flash_hider","vertical_grip","angled_grip","lightweight_grip","extended_mag","quickdraw_mag","tactical_stock","cheek_pad"]: _attachment_asset(attachment)

func _scope_asset(power: int) -> void:
	var im:=Image.create(96,96,false,Image.FORMAT_RGBA8); im.fill(C_CLEAR)
	var radius:=22+mini(power,8)
	_circle_outline(im,Vector2i(48,48),radius,C_TEAL,4)
	_circle_outline(im,Vector2i(48,48),maxi(7,20-power),C_MUTED,2)
	_line(im,Vector2i(48,14),Vector2i(48,82),C_LINE.lightened(.25),2); _line(im,Vector2i(14,48),Vector2i(82,48),C_LINE.lightened(.25),2)
	for tick in power: _rect(im,Rect2i(18+tick*7,78,4,4),C_AMBER)
	_save_as("attachment.scope_%dx"%power,"inventory/attachments/scope_%dx.png"%power,im,{"kind":"attachment","slot":"optic","magnification":power})

func _attachment_asset(name: String) -> void:
	var im:=Image.create(96,96,false,Image.FORMAT_RGBA8); im.fill(C_CLEAR)
	if name in ["compensator","suppressor","flash_hider"]:
		var length:=58 if name=="suppressor" else 42; _rect(im,Rect2i((96-length)/2,35,length,26),C_PANEL_2); _outline(im,Rect2i((96-length)/2,35,length,26),C_TEAL,3)
		for x in range((96-length)/2+8,(96+length)/2-4,10): _line(im,Vector2i(x,39),Vector2i(x,57),C_LINE,2)
	elif name.contains("grip"):
		_poly(im,[Vector2i(34,20),Vector2i(62,20),Vector2i(58,72),Vector2i(42,78)],C_PANEL_2); _outline(im,Rect2i(32,18,32,62),C_AMBER,3)
	elif name.contains("mag"):
		_poly(im,[Vector2i(30,18),Vector2i(65,18),Vector2i(61,74),Vector2i(39,82)],C_PANEL_2); _line(im,Vector2i(35,35),Vector2i(62,35),C_TEAL,3); _line(im,Vector2i(37,52),Vector2i(60,52),C_TEAL,3)
	else:
		_poly(im,[Vector2i(18,32),Vector2i(68,22),Vector2i(80,34),Vector2i(67,70),Vector2i(24,63)],C_PANEL_2); _line(im,Vector2i(28,48),Vector2i(67,39),C_TEAL,3)
	_save_as("attachment.%s"%name,"inventory/attachments/%s.png"%name,im,{"kind":"attachment","slot":"muzzle" if name in ["compensator","suppressor","flash_hider"] else ("grip" if name.contains("grip") else ("magazine" if name.contains("mag") else "stock"))})

func _make_weapon_surfaces() -> void:
	var weapons := {
		"ar_556": C_TEAL, "ar_762": Color("c58a54"), "smg_9mm": C_BLUE,
		"dmr_762": C_AMBER, "sniper_bolt": Color("6f8ee8"),
		"shotgun_12g": Color("e18b37"), "pistol_9mm": C_TEAL,
		"lmg_556": C_AMBER, "vss_9x39": Color("925bd6")
	}
	for weapon_id in weapons:
		var source_path := ROOT.path_join("inventory/weapons/%s.png" % weapon_id)
		var source_texture := load(source_path) as Texture2D
		var source := source_texture.get_image() if source_texture else null
		if source == null or source.is_empty():
			push_error("Missing weapon source: " + source_path)
			continue
		var accent: Color = weapons[weapon_id]
		_weapon_surface(weapon_id, "inventory", source, Vector2i(512, 256), accent, "transparent")
		_weapon_surface(weapon_id, "ground", source, Vector2i(512, 256), accent, "ground")
		_weapon_surface(weapon_id, "kill_feed", source, Vector2i(96, 48), accent, "silhouette")
		_weapon_surface(weapon_id, "statistics", source, Vector2i(96, 48), accent, "statistics")
		_weapon_surface(weapon_id, "weapon_card", source, Vector2i(512, 256), accent, "card")
		_weapon_surface(weapon_id, "comparison", source, Vector2i(256, 128), accent, "comparison")
		_weapon_surface(weapon_id, "market", source, Vector2i(512, 256), accent, "market")
		_weapon_surface(weapon_id, "training", source, Vector2i(256, 128), accent, "training")

func _weapon_surface(weapon_id: String, surface: String, source: Image, size: Vector2i, accent: Color, treatment: String) -> void:
	var canvas := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	canvas.fill(C_CLEAR)
	if treatment in ["card", "comparison", "market", "training", "statistics"]:
		_rect(canvas, Rect2i(0, 0, size.x, size.y), C_PANEL)
		_outline(canvas, Rect2i(1, 1, size.x - 2, size.y - 2), accent.darkened(0.35), 2)
	if treatment == "card":
		_rect(canvas, Rect2i(0, 0, 10, size.y), accent)
		_line(canvas, Vector2i(24, 24), Vector2i(size.x - 24, 24), accent, 2)
	elif treatment == "comparison":
		_rect(canvas, Rect2i(0, size.y - 12, size.x, 12), accent.darkened(0.2))
		_line(canvas, Vector2i(size.x / 2, 12), Vector2i(size.x / 2, size.y - 20), C_LINE, 2)
	elif treatment == "market":
		_rect(canvas, Rect2i(0, 0, size.x, 36), accent.darkened(0.65))
		_rect(canvas, Rect2i(size.x - 80, size.y - 20, 64, 4), accent)
	elif treatment == "training":
		for x in range(18, size.x - 12, 22):
			_line(canvas, Vector2i(x, size.y - 18), Vector2i(x + 10, size.y - 18), accent, 3)
	elif treatment == "ground":
		var shadow := _fit_weapon(source, size, 24, true, Color(0, 0, 0, 0.42))
		canvas.blend_rect(shadow, Rect2i(Vector2i.ZERO, size), Vector2i(5, 7))
	var fitted := _fit_weapon(source, size, 22 if size.x > 128 else 5, treatment == "silhouette", C_TEXT if treatment == "silhouette" else Color.WHITE)
	canvas.blend_rect(fitted, Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
	var relative := "weapons/%s/%s_%s.png" % [weapon_id, weapon_id, surface]
	_save_as("weapon.%s.%s" % [weapon_id, surface], relative, canvas, {
		"kind":"weapon_surface", "weapon":weapon_id, "surface":surface,
		"size":[size.x,size.y], "anchor":[0.5,0.5]
	})

func _fit_weapon(source: Image, target_size: Vector2i, padding: int, monochrome: bool, tint: Color) -> Image:
	var bounds := _alpha_bounds(source)
	var cropped := source.get_region(bounds)
	var available := Vector2i(maxi(1, target_size.x - padding * 2), maxi(1, target_size.y - padding * 2))
	var scale_factor := minf(float(available.x) / cropped.get_width(), float(available.y) / cropped.get_height())
	var scaled_size := Vector2i(maxi(1, roundi(cropped.get_width() * scale_factor)), maxi(1, roundi(cropped.get_height() * scale_factor)))
	cropped.resize(scaled_size.x, scaled_size.y, Image.INTERPOLATE_LANCZOS)
	if monochrome:
		for y in cropped.get_height():
			for x in cropped.get_width():
				var pixel := cropped.get_pixel(x, y)
				cropped.set_pixel(x, y, Color(tint.r, tint.g, tint.b, pixel.a * tint.a))
	var result := Image.create(target_size.x, target_size.y, false, Image.FORMAT_RGBA8)
	result.fill(C_CLEAR)
	var destination := Vector2i((target_size.x - scaled_size.x) / 2, (target_size.y - scaled_size.y) / 2)
	result.blend_rect(cropped, cropped.get_used_rect(), destination)
	return result

func _alpha_bounds(image: Image) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.04:
				min_x = mini(min_x, x); min_y = mini(min_y, y)
				max_x = maxi(max_x, x); max_y = maxi(max_y, y)
	if max_x < min_x:
		return Rect2i(0, 0, image.get_width(), image.get_height())
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func _write_manifest() -> void:
	for extra in [
		["branding.command_center","branding/command_center_background.png","background"],
		["match.map.astra","match/maps/tactical_island.png","map"],
		["match.map.verdant_reach","match/maps/verdant_reach.png","map"],
		["match.map.sunscorch_basin","match/maps/sunscorch_basin.png","map"],
		["match.map.frostline_valley","match/maps/frostline_valley_square.png","map"],
		["match.map.coastal_breakwater","match/maps/coastal_breakwater_square.png","map"],
		["match.map.highland_reserve","match/maps/highland_reserve_square.png","map"],
		["item.first_aid","inventory/items/first_aid.png","item"],
		["weapon.ar_556","inventory/weapons/ar_556.png","weapon"], ["weapon.ar_762","inventory/weapons/ar_762.png","weapon"],
		["weapon.smg_9mm","inventory/weapons/smg_9mm.png","weapon"], ["weapon.dmr_762","inventory/weapons/dmr_762.png","weapon"],
		["weapon.sniper_bolt","inventory/weapons/sniper_bolt.png","weapon"], ["weapon.shotgun_12g","inventory/weapons/shotgun_12g.png","weapon"],
		["weapon.pistol_9mm","inventory/weapons/pistol_9mm.png","weapon"],
		["weapon.lmg_556","inventory/weapons/lmg_556.png","weapon"], ["weapon.vss_9x39","inventory/weapons/vss_9x39.png","weapon"]
	]: entries[extra[0]]={"path":"res://assets/%s"%extra[1],"kind":extra[2],"lazy":true}
	var manifest := {"schema_version":2,"format":"png_only","renderer":"godot_4_gl_compatibility","palette":{"bg":"#0b1117","panel":"#121b24","teal":"#20d6aa","amber":"#f5b82e","danger":"#f05252"},"assets":entries,"animation_profiles":{"ui_pulse":{"frames":1,"fps":0,"loop":false,"runtime_tween":true,"transition":"ease_out"},"zone_shrink":{"frames":1,"fps":0,"loop":false,"runtime_tween":true,"preserve_phase":true},"marker_ping":{"frames":1,"fps":0,"loop":false,"runtime_tween":true,"hold_last":false}},"excluded":["player avatars","team logos","character body animation","cosmetics"]}
	var f:=FileAccess.open(ROOT+"/asset_manifest.json",FileAccess.WRITE); f.store_string(JSON.stringify(manifest,"  "))

func _save(relative: String, image: Image, metadata: Dictionary) -> void:
	var path := ROOT.path_join(relative); DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir())); image.save_png(path)
	var id := relative.trim_suffix(".png").replace("/","."); metadata["path"] = path; metadata["lazy"] = true; entries[id] = metadata

func _save_as(id: String, relative: String, image: Image, metadata: Dictionary) -> void:
	var path := ROOT.path_join(relative)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	image.save_png(path)
	metadata["path"] = path
	metadata["lazy"] = true
	entries[id] = metadata

func _rect(im:Image,r:Rect2i,c:Color)->void:
	for y in range(maxi(0,r.position.y),mini(im.get_height(),r.end.y)):
		for x in range(maxi(0,r.position.x),mini(im.get_width(),r.end.x)): im.set_pixel(x,y,c)
func _outline(im:Image,r:Rect2i,c:Color,w:int)->void:
	_rect(im,Rect2i(r.position.x,r.position.y,r.size.x,w),c); _rect(im,Rect2i(r.position.x,r.end.y-w,r.size.x,w),c); _rect(im,Rect2i(r.position.x,r.position.y,w,r.size.y),c); _rect(im,Rect2i(r.end.x-w,r.position.y,w,r.size.y),c)
func _line(im:Image,a:Vector2i,b:Vector2i,c:Color,w:int=1)->void:
	var d:=b-a; var steps:=maxi(absi(d.x),absi(d.y)); if steps==0:return
	for i in steps+1:
		var p:=Vector2(a).lerp(Vector2(b),float(i)/steps); _rect(im,Rect2i(roundi(p.x)-w/2,roundi(p.y)-w/2,w,w),c)
func _circle(im:Image,center:Vector2i,radius:int,c:Color)->void:
	for y in range(-radius,radius+1):
		for x in range(-radius,radius+1):
			if x*x+y*y<=radius*radius:
				var p:=center+Vector2i(x,y); if p.x>=0 and p.y>=0 and p.x<im.get_width() and p.y<im.get_height(): im.set_pixelv(p,c)
func _circle_outline(im:Image,center:Vector2i,radius:int,c:Color,w:int)->void:
	for y in range(-radius-w,radius+w+1):
		for x in range(-radius-w,radius+w+1):
			var q:=x*x+y*y
			if q<=radius*radius and q>=(radius-w)*(radius-w):
				var p:=center+Vector2i(x,y); if p.x>=0 and p.y>=0 and p.x<im.get_width() and p.y<im.get_height(): im.set_pixelv(p,c)
func _poly(im:Image,pts:Array,c:Color)->void:
	var min_y:=9999; var max_y:=-1
	for p in pts: min_y=mini(min_y,p.y); max_y=maxi(max_y,p.y)
	for y in range(min_y,max_y+1):
		var hits:Array[float]=[]
		for i in pts.size():
			var a:Vector2i=pts[i]; var b:Vector2i=pts[(i+1)%pts.size()]
			if (a.y<=y and b.y>y) or (b.y<=y and a.y>y): hits.append(a.x+float(y-a.y)*float(b.x-a.x)/float(b.y-a.y))
		hits.sort()
		for i in range(0,hits.size()-1,2): _line(im,Vector2i(ceili(hits[i]),y),Vector2i(floori(hits[i+1]),y),c)
