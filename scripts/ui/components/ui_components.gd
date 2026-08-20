class_name UIComponents
extends RefCounted

const Tokens = preload("res://scripts/ui/theme/design_tokens.gd")

static func label(text_value: String, font_size := 13, tone := Color("f0f6f5")) -> Label:
	var result := Label.new(); result.text = text_value
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", tone)
	result.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return result

static func button(text_value: String, variant := "secondary") -> Button:
	var result := Button.new(); result.text = text_value; result.custom_minimum_size.y = 40
	var primary := variant == "primary"; var danger := variant == "danger"
	var tone: Color = Tokens.color("danger") if danger else Tokens.color("primary") if primary else Tokens.color("surface_interactive")
	var border: Color = Tokens.color("danger") if danger else Tokens.color("primary") if primary else Tokens.color("border")
	result.add_theme_stylebox_override("normal", Tokens.style(tone if primary else Color(tone, 0.42), 4, border if primary or danger else Color.TRANSPARENT, 1 if primary or danger else 0, 10))
	result.add_theme_stylebox_override("hover", Tokens.style(tone.lightened(0.10), 4, border.lightened(0.15), 1, 10))
	result.add_theme_stylebox_override("pressed", Tokens.style(tone.darkened(0.12), 5, border, 2, 10))
	result.add_theme_stylebox_override("focus", Tokens.style(Color(tone, 0.85), 5, Tokens.color("information"), 2, 10))
	result.add_theme_stylebox_override("disabled", Tokens.style(Color(Tokens.color("surface"), 0.75), 5, Tokens.color("border_soft"), 1, 10))
	result.add_theme_color_override("font_color", Color("071018") if primary else Tokens.color("danger") if danger else Tokens.color("text"))
	result.add_theme_color_override("font_hover_color", Color("071018") if primary else Tokens.color("text"))
	result.add_theme_color_override("font_disabled_color", Tokens.color("disabled"))
	return result

static func panel(title := "", elevated := false) -> VBoxContainer:
	var result := VBoxContainer.new(); result.add_theme_constant_override("separation", Tokens.SPACE.md)
	result.add_theme_stylebox_override("panel", Tokens.style(Tokens.color("surface_high") if elevated else Tokens.color("surface"), 4, Color.TRANSPARENT, 0, 14))
	if not title.is_empty():
		var heading := label("▰  " + title.to_upper(), Tokens.TYPE.secondary, Tokens.color("text_secondary")); heading.custom_minimum_size.y = 24; result.add_child(heading)
	return result

static func badge(text_value: String, tone: Color) -> Label:
	var result := label(text_value.to_upper(), Tokens.TYPE.metadata, tone); result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.add_theme_stylebox_override("normal", Tokens.style(Color(tone, 0.10), 4, Color(tone, 0.55), 1, 6))
	return result

static func empty_state(title: String, description: String, is_error := false) -> VBoxContainer:
	var result := panel("", false); result.custom_minimum_size.y = 112
	var tone := Tokens.color("danger") if is_error else Tokens.color("text_secondary")
	var heading := label(title, Tokens.TYPE.section, tone); heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; result.add_child(heading)
	var copy := label(description, Tokens.TYPE.secondary, Tokens.color("text_secondary")); copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; result.add_child(copy)
	return result

static func page_header(title: String, subtitle: String, breadcrumb := "") -> VBoxContainer:
	var result := VBoxContainer.new(); result.add_theme_constant_override("separation",3)
	if not breadcrumb.is_empty(): result.add_child(label(breadcrumb,Tokens.TYPE.metadata,Tokens.color("text_secondary")))
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation",Tokens.SPACE.md); result.add_child(row)
	var marker := ColorRect.new(); marker.color=Tokens.color("primary"); marker.custom_minimum_size=Vector2(3,52); row.add_child(marker)
	var copy := VBoxContainer.new(); copy.add_child(label(title,Tokens.TYPE.page_title,Tokens.color("text"))); var description:=label(subtitle,Tokens.TYPE.body,Tokens.color("text_secondary")); description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; copy.add_child(description); row.add_child(copy)
	return result

