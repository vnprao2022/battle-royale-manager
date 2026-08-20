class_name AppShell
extends RefCounted

const Tokens = preload("res://scripts/ui/theme/design_tokens.gd")
const Responsive = preload("res://scripts/ui/utilities/responsive.gd")

static func build(owner: Control, assets) -> Dictionary:
	var bg := ColorRect.new(); bg.color = Tokens.color("background"); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); owner.add_child(bg)
	var backdrop := TextureRect.new(); backdrop.texture = assets.texture("branding.command_center"); backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; backdrop.modulate = Color(0.72,0.58,0.40,0.13); backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); owner.add_child(backdrop)
	var shade := ColorRect.new(); shade.color = Color(0.01,0.025,0.04,0.66); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); owner.add_child(shade)
	_add_tactical_atmosphere(owner)
	var root := Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.clip_contents=true; owner.add_child(root)
	var sidebar_width := Responsive.sidebar_width(owner.get_viewport_rect().size)
	var sidebar := VBoxContainer.new(); sidebar.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE); sidebar.offset_right=sidebar_width; sidebar.add_theme_constant_override("separation",5); sidebar.add_theme_stylebox_override("panel",Tokens.style(Tokens.color("sidebar"),0,Tokens.color("border"),0,10)); root.add_child(sidebar)
	var main := Control.new(); main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); main.offset_left=sidebar_width; main.clip_contents=true; root.add_child(main)
	var topbar_height := 60 if Responsive.is_compact(owner.get_viewport_rect().size) else 68
	var topbar := HBoxContainer.new(); topbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE); topbar.offset_bottom=topbar_height; topbar.add_theme_constant_override("separation",8 if Responsive.is_compact(owner.get_viewport_rect().size) else 14); topbar.add_theme_stylebox_override("panel",Tokens.style(Color("070d12ef"),0,Color.TRANSPARENT,0,8)); main.add_child(topbar)
	var margin := MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); margin.offset_top=topbar_height; var page_margin := Responsive.page_margin(owner.get_viewport_rect().size); margin.add_theme_constant_override("margin_left",page_margin); margin.add_theme_constant_override("margin_right",page_margin); margin.add_theme_constant_override("margin_top",12); margin.add_theme_constant_override("margin_bottom",14); main.add_child(margin)
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; margin.add_child(scroll)
	var content := VBoxContainer.new(); content.size_flags_horizontal=Control.SIZE_EXPAND_FILL; content.add_theme_constant_override("separation",12 if Responsive.is_compact(owner.get_viewport_rect().size) else 16); scroll.add_child(content)
	var toast := Label.new(); toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM); toast.position=Vector2(-220,-72); toast.size=Vector2(440,46); toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; toast.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; toast.visible=false; toast.add_theme_stylebox_override("normal",Tokens.style(Color("142837f2"),6,Tokens.color("information"),1,10)); toast.add_theme_color_override("font_color",Tokens.color("text")); owner.add_child(toast)
	return {"sidebar":sidebar,"topbar":topbar,"content":content,"toast":toast,"scroll":scroll}

static func _add_tactical_atmosphere(owner: Control) -> void:
	var layer:=Control.new(); layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); layer.mouse_filter=Control.MOUSE_FILTER_IGNORE; owner.add_child(layer)
	var size:=owner.get_viewport_rect().size
	for index in 13:
		var vertical:=ColorRect.new(); vertical.color=Color(0.10,0.72,0.68,0.022); vertical.position=Vector2(size.x*float(index)/12.0,0); vertical.size=Vector2(1,size.y); vertical.mouse_filter=Control.MOUSE_FILTER_IGNORE; layer.add_child(vertical)
	for index in 8:
		var horizontal:=ColorRect.new(); horizontal.color=Color(0.10,0.72,0.68,0.018); horizontal.position=Vector2(0,size.y*float(index)/7.0); horizontal.size=Vector2(size.x,1); horizontal.mouse_filter=Control.MOUSE_FILTER_IGNORE; layer.add_child(horizontal)
	var horizon:=ColorRect.new(); horizon.color=Color(1.0,0.12,0.16,0.035); horizon.position=Vector2(0,size.y*0.64); horizon.size=Vector2(size.x,2); horizon.mouse_filter=Control.MOUSE_FILTER_IGNORE; layer.add_child(horizon)