static func stat_card(caption: String, value: Variant, tone: Color, note := "") -> VBoxContainer:
	var result := panel("",false); result.size_flags_horizontal=Control.SIZE_EXPAND_FILL; result.add_child(label(str(value),Tokens.TYPE.stat,tone)); result.add_child(label(caption.to_upper(),Tokens.TYPE.metadata,Tokens.color("text")))
	if not note.is_empty(): result.add_child(label(note,Tokens.TYPE.metadata,Tokens.color("text_secondary")))
	return result

static func trend_indicator(value: int) -> Label:
	var symbol := "▲" if value > 0 else "▼" if value < 0 else "—"; var tone := Tokens.color("positive") if value>0 else Tokens.color("danger") if value<0 else Tokens.color("text_secondary"); return badge("%s %d" % [symbol,absi(value)],tone)

static func progress(value: float, tone: Color, height := 6) -> ProgressBar:
	var result := ProgressBar.new(); result.max_value=100; result.value=clampf(value,0,100); result.show_percentage=false; result.custom_minimum_size=Vector2(120,height); result.size_flags_horizontal=Control.SIZE_EXPAND_FILL; result.add_theme_stylebox_override("background",Tokens.style(Tokens.color("background"),height/2,Color.TRANSPARENT,0,0)); result.add_theme_stylebox_override("fill",Tokens.style(tone,height/2,Color.TRANSPARENT,0,0)); return result

static func player_row(player: Dictionary) -> Button:
	var result := button("@%s  •  %s\n%s  •  OVR %d  •  FORM %d  •  ENERGY %d%%" % [player.get("handle","player"),player.get("name",player.get("display_name","Unknown")),player.get("role","Flex"),int(player.get("overall",0)),int(player.get("form",0)),int(player.get("energy",0))]); result.alignment=HORIZONTAL_ALIGNMENT_LEFT; result.custom_minimum_size.y=62; return result

static func team_row(team: Dictionary) -> Button:
	var ranking: Dictionary=team.get("ranking",{}); var result:=button("%s  •  %s\nPOWER %d  •  TIER %s" % [team.get("name","Unknown Team"),team.get("region","Unknown"),int(team.get("power",ranking.get("power",0))),team.get("tier","—")]); result.alignment=HORIZONTAL_ALIGNMENT_LEFT; result.custom_minimum_size.y=58; return result

static func filter_bar(options: Array, selected: String, on_selected: Callable) -> HBoxContainer:
	var result:=HBoxContainer.new(); result.add_theme_constant_override("separation",Tokens.SPACE.sm)
	for option in options:
		var value:=str(option); var item:=button(value,"primary" if value==selected else "secondary"); item.pressed.connect(on_selected.bind(value)); result.add_child(item)
	return result

static func search_bar(placeholder: String, value: String, on_submit: Callable) -> LineEdit:
	var result:=LineEdit.new(); result.placeholder_text=placeholder; result.text=value; result.custom_minimum_size=Vector2(240,40); result.size_flags_horizontal=Control.SIZE_EXPAND_FILL; result.text_submitted.connect(on_submit); return result

static func sort_control(options: Array, selected: String, on_selected: Callable) -> OptionButton:
	var result:=OptionButton.new(); result.custom_minimum_size=Vector2(180,40)
	for option in options: result.add_item(str(option))
	result.select(maxi(0,options.find(selected))); result.item_selected.connect(on_selected); return result

static func data_table(columns: Array) -> VBoxContainer:
	var result:=panel("",true); var header:=HBoxContainer.new(); header.add_theme_constant_override("separation",Tokens.SPACE.sm); result.add_child(header)
	for column in columns:
		var title:=str(column[0] if column is Array else column); var width:=int(column[1]) if column is Array and column.size()>1 else 120; var cell:=label(title.to_upper(),Tokens.TYPE.metadata,Tokens.color("text_secondary")); cell.custom_minimum_size.x=width; header.add_child(cell)
	return result

static func chart_panel(title: String, unavailable_copy := "Complete matches to unlock verified telemetry.") -> VBoxContainer:
	var result:=panel(title,true); result.add_child(empty_state("NO VERIFIED SAMPLE",unavailable_copy)); return result

static func loading_state(message := "Loading…") -> VBoxContainer:
	var result:=empty_state("LOADING",message); var bar:=ProgressBar.new(); bar.indeterminate=true; result.add_child(bar); return result

static func error_state(title: String, message: String) -> VBoxContainer:
	return empty_state(title,message,true)

static func confirmation_dialog(title: String, message: String, confirm_text: String, on_confirm: Callable, dangerous := false) -> ConfirmationDialog:
	var result:=ConfirmationDialog.new(); result.title=title; result.dialog_text=message; result.ok_button_text=confirm_text; result.confirmed.connect(on_confirm)
	if dangerous: result.get_ok_button().add_theme_color_override("font_color",Tokens.color("danger"))
	return result

static func toast(message: String, tone := Color("16d8c1")) -> Label:
	var result:=label(message,Tokens.TYPE.body,Tokens.color("text")); result.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; result.add_theme_stylebox_override("normal",Tokens.style(Color(Tokens.color("surface_high"),0.96),5,tone,1,10)); return result

static func hero_panel(title: String, subtitle := "", tone := Color("ff8a00")) -> VBoxContainer:
	var result:=VBoxContainer.new(); result.add_theme_constant_override("separation",Tokens.SPACE.md); result.add_theme_stylebox_override("panel",Tokens.style(Color(Tokens.color("surface_hero"),0.96),3,Color.TRANSPARENT,0,Tokens.SPACE.xl))
	var eyebrow:=label(title.to_upper(),Tokens.TYPE.secondary,tone); result.add_child(eyebrow)
	if not subtitle.is_empty(): var copy:=label(subtitle,Tokens.TYPE.body,Tokens.color("text_secondary")); copy.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; result.add_child(copy)
	return result

static func game_stat(caption: String, value: Variant, tone: Color, note := "") -> VBoxContainer:
	var result:=VBoxContainer.new(); result.size_flags_horizontal=Control.SIZE_EXPAND_FILL; result.add_theme_constant_override("separation",2)
	result.add_child(label(caption.to_upper(),Tokens.TYPE.metadata,Tokens.color("text_secondary"))); result.add_child(label(str(value),Tokens.TYPE.stat,tone))
	if not note.is_empty(): result.add_child(label(note,Tokens.TYPE.metadata,Tokens.color("text_secondary")))
	return result

static func decision_card(index: String, title: String, state: String, tone: Color) -> Button:
	var result:=button("%s     %s\n       %s" % [index,title.to_upper(),state.to_upper()]); result.alignment=HORIZONTAL_ALIGNMENT_LEFT; result.custom_minimum_size.y=66; result.add_theme_color_override("font_color",tone); result.add_theme_stylebox_override("normal",Tokens.style(Color(Tokens.color("surface_interactive"),0.72),3,Color.TRANSPARENT,0,12)); result.add_theme_stylebox_override("hover",Tokens.style(Color(tone,0.14),3,tone,1,12)); return result

static func tactical_panel(title := "TACTICAL BOARD") -> VBoxContainer:
	var result:=panel(title,true); result.add_theme_stylebox_override("panel",Tokens.style(Color(Tokens.color("surface_tactical"),0.96),3,Color(Tokens.color("information"),0.18),1,16)); return result

static func career_milestone(code: String, title: String, note: String, tone: Color) -> VBoxContainer:
	var result:=VBoxContainer.new(); result.add_theme_constant_override("separation",3); result.add_theme_stylebox_override("panel",Tokens.style(Color(tone,0.07),3,Color.TRANSPARENT,0,14)); result.add_child(label(code,Tokens.TYPE.metadata,tone)); result.add_child(label(title,Tokens.TYPE.section,Tokens.color("text"))); result.add_child(label(note,Tokens.TYPE.secondary,Tokens.color("text_secondary"))); return result
