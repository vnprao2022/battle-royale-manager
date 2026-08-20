extends Control

const GameStateScript = preload("res://scripts/game_state.gd")
const AssetRegistryScript = preload("res://scripts/asset_registry.gd")
const UICardScript = preload("res://scripts/ui_card.gd")
const MatchRuntimeScript = preload("res://scripts/match_runtime.gd")
const MatchMapOverlayScript = preload("res://scripts/match_map_overlay.gd")
const MapCatalogScript = preload("res://scripts/map_catalog.gd")
const ContentManagerScript = preload("res://scripts/content_manager.gd")
const ProbabilityRingScript = preload("res://scripts/probability_ring.gd")
const TournamentEmblemScript = preload("res://scripts/tournament_emblem.gd")
const DashboardSymbolScript = preload("res://scripts/dashboard_symbol.gd")
const UIDataPresenterScript = preload("res://scripts/ui_data_presenter.gd")
const AppShellScript = preload("res://scripts/ui/app_shell.gd")
const UIRouterScript = preload("res://scripts/ui/router.gd")
const UIComponentsScript = preload("res://scripts/ui/components/ui_components.gd")
const DesignTokensScript = preload("res://scripts/ui/theme/design_tokens.gd")
const ResponsiveScript = preload("res://scripts/ui/utilities/responsive.gd")
const GamePresenterScript = preload("res://scripts/ui/presenters/game_presenter.gd")
const CareerPriorityPresenterScript = preload("res://scripts/ui/presenters/career_priority_presenter.gd")
const PerformanceCampusScreenScript = preload("res://scripts/ui/screens/performance_campus_screen.gd")
const UserSettingsScript = preload("res://scripts/user_settings.gd")

const BG := Color("05090d")
const SIDEBAR := Color("081018")
const PANEL := Color("0b141d")
const PANEL_HIGH := Color("101b24")
const LINE := Color("263947")
const ACCENT := Color("ff8a00")
const CYAN := Color("16d8c1")
const GOLD := Color("ffb52e")
const ORANGE := Color("ff9d22")
const DANGER := Color("ff4b55")
const SUCCESS := Color("35d07f")
const PURPLE := Color("a78bfa")
const TEXT := Color("f0f6f5")
const MUTED := Color("8ea3ad")
const DISABLED := Color("5d6b76")
const SPACE_XS := 4
const SPACE_SM := 8
const SPACE_MD := 12
const SPACE_LG := 16
const SPACE_20 := 20
const SPACE_XL := 24
const SPACE_2XL := 32
const RADIUS_SM := 3
const RADIUS_MD := 5
const RADIUS_LG := 7

var game := GameStateScript.new()
var assets := AssetRegistryScript.new()
var router := UIRouterScript.new()
var content: VBoxContainer
var sidebar: VBoxContainer
var topbar: HBoxContainer
var toast: Label
var shell_main: Control
var shell_margin: MarginContainer
var shell_sidebar_width := 0
var shell_topbar_height := 0
var user_settings := UserSettingsScript.new()
var active_page := "dashboard"
var selected_competition_id := "gsi_2026_s1"
var tactical_preview: Label
var selected_market := 0
var selected_player := 0
var roster_filter := "ALL"
var scout_filter := "ALL"
var scout_sort := "VALUE"
var inbox_channel := "ALL"
var selected_facility := "Training Room"
var campus_detail_open := false
var campus_zoom := 1.0
var campus_pan := Vector2.ZERO
var nav_buttons: Dictionary = {}
var week_transition_active := false
var match_runtime := MatchRuntimeScript.new()
var match_lab_nodes: Dictionary = {}
var map_catalog := MapCatalogScript.new()
var map_editor_data: Dictionary = {}
var match_map_zoom := 1.0
var selected_match_player := 0
var selected_match_team := 0
var last_match_panel_second := -1
var match_visible_teams: Dictionary = {}
var match_show_dead := false
var match_selector_popup_open := false
var match_ui_mode := "observer"
var match_final_result: Dictionary = {}
var match_runtime_is_career := false
var map_editor_controls: Dictionary = {}
var map_editor_selected_kind := "region"
var map_editor_selected_index := 0
var match_loadout_signature := ""
var match_killfeed_signature := ""
var match_scoreboard_signature := ""
var match_ui_last_refresh_msec := 0
var ranking_mode := "WORLD"
var ranking_query := ""
var selected_world_team_id := ""
var selected_profile_player: Dictionary = {}
var scout_query := ""
var scout_page := 0
var scout_age_filter := "ANY"
var scout_priority := "POTENTIAL"
var scrim_page := 0
var replay_speed := 1
var content_manager := ContentManagerScript.new()
var career_draft: Dictionary = {"slot_id":1,"difficulty":"Normal","starting_tier":"D","journey_mode":"story","team_mode":"new","roster_source":"generated","team_id":"","org_name":"","short_name":"","manager_name":"","region":"Global","logo_pattern":"shield","logo_asset_id":"logo.pattern.shield","logo_primary":"ff8a00","logo_secondary":"101b24"}
var pending_delete_slot := 0
var career_step := 1
var calendar_view := "MONTH"
var player_profile_tab := "OVERVIEW"

func _ready() -> void:
	# Keep OptionButton/PopupMenu inside the game viewport. Native child windows
	# cause a full-window compositor flash on Windows when a selector opens.
	get_viewport().set_embedding_subwindows(true)
	user_settings.load_settings()
	user_settings.apply_runtime(get_window())
	assets.initialize()
	match_runtime.updated.connect(_on_match_runtime_updated)
	match_runtime.event_emitted.connect(_on_match_event)
	match_runtime.match_finished.connect(_on_match_finished)
	_build_shell()
	_show_start_screen(game.has_save())

func _process(delta: float) -> void:
	match_runtime.tick(delta)

func _unhandled_input(event:InputEvent)->void:
	if active_page!="match_lab" or not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_EQUAL,KEY_PLUS,KEY_KP_ADD: _zoom_match_at_selected(0.25)
		KEY_MINUS,KEY_KP_SUBTRACT: _zoom_match_at_selected(-0.25)
		KEY_0,KEY_KP_0: _reset_match_zoom()
		KEY_W,KEY_UP: _pan_match_map(Vector2(0,28))
		KEY_S,KEY_DOWN: _pan_match_map(Vector2(0,-28))
		KEY_A,KEY_LEFT: _pan_match_map(Vector2(28,0))
		KEY_D,KEY_RIGHT: _pan_match_map(Vector2(-28,0))

func _build_shell() -> void:
	var shell: Dictionary = AppShellScript.build(self, assets)
	shell_main = shell.main
	shell_margin = shell.margin
	shell_sidebar_width = int(shell.sidebar_width)
	shell_topbar_height = int(shell.topbar_height)
	sidebar = shell.sidebar
	topbar = shell.topbar
	content = shell.content
	toast = shell.toast

func _set_precareer_layout(enabled: bool) -> void:
	sidebar.visible = not enabled
	topbar.visible = not enabled
	shell_main.offset_left = 0 if enabled else shell_sidebar_width
	shell_margin.offset_top = 0 if enabled else shell_topbar_height
	shell_margin.add_theme_constant_override("margin_left", 28 if enabled else ResponsiveScript.page_margin(get_viewport_rect().size))
	shell_margin.add_theme_constant_override("margin_right", 28 if enabled else ResponsiveScript.page_margin(get_viewport_rect().size))

func _show_start_screen(has_save: bool) -> void:
	_clear(sidebar); _clear(topbar); _clear(content)
	_set_precareer_layout(true)
	var hero := _panel("", PANEL_HIGH)
	hero.custom_minimum_size.y = 600
	content.add_child(hero)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	hero.add_child(box)
	var brand := _brand(); brand.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; box.add_child(brand)
	var kicker := _label("ESPORTS ORGANIZATION SIMULATOR", 12, ACCENT)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(kicker)
	var title := _label("BATTLE ROYALE MANAGER", 38, TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var copy := _label("Build a living esports organization. Every decision continues into the next match.", 16, MUTED)
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(copy)
	if has_save:
		var resume := _button("CONTINUE", true)
		resume.pressed.connect(func(): var slot := game.most_recent_slot(); if slot > 0 and game.load_slot(slot): _enter_game())
		box.add_child(resume)
	var new_career := _button("NEW CAREER", not has_save); new_career.pressed.connect(_show_new_career); box.add_child(new_career)
	var load_career := _button("LOAD CAREER", false); load_career.pressed.connect(_show_save_slots); box.add_child(load_career)
	var custom_content := _button("CUSTOM CONTENT", false); custom_content.pressed.connect(_show_custom_content); box.add_child(custom_content)
	var settings := _button("SETTINGS", false); settings.pressed.connect(_show_start_settings); box.add_child(settings)
	var exit_button := _button("EXIT", false); exit_button.pressed.connect(func(): get_tree().quit()); box.add_child(exit_button)

func _show_save_slots() -> void:
	_clear(sidebar); _clear(topbar); _clear(content); _set_precareer_layout(true)
	_header("LOAD CAREER", "Three independent, versioned career slots")
	_precareer_back()
	for metadata in game.list_save_slots():
		var card := _panel("", PANEL); content.add_child(card)
		if bool(metadata.get("empty", true)):
			card.add_child(_label("SAVE %d  •  EMPTY" % int(metadata.slot_id), 22, MUTED))
			var create := _button("CREATE IN THIS SLOT", true); create.pressed.connect(func(): career_draft.slot_id = int(metadata.slot_id); _show_new_career()); card.add_child(create)
		else:
			card.add_child(_label("SAVE %d  •  %s" % [int(metadata.slot_id), str(metadata.get("org_name", "Unknown"))], 22, TEXT))
			card.add_child(_label("Season %d • Week %d • %s • Tier %s • %s" % [int(metadata.get("season",1)),int(metadata.get("week",1)),str(metadata.get("tournament","")),str(metadata.get("tier","D")),str(metadata.get("difficulty","Normal"))], 13, MUTED))
			card.add_child(_label("Last saved: %s" % str(metadata.get("last_saved_at","Unknown")), 11, CYAN))
			var actions := HBoxContainer.new(); card.add_child(actions)
			var load := _button("LOAD", true); load.pressed.connect(func(): if game.load_slot(int(metadata.slot_id)): _enter_game()); actions.add_child(load)
			var overwrite := _button("OVERWRITE", false); overwrite.pressed.connect(func(): career_draft.slot_id = int(metadata.slot_id); _show_new_career()); actions.add_child(overwrite)
			var is_confirming := pending_delete_slot == int(metadata.slot_id)
			var remove := _button("CONFIRM DELETE SAVE %d" % int(metadata.slot_id) if is_confirming else "DELETE", false); remove.add_theme_color_override("font_color", DANGER); remove.pressed.connect(func(): if is_confirming: if game.delete_slot(int(metadata.slot_id)): pending_delete_slot = 0; _show_save_slots() else: pending_delete_slot = int(metadata.slot_id); _show_save_slots()); actions.add_child(remove)
			if is_confirming:
				var cancel := _button("CANCEL", false); cancel.pressed.connect(func(): pending_delete_slot = 0; _show_save_slots()); actions.add_child(cancel)
	var back := _button("BACK", false); back.pressed.connect(_show_start_screen.bind(game.most_recent_slot() > 0)); content.add_child(back)

func _show_new_career() -> void:
	_clear(sidebar); _clear(topbar); _clear(content); _set_precareer_layout(true)
	_header("Create your career", "Every choice defines expectations, resources and the road ahead.", "STEP %d OF 5" % career_step)
	_precareer_back()
	var steps := HBoxContainer.new(); steps.add_theme_constant_override("separation", 6); content.add_child(steps)
	for index in range(1,6):
		var label := _tag("%d  %s" % [index,["SAVE","CAREER","TEAM","IDENTITY","REVIEW"][index-1]], ACCENT if index == career_step else SUCCESS if index < career_step else MUTED); label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; steps.add_child(label)
	match career_step:
		1: _career_step_slot()
		2: _career_step_settings()
		3: _career_step_team()
		4: _career_step_identity()
		5: _career_step_review()

func _career_step_slot() -> void:
	var grid := GridContainer.new(); grid.columns=3; grid.add_theme_constant_override("h_separation",12); content.add_child(grid)
	for metadata in game.list_save_slots():
		var slot_id:=int(metadata.slot_id); var selected:=slot_id==int(career_draft.slot_id); var occupied:=not bool(metadata.get("empty",true))
		var card:=_choice_card("SAVE SLOT %d" % slot_id, str(metadata.get("org_name","New career")) if occupied else "Empty slot", "Season %d • Week %d\n%s" % [int(metadata.get("season",1)),int(metadata.get("week",1)),str(metadata.get("last_saved_at","Ready to begin"))] if occupied else "A clean timeline for your next organization.", selected, CYAN if not occupied else GOLD)
		card.pressed.connect(func(): career_draft.slot_id=slot_id; _show_new_career()); grid.add_child(card)
	_wizard_actions(false, "CAREER SETTINGS")

func _career_step_settings() -> void:
	var difficulty_panel:=_panel("DIFFICULTY",PANEL_HIGH); content.add_child(difficulty_panel); var difficulties:=GridContainer.new(); difficulties.columns=4; difficulty_panel.add_child(difficulties)
	for spec in [["Casual","More guidance","Forgiving board"],["Normal","Recommended","Balanced pressure"],["Hard","Tight margins","Demanding board"],["Director","No safety net","Maximum pressure"]]:
		var value:=str(spec[0]); var card:=_choice_card(value,str(spec[1]),str(spec[2]),str(career_draft.difficulty)==value,CYAN); card.pressed.connect(func(): career_draft.difficulty=value; _show_new_career()); difficulties.add_child(card)
	var path_panel:=_panel("CAREER PATH",PANEL_HIGH); content.add_child(path_panel); var paths:=HBoxContainer.new(); paths.add_theme_constant_override("separation",12); path_panel.add_child(paths)
	for spec in [["story","STORY: BUILD FROM TIER D","Create a new club, identity and development roster."],["existing","DEVELOP AN EXISTING TEAM","Take responsibility for a real database organization."]]:
		var value:=str(spec[0]); var card:=_choice_card(str(spec[1]),str(spec[2]),"Both paths use the same competitive world and progression rules.",str(career_draft.journey_mode)==value,ACCENT if value=="story" else CYAN); card.pressed.connect(func(): career_draft.journey_mode=value; career_draft.team_mode="new" if value=="story" else "existing"; career_draft.starting_tier="D" if value=="story" else career_draft.starting_tier; _show_new_career()); paths.add_child(card)
	var path_note := _panel("STARTING CONDITIONS", PANEL); content.add_child(path_note)
	path_note.add_child(_action_row("STORY", "Tier D club", "$250K budget, low reputation and a development board objective.", GOLD))
	path_note.add_child(_action_row("EXISTING", "Database team", "Tier, roster, identity and expectations follow the selected organization.", CYAN))
	_wizard_actions(true,"TEAM SETUP")

func _career_step_team() -> void:
	var database = game.career_database()
	if str(career_draft.journey_mode) == "story":
		career_draft.team_mode = "new"; career_draft.starting_tier = "D"
		var roster_panel := _panel("FOUNDING ROSTER", PANEL_HIGH); content.add_child(roster_panel)
		var roster_modes := HBoxContainer.new(); roster_modes.add_theme_constant_override("separation", 12); roster_panel.add_child(roster_modes)
		for spec in [["generated","GENERATED ACADEMY","Game creates six Tier D players plus ten development prospects."],["custom","MANAGER-BUILT CORE","Create four named Tier D players; remaining prospects are generated."]]:
			var value := str(spec[0]); var card := _choice_card(str(spec[1]), str(spec[2]), "All attributes are capped to the Tier D point budget.", str(career_draft.roster_source) == value, GOLD); card.pressed.connect(func(): career_draft.roster_source = value; _show_new_career()); roster_modes.add_child(card)
		roster_panel.add_child(_label("Tier D roster limits: overall 48–59, potential 60–76, four required roles and no hidden elite player.", 12, MUTED))
		_wizard_actions(true,"TEAM IDENTITY")
		return
	if str(career_draft.team_id).is_empty():
		for candidate in database.teams:
			if candidate.get("roster_ids", []).size() >= 4: career_draft.team_id=str(candidate.id); career_draft.org_name=str(candidate.name); career_draft.region=str(candidate.region); break
	var teams:=GridContainer.new(); teams.columns=ResponsiveScript.columns(get_viewport_rect().size, 4, 3, 3); teams.add_theme_constant_override("h_separation",8); teams.add_theme_constant_override("v_separation",8); content.add_child(teams)
	for source in database.teams:
		var selected:=str(career_draft.team_id)==str(source.id); var ranking:Dictionary=source.get("ranking",{}); var team_card:=_choice_card(str(source.name),"%s • %s • Tier %s"%[source.region,source.country,source.tier],"POWER %d  •  ROSTER %d"%[int(ranking.get("power",50)),source.get("roster_ids",[]).size()],selected,CYAN); team_card.icon=assets.texture(str(source.get("logo_asset_id",""))); team_card.expand_icon=true; team_card.pressed.connect(func(): career_draft.team_id=str(source.id); career_draft.region=str(source.region); if str(career_draft.team_mode)=="existing": career_draft.org_name=str(source.name); _show_new_career()); teams.add_child(team_card)
		team_card.disabled = source.get("roster_ids", []).size() < 4
		if team_card.disabled: team_card.tooltip_text = "Team has fewer than four currently linked PUBG players."
	_wizard_actions(true,"TEAM IDENTITY")

func _career_step_identity() -> void:
	var database = game.career_database(); var source:Dictionary=database.get_team(str(career_draft.team_id)); var existing:=str(career_draft.team_mode)=="existing"
	var split:=HBoxContainer.new(); split.add_theme_constant_override("separation",16); content.add_child(split); var form:=_panel("TEAM IDENTITY",PANEL_HIGH); form.size_flags_horizontal=Control.SIZE_EXPAND_FILL; split.add_child(form)
	var manager_name := LineEdit.new(); manager_name.placeholder_text = "Manager / head coach name"; manager_name.text = str(career_draft.get("manager_name", "")); manager_name.text_changed.connect(func(value): career_draft.manager_name = value); form.add_child(_field("MANAGER NAME", manager_name))
	if existing:
		form.add_child(_tag("OFFICIAL DATABASE • READ ONLY",SUCCESS))
		form.add_child(_label("You are taking control of %s. Identity, history and database records remain intact."%str(source.get("name","Team")),14,TEXT))
		var ranking:Dictionary=source.get("ranking",{}); form.add_child(_action_row("TEAM","Organization",str(source.get("name","Team")),ACCENT)); form.add_child(_action_row("REGION",str(source.get("region","Unknown")),str(source.get("country","Unknown")),CYAN)); form.add_child(_action_row("LEVEL","Tier %s"%str(source.get("tier","D")),"Power %d • World #%d"%[int(ranking.get("power",50)),int(ranking.get("world",0))],GOLD)); form.add_child(_action_row("ROSTER","%d active players"%source.get("roster_ids",[]).size(),"Player identities and contracts load from GameDatabase",PURPLE))
		career_draft.org_name=str(source.get("name","Team")); career_draft.logo_asset_id=str(source.get("logo_asset_id",""))
	else:
		var name:=LineEdit.new(); name.placeholder_text="Team name"; name.text=str(career_draft.get("org_name","")); name.text_changed.connect(func(value): career_draft.org_name=value); form.add_child(_field("TEAM NAME",name))
		var short_name:=LineEdit.new(); short_name.placeholder_text="2–5 character tag"; short_name.max_length=5; short_name.text=str(career_draft.get("short_name","")); short_name.text_changed.connect(func(value): career_draft.short_name=value.to_upper()); form.add_child(_field("SHORT NAME",short_name))
		var logo_path:=LineEdit.new(); logo_path.placeholder_text="PNG / JPG / WEBP path"; form.add_child(_field("IMPORT TEAM LOGO",logo_path)); var import:=_button("VALIDATE & IMPORT LOGO",false); import.pressed.connect(func(): var asset_id:="custom.%s.logo"%str(career_draft.get("short_name","team")).to_lower(); var result:=assets.import_custom_image(logo_path.text.strip_edges(),asset_id,"teams",Vector2i(512,512),2097152); if bool(result.get("ok",false)): career_draft.logo_asset_id=asset_id; _notify("Logo imported and normalized."); _show_new_career() else: _notify(str(result.get("error","Invalid logo.")))); form.add_child(import)
		var patterns := GridContainer.new(); patterns.columns = 4; patterns.add_theme_constant_override("h_separation", 8); form.add_child(_field("OR BUILD FROM A LOGO PATTERN", patterns))
		for spec in [["shield","logo.pattern.shield"],["wing","logo.pattern.wing"],["crown","logo.pattern.crown"],["monogram","logo.pattern.monogram"]]:
			var pattern := _button(str(spec[0]).to_upper(), str(career_draft.get("logo_pattern", "shield")) == str(spec[0])); pattern.icon = assets.texture(str(spec[1])); pattern.expand_icon = true; pattern.add_theme_constant_override("icon_max_width", 44); pattern.pressed.connect(func(): career_draft.logo_pattern = str(spec[0]); career_draft.logo_asset_id = str(spec[1]); _show_new_career()); patterns.add_child(pattern)
		if str(career_draft.roster_source) == "custom":
			var custom_players: Array = career_draft.get("custom_players", [])
			while custom_players.size() < 4: custom_players.append({"name":"","handle":"","role":["IGL","Entry","Support","Fragger"][custom_players.size()]})
			career_draft.custom_players = custom_players
			var founders := _panel("FOUR FOUNDING PLAYERS", PANEL); form.add_child(founders)
			for index in 4:
				var row := HBoxContainer.new(); founders.add_child(row); var player_name := LineEdit.new(); player_name.placeholder_text = "Player %d name" % (index + 1); player_name.text = str(custom_players[index].name); player_name.text_changed.connect(func(value): career_draft.custom_players[index].name = value); row.add_child(player_name); var handle := LineEdit.new(); handle.placeholder_text = "Nickname"; handle.text = str(custom_players[index].handle); handle.text_changed.connect(func(value): career_draft.custom_players[index].handle = value); row.add_child(handle); row.add_child(_tag(str(custom_players[index].role), CYAN))
	var preview:=_panel("LIVE TEAM PREVIEW",Color("10212b")); preview.custom_minimum_size.x=380; split.add_child(preview); preview.add_child(_team_logo(str(career_draft.get("logo_asset_id",source.get("logo_asset_id",""))),str(career_draft.get("short_name",source.get("tag","TEAM"))),Vector2(128,128))); preview.add_child(_label(str(career_draft.get("org_name",source.get("name","Your Team"))),28,TEXT)); preview.add_child(_tag("%s • %s TIER"%[str(career_draft.region),str(career_draft.starting_tier)],GOLD)); preview.add_child(_label("%s organization"%("Career override" if str(career_draft.team_mode)=="replace" else "New" if str(career_draft.team_mode)=="new" else "Official"),12,MUTED))
	_wizard_actions(true,"REVIEW CAREER")

func _career_step_review() -> void:
	var database = game.career_database(); var source:Dictionary=database.get_team(str(career_draft.team_id)); var team_name:=str(source.get("name","Team")) if str(career_draft.team_mode)=="existing" else str(career_draft.get("org_name","Custom Team"))
	var hero:=_panel("TEAM PREVIEW",Color("10212b")); content.add_child(hero); hero.add_child(_team_logo(str(career_draft.get("logo_asset_id",source.get("logo_asset_id",""))),str(career_draft.get("short_name",source.get("tag","TEAM"))),Vector2(120,120))); hero.add_child(_label(team_name,34,TEXT)); hero.add_child(_tag("%s • %s TIER"%[str(career_draft.region),str(career_draft.starting_tier)],GOLD))
	var details:=GridContainer.new(); details.columns=4; hero.add_child(details); details.add_child(_visual_stat("SAVE",career_draft.slot_id,CYAN,"Independent career")); details.add_child(_visual_stat("MANAGER",str(career_draft.get("manager_name","Not entered")),TEXT,"Head coach identity")); details.add_child(_visual_stat("DIFFICULTY",career_draft.difficulty,GOLD,"Board pressure")); details.add_child(_visual_stat("PATH",str(career_draft.journey_mode).to_upper(),PURPLE,"Career progression"))
	var start:=_button("START CAREER",true); start.disabled = str(career_draft.get("manager_name", "")).strip_edges().length() < 2 or team_name.strip_edges().length() < 2; start.tooltip_text = "Enter a manager name and valid team identity." if start.disabled else "Create the career and enter Command Center"; start.pressed.connect(func(): var options:=career_draft.duplicate(true); game.new_career(team_name,str(career_draft.manager_name),str(career_draft.region),options); if str(career_draft.team_mode)!="existing": game.set_custom_team_identity(team_name,str(career_draft.get("short_name","TEAM")),str(career_draft.get("logo_asset_id",""))); career_step=1; _enter_game()); content.add_child(start)
	_wizard_actions(true,"")

func _wizard_actions(show_back:bool,next_label:String)->void:
	var actions:=HBoxContainer.new(); actions.add_theme_constant_override("separation",8); content.add_child(actions)
	if show_back:
		var back:=_button("BACK",false); back.pressed.connect(func(): career_step=maxi(1,career_step-1); _show_new_career()); actions.add_child(back)
	else:
		var cancel:=_button("CANCEL",false); cancel.pressed.connect(func(): career_step=1; _show_start_screen(game.most_recent_slot()>0)); actions.add_child(cancel)
	var fill:=Control.new(); fill.size_flags_horizontal=Control.SIZE_EXPAND_FILL; actions.add_child(fill)
	if not next_label.is_empty():
		var next:=_button(next_label,true); next.pressed.connect(func(): career_step=mini(5,career_step+1); _show_new_career()); actions.add_child(next)

func _choice_card(title:String,subtitle:String,note:String,selected:bool,color:Color)->Button:
	var card:=_button(("SELECTED\n" if selected else "")+title,false); card.alignment=HORIZONTAL_ALIGNMENT_LEFT; card.text+="\n"+subtitle+"\n"+note; card.custom_minimum_size=Vector2(250,112); card.size_flags_horizontal=Control.SIZE_EXPAND_FILL; card.add_theme_font_size_override("font_size",12); card.add_theme_color_override("font_color",TEXT if selected else MUTED); card.add_theme_stylebox_override("normal",_style(Color("122330") if selected else PANEL,RADIUS_MD,Color(color,0.95 if selected else 0.35),2 if selected else 1)); card.add_theme_stylebox_override("hover",_style(Color("172d3b"),RADIUS_MD,color,1)); return card

func _show_custom_content() -> void:
	_clear(sidebar); _clear(topbar); _clear(content); _set_precareer_layout(true)
	_header("Community content", "Install secure packages without modifying the official database.", "CONTENT LIBRARY")
	_precareer_back()
	var split:=HBoxContainer.new(); split.add_theme_constant_override("separation",16); content.add_child(split)
	var import_panel:=_panel("IMPORT CONTENT",PANEL_HIGH); import_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL; split.add_child(import_panel)
	var drop:=_panel("",Color("0b1720")); drop.custom_minimum_size.y=160; import_panel.add_child(drop)
	var drop_title:=_label("BRM PACKAGE",22,TEXT); drop_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; drop.add_child(drop_title)
	var drop_copy:=_label("Drop a .brm package here or browse your computer",13,MUTED); drop_copy.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; drop.add_child(drop_copy)
	var supported:=_tag("SUPPORTED • .BRM",CYAN); supported.size_flags_horizontal=Control.SIZE_SHRINK_CENTER; drop.add_child(supported)
	var path:=LineEdit.new(); path.placeholder_text="Package path"; path.custom_minimum_size.y=44; import_panel.add_child(path)
	var browse:=_button("BROWSE FILE",false); browse.pressed.connect(func(): var dialog:=FileDialog.new(); dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE; dialog.access=FileDialog.ACCESS_FILESYSTEM; dialog.add_filter("*.brm","Battle Royale Manager Package"); dialog.file_selected.connect(func(selected_path): path.text=selected_path); dialog.canceled.connect(dialog.queue_free); dialog.file_selected.connect(func(_selected_path): dialog.queue_free()); add_child(dialog); dialog.popup_centered_ratio(0.72)); import_panel.add_child(browse)
	var report:=_label("Validation checks archive paths, schema, references, assets and package version.",12,MUTED); report.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; import_panel.add_child(report)
	var import_button:=_button("VALIDATE & IMPORT",true); import_button.pressed.connect(func(): var result:=content_manager.import_package(path.text.strip_edges()); report.text="✓ Installed %s • v%s"%[result.get("package_id",""),result.get("version","")] if bool(result.get("ok",false)) else "Import blocked • %s"%"; ".join(result.get("errors",[result.get("error","Unknown error")])); report.add_theme_color_override("font_color",SUCCESS if bool(result.get("ok",false)) else DANGER); if bool(result.get("ok",false)): _show_custom_content()); import_panel.add_child(import_button)
	var safety:=_panel("PACKAGE SAFETY",PANEL); safety.custom_minimum_size.x=380; split.add_child(safety)
	safety.add_child(_action_row("01","Official database protected","Installs to an isolated content library",SUCCESS)); safety.add_child(_action_row("02","Data + assets only","Executables and scripts are rejected",SUCCESS)); safety.add_child(_action_row("03","Transactional install","Failures roll back cleanly",SUCCESS)); safety.add_child(_action_row("04","Career content lock","Updates cannot silently mutate a career",CYAN))
	var packages:=content_manager.list_packages(); var library_header:=HBoxContainer.new(); content.add_child(library_header); library_header.add_child(_label("Installed packages",20,TEXT)); var fill:=Control.new(); fill.size_flags_horizontal=Control.SIZE_EXPAND_FILL; library_header.add_child(fill); library_header.add_child(_tag("%d INSTALLED"%packages.size(),ACCENT))
	var package_grid:=GridContainer.new(); package_grid.columns=ResponsiveScript.columns(get_viewport_rect().size, 3, 2, 2); package_grid.add_theme_constant_override("h_separation",10); package_grid.add_theme_constant_override("v_separation",10); content.add_child(package_grid)
	for package in packages:
		var card:=_panel("",PANEL); card.custom_minimum_size=Vector2(360,170); card.add_child(_tag("INSTALLED",SUCCESS)); card.add_child(_label("%s • v%s"%[package.get("name","Package"),package.get("version","0")],20,TEXT)); card.add_child(_label("%s • %s"%[package.get("author","Unknown"),package.get("package_id","")],11,CYAN)); card.add_child(_label(str(package.get("description","No description")),12,MUTED)); var counts:Dictionary=package.get("content",{}); card.add_child(_label("%d teams • %d players • %d maps • %d tournaments"%[int(counts.get("teams",0)),int(counts.get("players",0)),int(counts.get("maps",0)),int(counts.get("tournaments",0))],11,MUTED)); var export:=_button("EXPORT .BRM",false); export.pressed.connect(func(): var export_dir:="user://custom_content_exports"; DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(export_dir)); var destination:="%s/%s-%s-%d.brm"%[export_dir,str(package.get("package_id","package")),str(package.get("version","0")),Time.get_unix_time_from_system()]; var result:=content_manager.export_package(str(package.get("package_id","")),destination); _notify("Exported: %s"%ProjectSettings.globalize_path(destination) if bool(result.get("ok",false)) else str(result.get("error","Export failed.")))); card.add_child(export); package_grid.add_child(card)
	if packages.is_empty(): package_grid.add_child(_empty_state("NO PACKAGES INSTALLED","Import a validated .brm package to add teams, players, tournaments and maps."))
	var back:=_button("BACK",false); back.pressed.connect(_show_start_screen.bind(game.most_recent_slot()>0)); content.add_child(back)

func _show_start_settings() -> void:
	_clear(sidebar); _clear(topbar); _clear(content); _set_precareer_layout(true); _header("SETTINGS", "Audio, display, accessibility and local game preferences")
	_precareer_back()
	_build_settings_controls(false)

func _precareer_back() -> void:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); content.add_child(row)
	var back := _button("BACK TO MAIN MENU", false); back.icon = _small_icon("icons.navigation.back"); back.pressed.connect(_show_start_screen.bind(game.most_recent_slot() > 0)); row.add_child(back)

func _go_back() -> void:
	var previous := router.go_back()
	_show_page(str(previous.get("id", "dashboard")))

func _build_settings_controls(in_career: bool) -> void:
	var layout := GridContainer.new(); layout.columns = ResponsiveScript.columns(get_viewport_rect().size, 2, 2, 1); layout.add_theme_constant_override("h_separation", 16); layout.add_theme_constant_override("v_separation", 16); content.add_child(layout)
	var audio := _panel("AUDIO", PANEL_HIGH); audio.size_flags_horizontal=Control.SIZE_EXPAND_FILL; audio.custom_minimum_size.x=480; layout.add_child(audio)
	_settings_slider(audio, "MASTER VOLUME", "master_volume")
	_settings_slider(audio, "MUSIC VOLUME", "music_volume")
	_settings_slider(audio, "SFX VOLUME", "sfx_volume")
	var display := _panel("DISPLAY", PANEL_HIGH); display.size_flags_horizontal=Control.SIZE_EXPAND_FILL; display.custom_minimum_size.x=480; layout.add_child(display)
	var mode := OptionButton.new(); mode.custom_minimum_size.y = 42
	for value in ["WINDOWED", "FULLSCREEN", "BORDERLESS"]: mode.add_item(value); mode.set_item_metadata(mode.item_count - 1, value)
	for index in mode.item_count:
		if str(mode.get_item_metadata(index)) == str(user_settings.values.get("display_mode", "BORDERLESS")): mode.select(index); break
	mode.item_selected.connect(func(index): user_settings.set_value("display_mode", str(mode.get_item_metadata(index)), get_window()))
	display.add_child(_field("WINDOW MODE", mode))
	var resolution := OptionButton.new(); resolution.custom_minimum_size.y = 42
	for size in UserSettingsScript.RESOLUTIONS:
		var value := "%dx%d" % [size.x, size.y]; resolution.add_item(value); resolution.set_item_metadata(resolution.item_count - 1, value)
	for index in resolution.item_count:
		if str(resolution.get_item_metadata(index)) == str(user_settings.values.get("resolution", "1920x1080")): resolution.select(index); break
	resolution.item_selected.connect(func(index): user_settings.set_value("resolution", str(resolution.get_item_metadata(index)), get_window()))
	display.add_child(_field("WINDOWED RESOLUTION", resolution))
	var vsync := CheckButton.new(); vsync.text = "VERTICAL SYNC"; vsync.button_pressed = bool(user_settings.values.get("vsync", true)); vsync.toggled.connect(func(value): user_settings.set_value("vsync", value, get_window())); display.add_child(vsync)
	var accessibility := _panel("INTERFACE & ACCESSIBILITY", PANEL); accessibility.size_flags_horizontal=Control.SIZE_EXPAND_FILL; accessibility.custom_minimum_size.x=480; layout.add_child(accessibility)
	_settings_slider(accessibility, "UI SCALE", "ui_scale", 80, 130)
	for spec in [["reduce_motion", "REDUCE MOTION"], ["high_contrast", "HIGH CONTRAST"], ["autosave", "AUTOSAVE"]]:
		var toggle := CheckButton.new(); toggle.text = str(spec[1]); toggle.button_pressed = bool(user_settings.values.get(spec[0], false)); toggle.toggled.connect(func(value): user_settings.set_value(str(spec[0]), value, get_window())); accessibility.add_child(toggle)
	var gameplay := _panel("GAMEPLAY", PANEL); gameplay.size_flags_horizontal=Control.SIZE_EXPAND_FILL; gameplay.custom_minimum_size.x=480; layout.add_child(gameplay)
	if in_career:
		var difficulty := OptionButton.new(); difficulty.custom_minimum_size.y = 42
		for value in ["Casual", "Normal", "Hard", "Director"]: difficulty.add_item(value); difficulty.set_item_metadata(difficulty.item_count - 1, value)
		for index in difficulty.item_count:
			if str(difficulty.get_item_metadata(index)) == str(game.data.get("difficulty", "Normal")): difficulty.select(index); break
		difficulty.item_selected.connect(func(index): game.set_difficulty(str(difficulty.get_item_metadata(index))); _notify("Difficulty updated."))
		gameplay.add_child(_field("CAREER DIFFICULTY", difficulty))
		var custom_rules := _button("OPEN CUSTOM RULES", false); custom_rules.icon = _small_icon("icons.navigation.settings"); custom_rules.pressed.connect(_show_page.bind("developer")); gameplay.add_child(custom_rules)
		gameplay.add_child(_label("Custom Rules contains drop/loot density, zone damage, AI aggression, vehicle density and the map drop-zone editor. Enabling it marks the career as modified.", 11, MUTED))
	else:
		gameplay.add_child(_label("Career difficulty is selected when a career is created and can be changed later from this page inside the career.", 12, MUTED))
	var reset := _button("RESET SETTINGS", false); reset.pressed.connect(func(): user_settings.reset(get_window()); _show_page("settings") if in_career else _show_start_settings()); gameplay.add_child(reset)

func _settings_slider(parent: Container, label_text: String, key: String, minimum := 0, maximum := 100) -> void:
	var row := VBoxContainer.new(); row.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_theme_constant_override("separation", 4); parent.add_child(row)
	var readout := _label("%s  %d%%" % [label_text, int(user_settings.values.get(key, 100))], 11, TEXT); row.add_child(readout)
	var slider := HSlider.new(); slider.min_value = minimum; slider.max_value = maximum; slider.step = 1; slider.value = float(user_settings.values.get(key, 100)); slider.custom_minimum_size.y = 30
	slider.value_changed.connect(func(value): readout.text = "%s  %d%%" % [label_text, roundi(value)]; user_settings.set_value(key, roundi(value), get_window()))
	row.add_child(slider)

func _field(label_text: String, control: Control) -> VBoxContainer:
	var wrapper := VBoxContainer.new(); wrapper.add_theme_constant_override("separation", 5); wrapper.add_child(_label(label_text, 10, MUTED)); wrapper.add_child(control); return wrapper

func _enter_game() -> void:
	_set_precareer_layout(false)
	_build_sidebar()
	_show_page("dashboard")

func _build_sidebar() -> void:
	_clear(sidebar); nav_buttons.clear()
	var identity := HBoxContainer.new(); identity.add_theme_constant_override("separation", 9); sidebar.add_child(identity)
	var crest := _team_logo(str(game.data.get("org_logo_asset_id", "")), str(game.data.get("org_name", "MR")).left(2).to_upper(), Vector2(52, 52))
	crest.tooltip_text = "%s | %s" % [str(game.data.get("org_name", "Club")), str(game.data.get("region", "SEA"))]
	identity.add_child(crest)
	var club_copy := VBoxContainer.new(); club_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL; identity.add_child(club_copy)
	club_copy.add_child(_label(str(game.data.get("org_name", "CLUB")).to_upper(), 15, TEXT))
	club_copy.add_child(_label("SEASON %d  •  WEEK %d" % [int(game.data.get("season", 1)), int(game.data.get("week", 1))], 10, MUTED))
	club_copy.add_child(_label("WORLD RANK  #%d" % _player_world_rank(), 11, ACCENT))
	sidebar.add_child(HSeparator.new())
	var context_row := HBoxContainer.new(); context_row.add_theme_constant_override("separation", 4); sidebar.add_child(context_row)
	var club_context := _button("CLUB", str(game.data.get("management_context", "CLUB")) == "CLUB"); club_context.pressed.connect(func(): game.set_management_context("CLUB"); _build_sidebar(); _show_page("dashboard")); context_row.add_child(club_context)
	var national_context := _button("NATIONAL", str(game.data.get("management_context", "CLUB")) == "NATIONAL"); national_context.pressed.connect(func(): if str(game.data.get("national_team_id", "")).is_empty(): _show_page("national_team") else: game.set_management_context("NATIONAL"); _build_sidebar(); _show_page("national_team")); context_row.add_child(national_context)
	var nav_scroll := ScrollContainer.new(); nav_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; nav_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; nav_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO; sidebar.add_child(nav_scroll)
	var nav_list := VBoxContainer.new(); nav_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; nav_list.add_theme_constant_override("separation", 3); nav_scroll.add_child(nav_list)
	var pages := [
		["GROUP", "COMMAND"], ["dashboard", "COMMAND CENTER", "icons.navigation.home"],
		["GROUP", "TEAM"], ["roster", "SQUAD & LINEUP", "icons.navigation.roster"], ["contracts", "PLAYER CONTRACTS", "icons.navigation.inbox"], ["training", "TRAINING", "icons.replay.rotation"], ["tactics", "TACTICS", "icons.navigation.tactics"],
		["GROUP", "PLAYERS & SCOUTING"], ["scouting", "PLAYER DISCOVERY", "icons.navigation.scout"], ["transfers", "TRANSFER MARKET", "icons.status.reputation"], ["analytics", "TEAM ANALYSIS", "icons.status.reputation"], ["player_stats", "PLAYER STATS", "icons.navigation.roster"],
		["GROUP", "MATCHES & EVENTS"], ["match", "MATCH CENTER", "icons.navigation.match"], ["calendar", "SCHEDULE", "icons.replay.rotation"], ["tournament", "TOURNAMENTS", "icons.navigation.match"], ["rankings", "WORLD RANKING", "icons.status.reputation"],
		["GROUP", "ORGANIZATION"], ["facilities", "PERFORMANCE CAMPUS", "icons.navigation.facilities"], ["finance", "FINANCE & PARTNERS", "icons.status.fans"], ["national_team", "NATIONAL TEAM", "icons.status.reputation"],
		["GROUP", "CAREER"], ["trophies", "CAREER HISTORY", "icons.status.fans"],
		["GROUP", "SYSTEM"], ["inbox", "INBOX", "icons.navigation.inbox"], ["media", "WORLD FEED", "icons.status.fans"], ["settings", "SETTINGS & PROFILE", "icons.navigation.settings"]]
	pages.append(["developer", "CUSTOM RULES", "icons.navigation.settings"])
	for item in pages:
		if item[0] == "GROUP":
			var group := _label(str(item[1]), 9, MUTED); group.custom_minimum_size.y = 20; group.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM; nav_list.add_child(group); continue
		var btn := _button(str(item[1]), false)
		btn.custom_minimum_size = Vector2(180, 34)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.icon = _small_icon(str(item[2]))
		btn.tooltip_text = str(item[1])
		btn.pressed.connect(_show_page.bind(item[0]))
		nav_list.add_child(btn); nav_buttons[item[0]] = btn
	var save := _button("SAVE  •  SETTINGS  •  PROFILE", false); save.tooltip_text = "Save career and open settings/profile"; save.alignment = HORIZONTAL_ALIGNMENT_LEFT; save.icon = _small_icon("icons.navigation.save"); save.pressed.connect(func(): game.save_game(); _show_page("settings")); sidebar.add_child(save)

func _refresh_topbar() -> void:
	_clear(topbar)
	var compact: bool = ResponsiveScript.is_compact(get_viewport_rect().size)
	var pad := Control.new(); pad.custom_minimum_size.x = 10 if compact else 20; topbar.add_child(pad)
	if active_page != "dashboard" and not router.history.is_empty():
		var back := _button("BACK", false); back.icon = _small_icon("icons.navigation.back"); back.tooltip_text = "Return to the previous screen"; back.pressed.connect(_go_back); topbar.add_child(back)
	if not compact:
		var club_mark := _team_logo(str(game.data.get("org_logo_asset_id", "")), str(game.data.get("org_name", "MR")).left(2).to_upper(), Vector2(32, 32)); club_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER; topbar.add_child(club_mark)
	var page_name: String = str(router.descriptor(active_page).get("title", active_page.to_upper()))
	var page_label := _label(page_name, 14 if compact else 16, TEXT); page_label.custom_minimum_size.x = 118 if compact else 190; page_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; page_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER; topbar.add_child(page_label)
	var day_number := maxi(1, int((Time.get_unix_time_from_datetime_string(str(game.data.current_date) + "T00:00:00") - Time.get_unix_time_from_datetime_string("2026-01-01T00:00:00")) / 86400.0) + 1)
	var season_copy := "D%d • W%d" % [day_number, game.data.week] if compact else "SEASON %d  ·  DAY %d  ·  WEEK %d" % [game.data.season, day_number, game.data.week]
	var season_tag := _label(season_copy, 11, CYAN); season_tag.custom_minimum_size.x=72 if compact else 190; season_tag.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; topbar.add_child(season_tag)
	var fill := Control.new(); fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL; topbar.add_child(fill)
	topbar.add_child(_top_metric("FUNDS", "$%s" % GameStateScript.money(int(game.data.budget)), GOLD))
	if not compact: topbar.add_child(_top_metric("SUPPORT", "%s FANS" % GameStateScript.money(int(game.data.fans)), CYAN))
	topbar.add_child(_top_metric("SQUAD", "%d ENERGY" % _average("energy"), _metric_color(_average("energy"))))
	if not compact: topbar.add_child(_top_metric("MOMENTUM", "%d MORALE" % _average("happiness"), _metric_color(_average("happiness"))))
	var next_event: Dictionary = game.get_next_match(true)
	if not compact: topbar.add_child(_top_metric("NEXT EVENT", str(next_event.get("tournament", next_event.get("round", "REST DAY"))).to_upper(), ORANGE))
	var critical := _critical_alert_count()
	var unread: int = game.data.get("inbox", []).filter(func(item): return not bool(item.get("read", false))).size()
	var inbox_button := _button("INBOX  %d" % unread, false); inbox_button.icon = _small_icon("icons.navigation.inbox"); inbox_button.tooltip_text = "%d unread messages" % unread; inbox_button.pressed.connect(_show_page.bind("inbox")); topbar.add_child(inbox_button)
	var next_label := ("NEXT  !%d" % critical) if compact and critical > 0 else "NEXT  →" if compact else ("NEXT DAY  !%d" % critical) if critical > 0 else "NEXT DAY  →"
	var next := _button(next_label, true); next.custom_minimum_size.x = 88 if compact else 148; next.tooltip_text = "Advance one game day; stops for required events."; next.size_flags_vertical = Control.SIZE_SHRINK_CENTER; next.pressed.connect(_advance_day); topbar.add_child(next)
	var end := Control.new(); end.custom_minimum_size.x = 8 if compact else 18; topbar.add_child(end)

func _show_page(page: String) -> void:
	if page == "facility_detail": campus_detail_open = true
	var route := router.navigate(page)
	active_page = str(route.id); _refresh_topbar(); _clear(content); _update_nav()
	match active_page:
		"dashboard": _dashboard()
		"calendar": _calendar_page()
		"tournament": _competition_center()
		"competition_detail": _competition_detail()
		"finance": _finance_hub()
		"roster": _roster()
		"player_detail": _player_detail()
		"scouting": _scouting()
		"transfers": _transfers_page()
		"contracts": _contracts_page()
		"training": _training_page()
		"tactics": _tactics()
		"match": _match_page()
		"match_lab": _match_gameplay_lab()
		"map_manager": _map_manager_page()
		"rankings": _rankings()
		"team_profile": _team_profile()
		"national_team": _national_team_page()
		"facilities": _performance_campus()
		"inbox": _inbox()
		"analytics": _analytics_page()
		"player_stats": _player_stats_page()
		"media": _media_page()
		"developer": _developer_page()
		"trophies": _trophy_room()
		"settings": _settings_page()
	_animate_page()

func _dashboard() -> void:
	var team_overview: Dictionary = GamePresenterScript.team_overview(game.data,game.get_team_power())
	var compact := ResponsiveScript.is_compact(get_viewport_rect().size)
	var season_transition: Dictionary = game.data.get("season_transition", {})
	if not season_transition.is_empty() and str(season_transition.get("status", "AVAILABLE")) == "AVAILABLE":
		_season_summary(season_transition, compact)
	var top: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new(); top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN; top.add_theme_constant_override("separation", 16); content.add_child(top)
	var hero_slot := VBoxContainer.new(); hero_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(hero_slot)
	var hero_top_offset := Control.new(); hero_top_offset.custom_minimum_size.y = 10; hero_slot.add_child(hero_top_offset)
	var next := _panel("UPCOMING MATCH", Color("081119")); next.size_flags_vertical = Control.SIZE_SHRINK_BEGIN; next.custom_minimum_size = Vector2(0 if compact else 760, 420); hero_slot.add_child(next)
	var event := game.get_next_match(true)
	var career_priorities: Array = CareerPriorityPresenterScript.build(game.data, event)
	if event.is_empty(): next.add_child(_label("SEASON COMPLETE", 22, TEXT))
	else:
		var title_line := HBoxContainer.new(); title_line.add_theme_constant_override("separation", 13); next.add_child(title_line)
		var crest := TournamentEmblemScript.new(); crest.custom_minimum_size = Vector2(56, 56); title_line.add_child(crest)
		var event_copy := VBoxContainer.new(); event_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL; title_line.add_child(event_copy)
		event_copy.add_child(_label(str(event.tournament).to_upper(), 25, TEXT))
		var round_number := str(event.round).replace("MATCHDAY", "").replace("Matchday", "").strip_edges()
		event_copy.add_child(_label("MATCHDAY %s  •  %s  •  %s" % [round_number, str(event.date), str(event.map).to_upper()], 12, MUTED))
		next.add_child(HSeparator.new())
		var prediction := clampi(roundi(game.get_team_power() - 52.0), 8, 78)
		var match_readout := HBoxContainer.new(); match_readout.add_theme_constant_override("separation", 12); match_readout.custom_minimum_size.y = 172; next.add_child(match_readout)
		match_readout.add_child(_dashboard_probability(prediction))
		var own := VBoxContainer.new(); own.alignment = BoxContainer.ALIGNMENT_CENTER; own.custom_minimum_size.x = 156; match_readout.add_child(own)
		own.add_child(_team_logo(str(game.data.get("org_logo_asset_id", "")), str(game.data.org_name).left(2).to_upper(), Vector2(106, 86)))
		var org_name := _label(str(game.data.org_name).to_upper(), 16, TEXT); org_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; own.add_child(org_name)
		match_readout.add_child(VSeparator.new())
		match_readout.add_child(_dashboard_stat("icons.navigation.roster", "%d" % int(event.get("teams", 16)), "TEAMS", CYAN))
		match_readout.add_child(VSeparator.new())
		match_readout.add_child(_dashboard_stat("icons.navigation.match", "PTS", "PLACE + KILLS", GOLD))
		match_readout.add_child(VSeparator.new())
		match_readout.add_child(_dashboard_stat("symbol.location", str(event.get("map", "—")).to_upper(), "MAP", TEXT))
		match_readout.add_child(VSeparator.new())
		var readiness := int(team_overview.energy)
		match_readout.add_child(_dashboard_stat("icons.status.energy", "%d%%" % readiness, "READY", _metric_color(readiness)))
		var command_gap := Control.new(); command_gap.size_flags_vertical = Control.SIZE_EXPAND_FILL; next.add_child(command_gap)
		next.add_child(HSeparator.new())
		var command_row := HBoxContainer.new(); command_row.add_theme_constant_override("separation", 16); command_row.custom_minimum_size.y = 56; next.add_child(command_row)
		command_row.add_child(_dashboard_signal("symbol.warning", "RISK", "STARTER RECOVERY", GOLD))
		command_row.add_child(VSeparator.new())
		command_row.add_child(_dashboard_signal("symbol.tactics", "PLAN", "REVIEW FINAL PLAN", ACCENT))
		var command_spacer := Control.new(); command_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; command_row.add_child(command_spacer)
		var go := _button("PREPARE FOR MATCH  →", true); go.custom_minimum_size = Vector2(310, 46); go.pressed.connect(_show_page.bind("match")); command_row.add_child(go)
	var right_column := VBoxContainer.new(); right_column.custom_minimum_size.x = 0 if compact else 390; right_column.add_theme_constant_override("separation", 16); top.add_child(right_column)
	var contract_risk: int = game.data.get("roster", []).filter(func(player): return int(player.get("contract", 99)) <= 6).size()
	var low_energy: int = game.data.get("roster", []).filter(func(player): return int(player.get("energy", 100)) < 60).size()
	var objectives := _panel("ACTION REQUIRED  •  TODAY", Color("091119")); objectives.custom_minimum_size.y = 176; right_column.add_child(objectives)
	for index in mini(3, career_priorities.size()):
		var priority: Dictionary = career_priorities[index]; var route := str(priority.get("target_route","dashboard")); var icon := "icons.navigation.inbox" if route=="inbox" else "icons.navigation.match" if route=="match" else "icons.status.energy" if route=="roster" else "icons.navigation.tactics"; objectives.add_child(_dashboard_objective("%02d" % (index+1), str(priority.get("title","MANAGEMENT ACTION")), str(priority.get("action","OPEN")), icon, route))
	var tasks := _panel("RECENT CONSEQUENCES", PANEL_HIGH); tasks.custom_minimum_size.y = 205; right_column.add_child(tasks)
	var progression: Array = game.progression_summary(3)
	if progression.is_empty(): tasks.add_child(_action_row("NEW", "Career initialized", "No management consequence has been processed yet.", CYAN))
	for item in progression: tasks.add_child(_action_row(str(item.get("type","event")).left(8).to_upper(), str(item.get("title","Career update")), str(item.get("detail","")), CYAN))
	var inbox_action := _button("OPEN INBOX  →", false); inbox_action.pressed.connect(_show_page.bind("inbox")); right_column.add_child(inbox_action)
	var status := _panel("TEAM CONDITION", Color("091118")); status.size_flags_vertical = Control.SIZE_SHRINK_BEGIN; content.add_child(status)
	var vitals := HBoxContainer.new(); vitals.add_theme_constant_override("separation", 14); vitals.custom_minimum_size.y = 67; status.add_child(vitals)
	vitals.add_child(_dashboard_vital("icons.status.energy", str(team_overview.power), "POWER", CYAN, float(team_overview.power)))
	vitals.add_child(VSeparator.new())
	vitals.add_child(_dashboard_vital("symbol.trophy", "#%d" % _player_world_rank(), "RANK", CYAN, 72))
	vitals.add_child(VSeparator.new())
	vitals.add_child(_dashboard_vital("symbol.flame", str(team_overview.form), "FORM", GOLD, float(team_overview.form)))
	vitals.add_child(VSeparator.new())
	vitals.add_child(_dashboard_vital("icons.status.energy", "%d%%" % int(team_overview.energy), "ENERGY", _metric_color(int(team_overview.energy)), float(team_overview.energy)))
	var briefing := _panel("TODAY", PANEL_HIGH); content.add_child(briefing)
	var briefing_row := HBoxContainer.new(); briefing_row.add_theme_constant_override("separation", 18); briefing.add_child(briefing_row)
	var priorities := VBoxContainer.new(); priorities.size_flags_horizontal = Control.SIZE_EXPAND_FILL; briefing_row.add_child(priorities)
	priorities.add_child(_label("TODAY'S PRIORITIES", 11, CYAN))
	for index in mini(3, career_priorities.size()): priorities.add_child(_label("%d. %s" % [index+1, str(career_priorities[index].get("title","Management action")).capitalize()], 13 if index==0 else 12, TEXT if index==0 else MUTED))
	var condition := VBoxContainer.new(); condition.size_flags_horizontal = Control.SIZE_EXPAND_FILL; briefing_row.add_child(condition)
	condition.add_child(_label("TEAM CONDITION", 11, CYAN))
	condition.add_child(_label("FORM  %d     MORALE  %d%%     FATIGUE  %s" % [_average("form"), _average("happiness"), "MEDIUM" if _average("energy") < 75 else "LOW"], 13, _metric_color(_average("energy"))))
	condition.add_child(_label("NEXT MATCH  •  %s" % (str(event.get("date", "No match scheduled")) if not event.is_empty() else "No active event"), 11, MUTED))
	var briefing_actions := VBoxContainer.new(); briefing_actions.custom_minimum_size.x = 210; briefing_row.add_child(briefing_actions)
	var lineup := _button("SET LINEUP  →", false); lineup.pressed.connect(_show_page.bind("roster")); briefing_actions.add_child(lineup)
	var review_tactics := _button("REVIEW TACTICS  →", true); review_tactics.pressed.connect(_show_page.bind("tactics")); briefing_actions.add_child(review_tactics)
	var world := HBoxContainer.new(); world.size_flags_vertical = Control.SIZE_SHRINK_BEGIN; world.add_theme_constant_override("separation", 16); content.add_child(world)
	var rankings := _panel("WORLD RANKING", PANEL); rankings.size_flags_horizontal = Control.SIZE_EXPAND_FILL; world.add_child(rankings)
	for row in _ranking_rows().slice(0, 4): rankings.add_child(_dashboard_leaderboard_row(row))
	var ranking_footer := _button("VIEW FULL RANKING  →", false); ranking_footer.pressed.connect(_show_page.bind("rankings")); rankings.add_child(ranking_footer)
	var pulse := _panel("WORLD FEED", PANEL); pulse.size_flags_horizontal = Control.SIZE_EXPAND_FILL; world.add_child(pulse)
	pulse.add_child(_pulse_row("TRANSFER", str(game.data.market[0].name), "MARKET", DANGER, "transfer"))
	var pulse_event: Dictionary = game.get_next_match(true)
	var pulse_name := str(pulse_event.get("tournament", "Tournament schedule"))
	var pulse_teams := int(pulse_event.get("teams", game.data.teams.size() + 1))
	var pulse_round := str(pulse_event.get("round", "")).replace("MATCHDAY", "").replace("Matchday", "").strip_edges()
	pulse.add_child(_pulse_row("TOURNAMENT", pulse_name, "MATCHDAY %s" % pulse_round, GOLD, "tournament"))
	pulse.add_child(_pulse_row("TACTICS", "MATCH PLAN", str(game.data.get("coach_plan",{}).get("drop_policy","UNAVAILABLE")).replace("_"," "), CYAN, "tactics"))
	var feed_footer := _button("VIEW ALL NEWS  →", false); feed_footer.pressed.connect(_show_page.bind("media")); pulse.add_child(feed_footer)

func _season_summary(summary: Dictionary, compact: bool) -> void:
	var panel := _panel("SEASON %d COMPLETE" % int(summary.get("season", 0)), Color("17130b")); panel.add_theme_stylebox_override("panel", _style(Color("17130b"), 3, GOLD, 1)); content.add_child(panel)
	var layout: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new(); layout.add_theme_constant_override("separation", 18); panel.add_child(layout)
	var copy := VBoxContainer.new(); copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL; layout.add_child(copy)
	copy.add_child(_label("SEASON %d IS FINISHED" % int(summary.get("season", 0)), 26, GOLD))
	copy.add_child(_label("Season %d begins with your organization, roster, contracts and facilities preserved." % int(game.data.get("season", 1)), 12, TEXT))
	var metrics := HBoxContainer.new(); metrics.add_theme_constant_override("separation", 16); copy.add_child(metrics)
	metrics.add_child(_visual_stat("WORLD RANK", "#%s" % (str(summary.get("world_rank")) if int(summary.get("world_rank", 0)) > 0 else "—"), CYAN, "Final power ranking"))
	metrics.add_child(_visual_stat("MATCHES", int(summary.get("matches", 0)), TEXT, "Completed"))
	metrics.add_child(_visual_stat("BEST", "#%s" % (str(summary.get("best_placement")) if int(summary.get("best_placement", 0)) > 0 else "—"), GOLD, "%d points" % int(summary.get("points", 0))))
	metrics.add_child(_visual_stat("FINANCE", ("+" if int(summary.get("financial_result", 0)) >= 0 else "−") + "$%s" % GameStateScript.money(absi(int(summary.get("financial_result", 0)))), SUCCESS if int(summary.get("financial_result", 0)) >= 0 else DANGER, "$%s renewal" % GameStateScript.money(int(summary.get("renewal_income", 0)))))
	var actions := VBoxContainer.new(); actions.custom_minimum_size.x = 220; layout.add_child(actions)
	var history := _button("VIEW CAREER HISTORY", false); history.pressed.connect(_show_page.bind("trophies")); actions.add_child(history)
	var continue_button := _button("BEGIN SEASON %d  →" % int(game.data.get("season", 1)), true); continue_button.pressed.connect(func(): game.acknowledge_season_transition(); _show_page("dashboard")); actions.add_child(continue_button)

func _roster() -> void:
	selected_profile_player.clear()
	var starters := mini(4, game.data.roster.size())
	var substitutes := maxi(0, game.data.roster.size() - starters)
	var available: int = game.data.roster.filter(func(p): return int(p.get("energy", 0)) >= 50).size()
	var total_ovr := 0
	for player in game.data.roster: total_ovr += int(player.get("overall", 0))
	var average_ovr := total_ovr / maxi(1, game.data.roster.size())
	_header("SQUAD & LINEUP", "MAIN ROSTER  %d / 4     SUBSTITUTES  %d / 3     AVAILABLE  %d     AVERAGE OVR  %d     TEAM CHEMISTRY  %d" % [starters, substitutes, available, average_ovr, int(game.data.get("chemistry",0))], "ACTIVE SQUAD")
	var filters := HBoxContainer.new(); filters.add_theme_constant_override("separation", 8); content.add_child(filters)
	for filter_name in ["ALL", "MAIN ROSTER", "SUBSTITUTES", "LOW ENERGY", "CONTRACTS"]:
		var active: bool = roster_filter == filter_name
		var filter_button := _button(filter_name, active); filter_button.custom_minimum_size.y = 34; filter_button.pressed.connect(func(): roster_filter = filter_name; _show_page("roster")); filters.add_child(filter_button)
	var summary := HBoxContainer.new(); summary.add_theme_constant_override("separation", 28); content.add_child(summary)
	for metric in [["MAIN ROSTER", "%d / 4" % starters, CYAN], ["SUBSTITUTES", "%d / 3" % substitutes, CYAN], ["AVAILABLE", str(available), SUCCESS], ["AVERAGE OVR", str(average_ovr), CYAN], ["TEAM CHEMISTRY", str(int(game.data.get("chemistry",0))), _metric_color(int(game.data.get("chemistry",0)))]]:
		summary.add_child(_squad_summary_metric(str(metric[0]), str(metric[1]), metric[2]))
	var contract_risk: int = game.data.roster.filter(func(p): return int(p.get("contract", 99)) <= 6).size()
	var low_energy: int = game.data.roster.filter(func(p): return int(p.get("energy", 100)) < 60).size()
	if contract_risk > 0 or low_energy > 0:
		var alerts := HBoxContainer.new(); alerts.add_theme_constant_override("separation", 10); content.add_child(alerts)
		if contract_risk > 0:
			var contract_alert := _button("CONTRACT EXPIRING  %d" % contract_risk, false); contract_alert.icon = _small_icon("icons.navigation.inbox", 16); contract_alert.add_theme_color_override("font_color", GOLD); contract_alert.pressed.connect(func(): roster_filter = "CONTRACTS"; _show_page("roster")); alerts.add_child(contract_alert)
		if low_energy > 0:
			var energy_alert := _button("LOW ENERGY  %d" % low_energy, false); energy_alert.icon = _small_icon("icons.status.energy", 16); energy_alert.add_theme_color_override("font_color", GOLD); energy_alert.pressed.connect(func(): roster_filter = "LOW ENERGY"; _show_page("roster")); alerts.add_child(energy_alert)
	var compact := ResponsiveScript.is_compact(get_viewport_rect().size)
	var workspace: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new(); workspace.add_theme_constant_override("separation", 16); content.add_child(workspace)
	var roster_column := VBoxContainer.new(); roster_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL; roster_column.add_theme_constant_override("separation", 12); workspace.add_child(roster_column)
	var team_column := VBoxContainer.new(); team_column.custom_minimum_size.x = 0 if compact else 320; team_column.add_theme_constant_override("separation", 12); workspace.add_child(team_column)
	var main_roster := _panel("MAIN ROSTER  %d / 4" % starters, PANEL_HIGH); roster_column.add_child(main_roster)
	var main_cards := HBoxContainer.new(); main_cards.add_theme_constant_override("separation", 10); main_roster.add_child(main_cards)
	for index in starters:
		var player: Dictionary = game.data.roster[index]
		if _squad_filter_accepts(player, index): main_cards.add_child(_squad_player_card(player, index, true))
	var selected := clampi(selected_player, 0, maxi(0, game.data.roster.size() - 1))
	if not game.data.roster.is_empty():
		var selected_player_data: Dictionary = game.data.roster[selected]
		var action_bar := _panel("SELECTED PLAYER  •  @%s" % str(selected_player_data.get("handle", selected_player_data.get("name", "PLAYER"))), PANEL_HIGH); action_bar.custom_minimum_size.y = 88; roster_column.add_child(action_bar)
		var selected_summary := HBoxContainer.new(); selected_summary.add_theme_constant_override("separation", 10); action_bar.add_child(selected_summary)
		selected_summary.add_child(_player_avatar(str(selected_player_data.get("avatar_asset_id", "")), Vector2(52, 58)))
		var selected_copy := VBoxContainer.new(); selected_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL; selected_summary.add_child(selected_copy)
		selected_copy.add_child(_label("%s     OVR %d     ENERGY %d%%" % [str(selected_player_data.get("role", "FLEX")).to_upper(), int(selected_player_data.get("overall", 0)), int(selected_player_data.get("energy", 0))], 13, TEXT))
		selected_copy.add_child(_label("FORM %d     MORALE %d     %s" % [int(selected_player_data.get("form", 0)), int(selected_player_data.get("morale", 70)), "READY" if int(selected_player_data.get("energy", 0)) >= 60 else "RECOVERY ADVISED"], 10, SUCCESS if int(selected_player_data.get("energy", 0)) >= 60 else GOLD))
		var action_line := HBoxContainer.new(); action_line.custom_minimum_size.y = 34; action_line.add_theme_constant_override("separation", 10); action_bar.add_child(action_line)
		var action_fill := Control.new(); action_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL; action_line.add_child(action_fill)
		var profile := _command_button("VIEW PROFILE", "Open player dossier", "icons.navigation.roster", true); profile.pressed.connect(_show_page.bind("player_detail")); action_line.add_child(profile)
		var role := _command_button("CHANGE ROLE", "Tactical assignment", "symbol.tactics", false); role.pressed.connect(_show_role_popup.bind(selected_player_data)); action_line.add_child(role)
		if selected < 4 and game.data.roster.size() > 4:
			var reserve := _command_button("MOVE TO BENCH", "Adjust active roster", "symbol.exchange", false); reserve.pressed.connect(_show_reserve_popup.bind(selected_player_data, true)); action_line.add_child(reserve)
		elif selected >= 4:
			var promote := _command_button("PROMOTE", "Move to main roster", "symbol.exchange", false); promote.pressed.connect(_show_reserve_popup.bind(selected_player_data, false)); action_line.add_child(promote)
		var rest := _command_button("REST", "Recover energy", "icons.status.energy", false); rest.pressed.connect(_show_rest_popup.bind(selected_player_data)); action_line.add_child(rest)
	if substitutes > 0:
		var reserve_panel := _panel("SUBSTITUTES  %d / 3" % substitutes, PANEL); roster_column.add_child(reserve_panel)
		var reserve_rows := HBoxContainer.new(); reserve_rows.add_theme_constant_override("separation", 10); reserve_panel.add_child(reserve_rows)
		for index in range(4, game.data.roster.size()):
			var player: Dictionary = game.data.roster[index]
			if _squad_filter_accepts(player, index): reserve_rows.add_child(_squad_player_card(player, index, false))
	else:
		var reserve_panel := _panel("SUBSTITUTES  0 / 3", PANEL); roster_column.add_child(reserve_panel)
		var scout_reserves := _button("SCOUT PLAYERS  →", false); scout_reserves.pressed.connect(_show_page.bind("transfer")); reserve_panel.add_child(_label("NO SUBSTITUTE PLAYERS", 11, MUTED)); reserve_panel.add_child(scout_reserves)
	if not game.data.get("loaned_players", []).is_empty():
		var loan_panel := _panel("PLAYERS ON LOAN", PANEL_HIGH); roster_column.add_child(loan_panel)
		for loaned in game.data.get("loaned_players", []):
			var loan_record: Dictionary = {}; for record in game.data.get("loan_records", []): if str(record.get("player_id",""))==str(loaned.get("id","")) and str(record.get("status",""))=="ACTIVE": loan_record=record; break
			loan_panel.add_child(_action_row("LOAN", "@%s • %s" % [str(loaned.get("handle",loaned.get("name","player"))),str(loan_record.get("destination_team_name","Partner club"))], "Returns %s • destination covers %d%% salary" % [str(loan_record.get("return_date","—")),int(loan_record.get("salary_coverage",0))], CYAN))
	var composition := _panel("TEAM COMPOSITION", PANEL); composition.custom_minimum_size.y = 196; team_column.add_child(composition)
	var role_counts := {"FRAGGER":0, "ANCHOR":0, "SCOUT":0, "SUPPORT":0, "IGL":0, "FLEX":0}
	for player in game.data.roster.slice(0, starters):
		var role := str(player.get("role", "FLEX")).to_upper(); role_counts[role] = int(role_counts.get(role, 0)) + 1
	for role in ["FRAGGER", "ANCHOR", "SCOUT", "SUPPORT", "IGL", "FLEX"]:
		if int(role_counts.get(role, 0)) > 0: composition.add_child(_squad_metric_row(role, str(role_counts[role]), _role_color(role)))
	composition.add_child(_squad_metric_row("CHEMISTRY", str(int(game.data.get("chemistry",0))), _metric_color(int(game.data.get("chemistry",0))))); composition.add_child(_squad_metric_row("TEAMWORK", str(_average("teamwork")), _metric_color(_average("teamwork"))))
	var readiness := _panel("TEAM READINESS", PANEL); readiness.custom_minimum_size.y = 166; team_column.add_child(readiness)
	readiness.add_child(_squad_metric_row("POWER", str(roundi(game.get_team_power())), CYAN))
	readiness.add_child(_squad_metric_row("FORM", str(_average("form")), GOLD))
	readiness.add_child(_squad_metric_row("ENERGY", "%d%%" % _average("energy"), _metric_color(_average("energy"))))
	readiness.add_child(_squad_metric_row("CHEMISTRY", str(int(game.data.get("chemistry",0))), _metric_color(int(game.data.get("chemistry",0)))))
	var roster_alerts := _panel("ROSTER ALERTS", PANEL); team_column.add_child(roster_alerts)
	roster_alerts.add_child(_squad_metric_row("CONTRACT EXPIRING", str(contract_risk), DANGER if contract_risk > 0 else SUCCESS)); roster_alerts.add_child(_squad_metric_row("PLAYER LOW ENERGY", str(low_energy), GOLD if low_energy > 0 else SUCCESS)); roster_alerts.add_child(_squad_metric_row("INJURED PLAYERS", "0", SUCCESS))
	var lower := HBoxContainer.new(); lower.add_theme_constant_override("separation", 16); content.add_child(lower)
	var weekly := _panel("WEEKLY PLAN", PANEL); weekly.custom_minimum_size.y = 150; weekly.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lower.add_child(weekly)
	var plans := HBoxContainer.new(); plans.add_theme_constant_override("separation", 6); weekly.add_child(plans)
	for plan_spec in [["Cân bằng", "BALANCED"], ["Cường độ cao", "HIGH INTENSITY"], ["Nghỉ & hồi phục", "RECOVERY"]]:
		var option := str(plan_spec[0]); var plan := _button(str(plan_spec[1]), game.data.schedule == option); plan.custom_minimum_size.y = 32; plan.pressed.connect(func(): game.set_team_training_schedule(option); _show_page("roster")); plans.add_child(plan)
	var current_training_preview: Dictionary=game.training_plan_preview(); var plan_effects := "WEEKLY ENERGY  %+d     GROWTH CHANCE  %d%%     %s" % [int(current_training_preview.get("energy_change",0)),roundi(float(current_training_preview.get("growth_chance",0.0))*100.0),str(current_training_preview.get("form_rule",""))]
	weekly.add_child(_label(plan_effects, 11, SUCCESS if game.data.schedule != "Cường độ cao" else GOLD))
	var prep := _panel("NEXT MATCH PREPARATION", PANEL_HIGH); prep.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lower.add_child(prep)
	var prep_line := HBoxContainer.new(); prep_line.add_theme_constant_override("separation", 16); prep.add_child(prep_line)
	var event_copy := VBoxContainer.new(); event_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL; prep_line.add_child(event_copy); event_copy.add_child(_label("GLOBAL SURVIVAL INVITATIONAL", 13, TEXT)); event_copy.add_child(_label("MATCHDAY 1  •  VERDANT REACH", 11, MUTED))
	var chance := VBoxContainer.new(); chance.custom_minimum_size.x = 78; prep_line.add_child(chance); chance.add_child(_label("%d%%" % clampi(roundi(game.get_team_power() - 52.0), 8, 78), 21, DANGER)); chance.add_child(_label("TOP 8", 10, MUTED))
	var readiness_copy := VBoxContainer.new(); readiness_copy.custom_minimum_size.x = 90; prep_line.add_child(readiness_copy); readiness_copy.add_child(_label("%d%%" % _average("energy"), 18, SUCCESS)); readiness_copy.add_child(_label("TEAM READY", 10, MUTED))
	var prepare := _button("PREPARE FOR MATCH  →", true); prepare.pressed.connect(_show_page.bind("match")); prep_line.add_child(prepare)

func _squad_filter_accepts(player: Dictionary, index: int) -> bool:
	if roster_filter == "ALL": return true
	if roster_filter == "MAIN ROSTER": return index < 4
	if roster_filter == "SUBSTITUTES": return index >= 4
	if roster_filter in ["LOW ENERGY", "THỂ LỰC THẤP"]: return int(player.get("energy", 100)) < 60
	if roster_filter in ["CONTRACTS", "HỢP ĐỒNG"]: return int(player.get("contract", 99)) <= 6
	return true

func _player_detail() -> void:
	if game.data.roster.is_empty() and selected_profile_player.is_empty(): _show_page("roster"); return
	var player: Dictionary = selected_profile_player if not selected_profile_player.is_empty() else game.data.roster[clampi(selected_player, 0, game.data.roster.size() - 1)]
	var is_owned_player := false
	for roster_player in game.data.roster:
		if str(roster_player.get("id", "")) == str(player.get("id", "")):
			is_owned_player = true
			break
	_header("PLAYER PROFILE", "%s  /  @%s" % ["SQUAD" if is_owned_player else "WORLD DATABASE", str(player.get("handle", "player"))], "MANAGE PLAYER" if is_owned_player else "VIEW PROFILE")
	var hero := HBoxContainer.new(); hero.add_theme_constant_override("separation", 16); content.add_child(hero)
	var identity := _panel("IDENTITY", PANEL_HIGH); identity.custom_minimum_size.x = 360; hero.add_child(identity)
	var identity_top := HBoxContainer.new(); identity_top.add_theme_constant_override("separation", 12); identity.add_child(identity_top)
	var avatar := _player_avatar(str(player.get("avatar_asset_id", "")), Vector2(148, 176)); identity_top.add_child(avatar)
	var identity_copy := VBoxContainer.new(); identity_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL; identity_copy.add_theme_constant_override("separation", 5); identity_top.add_child(identity_copy)
	identity_copy.add_child(_label(str(player.get("region", "GLOBAL")).to_upper(), 10, CYAN))
	var full_player_name := str(player.get("name", "Player")); var identity_name := _label(_compact_player_name(full_player_name), 19 if full_player_name.length() > 22 else 21, TEXT); identity_name.custom_minimum_size.y = 48; identity_name.tooltip_text = full_player_name; identity_copy.add_child(identity_name); identity_copy.add_child(_label("@%s" % str(player.get("handle", "player")), 15, CYAN))
	identity_copy.add_child(_role_badge(str(player.get("role", "FLEX")), _role_color(str(player.get("role", "FLEX")))))
	identity_copy.add_child(_label("AGE  %d" % int(player.get("age", 0)), 11, MUTED))
	identity.add_child(_label("TEAM  •  %s     PERSONALITY  •  %s" % [str(player.get("current_team_name", game.data.get("org_name", "FAZE CLAN"))).to_upper(), str(player.get("personality", "CONFIDENT")).to_upper()], 11, MUTED))
	identity.add_child(_tag("READY TO PLAY" if int(player.get("energy", 0)) >= 60 else "RECOVERY ADVISED", SUCCESS if int(player.get("energy", 0)) >= 60 else GOLD))
	var performance := _panel("OVERALL PERFORMANCE", PANEL); performance.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hero.add_child(performance)
	var performance_top := HBoxContainer.new(); performance_top.add_theme_constant_override("separation", 18); performance.add_child(performance_top)
	var rating := VBoxContainer.new(); rating.custom_minimum_size.x = 112; performance_top.add_child(rating); rating.add_child(_label("%d" % int(player.get("overall", 0)), 42, ACCENT)); rating.add_child(_label("OVR", 13, TEXT)); rating.add_child(_label("POTENTIAL  %d" % int(player.get("potential", 0)), 10, CYAN))
	var attributes := VBoxContainer.new(); attributes.size_flags_horizontal = Control.SIZE_EXPAND_FILL; attributes.add_theme_constant_override("separation", 4); performance_top.add_child(attributes)
	for stat in [["AIM","aim",DANGER],["VISION","vision",CYAN],["REACTION","reaction",GOLD],["COMMUNICATION","communication",CYAN],["ZONE READING","zone_reading",CYAN],["GAME SENSE","game_sense",GOLD],["TEAMWORK","teamwork",SUCCESS],["CLUTCH","clutch",ACCENT],["ENERGY","energy",_metric_color(int(player.get("energy", 0)))]]:
		attributes.add_child(_player_stat_row(str(stat[0]), int(player.get(str(stat[1]), 0)), stat[2]))
	var contract := _panel("CONTRACT" if is_owned_player else "SCOUTING ESTIMATE", PANEL); contract.custom_minimum_size.x = 330; hero.add_child(contract)
	var contract_top := HBoxContainer.new(); contract_top.add_theme_constant_override("separation", 18); contract.add_child(contract_top)
	var contract_values := VBoxContainer.new(); contract_values.size_flags_horizontal = Control.SIZE_EXPAND_FILL; contract_top.add_child(contract_values)
	contract_values.add_child(_label("%d MONTHS" % int(player.get("contract", 0)), 26, TEXT)); contract_values.add_child(_label("REMAINING", 10, MUTED)); contract_values.add_child(_label("$%s / MONTH" % GameStateScript.money(int(player.get("salary", 0))), 15, GOLD)); contract_values.add_child(_label("MARKET  $%s" % GameStateScript.money(int(player.get("value", 0))), 13, CYAN))
	var contract_breakdown := VBoxContainer.new(); contract_breakdown.add_theme_constant_override("separation", 5); contract_top.add_child(contract_breakdown)
	contract_breakdown.add_child(_label("SALARY BREAKDOWN", 10, MUTED)); contract_breakdown.add_child(_label("BASIC  $%s" % GameStateScript.money(int(player.get("salary", 0))), 11, TEXT)); contract_breakdown.add_child(_label("BONUS  $%s" % GameStateScript.money(roundi(int(player.get("salary", 0)) * 0.12)), 11, TEXT)); contract_breakdown.add_child(_label("APPEARANCE  $%s" % GameStateScript.money(roundi(int(player.get("salary", 0)) * 0.08)), 11, TEXT))
	contract.add_child(_label("EXPIRY  %s" % _contract_expiry(int(player.get("contract", 0))), 10, MUTED)); contract.add_child(_tag("ACTIVE CONTRACT" if is_owned_player else "DATABASE PROFILE", SUCCESS if is_owned_player else CYAN))
	var support := _panel("PLAYER FIT", PANEL); content.add_child(support)
	var fit_grid := GridContainer.new(); fit_grid.columns = 5; fit_grid.add_theme_constant_override("h_separation", 16); support.add_child(fit_grid)
	for spec in [["PREFERRED ROLE", str(player.get("role", "FLEX")).to_upper(), _role_color(str(player.get("role", "FLEX")))], ["SECONDARY ROLE", "FLEX", CYAN], ["FAVORITE WEAPON", _favorite_weapon(player), CYAN], ["PLAY STYLE", str(player.get("personality", "AGGRESSIVE")).to_upper(), GOLD], ["STATUS", "READY TO PLAY" if int(player.get("energy", 0)) >= 60 else "LOW ENERGY", SUCCESS if int(player.get("energy", 0)) >= 60 else GOLD]]:
		fit_grid.add_child(_profile_info_cell(str(spec[0]), str(spec[1]), spec[2]))
	var action_panel := _panel("PLAYER ACTIONS", Color("0b151d")); content.add_child(action_panel)
	if not is_owned_player:
		var external_note := _label("WORLD DATABASE PROFILE  •  Club-management actions are only available for players on your roster.", 12, MUTED)
		external_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		action_panel.add_child(external_note)
		var external_actions := HBoxContainer.new(); external_actions.add_theme_constant_override("separation", 8); action_panel.add_child(external_actions)
		var market_player := false
		for candidate in game.data.market:
			if str(candidate.get("id", "")) == str(player.get("id", "")):
				market_player = true
				break
		if market_player:
			var make_offer := _button("MAKE TRANSFER OFFER", true); make_offer.tooltip_text = "Creates an Inbox negotiation; no instant signing."
			make_offer.pressed.connect(func(): var result := game.create_transfer_offer(str(player.get("id", "")), {"salary":int(player.get("salary", 0)),"months":24,"role":"ROTATION"}); _notify("Offer sent • check Inbox." if bool(result.get("ok",false)) else str(result.get("error","Offer unavailable."))); _show_page("inbox")); external_actions.add_child(make_offer)
		else:
			var unavailable := _button("RECRUITMENT UNAVAILABLE", false); unavailable.disabled = true; unavailable.tooltip_text = "This verified database player is not in the current transfer market."; external_actions.add_child(unavailable)
		var back_to_discovery := _button("BACK TO PLAYER DISCOVERY", false); back_to_discovery.pressed.connect(_show_page.bind("scouting")); external_actions.add_child(back_to_discovery)
	else:
		var action_sections := HBoxContainer.new(); action_sections.add_theme_constant_override("separation", 12); action_panel.add_child(action_sections)
		var daily := _action_group("DAILY"); daily.size_flags_horizontal = Control.SIZE_EXPAND_FILL; action_sections.add_child(daily)
		var role_contract := _action_group("ROLE & CONTRACT"); role_contract.size_flags_horizontal = Control.SIZE_EXPAND_FILL; action_sections.add_child(role_contract)
		var transfers := _action_group("TRANSFER & ROSTER"); transfers.size_flags_horizontal = Control.SIZE_EXPAND_FILL; action_sections.add_child(transfers)
		var danger_zone := _action_group("DANGER"); danger_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL; action_sections.add_child(danger_zone)
		var is_starter := selected_player < 4 and selected_profile_player.is_empty()
		var contract_urgent := int(player.get("contract", 99)) <= 6
		daily.add_child(_label("ENERGY  %d%%   •   FORM  %d" % [int(player.get("energy", 0)), int(player.get("form", 0))], 10, _metric_color(int(player.get("energy", 0)))))
		var rest := _command_button("REST PLAYER", "Recover energy and form", "icons.status.energy", true); rest.pressed.connect(_show_rest_popup.bind(player)); daily.add_child(rest)
		if is_starter and game.data.roster.size() > 4:
			var reserve := _command_button("MOVE TO BENCH", "Make a roster swap", "symbol.exchange", false); reserve.pressed.connect(_show_reserve_popup.bind(player, true)); daily.add_child(reserve)
		elif selected_player >= 4:
			var promote := _command_button("MOVE TO MAIN", "Promote to starters", "symbol.exchange", false); promote.pressed.connect(_show_reserve_popup.bind(player, false)); daily.add_child(promote)
		var adjust_role := _command_button("ADJUST ROLE", "Change tactical assignment", "symbol.tactics", false); adjust_role.pressed.connect(_show_role_popup.bind(player)); role_contract.add_child(adjust_role)
		var renew := _command_button("RENEW CONTRACT" if contract_urgent else "REVIEW CONTRACT", "%d months remaining" % int(player.get("contract", 0)), "icons.navigation.inbox", contract_urgent); renew.pressed.connect(_show_contract_popup.bind(player)); role_contract.add_child(renew)
		var salary := _command_button("ADJUST SALARY", "Current $%s / month" % GameStateScript.money(int(player.get("salary", 0))), "icons.navigation.inbox", false); salary.pressed.connect(_show_salary_popup.bind(player)); role_contract.add_child(salary)
		var listed := bool(player.get("transfer_listed", false))
		var transfer := _command_button("REMOVE FROM LIST" if listed else "TRANSFER LIST", "Open market availability", "symbol.exchange", false); transfer.pressed.connect(_show_transfer_popup.bind(player)); transfers.add_child(transfer)
		var offers := _command_button("VIEW OFFERS", "Review club proposals", "symbol.trophy", false); offers.pressed.connect(_show_offers_popup.bind(player)); transfers.add_child(offers)
		var loan := _command_button("LOAN OUT", "Temporary team move", "symbol.location", false); loan.pressed.connect(_show_loan_popup.bind(player)); transfers.add_child(loan)
		var move_reserves := _command_button("MOVE TO RESERVES", "Remove from active four", "symbol.exchange", false); move_reserves.pressed.connect(_show_reserve_popup.bind(player, true)); transfers.add_child(move_reserves)
		var terminate := _command_button("TERMINATE", "Pay contract termination fee", "symbol.warning", false, "danger"); terminate.pressed.connect(_show_danger_popup.bind(player, "TERMINATE CONTRACT")); danger_zone.add_child(terminate)
		var release := _command_button("RELEASE PLAYER", "Permanently remove player", "symbol.warning", false, "danger"); release.pressed.connect(_show_danger_popup.bind(player, "RELEASE PLAYER")); danger_zone.add_child(release)
		var back := _button("← BACK TO SQUAD", false); danger_zone.add_child(back); back.pressed.connect(_show_page.bind("roster"))
	var tabs := HBoxContainer.new(); tabs.add_theme_constant_override("separation", 8); content.add_child(tabs)
	for tab in ["OVERVIEW", "RECENT FORM", "CAREER", "PERSONALITY", "CHEMISTRY"]:
		var tab_button := _button(tab, player_profile_tab == tab); tab_button.custom_minimum_size.y = 34; tab_button.pressed.connect(func(): player_profile_tab = tab; _show_page("player_detail")); tabs.add_child(tab_button)
	var detail_row := HBoxContainer.new(); detail_row.add_theme_constant_override("separation", 12); content.add_child(detail_row)
	var detail := _panel(player_profile_tab, PANEL); detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL; detail_row.add_child(detail)
	match player_profile_tab:
		"RECENT FORM":
			detail.add_child(_label("FORM  %d" % int(player.get("form", 0)), 26, GOLD)); detail.add_child(_label("▂  ▅  ▅  ▇  ▆", 18, GOLD)); var latest: Dictionary = player.get("latest_stats", {}); detail.add_child(_squad_metric_row("AVERAGE RANK", str(latest.get("avg_rank", "—")), CYAN)); detail.add_child(_squad_metric_row("KILLS", str(latest.get("avg_kill", "—")), CYAN)); detail.add_child(_squad_metric_row("DAMAGE", str(latest.get("avg_damage", "—")), CYAN)); detail.add_child(_squad_metric_row("SURVIVAL", str(latest.get("avg_survive_time", "—")), CYAN))
		"CAREER":
			var career_data: Dictionary = player.get("career", {})
			detail.add_child(_squad_metric_row("MATCHES", str(int(career_data.get("matches",0))), CYAN)); detail.add_child(_squad_metric_row("KILLS", str(int(career_data.get("kills",0))), GOLD)); detail.add_child(_squad_metric_row("DAMAGE", str(int(career_data.get("damage",0))), ORANGE)); detail.add_child(_squad_metric_row("REVIVES", str(int(career_data.get("revives",0))), SUCCESS)); detail.add_child(_squad_metric_row("TITLES", str(int(career_data.get("titles",0))), PURPLE)); detail.add_child(_squad_metric_row("EARNINGS", "$%s" % GameStateScript.money(int(career_data.get("earnings",0))), ACCENT))
			var team_history: Array = player.get("team_history", [])
			if team_history.is_empty():
				detail.add_child(_label("CURRENT TEAM  •  %s" % str(player.get("current_team_name", game.data.get("org_name","Organization"))), 12, MUTED))
			else:
				for team_record in team_history: detail.add_child(_label(JSON.stringify(team_record), 11, MUTED))
		"PERSONALITY":
			for trait_spec in [["AGGRESSIVE","aggressive",DANGER],["TACTICAL","tactical",CYAN],["BIG GAME PLAYER","big_game",GOLD]]: detail.add_child(_player_stat_row(str(trait_spec[0]), int(player.get("personality_traits", {}).get(str(trait_spec[1]), 50)), trait_spec[2]))
		"CHEMISTRY":
			var links: Array = game.get_player_relationships(str(player.get("id", ""))); if links.is_empty(): detail.add_child(_label("NO ACTIVE TEAMMATE LINKS", 12, MUTED))
			for link in links: detail.add_child(_squad_metric_row(str(link.get("name", "Teammate")), "%+d" % int(link.get("value", 0)), SUCCESS if int(link.get("value", 0)) >= 0 else DANGER))
		_:
			var overview := HBoxContainer.new(); overview.add_theme_constant_override("separation", 10); detail.add_child(overview)
			var recent := _panel("RECENT FORM", PANEL_HIGH); recent.size_flags_horizontal = Control.SIZE_EXPAND_FILL; overview.add_child(recent); recent.add_child(_label("FORM  %d" % int(player.get("form", 0)), 24, SUCCESS)); var latest_overview: Dictionary = player.get("latest_stats", {}); recent.add_child(_label("AVG RANK  %s     KILLS  %s" % [str(latest_overview.get("avg_rank","—")),str(latest_overview.get("avg_kill","—"))], 10, TEXT)); recent.add_child(_label("DAMAGE  %s     SURVIVAL  %s" % [str(latest_overview.get("avg_damage","—")),str(latest_overview.get("avg_survive_time","—"))], 10, MUTED))
			var career := _panel("CAREER SUMMARY", PANEL_HIGH); career.size_flags_horizontal = Control.SIZE_EXPAND_FILL; overview.add_child(career); var career_overview: Dictionary = player.get("career", {}); career.add_child(_label(str(player.get("current_team_name", game.data.get("org_name", "Organization"))), 14, TEXT)); career.add_child(_label("MATCHES  %d     TITLES  %d" % [int(career_overview.get("matches",0)),int(career_overview.get("titles",0))], 10, CYAN)); career.add_child(_label("KILLS  %d     DAMAGE  %d" % [int(career_overview.get("kills",0)),int(career_overview.get("damage",0))], 10, MUTED))
			var personality := _panel("PERSONALITY", PANEL_HIGH); personality.size_flags_horizontal = Control.SIZE_EXPAND_FILL; overview.add_child(personality); personality.add_child(_player_stat_row("AGGRESSIVE", int(player.get("personality_traits", {}).get("aggressive", 70)), DANGER)); personality.add_child(_player_stat_row("TACTICAL", int(player.get("personality_traits", {}).get("tactical", 55)), CYAN)); personality.add_child(_player_stat_row("CLUTCH", int(player.get("clutch", 50)), GOLD))
			var chemistry := _panel("TEAM CHEMISTRY", PANEL_HIGH); chemistry.size_flags_horizontal = Control.SIZE_EXPAND_FILL; overview.add_child(chemistry); var relationship_count := game.get_player_relationships(str(player.get("id",""))).size(); chemistry.add_child(_label("TEAM LINK  %d" % int(game.data.get("chemistry",0)), 16, _metric_color(int(game.data.get("chemistry",0))))); chemistry.add_child(_label("%d RECORDED TEAMMATE CONNECTION(S)" % relationship_count, 10, MUTED)); var chemistry_details := _button("VIEW CHEMISTRY  →", false); chemistry_details.pressed.connect(func(): player_profile_tab="CHEMISTRY"; _show_page("player_detail")); chemistry.add_child(chemistry_details)

func _contract_expiry(months: int) -> String:
	var date := Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_datetime_string(str(game.data.current_date) + "T00:00:00") + months * 30 * 86400)
	return "%04d-%02d-%02d" % [int(date.year), int(date.month), int(date.day)]

func _show_player_popup(title: String, message: String, dangerous := false) -> void:
	var popup := PopupPanel.new(); popup.size = Vector2i(470, 270); popup.position = Vector2i((get_viewport_rect().size.x - popup.size.x) / 2.0, (get_viewport_rect().size.y - popup.size.y) / 2.0); popup.add_theme_stylebox_override("panel", _style(Color("0c171f"), 3, DANGER if dangerous else ACCENT, 1)); add_child(popup)
	var box := VBoxContainer.new(); box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); box.add_theme_constant_override("separation", 12); popup.add_child(box)
	box.add_child(_label(title, 20, DANGER if dangerous else TEXT)); var copy := _label(message, 13, MUTED); copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; copy.size_flags_vertical = Control.SIZE_EXPAND_FILL; box.add_child(copy)
	var actions := HBoxContainer.new(); actions.add_theme_constant_override("separation", 8); box.add_child(actions); var cancel := _button("CANCEL", false); cancel.pressed.connect(popup.queue_free); actions.add_child(cancel); var confirm := _button("CONFIRM", dangerous); confirm.pressed.connect(func(): popup.queue_free(); _notify("%s acknowledged." % title)); actions.add_child(confirm)
	popup.popup()

func _show_role_popup(player: Dictionary) -> void:
	var popup := PopupPanel.new(); popup.size = Vector2i(540, 340); popup.position = Vector2i((get_viewport_rect().size.x - popup.size.x) / 2.0, (get_viewport_rect().size.y - popup.size.y) / 2.0); popup.add_theme_stylebox_override("panel", _style(Color("0c171f"), 3, ACCENT, 1)); add_child(popup)
	var chosen := [str(player.get("role", "FLEX")).to_upper()]
	var box := VBoxContainer.new(); box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); box.add_theme_constant_override("separation", 10); popup.add_child(box); box.add_child(_label("ROLE ASSIGNMENT", 20, TEXT)); box.add_child(_label("CURRENT ROLE  •  %s\nChoose a role, then confirm the squad change." % chosen[0], 12, MUTED))
	var roles := GridContainer.new(); roles.columns = 3; roles.add_theme_constant_override("h_separation", 8); roles.add_theme_constant_override("v_separation", 8); box.add_child(roles)
	for role in ["FRAGGER", "ANCHOR", "SCOUT", "SUPPORT", "IGL", "FLEX"]:
		var role_button := _button(role, chosen[0] == role); role_button.pressed.connect(func(): chosen[0] = role; _notify("Role preview: %s. Confirm to apply." % role)); roles.add_child(role_button)
	var actions := HBoxContainer.new(); actions.add_theme_constant_override("separation", 8); box.add_child(actions)
	var cancel := _button("CANCEL", false); cancel.pressed.connect(popup.queue_free); actions.add_child(cancel)
	var confirm := _button("CONFIRM ROLE", true); confirm.pressed.connect(func(): var result := game.set_player_role(str(player.get("id", "")), chosen[0]); popup.queue_free(); _notify("Role changed to %s." % chosen[0] if bool(result.get("ok",false)) else str(result.get("error","Role change failed."))); _show_page("player_detail")); actions.add_child(confirm); popup.popup()

func _show_contract_popup(player: Dictionary) -> void:
	var popup := PopupPanel.new(); popup.size = Vector2i(520, 330); popup.position = Vector2i((get_viewport_rect().size.x - popup.size.x) / 2.0, (get_viewport_rect().size.y - popup.size.y) / 2.0); popup.add_theme_stylebox_override("panel", _style(Color("0c171f"), 3, GOLD, 1)); add_child(popup)
	var proposal := [24]
	var box := VBoxContainer.new(); box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); box.add_theme_constant_override("separation", 10); popup.add_child(box)
	box.add_child(_label("CONTRACT NEGOTIATION", 20, TEXT)); box.add_child(_label("CURRENT  %d MONTHS  •  $%s / MONTH\nROLE PROMISE  •  %s" % [int(player.get("contract", 0)), GameStateScript.money(int(player.get("salary", 0))), str(player.get("role", "FLEX")).to_upper()], 12, MUTED))
	var terms := HBoxContainer.new(); terms.add_theme_constant_override("separation", 8); box.add_child(terms)
	for months in [12, 24, 36]:
		var term := _button("%d MONTHS" % months, months == proposal[0]); term.pressed.connect(func(): proposal[0] = months; _notify("%d-month offer selected." % months)); terms.add_child(term)
	box.add_child(_label("SIGNING BONUS  $%s     RESPONSE  LIKELY ACCEPT" % GameStateScript.money(int(player.get("salary", 0)) * 2), 11, GOLD))
	var actions := HBoxContainer.new(); actions.add_theme_constant_override("separation", 8); box.add_child(actions); var cancel := _button("CANCEL", false); cancel.pressed.connect(popup.queue_free); actions.add_child(cancel)
	var send := _button("SEND OFFER", true); send.pressed.connect(func(): var result := game.renew_contract(str(player.get("id", "")), proposal[0]); popup.queue_free(); _notify(result); _show_page("player_detail")); actions.add_child(send); popup.popup()

func _show_salary_popup(player: Dictionary) -> void:
	var popup := PopupPanel.new(); popup.size = Vector2i(500, 310); popup.position = Vector2i((get_viewport_rect().size.x - popup.size.x) / 2.0, (get_viewport_rect().size.y - popup.size.y) / 2.0); popup.add_theme_stylebox_override("panel", _style(Color("0c171f"), 3, CYAN, 1)); add_child(popup)
	var current := int(player.get("salary", 0)); var expectation := roundi(current * 1.15)
	var box := VBoxContainer.new(); box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); box.add_theme_constant_override("separation", 10); popup.add_child(box)
	box.add_child(_label("SALARY NEGOTIATION", 20, TEXT)); box.add_child(_label("CURRENT  $%s / MONTH\nEXPECTATION  $%s / MONTH" % [GameStateScript.money(current), GameStateScript.money(expectation)], 12, MUTED))
	var offer := SpinBox.new(); offer.min_value = maxi(500, roundi(current * 0.7)); offer.max_value = roundi(current * 1.8); offer.step = 100; offer.value = expectation; offer.allow_greater = false; offer.custom_minimum_size.y = 42; box.add_child(offer)
	box.add_child(_label("OUTCOME PREVIEW  •  ACCEPT at expectation, COUNTER near target, REJECT below target.", 10, GOLD))
	var actions := HBoxContainer.new(); actions.add_theme_constant_override("separation", 8); box.add_child(actions); var cancel := _button("CANCEL", false); cancel.pressed.connect(popup.queue_free); actions.add_child(cancel)
	var make_offer := _button("MAKE OFFER", true); make_offer.pressed.connect(func(): var proposed := roundi(offer.value); var outcome := "ACCEPT" if proposed >= expectation else "COUNTER" if proposed >= roundi(expectation * 0.9) else "REJECT"; if outcome == "ACCEPT": var result := game.set_player_salary(str(player.get("id", "")), proposed); popup.queue_free(); _notify("Salary offer accepted." if bool(result.get("ok",false)) else str(result.get("error","Salary update failed."))); _show_page("player_detail") else: _notify("Salary response: %s." % outcome)); actions.add_child(make_offer); popup.popup()

func _show_transfer_popup(player: Dictionary) -> void:
	var listed := bool(player.get("transfer_listed", false))
	var popup := PopupPanel.new(); popup.size = Vector2i(480, 270); popup.position = Vector2i((get_viewport_rect().size.x - popup.size.x) / 2.0, (get_viewport_rect().size.y - popup.size.y) / 2.0); popup.add_theme_stylebox_override("panel", _style(Color("0c171f"), 3, ACCENT, 1)); add_child(popup)
	var box := VBoxContainer.new(); box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); box.add_theme_constant_override("separation", 12); popup.add_child(box); box.add_child(_label("TRANSFER LIST", 20, TEXT)); box.add_child(_label("MARKET VALUE  $%s\nASKING PRICE  NOT SET\nINTEREST  UNAVAILABLE UNTIL A CLUB SUBMITS AN OFFER" % GameStateScript.money(int(player.get("value", 0))), 13, MUTED))
	var controls := HBoxContainer.new(); controls.add_theme_constant_override("separation", 8); box.add_child(controls); var cancel := _button("CANCEL", false); cancel.pressed.connect(popup.queue_free); controls.add_child(cancel); var confirm := _button("REMOVE LISTING" if listed else "LIST PLAYER", true); confirm.pressed.connect(func(): var result:=game.set_transfer_listed(str(player.get("id","")),not listed); popup.queue_free(); _notify("Transfer-list status updated." if bool(result.get("ok",false)) else str(result.get("error","Update failed."))); _show_page("player_detail")); controls.add_child(confirm); popup.popup()

func _show_rest_popup(player: Dictionary) -> void:
	var gain := 8 + int(game.data.get("facilities", {}).get("Medical Room", 1)) * 4
	_show_confirm_action("REST PLAYER", "ENERGY  %d%%  →  %d%%\nFORM  %d  →  %d\nThe player skips high-intensity work today." % [int(player.get("energy", 0)), mini(100, int(player.get("energy", 0)) + gain), int(player.get("form", 0)), maxi(25, int(player.get("form", 0)) - 1)], "REST NOW", func(): _notify(game.recover_player(str(player.get("id", "")))); _show_page("player_detail"))

func _show_reserve_popup(player: Dictionary, to_reserves: bool) -> void:
	var title := "MOVE TO RESERVES" if to_reserves else "MOVE TO MAIN ROSTER"
	var message := "This changes the active four-player squad and recalculates team readiness."
	_show_confirm_action(title, message, "CONFIRM MOVE", func():
		if to_reserves: _bench_selected_player()
		else: _promote_selected_player()
		_show_page("player_detail"))

func _show_offers_popup(player: Dictionary) -> void:
	var offers: Array = game.data.get("inbound_offers", []).filter(func(offer): return str(offer.get("player_id",""))==str(player.get("id","")) and str(offer.get("status","")) in ["PENDING","COUNTERED"])
	if offers.is_empty(): _show_player_popup("TRANSFER OFFERS", "NO ACTIVE OFFERS\n\nListed players are evaluated during weekly progression using quality, age, role, form and deterministic market demand."); return
	var offer: Dictionary=offers[0]; _show_confirm_action("TRANSFER OFFER", "%s offers $%s for %s.\nStatus  •  %s\nDeadline  •  Week %d" % [str(offer.get("buyer_name","Club")),GameStateScript.money(int(offer.get("amount",0))),str(player.get("name","Player")),str(offer.get("status","PENDING")),int(offer.get("deadline_week",0))], "OPEN INBOX", func(): _show_page("inbox"))

func _show_loan_popup(player: Dictionary) -> void:
	var popup := PopupPanel.new(); popup.size = Vector2i(560, 390); popup.position = Vector2i((get_viewport_rect().size.x - popup.size.x) / 2.0, (get_viewport_rect().size.y - popup.size.y) / 2.0); popup.add_theme_stylebox_override("panel", _style(Color("0c171f"), 3, CYAN, 1)); add_child(popup)
	var box := VBoxContainer.new(); box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); box.add_theme_constant_override("separation", 10); popup.add_child(box); box.add_child(_label("LOAN PROPOSAL", 20, TEXT)); box.add_child(_label("The player leaves the active roster, remains club-owned and returns automatically on the recorded date.", 12, MUTED))
	var destinations: Array = game.loan_destinations()
	var destination := OptionButton.new()
	for item in destinations:
		destination.add_item(str(item.get("name", "Partner club")))
		destination.set_item_metadata(destination.item_count - 1, str(item.get("id", "")))
	box.add_child(destination)
	var duration := OptionButton.new()
	for weeks in [4, 8, 12]:
		duration.add_item("%d WEEKS" % weeks)
		duration.set_item_metadata(duration.item_count - 1, weeks)
	duration.select(1)
	box.add_child(duration)
	box.add_child(_label("SALARY COVERAGE  •  DESTINATION 50% / CLUB 50%\nRETURN DATE  •  Calculated from the selected duration",12,GOLD))
	var actions := HBoxContainer.new(); actions.add_theme_constant_override("separation", 8); box.add_child(actions); var cancel := _button("CANCEL", false); cancel.pressed.connect(popup.queue_free); actions.add_child(cancel)
	var send := _button("CONFIRM LOAN", true); send.pressed.connect(func(): var result:=game.create_loan(str(player.get("id","")),str(destination.get_item_metadata(destination.selected)),int(duration.get_item_metadata(duration.selected)),50); popup.queue_free(); _notify("Loan agreement completed." if bool(result.get("ok",false)) else str(result.get("error","Loan failed."))); _show_page("roster")); actions.add_child(send); popup.popup()

func _show_danger_popup(player: Dictionary, title: String) -> void:
	var fee := int(player.get("salary", 0)) * maxi(1, int(player.get("contract", 0)))
	var confirm_text := "CONFIRM TERMINATION" if title == "TERMINATE CONTRACT" else "CONFIRM RELEASE"
	_show_confirm_action(title, "REMAINING CONTRACT  %d MONTHS\nTERMINATION FEE  $%s\nTEAM IMPACT  •  Active roster depth decreases." % [int(player.get("contract", 0)), GameStateScript.money(fee)], confirm_text, func(): var result := game.terminate_player_contract(str(player.get("id", ""))) if title == "TERMINATE CONTRACT" else game.release_player(str(player.get("id", ""))); _notify(result); _show_page("roster"), true)

func _show_confirm_action(title: String, message: String, confirm_text: String, callback: Callable, dangerous := false) -> void:
	var popup := PopupPanel.new(); popup.size = Vector2i(480, 275); popup.position = Vector2i((get_viewport_rect().size.x - popup.size.x) / 2.0, (get_viewport_rect().size.y - popup.size.y) / 2.0); popup.add_theme_stylebox_override("panel", _style(Color("0c171f"), 3, DANGER if dangerous else ACCENT, 1)); add_child(popup)
	var box := VBoxContainer.new(); box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); box.add_theme_constant_override("separation", 12); popup.add_child(box); box.add_child(_label(title, 20, DANGER if dangerous else TEXT)); var copy := _label(message, 13, MUTED); copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; copy.size_flags_vertical = Control.SIZE_EXPAND_FILL; box.add_child(copy)
	var actions := HBoxContainer.new(); actions.add_theme_constant_override("separation", 8); box.add_child(actions); var cancel := _button("CANCEL", false); cancel.pressed.connect(popup.queue_free); actions.add_child(cancel); var confirm := _button_variant(confirm_text, "danger" if dangerous else "primary"); confirm.pressed.connect(func(): popup.queue_free(); callback.call()); actions.add_child(confirm); popup.popup()

func _scouting() -> void:
	var level := int(game.data.facilities.get("Analytics Lab", 1)); var active := game.active_scout_assignment(); var latest := game.latest_scout_report()
	_header("PLAYER SCOUTING", "Assign the scouting team, wait for research and review only the players they actually discover.", "ANALYTICS LEVEL %d  •  %d-%d RESULTS" % [level, 3, mini(7, 2 + level)])
	var brief := _panel("NEW SCOUTING ASSIGNMENT", PANEL_HIGH); content.add_child(brief)
	var role_row := HBoxContainer.new(); role_row.add_theme_constant_override("separation", 7); brief.add_child(role_row)
	for role in ["ALL", "IGL", "FRAGGER", "SUPPORT", "ENTRY", "ANCHOR"]:
		var role_button := _button(role, scout_filter == role); role_button.disabled = not active.is_empty(); role_button.pressed.connect(func(): scout_filter = role; _show_page("scouting")); role_row.add_child(role_button)
	var criteria := HBoxContainer.new(); criteria.add_theme_constant_override("separation", 10); brief.add_child(criteria)
	var age := OptionButton.new(); age.custom_minimum_size.x = 180
	for value in ["ANY", "U21", "22-25", "26+"]: age.add_item(value); age.set_item_metadata(age.item_count - 1, value)
	age.select(["ANY", "U21", "22-25", "26+"].find(scout_age_filter)); age.disabled = not active.is_empty(); age.item_selected.connect(func(index): scout_age_filter = str(age.get_item_metadata(index))); criteria.add_child(_field("AGE", age))
	var priority := OptionButton.new(); priority.custom_minimum_size.x = 220
	for value in ["POTENTIAL", "CURRENT_ABILITY", "AFFORDABILITY"]: priority.add_item(value.replace("_", " ")); priority.set_item_metadata(priority.item_count - 1, value)
	priority.select(["POTENTIAL", "CURRENT_ABILITY", "AFFORDABILITY"].find(scout_priority)); priority.disabled = not active.is_empty(); priority.item_selected.connect(func(index): scout_priority = str(priority.get_item_metadata(index))); criteria.add_child(_field("PRIORITY", priority))
	var assignment_button := _button("SCOUTING IN PROGRESS" if not active.is_empty() else "START SCOUTING ASSIGNMENT", active.is_empty()); assignment_button.disabled = not active.is_empty(); assignment_button.pressed.connect(func(): var result := game.start_scout_assignment({"role":scout_filter,"age_band":scout_age_filter,"priority":scout_priority}); _notify("Scout dispatched." if bool(result.get("ok",false)) else str(result.get("error","Assignment failed."))); _show_page("scouting")); criteria.add_child(assignment_button)
	if not active.is_empty():
		brief.add_child(_action_row("ACTIVE", "%s / %s / %s" % [str(active.criteria.role), str(active.criteria.age_band), str(active.criteria.priority).replace("_"," ")], "Report due %s • Cost $%s" % [str(active.completion_date), GameStateScript.money(int(active.cost))], GOLD))
	elif latest.is_empty():
		brief.add_child(_empty_state("NO SCOUT REPORT", "Choose criteria and start an assignment. The player database is not revealed until the report completes."))
	var report_title := "LATEST REPORT" if not latest.is_empty() else "SCOUTING RESULTS"
	var result_panel := _panel(report_title, PANEL); content.add_child(result_panel)
	if not latest.is_empty(): result_panel.add_child(_label("%s • %d players • %s priority" % [str(latest.get("date","")), int(latest.get("count",0)), str(latest.get("criteria",{}).get("priority","POTENTIAL")).replace("_"," ")], 12, MUTED))
	var search := LineEdit.new(); search.placeholder_text = "Filter this report"; search.text = scout_query; search.text_submitted.connect(func(value): scout_query = value.strip_edges(); _show_page("scouting")); result_panel.add_child(search)
	var candidates := GridContainer.new(); candidates.columns = ResponsiveScript.columns(get_viewport_rect().size, 3, 2, 1); candidates.add_theme_constant_override("h_separation", 10); candidates.add_theme_constant_override("v_separation", 10); result_panel.add_child(candidates)
	var visible := game.current_scout_results(scout_query, "ALL")
	for player in visible: candidates.add_child(_candidate_card(player, -1))
	if visible.is_empty() and active.is_empty(): candidates.add_child(_empty_state("NO DISCOVERED PLAYERS", "A completed assignment will reveal between three and seven candidates depending on Analytics Lab level."))

func _filtered_market() -> Array:
	var filtered: Array = []
	for index in game.data.market.size():
		var player: Dictionary = game.data.market[index]
		var accepted := scout_filter == "ALL" or str(player.get("role", "")).to_upper() == scout_filter
		if scout_filter == "U23": accepted = int(player.get("age", 99)) < 23
		elif scout_filter == "HIGH POTENTIAL": accepted = int(player.get("potential", 0)) >= 78
		if accepted: filtered.append({"player":player, "index":index})
	filtered.sort_custom(func(a, b):
		var left: Dictionary = a.player; var right: Dictionary = b.player
		if scout_sort == "VALUE": return int(left.get("value", 0)) < int(right.get("value", 0))
		return int(left.get(scout_sort.to_lower(), 0)) > int(right.get(scout_sort.to_lower(), 0)))
	return filtered

func _tactics() -> void:
	_header("TACTICS ROOM", "Set the coaching framework; the IGL adapts to flight path, zone and confirmed information.", "TEAM POWER  %.1f" % game.get_team_power())
	var active_plan: Dictionary = game.data.get("coach_plan", {})
	var compact_layout := ResponsiveScript.is_compact(get_viewport_rect().size)
	var tactical_hero: BoxContainer = VBoxContainer.new() if compact_layout else HBoxContainer.new(); tactical_hero.add_theme_constant_override("separation",16); content.add_child(tactical_hero)
	var tactical_board:=UIComponentsScript.tactical_panel("MATCH PLAN BOARD"); tactical_board.custom_minimum_size=Vector2(0 if compact_layout else 720,270); tactical_board.size_flags_horizontal=Control.SIZE_EXPAND_FILL; tactical_hero.add_child(tactical_board); tactical_board.add_child(_formation_board())
	var tactical_brief:=UIComponentsScript.hero_panel("COACHING INTENT","The IGL can adapt this framework when confirmed information, resources, or the zone demand it.",CYAN); tactical_brief.custom_minimum_size.x=0 if compact_layout else 420; tactical_hero.add_child(tactical_brief)
	var tactical_signals: BoxContainer = HBoxContainer.new() if compact_layout else VBoxContainer.new(); tactical_signals.add_theme_constant_override("separation", 14); tactical_brief.add_child(tactical_signals)
	tactical_signals.add_child(_decision_signal("DROP",str(active_plan.get("drop_policy","UNAVAILABLE")).replace("_"," "),CYAN)); tactical_signals.add_child(_decision_signal("ZONE",str(active_plan.get("zone_macro","UNAVAILABLE")).replace("_"," "),ACCENT)); tactical_signals.add_child(_decision_signal("FORMATION",str(active_plan.get("formation","UNAVAILABLE")).replace("_"," "),ORANGE)); tactical_signals.add_child(_decision_signal("ENGAGEMENT",str(active_plan.get("engagement","UNAVAILABLE")).replace("_"," "),PURPLE))
	var preset_bar := _panel("TACTICAL PRESETS", PANEL_HIGH); content.add_child(preset_bar)
	preset_bar.add_child(_label("Apply a real coach-plan profile, then fine tune the tactical layers below.", 11, MUTED))
	var presets := HBoxContainer.new(); presets.add_theme_constant_override("separation", 8); preset_bar.add_child(presets)
	for preset in [["BALANCED", {"drop_policy":"ADAPTIVE","zone_macro":"CENTER","engagement":"SELECTIVE"}, CYAN], ["AGGRESSIVE EARLY", {"drop_policy":"HOT_CONTEST","zone_macro":"FAST","engagement":"AGGRESSIVE"}, DANGER], ["EDGE CONTROL", {"drop_policy":"FIXED_SAFE","zone_macro":"EDGE","engagement":"SELECTIVE"}, GOLD], ["LATE SURVIVAL", {"drop_policy":"SPLIT_LOOT","zone_macro":"LATE","engagement":"AVOID"}, SUCCESS]]:
		var preset_button := _button(str(preset[0]), false); preset_button.add_theme_color_override("font_color", preset[2]); preset_button.pressed.connect(func():
			var plan: Dictionary = game.data.get("coach_plan", {}).duplicate(true)
			for key in preset[1]: plan[key] = preset[1][key]
			game.set_coach_plan_values(plan); _notify("Tactical preset applied: %s" % str(preset[0])); _show_page("tactics"))
		presets.add_child(preset_button)
	var preset_actions := HBoxContainer.new(); preset_actions.add_theme_constant_override("separation", 8); preset_bar.add_child(preset_actions)
	var reset_preset := _button("RESET TO BALANCED", false); reset_preset.pressed.connect(func(): game.set_coach_plan_values({"drop_policy":"ADAPTIVE","zone_macro":"CENTER","formation":"TWO_TWO","engagement":"SELECTIVE","positioning":"CENTER_HOLD","spacing":"NORMAL","flank":"NONE","focus_fire":"FOCUS","target_priority":"LOWEST_HP","combat_range":"ADAPTIVE","information":"INFO_FIRST","resource":"MINIMAL"}); _show_page("tactics")); preset_actions.add_child(reset_preset)
	var apply_match := _button("APPLY TO MATCH  →", true); apply_match.pressed.connect(_show_page.bind("match")); preset_actions.add_child(apply_match)
	var board := GridContainer.new(); board.columns=2; board.add_theme_constant_override("h_separation",12); board.add_theme_constant_override("v_separation",12); content.add_child(board)
	_coach_selector(board,"drop_policy","DROP POLICY",_tactic_options("drop_policy"))
	_coach_selector(board,"zone_macro","ZONE MACRO",_tactic_options("zone_macro"))
	_coach_selector(board,"formation","FORMATION",_tactic_options("formation"))
	_coach_selector(board,"engagement","ENGAGEMENT",_tactic_options("engagement"))
	var layers := _panel("2D TACTICAL LAYERS", PANEL_HIGH); content.add_child(layers)
	var layer_grid := GridContainer.new(); layer_grid.columns = 2; layer_grid.add_theme_constant_override("h_separation", 12); layer_grid.add_theme_constant_override("v_separation", 12); layers.add_child(layer_grid)
	for spec in [["positioning","POSITIONING"],["spacing","TEAM SPACING"],["flank","FLANK PLAN"],["focus_fire","FOCUS FIRE"],["target_priority","TARGET PRIORITY"],["combat_range","COMBAT RANGE"],["information","INFORMATION"],["resource","RESOURCE STRATEGY"]]:
		_coach_selector(layer_grid, str(spec[0]), str(spec[1]), _tactic_options(str(spec[0])))
	var consequence := _panel("ACTIVE MATCH PLAN", PANEL); content.add_child(consequence)
	var impact := HBoxContainer.new(); impact.add_theme_constant_override("separation", SPACE_MD); consequence.add_child(impact)
	impact.add_child(_decision_signal("DROP", str(active_plan.get("drop_policy","UNAVAILABLE")).replace("_"," "), CYAN))
	impact.add_child(_decision_signal("ZONE", str(active_plan.get("zone_macro","UNAVAILABLE")).replace("_"," "), ACCENT))
	impact.add_child(_decision_signal("FORMATION", str(active_plan.get("formation","UNAVAILABLE")).replace("_"," "), ORANGE))
	impact.add_child(_decision_signal("ENGAGEMENT", str(active_plan.get("engagement","UNAVAILABLE")).replace("_"," "), PURPLE))
	tactical_preview = _label("", 1, Color.TRANSPARENT); tactical_preview.visible = false; consequence.add_child(tactical_preview); _refresh_tactical_preview()
	var insight := UIComponentsScript.tactical_panel("ANALYST DOCTRINE"); content.add_child(insight)
	insight.add_child(_tag("INFORMATION MODEL ACTIVE", ACCENT)); insight.add_child(_label("Vision and hearing create detection probability. Nearby teams may remain unconfirmed when terrain, noise, or scouting coverage blocks information.", 14, TEXT)); insight.add_child(_label("THE COACH SETS INTENT — THE IGL CONTROLS MICRO", 11, GOLD)); insight.add_child(_label("The IGL may override a late rotation when healing is low, zone damage is high, or the planned route is gatekept.", 12, MUTED))

func _tactic_options(category: String) -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/tactics/coach_presets.json"))
	var options: Array = []
	if not parsed is Dictionary: return options
	for preset in parsed.get(category, []): options.append([str(preset.get("id", "")), str(preset.get("name", ""))])
	return options

func _competition_logo_asset(competition_id: String) -> String:
	for competition in game.data.get("tournaments", []):
		if str(competition.get("id", "")) == competition_id: return str(competition.get("logo_asset_id", ""))
	return ""

func _calendar_page() -> void:
	var base := Time.get_unix_time_from_datetime_string(str(game.data.current_date) + "T00:00:00")
	var view := Time.get_datetime_dict_from_unix_time(base + int(game.data.calendar_month_offset) * 32 * 86400)
	_header("SEASON CALENDAR", "Matchdays, rounds and every active competition in one schedule.", "%02d / %04d" % [view.month, view.year])
	var view_tabs := HBoxContainer.new(); view_tabs.add_theme_constant_override("separation", 7); content.add_child(view_tabs)
	for mode in ["MONTH","WEEK","DAY"]:
		var tab := _button(mode, calendar_view == mode); tab.pressed.connect(func(): calendar_view = mode; _show_page("calendar")); view_tabs.add_child(tab)
	if calendar_view != "MONTH":
		var range_days := 1 if calendar_view == "DAY" else 7; var timeline := _panel("%s AGENDA" % calendar_view, PANEL_HIGH); content.add_child(timeline)
		var current_unix := Time.get_unix_time_from_datetime_string(str(game.data.current_date)+"T00:00:00")
		for offset in range_days:
			var date := Time.get_date_string_from_unix_time(current_unix + offset*86400); var day_events: Array = game.data.get("calendar_events",[]).filter(func(event): return str(event.get("date",""))==date and str(event.get("status","scheduled"))!="completed")
			var day_card := _panel(date + (" • TODAY" if offset==0 else ""), PANEL); timeline.add_child(day_card)
			if day_events.is_empty(): day_card.add_child(_label("No scheduled organization events.",12,MUTED))
			for event in day_events: day_card.add_child(_calendar_event_row(event))
		return
	var nav := HBoxContainer.new(); content.add_child(nav)
	for spec in [["← PREVIOUS MONTH", -1], ["CURRENT MONTH", 0], ["NEXT MONTH →", 1]]:
		var b := _button(spec[0], false); b.pressed.connect(func(): game.set_calendar_month_offset(0 if spec[1] == 0 else int(game.data.calendar_month_offset) + spec[1]); _show_page("calendar")); nav.add_child(b)
	var grid := GridContainer.new(); grid.columns = 7; grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; grid.add_theme_constant_override("h_separation", 7); grid.add_theme_constant_override("v_separation", 7); content.add_child(grid)
	for wd in ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]: var h := _label(wd, 12, MUTED); h.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; grid.add_child(h)
	var first_unix := Time.get_unix_time_from_datetime_string("%04d-%02d-01T00:00:00" % [view.year, view.month]); var first := Time.get_datetime_dict_from_unix_time(first_unix)
	for i in (int(first.weekday) + 6) % 7: var blank := Control.new(); blank.custom_minimum_size = Vector2(130, 1); blank.size_flags_horizontal = Control.SIZE_EXPAND_FILL; grid.add_child(blank)
	var following := Time.get_datetime_dict_from_unix_time(first_unix + 32 * 86400); var following_unix := Time.get_unix_time_from_datetime_string("%04d-%02d-01T00:00:00" % [following.year, following.month]); var days := int((following_unix - first_unix) / 86400); var events := game.get_month_events(int(view.year), int(view.month))
	for day in range(1, days + 1):
		var iso := "%04d-%02d-%02d" % [view.year, view.month, day]; var cell := _panel("", Color("101b26")); cell.custom_minimum_size = Vector2(130, 92); cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL; grid.add_child(cell); cell.add_child(_label("%02d" % day, 16, ACCENT if iso == str(game.data.current_date) else TEXT))
		for e in events:
			if str(e.date) == iso:
				var event_line := HBoxContainer.new(); event_line.add_theme_constant_override("separation", 4); cell.add_child(event_line)
				var logo_asset := _competition_logo_asset(str(e.get("tournament_id", "")))
				if not logo_asset.is_empty(): event_line.add_child(_team_logo(logo_asset, str(e.tournament).left(2), Vector2(20, 20)))
				else: event_line.add_child(_label(_event_icon(str(e.get("type","event"))), 12, _event_color(str(e.get("type","event")))))
				event_line.add_child(_tag(str(e.round), _event_color(str(e.get("type","event"))))); cell.add_child(_label(str(e.tournament), 10, MUTED))

func _calendar_event_row(event: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation",10); row.add_child(_tag("%s  %s" % [str(event.get("time","--:--")),_event_icon(str(event.get("type","event")))],_event_color(str(event.get("type","event"))))); var copy := VBoxContainer.new(); copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(copy); copy.add_child(_label(str(event.get("tournament",event.get("type","EVENT"))),14,TEXT)); copy.add_child(_label(str(event.get("round","Scheduled event")),11,MUTED)); row.add_child(_tag("ACTION" if bool(event.get("requires_player_action",false)) else "INFO",ORANGE if bool(event.get("requires_player_action",false)) else MUTED)); return row

func _event_color(type: String) -> Color:
	return GOLD if type=="match" else ACCENT if type=="training" else CYAN if type=="scrim" else ORANGE if type in ["facility","contract","deadline"] else PURPLE if type in ["media","board"] else MUTED

func _event_icon(type: String) -> String:
	return {"match":"◆","training":"▲","scrim":"◎","facility":"▣","contract":"✦","media":"●","board":"■"}.get(type,"•")

func _match_page() -> void:
	var latest_match: Dictionary = game.data.get("last_match", {})
	if not latest_match.is_empty() and str(latest_match.get("date", "")) == str(game.data.get("current_date", "")):
		_header("MATCH DAY", "Official result, MVP and tactical replay from the completed match.", "OFFICIAL RESULT")
		_match_result(latest_match)
		return
	var event := game.get_playable_match()
	if event.is_empty(): event = game.get_next_match(true)
	_header("MATCH DAY", "Prepare the lineup, tactical plan and competitive objective.", "BROADCAST READY")
	if event.is_empty(): content.add_child(_panel("NO MATCHES REMAIN THIS SEASON", PANEL)); return
	if game.data.last_match.is_empty() or str(game.data.last_match.get("event_id", "")) != str(event.id):
		var hero := _panel("", PANEL_HIGH); content.add_child(hero)
		var map := _asset_preview(_map_asset(str(event.map)), Vector2(920, 290)); hero.add_child(map)
		hero.add_child(_team_logo(str(game.data.get("active_tournament_logo_asset_id", "")), str(event.tournament).left(2), Vector2(68, 68)))
		hero.add_child(_tag(str(event.tournament).to_upper(), GOLD)); hero.add_child(_label(str(event.round), 32, TEXT)); hero.add_child(_label("%s  •  %s  •  %d TEAMS" % [event.date, event.map, int(event.teams)], 15, MUTED))
		var lobby_summary := _label("FULL LOBBY  •  %d teams compete simultaneously  •  placement + kills determine points" % int(event.teams), 13, CYAN); hero.add_child(lobby_summary)
		var info := HBoxContainer.new(); info.add_theme_constant_override("separation", 10); hero.add_child(info)
		info.add_child(_visual_stat("TEAM POWER", roundi(game.get_team_power()), ACCENT, "Active squad")); info.add_child(_visual_stat("ENERGY", _average("energy"), _metric_color(_average("energy")), "4 starters")); info.add_child(_visual_stat("LOBBY", int(event.get("teams",0)), GOLD, "Teams")); info.add_child(_visual_stat("FORMAT", "PLACEMENT + KILLS", ORANGE, "Scoring"))
		hero.add_child(_label("WEATHER  UNAVAILABLE  •  PRIZE POOL  $%s" % GameStateScript.money(int(game.data.get("active_tournament_prize_pool",0))), 12, MUTED))
		var plan := _panel("MATCH PLAN", PANEL); content.add_child(plan); plan.add_child(_label("%s   →   %s   →   %s" % [_tactic_display_name(str(game.data.tactics.early)), _tactic_display_name(str(game.data.tactics.mid)), _tactic_display_name(str(game.data.tactics.late))], 17, TEXT))
		var intel := _panel("OPPONENT INTELLIGENCE", PANEL); content.add_child(intel)
		var opponent := _featured_opponent(); intel.add_child(_action_row("SCOUT", str(opponent.get("name","Lobby opponent")), "Power %d • Form %d • Region %s" % [int(opponent.get("power",0)),int(opponent.get("form",0)),str(opponent.get("region","Unknown"))], PURPLE))
		var phases := _panel("MATCH DECISION LAYER", PANEL_HIGH); content.add_child(phases); phases.add_child(_label("These choices become small tactical modifiers for the next simulation; MatchRuntime remains unchanged.", 12, MUTED))
		for phase in ["EARLY","MID","END"]:
			var row := HBoxContainer.new(); row.add_child(_label(phase + " GAME", 12, CYAN));
			for decision in ["FIGHT","ROTATE","HOLD"]:
				var choice := _button(decision, str(game.data.get("match_decisions",{}).get(phase,"")) == decision); choice.tooltip_text = "+ kills / risk" if decision=="FIGHT" else "+ placement / time" if decision=="ROTATE" else "+ survival / loot"; choice.pressed.connect(func(): game.set_match_decision(phase,decision); _show_page("match")); row.add_child(choice)
			phases.add_child(row)
		var sim := _button("START LIVE MATCH", true); sim.custom_minimum_size.y = 56; sim.pressed.connect(func():
			if game.get_playable_match().is_empty(): game.advance_to_next_match()
			var live_event := game.get_playable_match()
			var context := game.prepare_match_context(live_event)
			if not bool(context.get("ok", false)): _notify(str(context.get("error", "Match context failed"))); return
			var selection := game.set_active_match_event(str(live_event.get("id", "")))
			if not bool(selection.get("ok", false)):
				_notify(str(selection.get("message", "Match selection failed.")))
				return
			match_runtime_is_career = true; match_final_result.clear()
			match_runtime.start_match(game.data, str(live_event.get("map", "verdant_reach")), game.effective_match_plan()); match_ui_mode = "observer"; _show_page("match_lab")
		); content.add_child(sim)
	else: _match_result(game.data.last_match)

func _match_result(m: Dictionary) -> void:
	var own_points := 0
	for row in m.get("scoreboard", []):
		if str(row.get("tag", "")) == "MR": own_points = int(row.get("points", 0)); break
	var result := _panel("MATCH RESULT", PANEL_HIGH); content.add_child(result); result.add_child(_tag("FINAL PLACEMENT", GOLD)); result.add_child(_label("#%d" % int(m.get("placement", 16)), 52, TEXT)); result.add_child(_label("%d KILLS  •  %d POINTS  •  %d DAMAGE" % [int(m.get("kills", 0)), int(m.get("points", own_points)), int(m.get("damage", 0))], 17, ACCENT)); result.add_child(_tactical_replay(m))
	var split := HBoxContainer.new(); split.add_theme_constant_override("separation", 16); content.add_child(split)
	var players := _panel("MVP RATING", PANEL); players.size_flags_horizontal = Control.SIZE_EXPAND_FILL; split.add_child(players)
	for stat in m.get("player_stats", []): players.add_child(_rating_row(stat))
	var log := _panel("TEAMFIGHT LOG", PANEL); log.size_flags_horizontal = Control.SIZE_EXPAND_FILL; split.add_child(log)
	for entry in m.get("decision_log", []): log.add_child(_label(str(entry.get("text", entry.get("reason", ""))) if entry is Dictionary else str(entry), 12, MUTED))
	var timeline := _panel("REPLAY TIMELINE", PANEL); content.add_child(timeline)
	for e in m.get("timeline", []):
		var event_time := float(e.get("time", float(e.get("minute", 0)) * 60.0 + float(e.get("second", 0))))
		timeline.add_child(_action_row("%02d:%02d" % [int(event_time) / 60, int(event_time) % 60], str(e.get("phase", "MATCH")), str(e.get("text", e.get("reason", ""))), GOLD if str(e.get("type", "")) == "result" else CYAN))

func _match_gameplay_lab() -> void:
	match_lab_nodes.clear()
	match_loadout_signature=""; match_killfeed_signature=""; match_scoreboard_signature=""
	last_match_panel_second=-1
	if not match_runtime.running and match_runtime.elapsed <= 0.0:
		match_runtime.start_match(game.data)
	var lab_available := bool(game.data.get("developer_mode", false))
	var compact_match := ResponsiveScript.is_compact(get_viewport_rect().size)
	if match_ui_mode == "lab" and not lab_available:
		match_ui_mode = "observer"
	if match_ui_mode == "lab":
		_header("MATCH GAMEPLAY LAB", "AI, tactics, speed and diagnostic data", "DEVELOPER MODE")
	else:
		_header("MATCH OBSERVER  •  %s" % str(match_runtime.map_data.get("display_name", "TACTICAL MAP")), "Live simulation • Observer view", "BROADCAST OBSERVER")
	if not match_final_result.is_empty():
		_match_final_screen(match_final_result)
		return
	var controls := HBoxContainer.new(); controls.add_theme_constant_override("separation", 8); content.add_child(controls)
	var observer_mode := _button("OBSERVER", match_ui_mode=="observer"); observer_mode.icon=assets.texture("icons.navigation.match"); observer_mode.pressed.connect(_set_match_ui_mode.bind("observer")); controls.add_child(observer_mode)
	if lab_available:
		var lab_mode := _button("LAB", match_ui_mode=="lab"); lab_mode.icon=assets.texture("icons.navigation.settings"); lab_mode.pressed.connect(_set_match_ui_mode.bind("lab")); controls.add_child(lab_mode)
	if match_ui_mode == "lab":
		var restart := _button("NEW MATCH", false); restart.icon=assets.texture("icons.replay.stop"); restart.pressed.connect(_restart_match_lab); controls.add_child(restart)
		var pause := _button("", true); pause.tooltip_text="Pause / Resume"; pause.icon=assets.texture("icons.replay.pause"); pause.custom_minimum_size.x=48; pause.pressed.connect(match_runtime.toggle_pause); controls.add_child(pause)
		for value in [1, 4, 16, 32]: var speed_button := _button("%dX" % value, false); speed_button.pressed.connect(match_runtime.set_speed.bind(float(value))); controls.add_child(speed_button)
		var manager := _button("MAP MANAGER", false); manager.icon=assets.texture("icons.navigation.settings"); manager.pressed.connect(_show_page.bind("map_manager")); controls.add_child(manager)
	var zoom_out := _button("−", false); zoom_out.tooltip_text="Zoom out  [−]"; zoom_out.pressed.connect(_zoom_match_at_selected.bind(-0.25)); controls.add_child(zoom_out)
	var zoom_in := _button("+", false); zoom_in.tooltip_text="Zoom in  [+]"; zoom_in.pressed.connect(_zoom_match_at_selected.bind(0.25)); controls.add_child(zoom_in)
	var zoom_reset := _button("1:1", false); zoom_reset.tooltip_text="Reset zoom  [0] • Pan [WASD/Arrow] • Drag [Middle mouse]"; zoom_reset.pressed.connect(_reset_match_zoom); controls.add_child(zoom_reset)
	if match_visible_teams.is_empty(): for team in match_runtime.team_positions: match_visible_teams[str(team.tag)]=true
	var filter_button:=MenuButton.new(); filter_button.text="TEAMS"; filter_button.tooltip_text="Select the displayed team"; filter_button.icon=assets.texture("icons.navigation.roster"); controls.add_child(filter_button); match_lab_nodes.team_filter=filter_button
	var filter_popup:=filter_button.get_popup()
	for team_index in match_runtime.team_positions.size(): filter_popup.add_check_item("%s  %s" % [match_runtime.team_positions[team_index].tag,match_runtime.team_positions[team_index].name],team_index); filter_popup.set_item_checked(team_index,bool(match_visible_teams.get(str(match_runtime.team_positions[team_index].tag),true)))
	filter_popup.id_pressed.connect(_toggle_match_team_filter)
	var dead_filter:=CheckButton.new(); dead_filter.text="DEAD"; dead_filter.tooltip_text="Show eliminated players"; dead_filter.button_pressed=match_show_dead; dead_filter.icon=assets.texture("icons.combat.kill"); dead_filter.toggled.connect(_set_show_dead); controls.add_child(dead_filter)
	var spacer:=Control.new(); spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL; controls.add_child(spacer)
	var exit := _button("EXIT", false); exit.icon=assets.texture("icons.navigation.close"); exit.pressed.connect(_show_page.bind("dashboard")); controls.add_child(exit)
	if match_ui_mode == "lab":
		var plan := HBoxContainer.new(); plan.add_theme_constant_override("separation",8); content.add_child(plan)
		_coach_selector(plan,"drop_policy","Drop",[["FIXED_SAFE","Safe"],["ADAPTIVE","Adaptive"],["HOT_CONTEST","Hot"],["SPLIT_LOOT","Split Loot"]],true)
		_coach_selector(plan,"zone_macro","Macro",[["EDGE","Edge"],["CENTER","Center"],["FAST","Fast Rotate"],["LATE","Late Rotate"]],true)
		_coach_selector(plan,"formation","Formation",[["STACK","4 Stack"],["TWO_TWO","2-2"],["ONE_THREE","1-3"],["FOUR_WAY","4-way"],["ANCHOR_THREE","Anchor+3"]],true)
		_coach_selector(plan,"engagement","Fight",[["AVOID","Avoid"],["SELECTIVE","Selective"],["AGGRESSIVE","Push"],["THIRD_PARTY","Third-party"]],true)
	var metrics := HBoxContainer.new(); metrics.add_theme_constant_override("separation", 10); content.add_child(metrics)
	var metric_keys := ["clock", "alive", "zone"] if match_ui_mode=="observer" else ["clock", "phase", "teams", "alive", "zone", "morale"]
	for key in metric_keys:
		var card := _observer_panel() if match_ui_mode=="observer" else _panel(key.to_upper(), PANEL_HIGH); card.size_flags_horizontal = Control.SIZE_EXPAND_FILL; card.add_child(_label(key.to_upper(),10,MUTED)); var value_label := _label("--", 24 if match_ui_mode=="observer" and compact_match else 32 if match_ui_mode=="observer" else 25, ACCENT); card.add_child(value_label); metrics.add_child(card); match_lab_nodes[key] = value_label
	var split: BoxContainer = VBoxContainer.new() if compact_match else HBoxContainer.new(); split.add_theme_constant_override("separation", 14); content.add_child(split)
	var map_size:=920 if match_ui_mode=="observer" and compact_match else 700 if match_ui_mode=="observer" else 620
	var tactical := _observer_panel() if match_ui_mode=="observer" else _panel("Tactical map", PANEL_HIGH); tactical.custom_minimum_size.x=map_size+24; tactical.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tactical.size_flags_stretch_ratio=1.35 if match_ui_mode=="observer" else 1.0; split.add_child(tactical)
	var map_layer := Control.new(); map_layer.custom_minimum_size = Vector2(map_size, map_size); map_layer.size_flags_horizontal=Control.SIZE_EXPAND_FILL; map_layer.clip_contents=true; tactical.add_child(map_layer); match_lab_nodes.map_view=map_layer
	var map_canvas := Control.new(); map_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); map_canvas.pivot_offset=Vector2(map_size/2.0,map_size/2.0); map_layer.add_child(map_canvas); match_lab_nodes.map_canvas=map_canvas
	var map := _asset_preview(str(match_runtime.map_data.get("asset_id", "match.map.verdant_reach")), Vector2(map_size, map_size)); map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); map_canvas.add_child(map)
	var blue := ColorRect.new(); blue.mouse_filter = Control.MOUSE_FILTER_IGNORE; blue.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new(); shader.code = "shader_type canvas_item; uniform vec2 center=vec2(0.5); uniform float radius=1.0; uniform float aspect=2.0; uniform float strength=0.0; void fragment(){vec2 d=UV-center; d.x*=aspect; float outside=smoothstep(radius-0.012,radius,length(d)); COLOR=vec4(0.08,0.30,0.78,outside*strength);}"
	var material := ShaderMaterial.new(); material.shader = shader; blue.material = material; map_canvas.add_child(blue); match_lab_nodes.blue_zone = blue
	var red := ColorRect.new(); red.mouse_filter = Control.MOUSE_FILTER_IGNORE; red.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var red_shader := Shader.new(); red_shader.code = "shader_type canvas_item; uniform vec2 center=vec2(0.5); uniform float radius=0.0; uniform float aspect=1.0; uniform float strength=0.0; void fragment(){vec2 d=UV-center; d.x*=aspect; float inside=1.0-smoothstep(radius-0.010,radius,length(d)); float ring=smoothstep(radius-0.018,radius-0.010,length(d))*(1.0-smoothstep(radius-0.010,radius+0.002,length(d))); COLOR=vec4(0.95,0.12,0.16,max(inside*0.15,ring)*strength);}"
	var red_material := ShaderMaterial.new(); red_material.shader = red_shader; red.material = red_material; map_canvas.add_child(red); match_lab_nodes.red_zone = red
	var overlay := MatchMapOverlayScript.new(); overlay.mouse_filter = Control.MOUSE_FILTER_STOP; overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.set_map(match_runtime.map_data); overlay.player_selected.connect(_select_own_match_player); overlay.world_player_selected.connect(_select_world_match_player); overlay.zoom_requested.connect(_zoom_match_at_cursor); overlay.pan_requested.connect(_pan_match_map); map_canvas.add_child(overlay); match_lab_nodes.map_overlay = overlay
	var strategy := _label("AI MACRO: --", 13, GOLD); tactical.add_child(strategy); strategy.visible=match_ui_mode=="lab"; match_lab_nodes.strategy = strategy
	var timeline_strip:=HBoxContainer.new(); timeline_strip.add_theme_constant_override("separation",6); tactical.add_child(timeline_strip); timeline_strip.add_child(_asset_preview("icons.replay.zone",Vector2(22,22))); var zone_history:=_label("Circle timeline",11,MUTED); zone_history.size_flags_horizontal=Control.SIZE_EXPAND_FILL; timeline_strip.add_child(zone_history); match_lab_nodes.zone_history=zone_history
	var right_scroll := ScrollContainer.new(); right_scroll.custom_minimum_size.x = 410 if match_ui_mode=="observer" else 520; right_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL; right_scroll.size_flags_stretch_ratio=0.85 if match_ui_mode=="observer" else 1.0; right_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; split.add_child(right_scroll)
	var right := VBoxContainer.new(); right.custom_minimum_size.x = 410 if match_ui_mode=="observer" else 520; right.size_flags_horizontal=Control.SIZE_EXPAND_FILL; right.add_theme_constant_override("separation", 8); right_scroll.add_child(right)
	var squad := _observer_panel() if match_ui_mode=="observer" else _panel("All players", PANEL); right.add_child(squad); match_lab_nodes.roster_rows=[]
	var team_selector := OptionButton.new(); team_selector.custom_minimum_size.y=34; squad.add_child(team_selector); match_lab_nodes.team_selector=team_selector
	for team in match_runtime.team_positions: team_selector.add_item("%s  •  %s" % [team.tag,team.name])
	team_selector.item_selected.connect(_select_match_team)
	for i in 4: var row := _button("PLAYER",false); row.custom_minimum_size.y=38; row.pressed.connect(_select_match_player.bind(i)); squad.add_child(row); match_lab_nodes.roster_rows.append(row)
	var loadout := _observer_panel() if match_ui_mode=="observer" else _panel("Selected player", PANEL_HIGH); right.add_child(loadout); match_lab_nodes.loadout_panel=loadout
	var columns:=HBoxContainer.new(); columns.add_theme_constant_override("separation",8); right.add_child(columns)
	var killfeed := _observer_panel() if match_ui_mode=="observer" else _panel("Kill feed", PANEL); killfeed.size_flags_horizontal=Control.SIZE_EXPAND_FILL; columns.add_child(killfeed); match_lab_nodes.kill_feed=killfeed
	var scores := _observer_panel() if match_ui_mode=="observer" else _panel("Ranking", PANEL); scores.size_flags_horizontal=Control.SIZE_EXPAND_FILL; columns.add_child(scores); match_lab_nodes.scoreboard=scores
	match_lab_nodes.resource_rows = {}
	if match_ui_mode == "lab":
		var economy := _panel("Match resources", PANEL); right.add_child(economy)
		for key in ["ammo", "heal", "throwables", "armor", "fuel"]: var row := _label("", 11, MUTED); economy.add_child(row); match_lab_nodes.resource_rows[key] = row
		var feed := _panel("Decision & event log", PANEL); right.add_child(feed); match_lab_nodes.event_feed = feed
	_refresh_match_lab(match_runtime.snapshot())
	if match_lab_nodes.has("event_feed"): _refresh_match_feed(match_runtime.snapshot().timeline)
	_apply_match_zoom()

func _on_match_runtime_updated(snapshot: Dictionary) -> void:
	if active_page != "match_lab" or match_lab_nodes.is_empty() or match_selector_popup_open: return
	var now:=Time.get_ticks_msec()
	if now-match_ui_last_refresh_msec<50: return
	match_ui_last_refresh_msec=now
	_refresh_match_lab(snapshot)

func _on_match_event(_event: Dictionary) -> void:
	if active_page == "match_lab" and match_lab_nodes.has("event_feed"): _refresh_match_feed(match_runtime.timeline)

func _on_match_finished(result:Dictionary)->void:
	match_final_result=result.duplicate(true)
	if match_runtime_is_career:
		var commit := game.apply_match_runtime_result(result, game.get_playable_match())
		match_final_result["career_commit"] = commit
		match_runtime_is_career = false
	if active_page=="match_lab": call_deferred("_show_page","match_lab")

func _restart_match_lab()->void:
	match_final_result.clear(); match_map_zoom=1.0
	match_runtime.start_match(game.data)
	_show_page("match_lab")

func _match_final_screen(result:Dictionary)->void:
	var winner:Dictionary=result.get("winner",{}); var winner_name:=str(winner.get("name",winner.get("tag","UNKNOWN")))
	var hero:=_panel("MATCH COMPLETE",Color("18180c")); hero.add_child(_label("WINNER! WINNER! CHICKEN DINNER!",42,GOLD)); hero.add_child(_label(winner_name,30,TEXT)); hero.add_child(_label("%d KILLS  •  %d POINTS  •  %02d:%02d" % [winner.get("kills",0),winner.get("points",0),int(result.get("duration",0))/60,int(result.get("duration",0))%60],16,GOLD)); content.add_child(hero)
	var mvp_stats: Array = result.get("player_stats", []).duplicate(true)
	if not mvp_stats.is_empty():
		mvp_stats.sort_custom(func(a, b): return int(a.get("kills", 0)) * 500 + int(a.get("damage", 0)) + int(a.get("revives", 0)) * 180 + (300 if bool(a.get("survived", false)) else 0) > int(b.get("kills", 0)) * 500 + int(b.get("damage", 0)) + int(b.get("revives", 0)) * 180 + (300 if bool(b.get("survived", false)) else 0))
		var mvp: Dictionary = mvp_stats[0]
		hero.add_child(_label("MVP  •  %s (%s)  •  %d KILLS  •  %d DAMAGE  •  %d REVIVES" % [mvp.get("name", "Unknown"), mvp.get("team", ""), mvp.get("kills", 0), mvp.get("damage", 0), mvp.get("revives", 0)], 14, ACCENT))
	var actions:=HBoxContainer.new(); actions.add_theme_constant_override("separation",8); content.add_child(actions); var rematch:=_button("NEW MATCH",true); rematch.icon=assets.texture("icons.replay.play"); rematch.pressed.connect(_restart_match_lab); actions.add_child(rematch); var exit:=_button("COMMAND CENTER",false); exit.icon=assets.texture("icons.navigation.home"); exit.pressed.connect(_show_page.bind("dashboard")); actions.add_child(exit)
	var scoreboard: Array = result.get("scoreboard", [])
	var standings:=_panel("FINAL STANDINGS — %d TEAMS" % scoreboard.size(),PANEL_HIGH); content.add_child(standings); standings.add_child(_label("RK   TEAM                         ALIVE   KILLS   DAMAGE   POINTS",11,CYAN))
	var standings_grid := GridContainer.new(); standings_grid.columns=2; standings_grid.add_theme_constant_override("h_separation",28); standings_grid.add_theme_constant_override("v_separation",5); standings.add_child(standings_grid)
	for row in scoreboard:
		var standing_line := _label("%02d   %-24s   A%d  K%d  D%d  P%d" % [row.rank,"%s  %s" % [row.tag,row.name],row.alive,row.kills,row.damage,row.points],12,GOLD if int(row.rank)<=3 else ACCENT if str(row.tag)=="MR" else TEXT); standing_line.custom_minimum_size.x=620; standings_grid.add_child(standing_line)
	var player_stats: Array = result.get("player_stats", [])
	var players:=_panel("PLAYER STATISTICS — %d PLAYERS" % player_stats.size(),PANEL); content.add_child(players); var grid:=GridContainer.new(); grid.columns=2; grid.add_theme_constant_override("h_separation",24); grid.add_theme_constant_override("v_separation",4); players.add_child(grid)
	for player in player_stats: var line:=_label("%-4s %-16s %-10s  K%-2d  DMG %-4d  ACC %02d%%  %d/%d SHOTS  REV %d  %s" % [player.team,player.name,player.role,player.kills,player.damage,player.get("accuracy",0),player.get("hits",0),player.get("shots",0),player.get("revives",0),"SURVIVED" if player.survived else "OUT"],10,SUCCESS if player.survived else MUTED); line.custom_minimum_size.x=700; grid.add_child(line)

func _refresh_match_lab(state: Dictionary) -> void:
	if match_lab_nodes.is_empty(): return
	match_lab_nodes.clock.text = "%02d:%02d" % [int(state.elapsed) / 60, int(state.elapsed) % 60]
	if match_lab_nodes.has("phase"): match_lab_nodes.phase.text = str(state.phase)
	if match_lab_nodes.has("teams"): match_lab_nodes.teams.text = "%d / %d" % [state.teams_alive, match_runtime.team_positions.size()]
	match_lab_nodes.alive.text = str(state.players_alive)
	var severity:=str(["SAFE","VERY LOW","LOW","MEDIUM","ELEVATED","HIGH"][clampi(int(state.zone_number),0,5)])
	match_lab_nodes.zone.text = "Z%d • %s • %d DMG" % [state.zone_number,severity,state.blue_damage] if ResponsiveScript.is_compact(get_viewport_rect().size) else "BO %d  •  %s  •  %d dmg" % [state.zone_number,severity,state.blue_damage]
	if match_lab_nodes.has("morale"): match_lab_nodes.morale.text = "%d%%" % state.morale
	match_lab_nodes.strategy.text = "AI MACRO: %s  •  %s  •  CONTACT %d/%d  •  SPEED %sX%s" % [state.strategy, state.formation, state.confirmed_contacts, state.detection_attempts, state.speed, "  •  PAUSED" if state.paused else ""]
	match_lab_nodes.zone_history.text="BO %d  →  %s  •  %d alive  •  %d teams" % [state.zone_number,str(state.phase),state.players_alive,state.teams_alive]
	var display_state:=state.duplicate(true); display_state.visible_team_tags=match_visible_teams.duplicate(); display_state.show_dead=match_show_dead; display_state.selected_team=selected_match_team; display_state.selected_player=selected_match_player
	var overlay: Control = match_lab_nodes.map_overlay; overlay.set_state(display_state)
	var map_size: Vector2 = Vector2(match_lab_nodes.map_canvas.size)
	var map_aspect := map_size.x / maxf(1.0, map_size.y)
	var material: ShaderMaterial = match_lab_nodes.blue_zone.material; material.set_shader_parameter("center", Vector2(float(state.zone_center[0]), float(state.zone_center[1]))); material.set_shader_parameter("radius", float(state.blue_radius)); material.set_shader_parameter("aspect", map_aspect); material.set_shader_parameter("strength", 0.42 if int(state.zone_number) > 0 else 0.0)
	if match_lab_nodes.has("red_zone"):
		var red_state: Dictionary = state.get("red_zone", {}); var red_center: Array = red_state.get("center", [0.5, 0.5]); var red_material: ShaderMaterial = match_lab_nodes.red_zone.material; red_material.set_shader_parameter("center", Vector2(float(red_center[0]), float(red_center[1]))); red_material.set_shader_parameter("radius", float(red_state.get("radius", 0.0))); red_material.set_shader_parameter("aspect", map_aspect); red_material.set_shader_parameter("strength", 1.0 if bool(red_state.get("active", false)) else 0.0)
	var selected_squad: Array = state.roster if selected_match_team==0 else state.team_positions[selected_match_team].members
	for i in mini(selected_squad.size(), match_lab_nodes.roster_rows.size()):
		var p: Dictionary = selected_squad[i]; var row: Button = match_lab_nodes.roster_rows[i]; row.text = "%s  %-14s  %3d HP   K%d   DMG%d   %d/%d SHOTS   %s   %s" % ["●" if i==selected_match_player else "○",p.name,p.get("health",100),p.get("kills",0),p.get("damage",0),p.get("hits",0),p.get("shots",0),_short_weapon(str(p.get("loadout",{}).get("primary","—"))),_status_symbol(str(p.state))]; row.icon=assets.texture(_status_asset(str(p.state)))
	for key in match_lab_nodes.resource_rows: match_lab_nodes.resource_rows[key].text = "%-12s %s" % [str(key).to_upper(),str(state.resources.get(key,0))]
	_refresh_selected_loadout(state); _refresh_kill_feed(state.kill_feed); _refresh_scoreboard(state.scoreboard)

func _map_manager_page() -> void:
	match_lab_nodes.clear(); map_editor_controls.clear()
	if map_editor_data.is_empty(): map_editor_data = map_catalog.load_map("verdant_reach")
	_header("MAP MANAGER", "Tune loot, heat and traversal through descriptors; changes apply to new matches", "DATA-DRIVEN TOOL")
	var toolbar := HBoxContainer.new(); toolbar.add_theme_constant_override("separation", 8); content.add_child(toolbar)
	for id in ["verdant_reach", "sunscorch_basin", "tactical_island", "frostline_valley", "coastal_breakwater", "highland_reserve"]:
		var choose := _button(id.to_upper(), str(map_editor_data.get("id", "")) == id); choose.pressed.connect(func(): map_editor_data = map_catalog.load_map(id); _show_page("map_manager")); toolbar.add_child(choose)
	var save := _button("SAVE OVERRIDE", true); save.pressed.connect(func(): _notify("Map override saved." if map_catalog.save_override(map_editor_data) else "The map descriptor is invalid.")); toolbar.add_child(save)
	save.icon=assets.texture("icons.navigation.save"); save.expand_icon=true
	var add_region:=_button("ADD REGION",false); add_region.icon=assets.texture("icons.replay.zone"); add_region.expand_icon=true; add_region.pressed.connect(_add_map_region); toolbar.add_child(add_region)
	var add_point:=_button("ADD LOOT POINT",false); add_point.icon=assets.texture("icons.replay.loot"); add_point.expand_icon=true; add_point.pressed.connect(_add_map_point); toolbar.add_child(add_point)
	var reset := _button("RESET DEFAULT", false); reset.pressed.connect(func(): var id := str(map_editor_data.id); map_catalog.reset_override(id); map_editor_data = map_catalog.load_map(id); _show_page("map_manager")); toolbar.add_child(reset)
	var back := _button("BACK TO LAB", false); back.pressed.connect(_show_page.bind("match_lab")); toolbar.add_child(back)
	var split := HBoxContainer.new(); split.add_theme_constant_override("separation", 14); content.add_child(split)
	var preview := _panel("MAP PREVIEW — YELLOW = LOOT ENABLED", PANEL_HIGH); preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL; split.add_child(preview)
	var layer := Control.new(); layer.custom_minimum_size = Vector2(900, 600); preview.add_child(layer)
	var image := _asset_preview(str(map_editor_data.asset_id), Vector2(900, 600)); image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); layer.add_child(image)
	var map_overlay := MatchMapOverlayScript.new(); map_overlay.mouse_filter = Control.MOUSE_FILTER_STOP; map_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); map_overlay.set_map(map_editor_data); map_overlay.enable_editor(); map_overlay.editor_item_moved.connect(_on_map_editor_item_moved); layer.add_child(map_overlay); match_lab_nodes.map_editor_overlay=map_overlay
	var settings := _panel("MASTER LIST & DETAIL INSPECTOR", PANEL); settings.custom_minimum_size.x = 600; split.add_child(settings)
	settings.add_child(_label("MASTER LIST", 14, GOLD))
	for i in map_editor_data.get("regions", []).size():
		var region_master := _button("REGION  %s" % str(map_editor_data.regions[i].get("name", "Unnamed")), map_editor_selected_kind == "region" and map_editor_selected_index == i); region_master.pressed.connect(_select_map_editor_item.bind("region", i)); settings.add_child(region_master)
	for i in map_editor_data.get("points", []).size():
		var point_master := _button("POINT   %s" % str(map_editor_data.points[i].get("name", "Unnamed")), map_editor_selected_kind == "point" and map_editor_selected_index == i); point_master.pressed.connect(_select_map_editor_item.bind("point", i)); settings.add_child(point_master)
	settings.add_child(HSeparator.new())
	settings.add_child(_label("DETAIL INSPECTOR", 14, GOLD))
	settings.add_child(_label("Select an item from Master List, or drag it on the map. Coordinates update immediately.", 11, MUTED))
	settings.add_child(_label("REGION DETAIL", 13, CYAN))
	for i in map_editor_data.get("regions", []).size():
		var region: Dictionary = map_editor_data.regions[i]
		var row := VBoxContainer.new(); row.visible = map_editor_selected_kind == "region" and map_editor_selected_index == i; settings.add_child(row); var identity:=HBoxContainer.new(); row.add_child(identity); var region_name:=LineEdit.new(); region_name.text=str(region.name); region_name.placeholder_text="Region name"; region_name.custom_minimum_size.x=220; region_name.text_changed.connect(func(value): map_editor_data.regions[i].name=value; _refresh_map_editor_preview()); identity.add_child(region_name); var terrain:=OptionButton.new(); for terrain_name in ["urban","forest","field","rock","industrial","water","road"]: terrain.add_item(terrain_name); if terrain_name==str(region.terrain): terrain.select(terrain.item_count-1); terrain.item_selected.connect(_on_map_region_terrain_selected.bind(i)); identity.add_child(terrain)
		var geometry:=HBoxContainer.new(); row.add_child(geometry); var rx:=_map_number_editor(geometry,"X",float(region.position[0]),0.0,1.0,0.01,func(value): map_editor_data.regions[i].position[0]=value; _refresh_map_editor_preview()); var ry:=_map_number_editor(geometry,"Y",float(region.position[1]),0.0,1.0,0.01,func(value): map_editor_data.regions[i].position[1]=value; _refresh_map_editor_preview()); map_editor_controls["region:%d:x"%i]=rx; map_editor_controls["region:%d:y"%i]=ry; _map_number_editor(geometry,"R",float(region.get("radius",0.08)),0.01,0.30,0.01,func(value): map_editor_data.regions[i].radius=value; _refresh_map_editor_preview()); var remove_region:=_button("REMOVE",false); remove_region.pressed.connect(_remove_map_region.bind(i)); geometry.add_child(remove_region)
		var loot := HBoxContainer.new(); row.add_child(loot); var loot_label := _label("Loot ×%.2f" % float(region.loot_multiplier), 12, MUTED); loot_label.custom_minimum_size.x=110; loot.add_child(loot_label); var loot_slider := HSlider.new(); loot_slider.min_value=0.0; loot_slider.max_value=2.5; loot_slider.step=0.05; loot_slider.value=float(region.loot_multiplier); loot_slider.custom_minimum_size.x=250; loot_slider.value_changed.connect(func(value): map_editor_data.regions[i].loot_multiplier=value; loot_label.text="Loot ×%.2f" % value; _refresh_map_editor_preview()); loot.add_child(loot_slider)
		var heat := HBoxContainer.new(); row.add_child(heat); var heat_label := _label("Hotness %.0f%%" % (float(region.hotness)*100.0), 12, MUTED); heat_label.custom_minimum_size.x=110; heat.add_child(heat_label); var heat_slider := HSlider.new(); heat_slider.min_value=0.0; heat_slider.max_value=1.0; heat_slider.step=0.05; heat_slider.value=float(region.hotness); heat_slider.custom_minimum_size.x=250; heat_slider.value_changed.connect(func(value): map_editor_data.regions[i].hotness=value; heat_label.text="Hotness %.0f%%" % (value*100.0)); heat.add_child(heat_slider)
	settings.add_child(_label("POINT DETAIL", 13, CYAN))
	for i in map_editor_data.get("points", []).size():
		var point: Dictionary = map_editor_data.points[i]; var point_box:=VBoxContainer.new(); point_box.visible = map_editor_selected_kind == "point" and map_editor_selected_index == i; settings.add_child(point_box); var point_identity:=HBoxContainer.new(); point_box.add_child(point_identity); var enabled := CheckBox.new(); enabled.button_pressed=bool(point.enabled); enabled.icon=assets.texture("icons.replay.loot"); enabled.toggled.connect(func(value): map_editor_data.points[i].enabled=value; _refresh_map_editor_preview()); point_identity.add_child(enabled); var point_name:=LineEdit.new(); point_name.text=str(point.name); point_name.custom_minimum_size.x=190; point_name.text_changed.connect(func(value): map_editor_data.points[i].name=value; _refresh_map_editor_preview()); point_identity.add_child(point_name); var point_type:=OptionButton.new(); for type_name in ["house","compound","bridge","warehouse","tower","container","vehicle_spawn","airdrop"]: point_type.add_item(type_name); if type_name==str(point.get("type","house")): point_type.select(point_type.item_count-1); point_type.item_selected.connect(_on_map_point_type_selected.bind(i)); point_identity.add_child(point_type)
		var point_row := HBoxContainer.new(); point_box.add_child(point_row); var px:=_map_number_editor(point_row,"X",float(point.position[0]),0.0,1.0,0.01,func(value): map_editor_data.points[i].position[0]=value; _refresh_map_editor_preview()); var py:=_map_number_editor(point_row,"Y",float(point.position[1]),0.0,1.0,0.01,func(value): map_editor_data.points[i].position[1]=value; _refresh_map_editor_preview()); map_editor_controls["point:%d:x"%i]=px; map_editor_controls["point:%d:y"%i]=py; _map_number_editor(point_row,"LOOT",float(point.loot_multiplier),0.0,2.5,0.05,func(value): map_editor_data.points[i].loot_multiplier=value; _refresh_map_editor_preview()); _map_number_editor(point_row,"CAP",float(point.get("capacity",8)),1.0,100.0,1.0,func(value): map_editor_data.points[i].capacity=roundi(value)); var remove_point:=_button("REMOVE",false); remove_point.pressed.connect(_remove_map_point.bind(i)); point_row.add_child(remove_point)
	settings.add_child(_label("OVERLAP RULE: overlapping regions or points use only the highest loot multiplier; values do not stack. Stock falls after each loot pass.",11,GOLD))
	var traversal := _panel("TRAVERSAL RULES", PANEL); content.add_child(traversal)
	for terrain in map_editor_data.get("terrain_rules", {}):
		var rule: Dictionary = map_editor_data.terrain_rules[terrain]; var terrain_row := HBoxContainer.new(); terrain_row.add_theme_constant_override("separation", 10); traversal.add_child(terrain_row)
		var terrain_name := _label(str(terrain).to_upper(), 12, CYAN if bool(rule.get("walkable",false)) else DANGER); terrain_name.custom_minimum_size.x=140; terrain_row.add_child(terrain_name)
		var walk_allowed := CheckBox.new(); walk_allowed.text="Walk/Swim"; walk_allowed.button_pressed=bool(rule.get("walkable",true)); walk_allowed.toggled.connect(func(value): map_editor_data.terrain_rules[terrain].walkable=value); terrain_row.add_child(walk_allowed)
		var walk_speed := SpinBox.new(); walk_speed.prefix="Walk ×"; walk_speed.min_value=0.0; walk_speed.max_value=1.5; walk_speed.step=0.05; walk_speed.value=float(rule.get("walk_speed",1.0)); walk_speed.value_changed.connect(func(value): map_editor_data.terrain_rules[terrain].walk_speed=value); terrain_row.add_child(walk_speed)
		var vehicle_allowed := CheckBox.new(); vehicle_allowed.text="Vehicle"; vehicle_allowed.button_pressed=bool(rule.get("vehicle",false)); vehicle_allowed.toggled.connect(func(value): map_editor_data.terrain_rules[terrain].vehicle=value); terrain_row.add_child(vehicle_allowed)
		var vehicle_speed := SpinBox.new(); vehicle_speed.prefix="Vehicle ×"; vehicle_speed.min_value=0.0; vehicle_speed.max_value=1.5; vehicle_speed.step=0.05; vehicle_speed.value=float(rule.get("vehicle_speed",0.0)); vehicle_speed.value_changed.connect(func(value): map_editor_data.terrain_rules[terrain].vehicle_speed=value); terrain_row.add_child(vehicle_speed)

func _map_number_editor(parent:Control,label_text:String,value:float,min_value:float,max_value:float,step:float,callback:Callable)->SpinBox:
	var editor:=SpinBox.new(); editor.prefix=label_text+" "; editor.min_value=min_value; editor.max_value=max_value; editor.step=step; editor.value=value; editor.custom_minimum_size.x=105; editor.value_changed.connect(callback); parent.add_child(editor)
	return editor

func _refresh_map_editor_preview()->void:
	if match_lab_nodes.has("map_editor_overlay"): match_lab_nodes.map_editor_overlay.set_map(map_editor_data)

func _select_map_editor_item(kind: String, index: int) -> void:
	var collection: Array = map_editor_data.get("regions" if kind == "region" else "points", [])
	if index < 0 or index >= collection.size(): return
	map_editor_selected_kind = kind; map_editor_selected_index = index
	_show_page("map_manager")

func _on_map_editor_item_moved(kind:String,index:int,position:Vector2)->void:
	var collection:Array=map_editor_data.get("regions" if kind=="region" else "points",[])
	if index<0 or index>=collection.size(): return
	map_editor_selected_kind=kind; map_editor_selected_index=index
	collection[index].position=[snappedf(position.x,0.001),snappedf(position.y,0.001)]
	for axis in ["x","y"]:
		var key:="%s:%d:%s"%[kind,index,axis]
		if map_editor_controls.has(key): map_editor_controls[key].set_value_no_signal(position.x if axis=="x" else position.y)
	_refresh_map_editor_preview()

func _add_map_region()->void:
	var index:int=map_editor_data.get("regions",[]).size(); map_editor_data.regions.append({"id":"custom_region_%02d"%(index+1),"name":"Custom Region %02d"%(index+1),"position":[0.5,0.5],"radius":0.08,"loot_multiplier":1.0,"hotness":0.5,"terrain":"urban","walkable":true,"vehicle":true,"capacity":60}); map_editor_selected_kind="region"; map_editor_selected_index=index; _show_page("map_manager")

func _add_map_point()->void:
	var index:int=map_editor_data.get("points",[]).size(); map_editor_data.points.append({"id":"custom_point_%02d"%(index+1),"name":"Custom Point %02d"%(index+1),"position":[0.5,0.5],"type":"house","loot_multiplier":1.0,"capacity":10,"enabled":true}); map_editor_selected_kind="point"; map_editor_selected_index=index; _show_page("map_manager")

func _remove_map_region(index:int)->void:
	if index>=0 and index<map_editor_data.regions.size(): map_editor_data.regions.remove_at(index); _show_page("map_manager")

func _remove_map_point(index:int)->void:
	if index>=0 and index<map_editor_data.points.size(): map_editor_data.points.remove_at(index); _show_page("map_manager")

func _refresh_match_feed(events: Array) -> void:
	if not match_lab_nodes.has("event_feed"): return
	var feed: VBoxContainer = match_lab_nodes.event_feed
	_clear(feed)
	feed.add_child(_label("LIVE EVENT FEED", 13, MUTED))
	for event in events.slice(0, mini(7, events.size())):
		var time_text := "%02d:%02d" % [int(event.time) / 60, int(event.time) % 60]
		feed.add_child(_label("%s  [%s]  %s" % [time_text, event.channel, event.text], 11, GOLD if event.channel == "RESULT" else TEXT))

func _zoom_match_at_cursor(local_position:Vector2,delta:float)->void:
	if not match_lab_nodes.has("map_canvas") or not match_lab_nodes.has("map_view"): return
	var canvas:Control=match_lab_nodes.map_canvas; var cursor_in_view:=canvas.position+local_position*match_map_zoom; var next_zoom:=clampf(match_map_zoom+delta,1.0,3.5)
	canvas.position=cursor_in_view-local_position*next_zoom; match_map_zoom=next_zoom; _apply_match_zoom()

func _zoom_match_at_selected(delta:float)->void:
	if not match_lab_nodes.has("map_canvas") or not match_lab_nodes.has("map_view"): return
	var state:=match_runtime.snapshot(); var squad:Array=state.roster if selected_match_team==0 else state.team_positions[selected_match_team].members
	var normalized:=Vector2(0.5,0.5) if squad.is_empty() else Vector2(squad[clampi(selected_match_player,0,squad.size()-1)].position)
	var canvas:Control=match_lab_nodes.map_canvas; var view:Control=match_lab_nodes.map_view; var next_zoom:=clampf(match_map_zoom+delta,1.0,3.5); canvas.position=view.size*0.5-normalized*canvas.size*next_zoom; match_map_zoom=next_zoom; _apply_match_zoom()

func _reset_match_zoom()->void:
	match_map_zoom=1.0
	if match_lab_nodes.has("map_canvas"): match_lab_nodes.map_canvas.position=Vector2.ZERO
	_apply_match_zoom()

func _pan_match_map(relative:Vector2)->void:
	if not match_lab_nodes.has("map_canvas"): return
	match_lab_nodes.map_canvas.position+=relative; _clamp_match_pan()

func _clamp_match_pan()->void:
	if not match_lab_nodes.has("map_canvas") or not match_lab_nodes.has("map_view"): return
	var canvas:Control=match_lab_nodes.map_canvas; var view:Control=match_lab_nodes.map_view; var minimum:=view.size-canvas.size*match_map_zoom
	canvas.position=Vector2(clampf(canvas.position.x,minimum.x,0.0),clampf(canvas.position.y,minimum.y,0.0))

func _apply_match_zoom() -> void:
	if match_lab_nodes.has("map_canvas"):
		var canvas: Control=match_lab_nodes.map_canvas; canvas.scale=Vector2.ONE*match_map_zoom; _clamp_match_pan()

func _select_match_player(index: int) -> void:
	selected_match_player=clampi(index,0,3); last_match_panel_second=-1
	if active_page=="match_lab": _refresh_match_lab(match_runtime.snapshot())

func _select_match_team(index: int) -> void:
	selected_match_team=clampi(index,0,15); selected_match_player=0; last_match_panel_second=-1
	if active_page=="match_lab": _refresh_match_lab(match_runtime.snapshot())

func _toggle_match_team_filter(team_index:int)->void:
	if team_index<0 or team_index>=match_runtime.team_positions.size(): return
	var tag:=str(match_runtime.team_positions[team_index].tag); match_visible_teams[tag]=not bool(match_visible_teams.get(tag,true))
	if match_lab_nodes.has("team_filter"): match_lab_nodes.team_filter.get_popup().set_item_checked(team_index,bool(match_visible_teams[tag]))
	_refresh_match_lab(match_runtime.snapshot())

func _set_show_dead(value:bool)->void:
	match_show_dead=value; _refresh_match_lab(match_runtime.snapshot())

func _set_match_ui_mode(value:String)->void:
	match_ui_mode=value
	_show_page("match_lab")

func _select_own_match_player(index: int) -> void:
	selected_match_team=0
	if match_lab_nodes.has("team_selector"): match_lab_nodes.team_selector.select(0)
	_select_match_player(index)

func _select_world_match_player(team_index: int, member_index: int) -> void:
	selected_match_team=clampi(team_index,1,15); selected_match_player=clampi(member_index,0,3); last_match_panel_second=-1
	if match_lab_nodes.has("team_selector"): match_lab_nodes.team_selector.select(selected_match_team)
	if active_page=="match_lab": _refresh_match_lab(match_runtime.snapshot())

func _refresh_selected_loadout(state: Dictionary) -> void:
	var squad: Array=state.roster if selected_match_team==0 else state.team_positions[selected_match_team].members
	if squad.is_empty(): return
	var p: Dictionary=squad[clampi(selected_match_player,0,squad.size()-1)]; var l: Dictionary=p.loadout
	var team_tag := "MR" if selected_match_team==0 else str(state.team_positions[selected_match_team].tag)
	var visual_loadout:=l.duplicate(true); visual_loadout.erase("active_weapon")
	var signature:=JSON.stringify([team_tag,p.get("name",""),p.get("role",""),visual_loadout])
	if signature!=match_loadout_signature:
		match_loadout_signature=signature
		var panel: VBoxContainer=match_lab_nodes.loadout_panel; _clear(panel)
		var identity:=HBoxContainer.new(); identity.add_theme_constant_override("separation",8); panel.add_child(identity)
		var status_icon:=_asset_preview(_status_asset(str(p.state)),Vector2(30,30)); identity.add_child(status_icon); match_lab_nodes.focus_status_icon=status_icon
		var name_box:=VBoxContainer.new(); name_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL; identity.add_child(name_box)
		var title:=_label("",17,ACCENT); var meta:=_label("",10,MUTED); name_box.add_child(title); name_box.add_child(meta); match_lab_nodes.focus_title=title; match_lab_nodes.focus_meta=meta
		var health_label:=_label("",24,SUCCESS); identity.add_child(health_label); match_lab_nodes.focus_health_label=health_label
		var health_bar:=_progress_static(float(p.get("health",100)),SUCCESS,7); panel.add_child(health_bar); match_lab_nodes.focus_health_bar=health_bar
		var weapons:=HBoxContainer.new(); weapons.add_theme_constant_override("separation",10); panel.add_child(weapons); weapons.add_child(_observer_weapon(str(l.primary),str(l.scope),int(l.get("primary_ammo", l.get("ammo",0))),true)); weapons.add_child(_observer_weapon(str(l.secondary),"",int(l.get("secondary_ammo",0)),false))
		var equipment:=HBoxContainer.new(); equipment.add_theme_constant_override("separation",12); panel.add_child(equipment); equipment.add_child(_icon_count("icons.equipment.helmet",_roman_level(str(l.helmet)),"Helmet")); equipment.add_child(_icon_count("icons.equipment.vest",_roman_level(str(l.vest)),"Vest")); equipment.add_child(_icon_count("icons.equipment.backpack",_roman_level(str(l.backpack)),"Backpack")); equipment.add_child(_icon_count("icons.equipment.scope",str(l.scope).replace(" Scope",""),"Scope"))
		var inventory:=GridContainer.new(); inventory.columns=6; inventory.add_theme_constant_override("h_separation",12); inventory.add_theme_constant_override("v_separation",5); panel.add_child(inventory)
		for spec in [["inventory.items.bandage",l.get("bandage",0),"Bandage"],["item.first_aid",l.get("first_aid",0),"First Aid"],["inventory.items.med_kit",l.get("medkit",0),"Med Kit"],["inventory.items.energy_drink",l.get("energy_drink",0),"Energy Drink"],["inventory.items.painkiller",l.get("painkiller",0),"Painkiller"],["inventory.items.adrenaline",l.get("adrenaline",0),"Adrenaline"],["icons.utility.smoke",l.get("smoke",0),"Smoke"],["icons.utility.frag",l.get("frag",0),"Frag"],["icons.utility.molotov",l.get("molotov",0),"Molotov"],["icons.utility.flash",l.get("flash",0),"Flash"]]: inventory.add_child(_icon_count(str(spec[0]),str(spec[1]),str(spec[2])))
	var hp:=int(p.get("health",100)); var health_color:=SUCCESS if hp>50 else DANGER
	match_lab_nodes.focus_status_icon.texture=assets.texture(_status_asset(str(p.state)))
	match_lab_nodes.focus_title.text="%s  •  %s" % [team_tag,p.name]
	match_lab_nodes.focus_meta.text="%s  •  %s  •  K%d  •  DMG %d  •  ACC %d%% (%d/%d)  •  BOOST %d%%" % [p.get("role","Player"),_status_symbol(str(p.state)),p.get("kills",0),p.get("damage",0),roundi(float(p.get("hits",0))*100.0/maxi(1,int(p.get("shots",0)))),p.get("hits",0),p.get("shots",0),roundi(float(p.get("boost",0.0)))]
	match_lab_nodes.focus_health_label.text=str(hp); match_lab_nodes.focus_health_label.add_theme_color_override("font_color",health_color)
	match_lab_nodes.focus_health_bar.value=float(hp); match_lab_nodes.focus_health_bar.add_theme_stylebox_override("fill",_style(health_color,4,health_color,0))

func _refresh_kill_feed(entries: Array) -> void:
	var signature:=JSON.stringify(entries)
	if signature==match_killfeed_signature: return
	match_killfeed_signature=signature
	var panel: VBoxContainer=match_lab_nodes.kill_feed; _clear(panel); var heading:=HBoxContainer.new(); heading.add_child(_asset_preview("icons.combat.kill",Vector2(22,22))); heading.add_child(_label("Combat feed",12,MUTED)); panel.add_child(heading)
	if entries.is_empty(): panel.add_child(_label("No contact",11,MUTED)); return
	for e in entries.slice(0,mini(7,entries.size())):
		var line:=HBoxContainer.new(); line.add_theme_constant_override("separation",5); panel.add_child(line)
		var outcome:=str(e.outcome); var cause:=outcome if outcome in ["BLUE","VEHICLE"] else str(e.weapon)
		var text_color:=DANGER if outcome in ["FLUSH","BLEED OUT","BLUE","SQUAD WIPE","VEHICLE"] else GOLD
		var actor := _label(str(e.actor), 10, text_color); actor.custom_minimum_size.x = 76; line.add_child(actor)
		var cause_icon:=_asset_preview(_killfeed_cause_asset(cause),Vector2(34,18)); cause_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; cause_icon.tooltip_text=cause; line.add_child(cause_icon)
		var target := _label(str(e.target), 10, TEXT); target.custom_minimum_size.x = 76; line.add_child(target)
		line.add_child(_tag(_killfeed_outcome_text(outcome,cause), text_color))

func _refresh_scoreboard(entries: Array) -> void:
	var signature:=JSON.stringify(entries)
	if signature==match_scoreboard_signature: return
	match_scoreboard_signature=signature
	var panel: VBoxContainer=match_lab_nodes.scoreboard; _clear(panel); var heading:=HBoxContainer.new(); heading.add_child(_asset_preview("icons.navigation.match",Vector2(22,22))); heading.add_child(_label("Ranking",12,MUTED)); heading.add_child(_asset_preview("match.markers.player",Vector2(18,18))); heading.add_child(_asset_preview("icons.combat.kill",Vector2(18,18))); panel.add_child(heading)
	for row in entries.slice(0,mini(10,entries.size())): panel.add_child(_label("%02d  %-5s   %d      %d      %d" % [row.rank,row.tag,row.alive,row.kills,row.points],10,GOLD if str(row.tag)=="MR" or int(row.rank)<=3 else TEXT))

func _finance_hub() -> void:
	_header("FINANCE & PARTNERS", "Track recorded cash flow, payroll exposure and commercial partners.", "ORGANIZATION OPERATIONS")
	var projection: Dictionary = game.weekly_finance_projection()
	var components: Dictionary = projection.get("components", {})
	var payroll := int(components.get("payroll", 0))
	var active_name := "NO ACTIVE SPONSOR"
	var sponsor_income := int(components.get("sponsor", 0))
	for sponsor in game.data.get("sponsors", []):
		if str(sponsor.get("id", "")) == str(game.data.get("active_sponsor_id", "")): active_name = str(sponsor.get("name", "SPONSOR")); break
	var merchandise_income := int(components.get("merchandise", 0))
	var video_income := int(components.get("video", 0))
	var streaming_income := int(components.get("streaming", 0))
	var operating_cost := int(projection.get("expenses", 0)) - payroll
	var weekly_net := int(projection.get("net", 0))
	var runway := 99 if weekly_net >= 0 else maxi(0, int(int(game.data.budget) / maxi(1, -weekly_net)))
	var economy_hero := UIComponentsScript.hero_panel("CAREER ECONOMY", "Your runway determines how aggressively the organization can recruit, build and compete.", GOLD); content.add_child(economy_hero)
	var metrics := HBoxContainer.new(); metrics.add_theme_constant_override("separation", 18); economy_hero.add_child(metrics)
	metrics.add_child(UIComponentsScript.game_stat("CASH", "$%s" % GameStateScript.money(int(game.data.budget)), GOLD, "Operating balance"))
	metrics.add_child(UIComponentsScript.game_stat("WEEKLY PAYROLL", "$%s" % GameStateScript.money(payroll), DANGER, "%d contracted players" % game.data.roster.size()))
	metrics.add_child(UIComponentsScript.game_stat("PARTNER INCOME", "$%s" % GameStateScript.money(sponsor_income), CYAN, active_name))
	metrics.add_child(UIComponentsScript.game_stat("RUNWAY", "%d WEEKS" % runway, SUCCESS if runway >= 16 else GOLD if runway >= 8 else DANGER, "%s$%s projected net" % ["+" if weekly_net >= 0 else "-", GameStateScript.money(absi(weekly_net))]))
	if not str(game.data.get("active_sponsor_id", "")).is_empty():
		var sponsor_status: Dictionary = game.data.get("sponsor_status", {}); var status_color := SUCCESS if str(sponsor_status.get("state","HEALTHY"))=="HEALTHY" else GOLD if str(sponsor_status.get("state",""))=="WARNING" else DANGER
		var objective_panel := _panel("SPONSOR OBJECTIVE", PANEL_HIGH); content.add_child(objective_panel); objective_panel.add_child(_label("%s • %s" % [str(sponsor_status.get("state","HEALTHY")),active_name],16,status_color)); objective_panel.add_child(_progress(float(sponsor_status.get("progress",0)),status_color,9)); objective_panel.add_child(_label("Progress %d%% • reviews create Inbox decisions when expectations slip." % int(sponsor_status.get("progress",0)),12,MUTED))
	var health := _panel("FINANCIAL HEALTH", PANEL); content.add_child(health)
	var health_score := clampi(runway * 5, 0, 100); health.add_child(_progress(health_score, SUCCESS if runway >= 16 else GOLD if runway >= 8 else DANGER, 9))
	health.add_child(_label("STABLE • %d weeks runway" % runway if runway >= 12 else "WATCH • %d weeks runway" % runway, 12, SUCCESS if runway >= 12 else GOLD))
	var split := HBoxContainer.new(); split.add_theme_constant_override("separation", 16); content.add_child(split)
	var ledger_panel := _panel("RECENT CASH FLOW", PANEL_HIGH); ledger_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL; split.add_child(ledger_panel)
	ledger_panel.add_child(_label("WEEK   TYPE                         AMOUNT", 11, MUTED))
	for entry in game.data.get("finance_ledger", []).slice(0, 10):
		var amount := int(entry.get("amount", 0)); var color := SUCCESS if amount >= 0 else DANGER
		ledger_panel.add_child(_label("%02d     %-27s  %s$%s" % [int(entry.get("week", 1)), str(entry.get("label", "Entry")), "+" if amount >= 0 else "-", GameStateScript.money(absi(amount))], 12, color))
	ledger_panel.add_child(HSeparator.new())
	ledger_panel.add_child(_action_row("IN", "Weekly income", "+$%s sponsor revenue" % GameStateScript.money(sponsor_income), SUCCESS if sponsor_income > 0 else MUTED))
	ledger_panel.add_child(_action_row("OUT", "Payroll expense", "-$%s / week" % GameStateScript.money(payroll), DANGER))
	ledger_panel.add_child(_action_row("NET", "Projected cash flow", "%s$%s / week" % ["+" if weekly_net >= 0 else "-", GameStateScript.money(absi(weekly_net))], SUCCESS if weekly_net >= 0 else DANGER))
	ledger_panel.add_child(_action_row("MERCH", "Merchandise", "+$%s / week" % GameStateScript.money(merchandise_income), SUCCESS))
	ledger_panel.add_child(_action_row("VIDEO", "Video platforms", "+$%s / week" % GameStateScript.money(video_income), SUCCESS))
	ledger_panel.add_child(_action_row("LIVE", "Streaming", "+$%s / week" % GameStateScript.money(streaming_income), SUCCESS))
	ledger_panel.add_child(_action_row("OPS", "Facilities, scouting & travel", "-$%s / week" % GameStateScript.money(operating_cost), DANGER))
	var sponsor_panel := _panel("PARTNER OFFERS", PANEL); sponsor_panel.custom_minimum_size.x = 520; split.add_child(sponsor_panel)
	for sponsor in game.data.get("sponsors", []):
		var current := str(sponsor.get("id", "")) == str(game.data.get("active_sponsor_id", ""))
		var unlocked := int(game.data.reputation) >= int(sponsor.get("reputation_required", 0))
		var card := _panel(str(sponsor.get("name", "SPONSOR")), PANEL_HIGH); sponsor_panel.add_child(card)
		card.add_child(_label("%s  •  +$%s/week  •  $%s signing" % [str(sponsor.get("category", "Partner")), GameStateScript.money(int(sponsor.get("weekly_income", 0))), GameStateScript.money(int(sponsor.get("signing_bonus", 0)))], 11, CYAN if unlocked else MUTED))
		card.add_child(_label(str(sponsor.get("objective", "")), 11, TEXT))
		var action := _button("ACTIVE" if current else "SIGN PARTNER" if unlocked else "LOCKED • REP %d" % int(sponsor.get("reputation_required", 0)), not current and unlocked)
		action.disabled = current or not unlocked or not str(game.data.get("active_sponsor_id", "")).is_empty()
		action.pressed.connect(func(): _notify(game.accept_sponsor(str(sponsor.get("id", "")))); _show_page("finance")); card.add_child(action)
	var allocation := _panel("NEXT FINANCIAL RISKS", PANEL); content.add_child(allocation)
	allocation.add_child(_action_row("PAYROLL", "Weekly payroll due", "-$%s next advance" % GameStateScript.money(payroll), DANGER))
	allocation.add_child(_action_row("CONTRACT", "Renewal watch", "Review shortest player contract before transfers", GOLD))
	allocation.add_child(_action_row("SPONSOR", active_name, "+$%s/week secured" % GameStateScript.money(sponsor_income), SUCCESS if sponsor_income > 0 else MUTED))

func _performance_campus() -> void:
	_header("PERFORMANCE CAMPUS", "Facility levels, construction schedules, costs and verified operational benefits.", "ORGANIZATION INFRASTRUCTURE")
	var screen: Control = PerformanceCampusScreenScript.new(); screen.size_flags_horizontal=Control.SIZE_EXPAND_FILL; content.add_child(screen); screen.setup({"game":game,"assets":assets,"money":func(value): return GameStateScript.money(int(value)),"notify":func(message): _notify(str(message)),"reload":func(): _show_page("facilities")},router.current_params)

func _facilities() -> void:
	var definitions: Dictionary = game.data.get("facility_definitions", {})
	var available_width := get_viewport_rect().size.x - (168.0 if get_viewport_rect().size.x < 1500.0 else 190.0) - (28.0 if get_viewport_rect().size.x < 1500.0 else 44.0)
	var world_height := maxf(620.0, get_viewport_rect().size.y - 112.0)
	var world := Control.new(); world.custom_minimum_size = Vector2(available_width, world_height); world.clip_contents = true; content.add_child(world)
	var backdrop := TextureRect.new(); backdrop.texture = assets.texture("campus.mekong.overview"); backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var scaled_size := Vector2(available_width, world_height) * campus_zoom; backdrop.position = (Vector2(available_width, world_height) - scaled_size) * 0.5 + campus_pan; backdrop.size = scaled_size; world.add_child(backdrop)
	var tint := ColorRect.new(); tint.color = Color(0.01, 0.025, 0.04, 0.12); tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); tint.mouse_filter = Control.MOUSE_FILTER_IGNORE; world.add_child(tint)
	var title := VBoxContainer.new(); title.position = Vector2(20, 18); title.size = Vector2(420, 80); world.add_child(title); title.add_child(_label("PERFORMANCE CAMPUS", 26, TEXT)); title.add_child(_label("Your organization, operating in real time", 12, MUTED))
	var controls := HBoxContainer.new(); controls.position = Vector2(available_width - 390, 18); controls.size = Vector2(370, 44); controls.add_theme_constant_override("separation", 6); world.add_child(controls)
	for spec in [["ZOOM OUT", -0.1], ["OVERVIEW", 0.0], ["ZOOM IN", 0.1]]:
		var control := _button(str(spec[0]), false); control.custom_minimum_size.x = 72; control.tooltip_text = "Campus camera zoom"; control.pressed.connect(_change_campus_zoom.bind(float(spec[1]))); controls.add_child(control)
	var pan_controls := HBoxContainer.new(); pan_controls.position = Vector2(20, world_height - 62); pan_controls.size = Vector2(390, 44); pan_controls.add_theme_constant_override("separation", 6); world.add_child(pan_controls)
	for spec in [["PAN LEFT", Vector2(55, 0)], ["PAN UP", Vector2(0, 40)], ["PAN DOWN", Vector2(0, -40)], ["PAN RIGHT", Vector2(-55, 0)]]:
		var pan_button := _button(str(spec[0]), false); pan_button.custom_minimum_size.x = 88; pan_button.tooltip_text = "Move campus camera"; pan_button.pressed.connect(_move_campus.bind(Vector2(spec[1]))); pan_controls.add_child(pan_button)
	var positions := [Vector2(0.25, 0.28), Vector2(0.73, 0.28), Vector2(0.27, 0.72), Vector2(0.72, 0.70)]
	var index := 0
	for facility_key in game.data.facilities:
		var key := str(facility_key); var facility: Dictionary = definitions.get(key, {}); var normalized: Vector2 = positions[index % positions.size()]; index += 1
		var point := (normalized - Vector2(0.5, 0.5)) * Vector2(available_width, world_height) * campus_zoom + Vector2(available_width, world_height) * 0.5 + campus_pan
		var selected := campus_detail_open and selected_facility == key
		var connector := Line2D.new(); connector.width = 2.5 if selected else 1.25; connector.default_color = ACCENT if selected else Color(CYAN, 0.65); connector.points = PackedVector2Array([point + Vector2(0, 42), point + Vector2(0, 10)]); world.add_child(connector)
		var marker := _button("%s\nLEVEL %d  •  %s" % [str(facility.get("display_name", key)).to_upper(), int(game.data.facilities[key]), "SELECTED" if selected else "READY"], selected); marker.position = point - Vector2(100, 42); marker.size = Vector2(200, 62); marker.alignment = HORIZONTAL_ALIGNMENT_LEFT; marker.icon = _small_icon(str(facility.get("asset_id", "")), 26); marker.tooltip_text = "%s — click to inspect" % str(facility.get("description", "")); marker.pressed.connect(func(): selected_facility = key; campus_detail_open = true; campus_zoom = 1.12; _show_page("facilities")); world.add_child(marker)
	if campus_detail_open and definitions.has(selected_facility):
		var definition: Dictionary = definitions[selected_facility]; var level := int(game.data.facilities[selected_facility]); var upgrades: Array = definition.get("levels", []); var max_level := int(definition.get("max_level", upgrades.size())); var cost := int(definition.get("base_upgrade_cost", 0)) * (level + 1)
		var overlay := _panel("FACILITY INSPECTION", Color("0d1824f2")); overlay.position = Vector2(available_width - (370 if get_viewport_rect().size.x < 1500.0 else 430), 84); overlay.size = Vector2(350 if get_viewport_rect().size.x < 1500.0 else 410, world_height - 110); world.add_child(overlay)
		var close := _button("BACK TO OVERVIEW", false); close.pressed.connect(func(): campus_detail_open = false; campus_zoom = 1.0; campus_pan = Vector2.ZERO; _show_page("facilities")); overlay.add_child(close)
		overlay.add_child(_label(str(definition.get("display_name", selected_facility)), 24, TEXT)); overlay.add_child(_tag("LEVEL %d / %d" % [level, max_level], ACCENT)); overlay.add_child(_label(str(definition.get("description", "")), 13, MUTED)); overlay.add_child(HSeparator.new())
		overlay.add_child(_label("CURRENT EFFECT", 11, MUTED)); overlay.add_child(_label(str(upgrades[level - 1]) if level > 0 and level <= upgrades.size() else "Base operations", 15, SUCCESS))
		if level < max_level:
			overlay.add_child(_label("NEXT LEVEL", 11, MUTED)); overlay.add_child(_label(str(upgrades[level]) if level < upgrades.size() else "Capacity improvement", 15, GOLD)); overlay.add_child(_label("UPGRADE COST", 11, MUTED)); overlay.add_child(_label("$%s" % GameStateScript.money(cost), 28, GOLD))
			var can_afford := int(game.data.budget) >= cost; overlay.add_child(_tag("READY TO BUILD" if can_afford else "INSUFFICIENT FUNDS", SUCCESS if can_afford else DANGER))
			var construction_days := maxi(2, 3 + level * 2); var upgrade := _button("START UPGRADE • %d DAYS" % construction_days, can_afford); upgrade.disabled = not can_afford; upgrade.tooltip_text = "Requires $%s • completion is added to Calendar" % GameStateScript.money(cost); upgrade.pressed.connect(func(): _notify(game.upgrade_facility(selected_facility)); campus_zoom = 1.18; _show_page("facilities")); overlay.add_child(upgrade)
		else: overlay.add_child(_tag("MAX LEVEL", SUCCESS))

func _change_campus_zoom(delta: float) -> void:
	if is_zero_approx(delta):
		campus_zoom = 1.0
		campus_pan = Vector2.ZERO
	else:
		campus_zoom = clampf(campus_zoom + delta, 1.0, 1.3)
	_show_page("facilities")

func _move_campus(delta: Vector2) -> void:
	if campus_zoom <= 1.0: campus_zoom = 1.08
	campus_pan += delta
	campus_pan.x = clampf(campus_pan.x, -180.0, 180.0)
	campus_pan.y = clampf(campus_pan.y, -120.0, 120.0)
	_show_page("facilities")

func _facility_detail() -> void:
	var definitions: Dictionary = game.data.get("facility_definitions", {})
	var definition: Dictionary = definitions.get(selected_facility, {})
	if definition.is_empty(): _show_page("facilities"); return
	var level := int(game.data.get("facilities", {}).get(selected_facility, 0))
	var max_level := int(definition.get("max_level", 0))
	_header(str(definition.get("display_name", selected_facility)).to_upper(), "Facility upgrade roadmap and operational impact", "LEVEL %d / %d" % [level, max_level])
	var back := _button("BACK TO CAMPUS", false); back.pressed.connect(_show_page.bind("facilities")); content.add_child(back)
	var hero := _panel("", PANEL_HIGH); content.add_child(hero); hero.add_child(_asset_preview(str(definition.get("asset_id", "")), Vector2(1020, 300))); hero.add_child(_label(str(definition.get("description", "")), 16, TEXT))
	var roadmap := _panel("UPGRADE ROADMAP", PANEL); content.add_child(roadmap)
	var upgrades: Array = definition.get("levels", [])
	for upgrade_index in upgrades.size():
		var state := "UNLOCKED" if upgrade_index < level else "NEXT" if upgrade_index == level else "LOCKED"
		roadmap.add_child(_action_row("%02d" % (upgrade_index + 1), str(upgrades[upgrade_index]), state, SUCCESS if state == "UNLOCKED" else GOLD if state == "NEXT" else MUTED))
	if level < max_level:
		var cost := int(definition.get("base_upgrade_cost", 0)) * (level + 1)
		var active_project: Dictionary = {}
		for project in game.data.get("facility_projects", []):
			if str(project.get("facility", "")) == selected_facility and str(project.get("status", "")) == "UPGRADING": active_project = project; break
		if not active_project.is_empty():
			var start_unix := Time.get_unix_time_from_datetime_string(str(active_project.start_date) + "T00:00:00"); var now_unix := Time.get_unix_time_from_datetime_string(str(game.data.current_date) + "T00:00:00"); var elapsed := clampi(int((now_unix-start_unix)/86400.0),0,int(active_project.duration_days))
			content.add_child(_tag("UPGRADING • DAY %d / %d" % [elapsed, int(active_project.duration_days)], ORANGE)); content.add_child(_progress(100.0*elapsed/maxi(1,int(active_project.duration_days)), ORANGE, 10)); content.add_child(_label("Completion: %s • The calendar will stop for this event." % str(active_project.completion_date), 12, MUTED))
		else:
			var upgrade_button := _button("START UPGRADE • $%s • %d DAYS" % [GameStateScript.money(cost), maxi(2,3+level*2)], true); upgrade_button.pressed.connect(func(): _notify(game.upgrade_facility(selected_facility)); _show_page("facility_detail")); content.add_child(upgrade_button)
	else: content.add_child(_tag("FACILITY MAXED", SUCCESS))
	for event in game.actionable_events():
		if str(event.get("type", "")) == "facility" and str(event.get("facility", "")) == selected_facility:
			var complete := _button("ACKNOWLEDGE UPGRADE COMPLETE", true); complete.pressed.connect(func(): game.acknowledge_calendar_event(str(event.id)); _show_page("facilities")); content.add_child(complete)

func _analytics_page() -> void:
	var telemetry: Array = game.data.get("telemetry", [])
	_header("TEAM ANALYSIS", "Verified match evidence, tactical patterns and the current competitive meta.", "%d RECORDED MATCHES" % telemetry.size())
	var meta: Dictionary = game.data.get("meta_state", {}); var tiers: Dictionary = meta.get("tiers", {})
	if telemetry.is_empty():
		var next_match: Dictionary = game.get_next_match(true)
		var compact_layout := ResponsiveScript.is_compact(get_viewport_rect().size)
		var waiting: BoxContainer = VBoxContainer.new() if compact_layout else HBoxContainer.new(); waiting.add_theme_constant_override("separation", 22); content.add_child(waiting)
		var map_panel := _panel("FIRST EVIDENCE TARGET", PANEL_HIGH); map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL; waiting.add_child(map_panel)
		map_panel.add_child(_asset_preview(_map_asset(str(next_match.get("map", "Verdant Reach"))), Vector2(720, 285)))
		map_panel.add_child(_tag(str(next_match.get("map", "MAP UNAVAILABLE")).to_upper(), CYAN))
		var briefing := UIComponentsScript.tactical_panel("ANALYST BRIEFING"); briefing.custom_minimum_size.x = 0 if compact_layout else 420; waiting.add_child(briefing)
		briefing.add_child(_tag("AWAITING VERIFIED TELEMETRY", GOLD))
		briefing.add_child(_label(str(next_match.get("tournament", "No competition scheduled")), 26, TEXT))
		briefing.add_child(_label("%s  •  %s" % [str(next_match.get("round", "UPCOMING")), str(next_match.get("date", "DATE UNAVAILABLE"))], 13, GOLD))
		briefing.add_child(_label("The analyst room unlocks weapon usage, performance samples and tactical comparisons only after a completed match.", 13, MUTED))
		var prepare := _button("PREPARE FOR MATCH  →", true); prepare.custom_minimum_size.y = 52; prepare.pressed.connect(_show_page.bind("match")); briefing.add_child(prepare)
		return
	var evidence := HBoxContainer.new(); evidence.add_theme_constant_override("separation", 24); content.add_child(evidence)
	evidence.add_child(UIComponentsScript.game_stat("RECORDED MATCHES", telemetry.size(), CYAN, "MatchRuntime telemetry"))
	evidence.add_child(UIComponentsScript.game_stat("BOARD CONFIDENCE", "%d%%" % int(game.data.get("board_confidence",65)), GOLD, "Current career state"))
	evidence.add_child(UIComponentsScript.game_stat("FAN SENTIMENT", "%d%%" % int(game.data.get("fan_sentiment",65)), ACCENT, "Current career state"))
	var analyze := _button("UPDATE META REPORT", true); analyze.pressed.connect(func(): game.analyze_meta(); _show_page("analytics")); content.add_child(analyze)
	var analysis_split := HBoxContainer.new(); analysis_split.add_theme_constant_override("separation", 22); content.add_child(analysis_split)
	var weapons := VBoxContainer.new(); weapons.size_flags_horizontal = Control.SIZE_EXPAND_FILL; weapons.add_theme_constant_override("separation", 9); analysis_split.add_child(weapons); weapons.add_child(_label("Weapon performance", 20, TEXT))
	if tiers.is_empty(): weapons.add_child(_empty_state("REPORT NOT RUN", "Update the meta report to process the recorded match sample."))
	else:
		for weapon in tiers: weapons.add_child(_action_row(str(tiers[weapon]), str(weapon), "Score %d • Used %d times" % [int(meta.get("weapon_performance",{}).get(weapon,0)),int(meta.get("weapon_usage",{}).get(weapon,0))], GOLD if str(tiers[weapon]) in ["S","A"] else MUTED))
	var changes := VBoxContainer.new(); changes.custom_minimum_size.x = 390; changes.add_theme_constant_override("separation", 9); analysis_split.add_child(changes); changes.add_child(_label("Balance history", 20, TEXT))
	for meta_patch in meta.get("patch_history", []): changes.add_child(_action_row("W%d" % int(meta_patch.get("week",1)), str(meta_patch.get("note","Balance patch")), JSON.stringify(meta_patch.get("changes",{})), CYAN))
	if meta.get("patch_history", []).is_empty(): changes.add_child(_label("No balance changes have affected this career.", 13, MUTED))

func _transfers_page() -> void:
	_header("TRANSFER CENTER", "Move from discovery to a signed contract through verified scouting and negotiation.", "$%s AVAILABLE" % GameStateScript.money(int(game.data.budget)))
	var market_players: Array = game.data.get("market", [])
	var offers: Array = game.data.get("transfer_offers", [])
	var window:Dictionary=game.transfer_window_status(); var window_panel:=UIComponentsScript.hero_panel("%s TRANSFER WINDOW" % str(window.get("name","CLOSED")),"Contracted-player approaches are available only during registered windows. Free agents may negotiate at any time.",SUCCESS if bool(window.get("open",false)) else DANGER); content.add_child(window_panel)
	window_panel.add_child(_label("CAREER WEEK %d  •  %s" % [int(window.get("week",1)),"OPEN NOW" if bool(window.get("open",false)) else "NEXT WINDOW: %s" % str(window.get("next","Next season"))],15,GOLD))
	var compact_layout := ResponsiveScript.is_compact(get_viewport_rect().size)
	var stage: BoxContainer = VBoxContainer.new() if compact_layout else HBoxContainer.new(); stage.add_theme_constant_override("separation", 20); content.add_child(stage)
	var lead := UIComponentsScript.hero_panel("NEXT RECRUIT", "Scout → evaluate → negotiate → sign", GOLD); lead.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lead.custom_minimum_size.y = 285; stage.add_child(lead)
	if market_players.is_empty():
		lead.add_child(_empty_state("NO SCOUTED PLAYERS", "Open Player Discovery to build a verified shortlist."))
	else:
		var prospect: Dictionary = market_players[0]
		var identity := HBoxContainer.new(); identity.add_theme_constant_override("separation", 18); lead.add_child(identity)
		identity.add_child(_player_avatar(str(prospect.get("avatar_asset_id", "")), Vector2(150, 190)))
		var prospect_copy := VBoxContainer.new(); prospect_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL; identity.add_child(prospect_copy)
		prospect_copy.add_child(_label(str(prospect.get("name", "Player")), 32, TEXT)); prospect_copy.add_child(_label("%s  •  AGE %d  •  OVR %d" % [str(prospect.get("role", "Flex")).to_upper(), int(prospect.get("age",0)), int(prospect.get("overall",0))], 14, _role_color(str(prospect.get("role","Flex")))))
		prospect_copy.add_child(_label("VALUE  $%s\nEXPECTED SALARY  $%s / MONTH\nSCOUT CONFIDENCE  %d%%" % [GameStateScript.money(int(prospect.get("value",0))), GameStateScript.money(int(prospect.get("salary",0))), int(prospect.get("confidence",0))], 13, GOLD))
		var inspect := _button("OPEN PLAYER DOSSIER  →", true); inspect.pressed.connect(func(): selected_profile_player = prospect; _show_page("player_detail")); prospect_copy.add_child(inspect)
	var offer_zone := VBoxContainer.new(); offer_zone.custom_minimum_size.x = 0 if compact_layout else 420; offer_zone.add_theme_constant_override("separation", 10); stage.add_child(offer_zone)
	offer_zone.add_child(_label("Negotiations", 22, TEXT)); offer_zone.add_child(_label("%d pending decision(s)" % offers.size(), 13, ORANGE if not offers.is_empty() else MUTED))
	if offers.is_empty(): offer_zone.add_child(_label("No active offer. Evaluate a player, then submit terms from their dossier. Responses arrive in the Inbox.", 13, MUTED))
	for offer in offers.slice(0,3): offer_zone.add_child(_action_row(str(offer.get("status","PENDING")),str(offer.get("player_name","Player")),"$%s / month • %d months • %s" % [GameStateScript.money(int(offer.get("salary",0))),int(offer.get("months",0)),str(offer.get("response","PENDING"))],GOLD))
	var negotiation_actions := HBoxContainer.new(); negotiation_actions.add_theme_constant_override("separation",8); offer_zone.add_child(negotiation_actions)
	var discover := _button("DISCOVER PLAYERS", true); discover.pressed.connect(_show_page.bind("scouting")); negotiation_actions.add_child(discover)
	var review_inbox := _button("OPEN INBOX", false); review_inbox.pressed.connect(_show_page.bind("inbox")); negotiation_actions.add_child(review_inbox)
	var free_agents:Array=market_players.filter(func(player): return str(player.get("squad_role",""))=="free_agent" or str(player.get("team_id","")).is_empty())
	var contracted:Array=market_players.filter(func(player): return not player in free_agents)
	var free_panel:=_panel("FREE AGENTS • NEGOTIATION ALWAYS AVAILABLE",PANEL_HIGH); content.add_child(free_panel)
	for market_player in free_agents.slice(0,6): free_panel.add_child(_market_player_row(market_player))
	if free_agents.is_empty(): free_panel.add_child(_empty_state("NO FREE AGENTS DISCOVERED","Complete scouting assignments to find unattached players."))
	var contracted_panel:=_panel("CONTRACTED PLAYERS • WINDOW REQUIRED",PANEL); content.add_child(contracted_panel)
	for market_player in contracted.slice(0,6): contracted_panel.add_child(_market_player_row(market_player))
	if contracted.is_empty(): contracted_panel.add_child(_empty_state("NO CONTRACTED TARGETS","Scout a club player before approaching their organization."))

func _contracts_page() -> void:
	_header("PLAYER CONTRACTS", "Protect the core roster, resolve expiring deals and control payroll.", "SQUAD COMMITMENTS")
	var roster: Array = game.data.get("roster", [])
	var contract_summary: Dictionary = GamePresenterScript.contract_overview(game.data)
	var urgent: Array = contract_summary.urgent
	var warning: Array = contract_summary.watch
	var payroll: int = int(contract_summary.payroll)
	var compact_layout := ResponsiveScript.is_compact(get_viewport_rect().size)
	var renewal_target: Dictionary = roster.reduce(func(current, player): return player if current.is_empty() or int(player.get("contract",99)) < int(current.get("contract",99)) else current, {}) if not roster.is_empty() else {}
	var renewal := UIComponentsScript.hero_panel("NEXT RENEWAL", "The shortest remaining contract sets the immediate roster risk.", DANGER if not urgent.is_empty() else GOLD); content.add_child(renewal)
	if not renewal_target.is_empty():
		var renewal_line := HBoxContainer.new(); renewal_line.add_theme_constant_override("separation",18); renewal.add_child(renewal_line); renewal_line.add_child(_player_avatar(str(renewal_target.get("avatar_asset_id","")),Vector2(78,92)))
		var renewal_copy := VBoxContainer.new(); renewal_copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL; renewal_line.add_child(renewal_copy); renewal_copy.add_child(_label("@%s  •  %s" % [str(renewal_target.get("handle",renewal_target.get("name","player"))),str(renewal_target.get("role","Flex"))],20,TEXT)); renewal_copy.add_child(_label("%d MONTHS REMAINING  •  $%s / MONTH" % [int(renewal_target.get("contract",0)),GameStateScript.money(int(renewal_target.get("salary",0)))],15,GOLD))
		var review_target := _button("REVIEW CONTRACT  →", not urgent.is_empty()); review_target.pressed.connect(func(): selected_profile_player=renewal_target; _show_page("player_detail")); renewal_line.add_child(review_target)
	var contract_state := HBoxContainer.new(); contract_state.add_theme_constant_override("separation",24); renewal.add_child(contract_state); contract_state.add_child(UIComponentsScript.game_stat("MONTHLY PAYROLL","$%s"%GameStateScript.money(payroll),GOLD,"%d players"%roster.size())); contract_state.add_child(UIComponentsScript.game_stat("URGENT",urgent.size(),DANGER if not urgent.is_empty() else SUCCESS,"Six months or less")); contract_state.add_child(UIComponentsScript.game_stat("WATCH",warning.size(),GOLD,"Six to twelve months"))
	var layout: BoxContainer = VBoxContainer.new() if compact_layout else HBoxContainer.new(); layout.add_theme_constant_override("separation", 20); content.add_child(layout)
	var commitments := VBoxContainer.new(); commitments.size_flags_horizontal = Control.SIZE_EXPAND_FILL; commitments.add_theme_constant_override("separation",8); layout.add_child(commitments); commitments.add_child(_label("Roster contracts",20,TEXT))
	var table_header := HBoxContainer.new(); table_header.add_theme_constant_override("separation", 8); commitments.add_child(table_header)
	for column in [["PLAYER",250],["ROLE",100],["SALARY",130],["TERM",110],["STATUS",150],["ACTION",130]]:
		var header := _label(str(column[0]), 10, MUTED); header.custom_minimum_size.x = int(column[1]); table_header.add_child(header)
	for player in roster:
		commitments.add_child(_contract_command_row(player))
	if not game.data.get("loaned_players", []).is_empty():
		commitments.add_child(_label("Loan commitments",16,CYAN))
		for loaned in game.data.get("loaned_players", []):
			var active_loan: Dictionary={}; for record in game.data.get("loan_records",[]): if str(record.get("player_id",""))==str(loaned.get("id","")) and str(record.get("status",""))=="ACTIVE": active_loan=record; break
			commitments.add_child(_action_row("LOAN",str(loaned.get("name","Player")),"%d months • club pays %d%% • returns %s" % [int(loaned.get("contract",0)),100-int(active_loan.get("salary_coverage",0)),str(active_loan.get("return_date","—"))],CYAN))
	var guidance := VBoxContainer.new(); guidance.custom_minimum_size.x = 0 if compact_layout else 300; guidance.add_theme_constant_override("separation",10); layout.add_child(guidance)
	guidance.add_child(_label("Renew first", 20, TEXT))
	guidance.add_child(_label("1. Resolve urgent expiries\n2. Protect core-role players\n3. Keep payroll inside runway", 13, TEXT))
	guidance.add_child(_decision_signal("URGENT", "%d player(s)" % urgent.size(), DANGER if not urgent.is_empty() else SUCCESS))
	guidance.add_child(_decision_signal("TRANSFER LISTED", "%d player(s)" % roster.filter(func(p): return bool(p.get("transfer_listed", false))).size(), GOLD))
	guidance.add_child(_label("%d safe contracts currently need no action." % roster.filter(func(p): return int(p.get("contract", 0)) > 12).size(), 12, MUTED))
	var open_roster := _button("OPEN SQUAD & LINEUP  →", false); open_roster.pressed.connect(_show_page.bind("roster")); guidance.add_child(open_roster)

func _training_page() -> void:
	_header("TRAINING CENTER", "Diagnose weaknesses, build the week and accept the trade-off between growth and readiness.", "ACTIVE PROGRAM: %s" % str(game.data.get("training_program","CUSTOM")))
	var readiness := HBoxContainer.new(); readiness.add_theme_constant_override("separation",10); content.add_child(readiness)
	readiness.add_child(_visual_stat("ENERGY",_average("energy"),_metric_color(_average("energy")),"Squad average")); readiness.add_child(_visual_stat("FORM",_average("form"),GOLD,"Competition rhythm")); readiness.add_child(_visual_stat("CHEMISTRY",int(game.data.get("chemistry",0)),CYAN,"Team coordination")); readiness.add_child(_visual_stat("MATCH READINESS",int(game.data.get("match_readiness",65)),SUCCESS,"Energy, form and chemistry"))
	var focus_panel := _panel("TEAM TRAINING FOCUS",PANEL_HIGH); content.add_child(focus_panel)
	var focus_grid := GridContainer.new(); focus_grid.columns=3; focus_panel.add_child(focus_grid)
	var current_focus := str(game.data.get("team_training_focus","Strategy"))
	var focus_notes := {"Combat":"Aim and mechanical development","Strategy":"Rotation and decision making","Teamwork":"Chemistry and coordination","Mental":"Composure and consistency","Intensive":"Fast growth with high fatigue","Recovery":"Energy and form recovery"}
	for focus in ["Combat","Strategy","Teamwork","Mental","Intensive","Recovery"]:
		var choice:=_choice_card(focus.to_upper(),str(focus_notes[focus]),"Selected focus changes weekly attribute development.",focus==current_focus,ORANGE if focus=="Intensive" else SUCCESS if focus=="Recovery" else ACCENT); choice.pressed.connect(func(): game.set_team_training_focus(focus); _show_page("training")); focus_grid.add_child(choice)
	var programs := _panel("TRAINING PROGRAMS",PANEL); content.add_child(programs)
	var program_actions:=HBoxContainer.new(); program_actions.add_theme_constant_override("separation",8); programs.add_child(program_actions)
	for program in ["MECHANICAL","STRATEGIC","BALANCED","RECOVERY"]:
		var program_button:=_button(program,str(game.data.get("training_program",""))==program); program_button.pressed.connect(func(): game.apply_training_program(program); _show_page("training")); program_actions.add_child(program_button)
	programs.add_child(_label("Programs populate all seven days. Any manual day change becomes a custom program.",12,MUTED))
	var weekly := _panel("WEEKLY SCHEDULE",PANEL_HIGH); content.add_child(weekly)
	var day_names := ["MON","TUE","WED","THU","FRI","SAT","SUN"]
	var activities := ["Combat","Strategy","Teamwork","Mental","Scrim","Recovery","Rest"]
	var intensities := ["Light","Team","Intensive","Competitive","Rest"]
	var schedule:Array=game.data.get("training_schedule",[])
	for index in 7:
		var entry:Dictionary=schedule[index] if index<schedule.size() else {"activity":"Rest","intensity":"Rest"}; var row:=HBoxContainer.new(); row.add_theme_constant_override("separation",10); weekly.add_child(row)
		var day_label:=_label(day_names[index],13,GOLD); day_label.custom_minimum_size.x=55; row.add_child(day_label)
		var activity:=OptionButton.new(); activity.custom_minimum_size.x=190
		for item in activities: activity.add_item(item)
		activity.select(maxi(0,activities.find(str(entry.activity)))); row.add_child(activity)
		var intensity:=OptionButton.new(); intensity.custom_minimum_size.x=160
		for item in intensities: intensity.add_item(item)
		intensity.select(maxi(0,intensities.find(str(entry.intensity)))); row.add_child(intensity)
		var apply_day:=_button("APPLY",false); apply_day.pressed.connect(func(): game.set_training_day(index,activity.get_item_text(activity.selected),intensity.get_item_text(intensity.selected)); _show_page("training")); row.add_child(apply_day)
		row.add_child(_label(_training_tradeoff(str(entry.activity),str(entry.intensity)),12,MUTED))
	var individual := _panel("INDIVIDUAL DEVELOPMENT",PANEL_HIGH); content.add_child(individual)
	for player in game.data.get("roster",[]):
		var recommendation:=_training_recommendation(player); var card:=_panel("",PANEL); individual.add_child(card); var row:=HBoxContainer.new(); row.add_theme_constant_override("separation",10); card.add_child(row); row.add_child(_player_avatar(str(player.get("avatar_asset_id","")),Vector2(54,62)))
		var identity:=_label("@%s  %s\nAIM %d   STRATEGY %d   MENTAL %d   TEAMWORK %d   FORM %d\nRECOMMENDED: %s" % [str(player.get("handle",player.get("name","Player"))),str(player.get("role","Flex")).to_upper(),int(player.get("aim",0)),int(player.get("game_sense",0)),int(player.get("clutch",0)),int(player.get("teamwork",0)),int(player.get("form",0)),recommendation],12,TEXT); identity.custom_minimum_size.x=550; row.add_child(identity)
		var current:=str(game.data.get("individual_training",{}).get(str(player.get("id","")),recommendation)); for focus in ["Aim","Strategy","Mental","Recovery","Teamwork"]: var focus_button:=_button(focus,current==focus); focus_button.pressed.connect(func(): game.set_individual_training(str(player.get("id","")),focus); _show_page("training")); row.add_child(focus_button)
	var impact:Dictionary=game.data.get("recent_training_impact",{})
	var report:=_panel("RECENT TRAINING IMPACT",PANEL); content.add_child(report)
	if impact.is_empty(): report.add_child(_empty_state("NO COMPLETED WEEK","Complete a career week to produce verified training changes."))
	else: report.add_child(_label("Week %d  •  %s  •  Energy %+d  •  Team power %+d\nAttribute changes are consumed by MatchRuntime through the updated player attributes, form, energy and teamwork." % [int(impact.get("week",0)),str(impact.get("focus","")),int(impact.get("energy_delta",0)),int(impact.get("team_power_delta",0))],13,TEXT))
	var staff_panel:=_panel("STAFF IMPACT",PANEL); content.add_child(staff_panel); for staff in game.data.get("staff",[]): staff_panel.add_child(_action_row(str(staff.get("rating",0)),str(staff.get("role","Staff")),str(staff.get("effect","")),PURPLE))

func _player_stats_page() -> void:
	_header("PLAYER PERFORMANCE", "Read the squad through its players: current form, energy, role and competitive ceiling.", "ACTIVE ROSTER")
	var roster: Array = game.data.get("roster", [])
	var average_ovr := _average("overall")
	var average_form := _average("form")
	var average_energy := _average("energy")
	var strongest: Dictionary = roster.reduce(func(best, current): return current if best.is_empty() or int(current.get("overall", 0)) > int(best.get("overall", 0)) else best, {}) if not roster.is_empty() else {}
	if strongest.is_empty(): content.add_child(_empty_state("NO ACTIVE PLAYERS", "Build a roster before comparing player performance.")); return
	var compact_layout := ResponsiveScript.is_compact(get_viewport_rect().size)
	var spotlight: BoxContainer = VBoxContainer.new() if compact_layout else HBoxContainer.new(); spotlight.add_theme_constant_override("separation",24); content.add_child(spotlight)
	var featured := UIComponentsScript.hero_panel("TOP PERFORMER", "The current overall leader in the active squad.", CYAN); featured.size_flags_horizontal=Control.SIZE_EXPAND_FILL; featured.custom_minimum_size.y=285; spotlight.add_child(featured)
	var featured_line:=HBoxContainer.new(); featured_line.add_theme_constant_override("separation",20); featured.add_child(featured_line); featured_line.add_child(_player_avatar(str(strongest.get("avatar_asset_id","")),Vector2(150,190)))
	var featured_copy:=VBoxContainer.new(); featured_copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL; featured_line.add_child(featured_copy)
	featured_copy.add_child(_label("@%s"%str(strongest.get("handle",strongest.get("name","player"))),30,TEXT))
	featured_copy.add_child(_label(str(strongest.get("name","Player")),14,MUTED))
	featured_copy.add_child(_label("%d"%int(strongest.get("overall",0)),52,CYAN))
	featured_copy.add_child(_label("OVERALL  •  %s"%str(strongest.get("role","Flex")).to_upper(),11,_role_color(str(strongest.get("role","Flex")))))
	var featured_metrics:=HBoxContainer.new(); featured_metrics.add_theme_constant_override("separation",14); featured_copy.add_child(featured_metrics); featured_metrics.add_child(_decision_signal("FORM",str(strongest.get("form",0)),GOLD)); featured_metrics.add_child(_decision_signal("ENERGY","%d%%"%int(strongest.get("energy",0)),_metric_color(int(strongest.get("energy",0))))); featured_metrics.add_child(_decision_signal("CLUTCH",str(strongest.get("clutch",0)),PURPLE))
	var open_featured:=_button("OPEN DOSSIER  →",true); open_featured.pressed.connect(func(): selected_profile_player=strongest; _show_page("player_detail")); featured_copy.add_child(open_featured)
	var baseline:=VBoxContainer.new(); baseline.custom_minimum_size.x=0 if compact_layout else 390; baseline.add_theme_constant_override("separation",12); spotlight.add_child(baseline); baseline.add_child(_label("Squad baseline",22,TEXT)); baseline.add_child(_label("OVR %d  •  FORM %d  •  ENERGY %d%%"%[average_ovr,average_form,average_energy],18,GOLD)); baseline.add_child(_progress(average_form,GOLD,7)); baseline.add_child(_label("%d player(s) are below the current form average."%roster.filter(func(p): return int(p.get("form",0))<average_form).size(),13,MUTED)); baseline.add_child(_label(UIDataPresenterScript.status_word(average_energy,"READY","MANAGE LOAD","RECOVERY NEEDED"),15,_metric_color(average_energy))); var team_analysis:=_button("OPEN TEAM ANALYSIS  →",false); team_analysis.pressed.connect(_show_page.bind("analytics")); baseline.add_child(team_analysis)
	var comparison:=VBoxContainer.new(); comparison.add_theme_constant_override("separation",7); content.add_child(comparison); comparison.add_child(_label("Squad comparison",20,TEXT))
	for player in roster: comparison.add_child(_performance_player_row(player,average_ovr))

func _media_page() -> void:
	_header("MEDIA CENTER", "Public responses affect supporters, squad morale and board expectations.", "COMMUNICATION")
	var media_story: Dictionary=game.current_media_story(); var media_available:=str(media_story.get("status","AVAILABLE"))=="AVAILABLE"
	var compact_layout := ResponsiveScript.is_compact(get_viewport_rect().size)
	var story := _panel("PRESS CONFERENCE • RESPONSE REQUIRED" if media_available else "PRESS CONFERENCE • ANSWERED", PANEL_HIGH); content.add_child(story)
	var conference: BoxContainer = VBoxContainer.new() if compact_layout else HBoxContainer.new(); conference.add_theme_constant_override("separation", 24); story.add_child(conference)
	var prompt := VBoxContainer.new(); prompt.custom_minimum_size.x = 0 if compact_layout else 500; prompt.add_theme_constant_override("separation", 12); conference.add_child(prompt)
	prompt.add_child(_tag("LIVE MEDIA DUTY" if media_available else "RESPONSE RECORDED", ORANGE if media_available else SUCCESS))
	prompt.add_child(_label(str(media_story.get("prompt","Expectations rise before the next lobby.")), 23, TEXT))
	prompt.add_child(_label("Choose your framing. The media system records it." if media_available else "%s • %s" % [str(media_story.get("tone","ANSWERED")),str(media_story.get("answered_date",""))], 13, MUTED))
	prompt.add_child(_decision_signal("SUPPORTERS", GameStateScript.money(int(game.data.get("fans", 0))), CYAN))
	prompt.add_child(_decision_signal("FAN SENTIMENT", "%d%%" % int(game.data.get("fan_sentiment", 65)), ACCENT))
	prompt.add_child(_decision_signal("BOARD", "%d%%" % int(game.data.get("board_confidence", 65)), GOLD))
	var responses := VBoxContainer.new(); responses.size_flags_horizontal = Control.SIZE_EXPAND_FILL; responses.add_theme_constant_override("separation", 9); conference.add_child(responses)
	responses.add_child(_label("SELECT YOUR RESPONSE" if media_available else "RESOLVED CONSEQUENCE", 11, CYAN))
	if media_available:
		for spec in [["POSITIVE", "We are ready to challenge for the podium.", "success"], ["NEUTRAL", "Our focus is executing the plan, one match at a time.", "secondary"], ["NEGATIVE", "The current schedule makes expectations unrealistic.", "danger"]]:
			var answer := _button_variant("%s\n%s" % [spec[0], spec[1]], spec[2]); answer.custom_minimum_size.y = 64; answer.alignment = HORIZONTAL_ALIGNMENT_LEFT; answer.pressed.connect(func(): var result := game.record_media_response(str(spec[0]),str(spec[1]),str(media_story.get("id",""))); _notify("Media response recorded." if bool(result.get("ok",false)) else str(result.get("error","Response failed."))); _show_page("media")); responses.add_child(answer)
	else:
		responses.add_child(_action_row(str(media_story.get("tone","ANSWERED")),str(media_story.get("message","Response recorded")),"Fan sentiment %+d • Board confidence %+d" % [int(media_story.get("effects",{}).get("fan_sentiment",0)),int(media_story.get("effects",{}).get("board_confidence",0))],SUCCESS))
	var meta_state: Dictionary = game.data.get("meta_state", {}); var meta_copy := "No analyzed match sample" if meta_state.get("weapon_usage", {}).is_empty() else "%d weapons in the current telemetry sample" % meta_state.get("weapon_usage", {}).size()
	var feed := _panel("MEDIA PULSE", PANEL); content.add_child(feed); feed.add_child(_pulse_row("SUPPORTERS", "Audience status", "%s supporters are tracking the next event" % GameStateScript.money(int(game.data.fans)), CYAN, "dashboard")); feed.add_child(_pulse_row("META", "Analyst sample", meta_copy, PURPLE, "analytics"))

func _settings_page() -> void:
	_header("MANAGER PROFILE & SETTINGS", "Career identity, local-save status and interface accessibility.", "LOCAL CAREER")
	var split := HBoxContainer.new(); split.add_theme_constant_override("separation", 14); content.add_child(split)
	var profile := _panel("MANAGER PROFILE", PANEL_HIGH); profile.size_flags_horizontal = Control.SIZE_EXPAND_FILL; split.add_child(profile)
	profile.add_child(_label(str(game.data.get("manager_name", "Manager")), 28, TEXT))
	profile.add_child(_tag("SEASON %d  •  %s" % [int(game.data.get("season", 1)), str(game.data.get("career_type", "normal")).to_upper()], CYAN))
	profile.add_child(_action_row("CLUB", str(game.data.get("org_name", "Organization")), "Region %s • World rank #%d" % [str(game.data.get("region", "Global")), _player_world_rank()], ACCENT))
	profile.add_child(_action_row("CAREER", "%d match records" % game.data.get("history", []).size(), "Reputation %d / 100 • %s fans" % [int(game.data.get("reputation", 0)), GameStateScript.money(int(game.data.get("fans", 0)))], GOLD))
	var controls := _panel("SAVE & CAREER", PANEL); controls.custom_minimum_size.x = 410; split.add_child(controls)
	controls.add_child(_label("LOCAL CAREER SAVE", 11, CYAN))
	controls.add_child(_label("Autosave runs after committed management actions.", 12, MUTED))
	var save_now := _button("SAVE CAREER NOW", true); save_now.pressed.connect(func(): game.save_game(); _notify("Career saved.")); controls.add_child(save_now)
	var back_home := _button("RETURN TO COMMAND CENTER", false); back_home.pressed.connect(_show_page.bind("dashboard")); controls.add_child(back_home)
	_build_settings_controls(true)

func _developer_page() -> void:
	_header("CUSTOM RULES", "Optional rules connect to new matches and mark this career as modified", "PLAYER-CONTROLLED RULESET")
	var enabled := bool(game.data.get("developer_mode", false)); var toggle := _button("DISABLE DEVELOPER MODE" if enabled else "ENABLE DEVELOPER MODE", enabled); toggle.pressed.connect(func(): game.set_developer_mode(not enabled); _show_page("developer")); content.add_child(toggle)
	var status := _panel("RUNTIME OVERRIDES", PANEL); content.add_child(status)
	for spec in [["weapon_damage_scale","WEAPON DAMAGE"],["zone_damage_scale","ZONE DAMAGE"],["loot_density_scale","LOOT DENSITY"],["ai_aggression_scale","AI AGGRESSION"],["vehicle_density_scale","VEHICLE DENSITY"]]:
		var row := HBoxContainer.new(); status.add_child(row); var value := SpinBox.new(); value.min_value=0.25; value.max_value=4.0; value.step=0.05; value.value=float(game.data.get("simulation_overrides",{}).get(spec[0],1.0)); value.size_flags_horizontal=Control.SIZE_EXPAND_FILL; var override_label := _label(str(spec[1]),12,TEXT); override_label.custom_minimum_size.x=180; row.add_child(override_label); row.add_child(value); var apply := _button("APPLY", true); apply.disabled=not enabled; apply.pressed.connect(func(): var result := game.set_simulation_override(str(spec[0]),value.value); _notify("Runtime override applied." if bool(result.get("ok",false)) else str(result.get("error","Rejected.")))); row.add_child(apply)
	var reset := _button("RESET ALL OVERRIDES", false); reset.disabled=not enabled; reset.pressed.connect(func(): game.reset_simulation_overrides(); _show_page("developer")); status.add_child(reset)
	var tools := _panel("INTERNAL TOOLS", PANEL); content.add_child(tools)
	var lab := _button("OPEN EXISTING MATCH LAB", true); lab.disabled=not enabled; lab.pressed.connect(_show_page.bind("match_lab")); tools.add_child(lab)
	var map_tool := _button("OPEN EXISTING MAP MANAGER", false); map_tool.disabled=not enabled; map_tool.pressed.connect(_show_page.bind("map_manager")); tools.add_child(map_tool)
	tools.add_child(_label("AI debugger, zone simulation and entity controls remain owned by the existing Match Lab. They unlock only while Custom Rules is enabled and mark the career as modified.", 11, MUTED))

func _inbox() -> void:
	var unread:int = game.data.inbox.filter(func(message): return not bool(message.get("read", false))).size()
	var pending_count: int = game.data.get("pending_events", []).size() + game.data.get("scrim_requests", []).size()
	_header("INBOX", "Decisions, reports and conversations that can change the career.", "%d RESPONSE REQUIRED  •  %d UNREAD" % [pending_count, unread])
	var scrim_requests: Array = game.data.get("scrim_requests", [])
	for request in scrim_requests:
		var participants: Array = request.get("participants", []); var scrim := UIComponentsScript.hero_panel(str(request.get("cluster_name","SCRIM CLUSTER A")),"A private practice lobby is ready for your response.",CYAN); content.add_child(scrim); scrim.add_child(_label("SCRIM INVITATION",11,CYAN)); scrim.add_child(_label("%d TEAMS • %d OPEN SLOTS • %s %s • NO RANKING IMPACT" % [participants.size(),int(request.get("available_slots",0)),str(request.get("date",game.data.current_date)),str(request.get("time","15:00"))],12,MUTED))
		var teams := HBoxContainer.new(); teams.add_theme_constant_override("separation",6); scrim.add_child(teams)
		for participant in participants.slice(0, mini(8,participants.size())): teams.add_child(_team_logo(str(participant.get("logo_asset_id","")),str(participant.get("team_name","TM")).left(2),Vector2(38,38)))
		if participants.size()>8: teams.add_child(_tag("+%d TEAMS"%(participants.size()-8),CYAN))
		var setup := HBoxContainer.new()
		scrim.add_child(setup)
		var matches := OptionButton.new()
		for count in [1,3,5,7]:
			matches.add_item("%d MATCHES" % count)
			matches.set_item_metadata(matches.item_count - 1, count)
		matches.select(1)
		setup.add_child(matches)
		var map_choice := OptionButton.new()
		for map_entry in [["VERDANT REACH","verdant_reach"],["SUNSCORCH BASIN","sunscorch_basin"],["TACTICAL ISLAND","tactical_island"],["FROSTLINE VALLEY","frostline_valley"],["COASTAL BREAKWATER","coastal_breakwater"],["HIGHLAND RESERVE","highland_reserve"]]: map_choice.add_item(str(map_entry[0])); map_choice.set_item_metadata(map_choice.item_count-1,str(map_entry[1]))
		setup.add_child(map_choice)
		var objective := OptionButton.new()
		for spec in [["TACTICAL FAMILIARITY","TACTICAL_FAMILIARITY"],["CHEMISTRY","CHEMISTRY"],["PLAYER FORM","PLAYER_FORM"],["OPPONENT ANALYSIS","OPPONENT_ANALYSIS"]]:
			objective.add_item(str(spec[0]))
			objective.set_item_metadata(objective.item_count - 1, str(spec[1]))
		setup.add_child(objective)
		var accept := _button("ACCEPT CLUSTER",true); accept.pressed.connect(func(): var result:=game.accept_scrim(str(request.id),{"matches":int(matches.get_item_metadata(matches.selected)),"map":str(map_choice.get_item_metadata(map_choice.selected)),"objective":str(objective.get_item_metadata(objective.selected))}); _notify("Cluster scrim completed and training effects saved." if bool(result.get("ok",false)) else str(result.get("error","Scrim failed"))); _show_page("inbox")); setup.add_child(accept); var reject:=_button("DECLINE",false); reject.pressed.connect(func(): game.reject_scrim(str(request.id)); _show_page("inbox")); setup.add_child(reject)
	for event in game.data.get("pending_events", []):
		var urgent := _panel("RESPONSE REQUIRED", Color("251720")); content.add_child(urgent)
		var context: Dictionary = event.get("context", {})
		var event_type := str(event.get("type", "event"))
		urgent.add_child(_label(event_type.replace("_", " ").to_upper(), 20, DANGER))
		var event_copy := "Placement #%d • %d kills. Your answer changes real career state and is recorded in history." % [int(context.get("placement", 0)), int(context.get("kills", 0))]
		if event_type == "transfer_offer":
			event_copy = "%s responded %s to a %d-month contract at $%s per month. Choose a listed response to resolve this negotiation." % [str(context.get("player_name", "The player")), str(context.get("response", "PENDING")), int(context.get("months", 0)), GameStateScript.money(int(context.get("salary", 0)))]
		elif event_type == "inbound_transfer_offer":
			event_copy = "%s offers $%s for %s. Accepting removes the player from the active roster and records transfer income; rejecting keeps the player." % [str(context.get("buyer_name","A club")),GameStateScript.money(int(context.get("amount",0))),str(context.get("player_name","the player"))]
		elif event_type == "sponsor_pressure":
			event_copy = "Sponsor review status: %s • objective progress %d%%. Your response changes the recorded board, supporter or finance state." % [str(context.get("state", "REVIEW")).replace("_", " "), int(context.get("progress", 0))]
		elif event_type == "relationship_conflict":
			var player_a := str(context.get("player_a", "Player A")); var player_b := str(context.get("player_b", "Player B")); var names: Dictionary = {}
			for player in game.data.get("roster", []): names[str(player.get("id", ""))] = str(player.get("name", "Player"))
			event_copy = "%s and %s disagree about %s. Your choice shifts morale, teammate chemistry and future memories." % [str(names.get(player_a, player_a)), str(names.get(player_b, player_b)), str(context.get("topic", "team strategy"))]
		urgent.add_child(_label(event_copy, 12, TEXT))
		var choices := HBoxContainer.new(); choices.add_theme_constant_override("separation", 8); urgent.add_child(choices)
		for choice in event.get("choices", []):
			var choice_id := str(choice.get("id", "")); var event_id := str(event.get("id", "")); var choose := _button(str(choice.get("label", choice_id)), true); choose.tooltip_text = "Effects are applied once and saved to event history."; choose.pressed.connect(func(): var result := game.resolve_event(event_id, choice_id); _notify("Decision recorded." if bool(result.get("ok",false)) else str(result.get("error","Unable to resolve event."))); _show_page("inbox")); choices.add_child(choose)
	var compact_layout:=ResponsiveScript.is_compact(get_viewport_rect().size)
	var split: BoxContainer=VBoxContainer.new() if compact_layout else HBoxContainer.new(); split.add_theme_constant_override("separation", 20); content.add_child(split)
	var folders := VBoxContainer.new(); folders.custom_minimum_size.x = 0 if compact_layout else 210; folders.add_theme_constant_override("separation",6); split.add_child(folders); folders.add_child(_label("Channels",20,TEXT))
	var folder_buttons: Container = GridContainer.new() if compact_layout else VBoxContainer.new()
	if folder_buttons is GridContainer:
		folder_buttons.columns=4
		folder_buttons.add_theme_constant_override("h_separation",6)
		folder_buttons.add_theme_constant_override("v_separation",6)
	else:
		folder_buttons.add_theme_constant_override("separation",6)
	folders.add_child(folder_buttons)
	for f in ["ALL", "BOARD", "TEAM", "SCOUTING", "COMPETITION", "MEDIA", "FINANCE"]:
		var channel := _button(f, f == inbox_channel); channel.alignment = HORIZONTAL_ALIGNMENT_LEFT; channel.pressed.connect(func(): inbox_channel = f; _show_page("inbox")); folder_buttons.add_child(channel)
	var messages := VBoxContainer.new(); messages.size_flags_horizontal = Control.SIZE_EXPAND_FILL; messages.add_theme_constant_override("separation",6); split.add_child(messages); messages.add_child(_label("Latest messages",20,TEXT))
	var visible_count := 0
	for item in game.data.inbox:
		var category := str(item.get("category", "SYSTEM")); var color := DANGER if category == "URGENT" else GOLD if category in ["CONTRACT", "SPONSOR"] else CYAN if category == "SCOUT" else ORANGE if category == "COMPETITION" else MUTED
		var display_channel := _inbox_category_name(category)
		if inbox_channel != "ALL" and display_channel != inbox_channel: continue
		visible_count += 1
		var state := "● UNREAD" if not bool(item.get("read", false)) else "READ"
		var row := _button("%s  •  WEEK %d  •  %s\n%s\n%s" % [display_channel, int(item.get("week", 1)), state, str(item.get("title", "")), str(item.get("body", ""))], false); row.alignment = HORIZONTAL_ALIGNMENT_LEFT; row.custom_minimum_size.y = 88; row.add_theme_color_override("font_color", color if not bool(item.get("read", false)) else MUTED); var message_style:=_style(Color(color,0.055) if not bool(item.get("read",false)) else Color(PANEL,0.35),2,Color.TRANSPARENT,0); message_style.border_width_left=3 if not bool(item.get("read",false)) else 0; message_style.border_color=color; row.add_theme_stylebox_override("normal",message_style); row.tooltip_text = "Open this message and continue to the related screen"; row.pressed.connect(func():
			item.read = true
			game.save_game()
			var destination := str(item.get("action_page", "")); if not destination.is_empty(): _show_page(destination) else: _show_page("inbox"))
		messages.add_child(row)
	if visible_count == 0: messages.add_child(_empty_state("NO MESSAGES", "This channel has no current updates."))

func _inbox_category_name(category:String) -> String:
	if category in ["URGENT", "BOARD", "CONTRACT"]: return "BOARD"
	if category in ["TEAM", "PLAYER", "RECOVERY"]: return "TEAM"
	if category in ["SCOUT", "TRANSFER"]: return "SCOUTING"
	if category in ["COMPETITION", "TOURNAMENT", "MATCH"]: return "COMPETITION"
	if category in ["SPONSOR", "FINANCE"]: return "FINANCE"
	return "MEDIA"

func _competition_center() -> void:
	var competitions: Array = game.data.get("tournaments", [])
	_header("COMPETITION CENTER", "Allocate lineup capacity, energy and priority across active events.", "%d ACTIVE COMPETITIONS" % competitions.size())
	var load := _panel("THIS WEEK", PANEL_HIGH); content.add_child(load)
	var load_metrics := HBoxContainer.new(); load_metrics.add_theme_constant_override("separation", 10); load.add_child(load_metrics)
	var matches: int = game.data.get("calendar_events", []).filter(func(event): return str(event.get("status", "scheduled")) == "scheduled" and str(event.get("date", "")) <= game._add_days(str(game.data.current_date), 7)).size()
	load_metrics.add_child(_visual_stat("MATCHES", matches, GOLD, "Next 7 days")); load_metrics.add_child(_visual_stat("COMPETITIONS", competitions.size(), CYAN, "Active fronts")); load_metrics.add_child(_visual_stat("TEAM LOAD", "HIGH" if matches >= 3 else "MEDIUM", DANGER if matches >= 3 else GOLD, "Energy & rotation matter"))
	var grid := GridContainer.new(); grid.columns = ResponsiveScript.columns(get_viewport_rect().size,4,3,2); grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 12); content.add_child(grid)
	for competition in competitions:
		var competition_id := str(competition.get("id", ""))
		var live_standings := game.get_tournament_standings(competition_id)
		var own_rows := live_standings.filter(func(row): return bool(row.get("is_player", false)))
		var own_row: Dictionary = own_rows[0] if not own_rows.is_empty() else {}
		var competition_events: Array = game.data.get("calendar_events", []).filter(func(item): return str(item.get("tournament_id", "")) == competition_id)
		var completed_count := competition_events.filter(func(item): return str(item.get("status", "scheduled")) == "completed").size()
		var next_events := competition_events.filter(func(item): return str(item.get("status", "scheduled")) == "scheduled")
		competition.standing = int(own_row.get("rank", live_standings.size()))
		competition.stage = "COMPLETE" if completed_count == competition_events.size() and not competition_events.is_empty() else "ROUND %d/%d" % [completed_count + 1, competition_events.size()]
		competition.next_in_days = 0 if next_events.is_empty() else maxi(0, int((Time.get_unix_time_from_datetime_string(str(next_events[0].date) + "T00:00:00") - Time.get_unix_time_from_datetime_string(str(game.data.current_date) + "T00:00:00")) / 86400.0))
		var card := _panel(str(competition.get("short_name", "COMP")), Color("0a141c")); card.custom_minimum_size = Vector2(300, 330); grid.add_child(card)
		var identity:=HBoxContainer.new(); identity.add_theme_constant_override("separation",12); card.add_child(identity); identity.add_child(_team_logo(str(competition.get("logo_asset_id","")),str(competition.get("short_name","CP")),Vector2(58,58))); var identity_copy:=VBoxContainer.new(); identity_copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL; identity.add_child(identity_copy); identity_copy.add_child(_label(str(competition.get("name", "Competition")), 18, TEXT)); identity_copy.add_child(_label("%s · TIER %s" % [competition.get("tournament_type","INTERNATIONAL"),competition.get("tier",1)], 11, MUTED))
		card.add_child(_label("%d TEAMS  •  %d PLAYERS  •  %d MATCHES" % [int(competition.get("team_count",16)),int(competition.get("max_players",64)),int(competition.get("total_matches",1))], 11, CYAN)); card.add_child(_label("#%d" % int(competition.get("standing", 0)), 38, ACCENT)); card.add_child(_label("CURRENT STANDING  •  %s" % str(competition.get("stage", "")), 11, MUTED)); card.add_child(_label("$%s PRIZE POOL" % GameStateScript.money(int(competition.get("prize_pool",0))), 20, GOLD)); var qualification:Dictionary=competition.get("qualification_rules",{}); card.add_child(_label("ENTRY: TIER %s  •  %s"%[str(qualification.get("minimum_tier","D")),"%d RP"%int(qualification.get("minimum_ranking_points",0)) if int(qualification.get("minimum_ranking_points",0))>0 else "NO RP FLOOR"],11,MUTED))
		var reasons: Array = competition.get("priority_reasons", []); if not reasons.is_empty(): card.add_child(_label("WHY  •  %s" % str(reasons[0]), 11, MUTED))
		var registration := game.tournament_registration_status(competition_id); var registration_status := str(registration.get("status","NOT_ELIGIBLE")); card.add_child(_tag(registration_status.replace("_"," "), ACCENT if registration_status=="REGISTERED" else DANGER if registration_status in ["NOT_ELIGIBLE","SCHEDULE_CONFLICT"] else GOLD))
		if registration_status == "AVAILABLE":
			var register := _button("REGISTER", true); register.pressed.connect(func(): var result := game.register_tournament(competition_id); _notify("Tournament registered." if bool(result.get("ok",false)) else str(result.get("status","Registration failed"))); _show_page("tournament")); card.add_child(register)
		var open := _button("OPEN COMPETITION  →", false); open.pressed.connect(func(): selected_competition_id = str(competition.get("id", "")); _show_page("competition_detail")); card.add_child(open)
	var upcoming := _panel("UPCOMING", PANEL); content.add_child(upcoming)
	var upcoming_list := HBoxContainer.new(); upcoming_list.add_theme_constant_override("separation", 12); upcoming.add_child(upcoming_list)
	for event in game.data.get("calendar_events", []).filter(func(item): return str(item.get("status", "scheduled")) == "scheduled").slice(0, 5):
		var event_card := _action_row(str(event.get("tournament", "COMP")).left(4).to_upper(), str(event.get("round", "Match")), "%s  •  %s" % [str(event.get("date", "")), str(event.get("map", ""))], GOLD); event_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL; upcoming_list.add_child(event_card)

func _competition_detail() -> void:
	var event := game.get_playable_match()
	if event.is_empty(): event = game.get_next_match(true)
	var tournament_id := selected_competition_id if not selected_competition_id.is_empty() else str(event.get("tournament_id", game.data.get("active_tournament_id", "gsi_2026_s1")))
	var competition: Dictionary = {}
	for item in game.data.get("tournaments", []):
		if str(item.get("id", "")) == tournament_id: competition = item; break
	if event.is_empty() or str(event.get("tournament_id", "")) != tournament_id:
		var matches: Array = game.data.get("calendar_events", []).filter(func(item): return str(item.get("tournament_id", "")) == tournament_id); event = matches[0] if not matches.is_empty() else {}
	var tournament_name := str(competition.get("name", event.get("tournament", game.data.get("active_tournament_name", "Global Survival Invitational"))))
	var team_count := int(competition.get("team_count", event.get("teams", game.data.get("active_tournament_team_count", 16))))
	var rounds: Array = game.data.get("calendar_events", []).filter(func(item): return str(item.get("tournament_id", "")) == tournament_id)
	var completed := rounds.filter(func(item): return str(item.get("status", "scheduled")) == "completed").size()
	_header(tournament_name, "Tournament schedule, standings, cut line and round progression.", "LIVE TOURNAMENT")
	var hero := _panel(tournament_name.to_upper(), PANEL_HIGH); content.add_child(hero)
	var summary := HBoxContainer.new(); summary.add_theme_constant_override("separation", 12); hero.add_child(summary)
	summary.add_child(_team_logo(str(game.data.get("active_tournament_logo_asset_id", "")), tournament_name.left(2).to_upper(), Vector2(82, 82)))
	summary.add_child(_visual_stat("TEAMS", team_count, CYAN, "Active lobby")); summary.add_child(_visual_stat("MATCHES", "%d/%d" % [completed, rounds.size()], GOLD, "Completed")); summary.add_child(_visual_stat("CUT LINE", "TOP 8", ORANGE, "Final qualification")); summary.add_child(_visual_stat("PRIZE POOL", "$%s" % GameStateScript.money(int(game.data.get("active_tournament_prize_pool", 0))), ACCENT, "Current event"))
	var actions := HBoxContainer.new(); actions.add_theme_constant_override("separation", 8); hero.add_child(actions)
	var next_match := _button("OPEN MATCH DAY", true); next_match.pressed.connect(_show_page.bind("match")); actions.add_child(next_match)
	var calendar := _button("VIEW CALENDAR", false); calendar.pressed.connect(_show_page.bind("calendar")); actions.add_child(calendar)
	var split := HBoxContainer.new(); split.add_theme_constant_override("separation", 16); content.add_child(split)
	var standings := _panel("LIVE STANDINGS", PANEL_HIGH); standings.size_flags_horizontal = Control.SIZE_EXPAND_FILL; split.add_child(standings)
	standings.add_child(_label("RK   TEAM                         MP   WWCD   KILLS   PTS", 11, MUTED))
	for row in game.get_tournament_standings(tournament_id):
		var color := ACCENT if bool(row.get("is_player", false)) else GOLD if int(row.rank) <= 3 else ORANGE if int(row.rank) == 8 else TEXT
		var marker := "QUALIFIED" if int(row.rank) <= 8 else "CUT"
		var standing_row := HBoxContainer.new(); standing_row.custom_minimum_size.y = 34; standing_row.add_theme_constant_override("separation", 8); standings.add_child(standing_row)
		var rank_label := _label("%02d" % row.rank, 12, color); rank_label.custom_minimum_size.x = 24; standing_row.add_child(rank_label); standing_row.add_child(_team_logo(str(row.get("logo_asset_id", "")), str(row.name).left(2).to_upper(), Vector2(28, 28)))
		var standing_name := _label(str(row.name), 12, color); standing_name.custom_minimum_size.x = 220; standing_row.add_child(standing_name)
		var standing_stats := _label("MP %d   W %d   K %d   PTS %d" % [row.matches, row.wins, row.kills, row.points], 12, color); standing_stats.custom_minimum_size.x = 150; standing_row.add_child(standing_stats); var standing_fill := Control.new(); standing_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL; standing_row.add_child(standing_fill); standing_row.add_child(_tag(marker, color))
	var schedule := _panel("TOURNAMENT SCHEDULE", PANEL); schedule.custom_minimum_size.x = 460; split.add_child(schedule)
	for round in rounds:
		var status := "COMPLETE" if str(round.status) == "completed" else "NEXT" if str(round.id) == str(event.get("id", "")) else "UPCOMING"
		var color := SUCCESS if status == "COMPLETE" else GOLD if status == "NEXT" else MUTED
		schedule.add_child(_action_row(status, str(round.round), "%s  •  %s" % [round.date, round.map], color))
	var rule := _panel("FORMAT & TIEBREAK", PANEL); content.add_child(rule)
	rule.add_child(_label("SUPER RULE: placement points + 1 point per kill. The top eight advance; ties are resolved by kills, WWCDs, then the most recent result.", 13, TEXT))

func _rankings() -> void:
	_header("WORLD RANKING", "Competitive results determine rank; power remains an internal strength estimate.", "CLUB AND NATIONAL TABLES")
	var controls := HBoxContainer.new(); controls.add_theme_constant_override("separation", 8); content.add_child(controls)
	for tab in ["CLUB", "NATIONAL", "COMPETITION"]:
		var tab_button := _button(tab, tab == ranking_mode)
		tab_button.pressed.connect(func(): ranking_mode = tab; _show_page("rankings"))
		controls.add_child(tab_button)
	var search := LineEdit.new(); search.placeholder_text = "Search teams"; search.custom_minimum_size.x = 220; search.size_flags_horizontal = Control.SIZE_EXPAND_FILL; controls.add_child(search)
	if ranking_mode == "WORLD": ranking_mode = "CLUB"
	var table := _panel("%s COMPETITIVE RANKING" % ranking_mode, PANEL_HIGH); content.add_child(table)
	var header := HBoxContainer.new(); header.custom_minimum_size.y = 30; header.add_theme_constant_override("separation", 8); table.add_child(header)
	var compact := ResponsiveScript.is_compact(get_viewport_rect().size)
	for spec in [["#",42],["TEAM",280 if compact else 430],["REGION",110 if compact else 180],["RP",90 if compact else 120],["FORM",90 if compact else 120],["MOMENTUM",100 if compact else 140],["TIER",70]]:
		var column := _label(str(spec[0]), 11, MUTED); column.custom_minimum_size.x = int(spec[1]); header.add_child(column)
	search.text = ranking_query
	search.text_submitted.connect(func(value): ranking_query = value.strip_edges(); _show_page("rankings"))
	var rows := game.competitive_rankings("NATIONAL" if ranking_mode=="NATIONAL" else "CLUB").map(func(profile): return {"rank":profile.rank,"id":profile.id,"name":profile.name,"region":profile.region,"power":profile.ranking_points,"form":profile.form,"trend":profile.momentum,"tier":profile.tier,"recent_results":profile.recent_results,"logo_asset_id":profile.logo_asset_id,"is_player":str(profile.id)==str(game.data.get("organization_id",""))})
	if ranking_mode == "COMPETITION":
		var tournament_id := str(game.data.get("active_tournament_id", "gsi_2026_s1"))
		rows = game.get_tournament_standings(tournament_id).map(func(row): return {"rank":row.rank,"id":row.get("team_id",""),"name":row.name,"power":row.points,"form":row.kills,"trend":row.wins,"tier":"EVENT","recent_results":[],"region":"POINTS / KILLS / WINS","logo_asset_id":row.get("logo_asset_id", ""),"is_player":row.get("is_player", false)})
	if not ranking_query.is_empty(): rows = rows.filter(func(row): return ranking_query.to_lower() in str(row.name).to_lower())
	if not rows.is_empty():
		var elite:=UIComponentsScript.hero_panel("WORLD ELITE","Ranking Points come from tournament finishes, event tier, consistency and activity decay.",GOLD); content.add_child(elite); content.move_child(elite,table.get_index())
		var podium:=HBoxContainer.new(); podium.add_theme_constant_override("separation",12); elite.add_child(podium)
		for row in rows.slice(0,mini(3,rows.size())): podium.add_child(_ranking_podium_card(row))
	for row in rows.slice(mini(3,rows.size())): table.add_child(_ranking_row(row))
	if rows.is_empty(): table.add_child(_empty_state("NO RESULTS", "No team matches the current filter."))

func _team_profile() -> void:
	var database = game.career_database(); var errors := game.database_errors()
	var team: Dictionary = database.get_team(selected_world_team_id)
	if not errors.is_empty() or team.is_empty():
		_header("TEAM PROFILE", "World database entity", "ERROR")
		content.add_child(_empty_state("TEAM NOT AVAILABLE", "The selected team could not be resolved from GameDatabase.")); return
	_header(str(team.get("name", "Team")).to_upper(), "World team profile, roster and competitive identity", "%s • TIER %s" % [team.get("team_type", "CLUB"), team.get("tier", "D")])
	var hero := HBoxContainer.new(); hero.add_theme_constant_override("separation", 16); content.add_child(hero)
	var identity := _panel("BASIC INFO", PANEL_HIGH); identity.custom_minimum_size.x = 380; hero.add_child(identity)
	identity.add_child(_team_logo(str(team.get("logo_asset_id", "")), str(team.get("tag", "TEAM")), Vector2(128,128)))
	identity.add_child(_label(str(team.get("name", "Team")), 30, TEXT)); identity.add_child(_tag(str(team.get("team_type", "CLUB")), PURPLE if str(team.get("team_type", "CLUB")) == "NATIONAL" else ACCENT))
	identity.add_child(_action_row("REGION", str(team.get("region", "Unknown")), str(team.get("country", "Unknown")), CYAN)); identity.add_child(_action_row("LEVEL", "Tier %s" % team.get("tier", "D"), "Canonical ID: %s" % team.get("id", ""), GOLD))
	var power := int(team.get("ranking", {}).get("power", 50)); var form := int(team.get("performance", {}).get("consistency", 50))
	var metrics := _panel("COMPETITIVE", PANEL); metrics.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hero.add_child(metrics); metrics.add_child(_visual_stat("POWER", power, GOLD, "World database rating")); metrics.add_child(_visual_stat("FORM", form, SUCCESS, "Current consistency")); metrics.add_child(_visual_stat("ROSTER", team.get("roster_ids", []).size(), CYAN, "Currently linked players"))
	var roster_panel := _panel("ROSTER", PANEL_HIGH); content.add_child(roster_panel)
	var roster_grid := GridContainer.new(); roster_grid.columns = ResponsiveScript.columns(get_viewport_rect().size, 3, 2, 2); roster_grid.add_theme_constant_override("h_separation", 10); roster_grid.add_theme_constant_override("v_separation", 10); roster_panel.add_child(roster_grid)
	var players: Array = database.get_team_players(str(team.get("id", "")))
	for source in players:
		var ratings: Dictionary = source.get("ratings", {}); var card := _button("@%s\n%s\n%s • OVR %d" % [source.get("handle", "player"), source.get("display_name", "Unknown"), source.get("role", "Flex"), int(ratings.get("overall", 0))], false); card.alignment = HORIZONTAL_ALIGNMENT_LEFT; card.custom_minimum_size = Vector2(330, 110); card.icon = assets.texture(str(source.get("avatar_asset_id", ""))); card.expand_icon = true; card.add_theme_constant_override("icon_max_width", 76); card.tooltip_text = "Open full Player Profile"; card.pressed.connect(func(): selected_profile_player = game.player_profile_from_database(str(source.get("id", ""))); _show_page("player_detail")); roster_grid.add_child(card)
	if players.is_empty(): roster_panel.add_child(_empty_state("NO ACTIVE ROSTER", "No current players are linked to this team in the PUBG source data."))
	var knowledge := _panel("TEAM IDENTITY & HISTORY", PANEL); content.add_child(knowledge); knowledge.add_child(_action_row("TACTICS", "Insufficient data", "No verified tactical identity exists in the source database.", MUTED)); knowledge.add_child(_action_row("RESULTS", "Insufficient data", "Match history has not been imported for this entity.", MUTED)); knowledge.add_child(_action_row("HISTORY", "Source profile available", str(team.get("source_url", "No source URL")), CYAN))

func _national_team_page() -> void:
	var database = game.career_database(); var selected_id := str(game.data.get("national_team_id", ""))
	if selected_id.is_empty():
		_header("NATIONAL TEAM", "Accept an international role and select players without changing their club careers.", "INTERNATIONAL DUTY")
		var candidates: Array = []
		for national_team in database.teams:
			if str(national_team.get("team_type", "")) == "NATIONAL": candidates.append({"team":national_team,"eligible":game.eligible_national_players(str(national_team.id)).size()})
		candidates.sort_custom(func(a,b): return int(a.eligible)>int(b.eligible))
		if candidates.is_empty(): content.add_child(_empty_state("NO NATIONAL PROGRAMS", "No national teams are available in the current database.")); return
		var featured_entry: Dictionary = candidates[0]; var featured_team: Dictionary = featured_entry.team; var featured_count := int(featured_entry.eligible); var compact_layout:=ResponsiveScript.is_compact(get_viewport_rect().size)
		var ceremony: BoxContainer = VBoxContainer.new() if compact_layout else HBoxContainer.new(); ceremony.add_theme_constant_override("separation",28); content.add_child(ceremony)
		var national_hero:=UIComponentsScript.hero_panel("INTERNATIONAL APPOINTMENT","Represent a country, assemble a six-player squad and compete for national prestige.",PURPLE); national_hero.size_flags_horizontal=Control.SIZE_EXPAND_FILL; national_hero.custom_minimum_size.y=310; ceremony.add_child(national_hero)
		var national_identity:=HBoxContainer.new(); national_identity.add_theme_constant_override("separation",24); national_hero.add_child(national_identity); national_identity.add_child(_team_logo(str(featured_team.get("logo_asset_id","")),str(featured_team.get("tag","NT")),Vector2(170,120)))
		var national_copy:=VBoxContainer.new(); national_copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL; national_identity.add_child(national_copy); national_copy.add_child(_label(str(featured_team.get("name","National Team")),36,TEXT)); national_copy.add_child(_label("%d ELIGIBLE PLAYERS"%featured_count,17,GOLD)); national_copy.add_child(_label("Club contracts and ownership remain unchanged during international duty.",13,MUTED)); var accept_role:=_button("ACCEPT NATIONAL ROLE  →",true); accept_role.disabled=featured_count<4; accept_role.pressed.connect(func(): var result:=game.select_national_team(str(featured_team.id)); if bool(result.get("ok",false)): _build_sidebar(); _show_page("national_team") else: _notify(str(result.get("error","Selection failed")))); national_copy.add_child(accept_role)
		var rules:=VBoxContainer.new(); rules.custom_minimum_size.x=0 if compact_layout else 390; rules.add_theme_constant_override("separation",10); ceremony.add_child(rules); rules.add_child(_label("The role",22,TEXT)); rules.add_child(_label("Select up to six eligible players.\nBuild starters and substitutes.\nClub salaries and transfers remain separate.\nInternational results add prestige.",14,MUTED))
		var alternatives:=VBoxContainer.new(); alternatives.add_theme_constant_override("separation",8); content.add_child(alternatives); alternatives.add_child(_label("Other national programs",20,TEXT))
		for entry in candidates.slice(1,candidates.size()):
			var national: Dictionary=entry.team; alternatives.add_child(_national_program_row(national,int(entry.eligible)))
		return
	var team: Dictionary = database.get_team(selected_id)
	_header(str(team.get("name", "National Team")).to_upper(), "National duty references players from their clubs; no transfers or duplicate entities.", "NATIONAL TEAM")
	var summary := HBoxContainer.new(); summary.add_theme_constant_override("separation", 12); content.add_child(summary); var identity := _panel("INTERNATIONAL SQUAD", PANEL_HIGH); identity.custom_minimum_size.x = 360; summary.add_child(identity); identity.add_child(_team_logo(str(team.get("logo_asset_id", "")), str(team.get("tag", "NT")), Vector2(110,110))); identity.add_child(_label(str(team.get("name", "National Team")), 28, TEXT)); identity.add_child(_tag("NATIONAL TEAM", PURPLE)); identity.add_child(_label("No salary • No transfer fee • No club contract", 12, MUTED))
	var metrics := _panel("CAMP STATUS", PANEL); metrics.size_flags_horizontal = Control.SIZE_EXPAND_FILL; summary.add_child(metrics); metrics.add_child(_visual_stat("CALLED UP", game.data.get("national_roster_ids", []).size(), CYAN, "Maximum 6 players")); metrics.add_child(_visual_stat("ELIGIBLE", game.eligible_national_players(selected_id).size(), GOLD, "Nationality-matched world players")); metrics.add_child(_visual_stat("CONTEXT", "NATIONAL", PURPLE, "Club ownership remains unchanged"))
	var roster := _panel("STARTERS & SUBSTITUTES", PANEL_HIGH); content.add_child(roster); var roster_grid := GridContainer.new(); roster_grid.columns = 3; roster.add_child(roster_grid)
	for player_id in game.data.get("national_roster_ids", []):
		var profile := game.player_profile_from_database(str(player_id)); var release := _button("%s\n@%s • %s\nCURRENT CLUB: %s\nRELEASE FROM SQUAD" % [profile.name, profile.handle, profile.role, profile.get("current_team_name","Free Agent")], false); release.alignment = HORIZONTAL_ALIGNMENT_LEFT; release.icon = assets.texture(str(profile.get("avatar_asset_id",""))); release.expand_icon = true; release.custom_minimum_size = Vector2(340,120); release.pressed.connect(func(): game.release_national_player(str(player_id)); _show_page("national_team")); roster_grid.add_child(release)
	if game.data.get("national_roster_ids", []).is_empty(): roster.add_child(_empty_state("NO PLAYERS CALLED UP", "Select eligible players below. Their club ownership will not change."))
	var available := _panel("AVAILABLE PLAYERS", PANEL); content.add_child(available); var available_grid := GridContainer.new(); available_grid.columns = ResponsiveScript.columns(get_viewport_rect().size, 3, 2, 2); available.add_child(available_grid)
	for profile in game.eligible_national_players(selected_id).slice(0,24):
		if str(profile.id) in game.data.get("national_roster_ids", []): continue
		var call_up := _button("%s\n@%s • %s • OVR %d\nCLUB: %s\nCALL UP" % [profile.name, profile.handle, profile.role, profile.overall, profile.get("current_team_name","Free Agent")], false); call_up.alignment = HORIZONTAL_ALIGNMENT_LEFT; call_up.icon = assets.texture(str(profile.get("avatar_asset_id",""))); call_up.expand_icon = true; call_up.custom_minimum_size = Vector2(340,120); call_up.disabled = game.data.get("national_roster_ids", []).size() >= 6
		call_up.pressed.connect(func():
			var result := game.call_up_player(str(profile.id))
			if not bool(result.get("ok",false)): _notify(str(result.get("error","Call-up failed")))
			_show_page("national_team"))
		available_grid.add_child(call_up)

func _trophy_room() -> void:
	_header("CAREER HISTORY", "Review the verified record built by this organization.", "REPUTATION  %d" % int(game.data.reputation))
	var hero := _panel("ORGANIZATION LEGACY", PANEL_HIGH); content.add_child(hero)
	var hero_row := HBoxContainer.new(); hero_row.add_theme_constant_override("separation", SPACE_LG); hero.add_child(hero_row)
	hero_row.add_child(_team_logo(str(game.data.get("org_logo_asset_id", "")), str(game.data.org_name).left(2).to_upper(), Vector2(110, 110)))
	var hero_copy := VBoxContainer.new(); hero_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hero_row.add_child(hero_copy)
	hero_copy.add_child(_label(str(game.data.org_name), 30, TEXT)); hero_copy.add_child(_label("Season %d • %s • %s supporters" % [game.data.season, game.data.region, GameStateScript.money(int(game.data.fans))], 14, MUTED)); hero_copy.add_child(_progress(int(game.data.reputation), GOLD, 8)); hero_copy.add_child(_label("REPUTATION %d / 100" % int(game.data.reputation), 11, GOLD))
	var hero_metrics := HBoxContainer.new(); hero_metrics.add_theme_constant_override("separation", SPACE_SM); hero_row.add_child(hero_metrics)
	hero_metrics.add_child(_visual_stat("SEASON", int(game.data.season), CYAN, "Career history")); hero_metrics.add_child(_visual_stat("BEST FINISH", "#%d" % _best_placement(), GOLD, "Recorded competition result")); hero_metrics.add_child(_visual_stat("WORLD RANK", "#%d" % _player_world_rank(), ACCENT, "Current position"))
	var shelf := GridContainer.new(); shelf.columns = 3; shelf.add_theme_constant_override("h_separation", 14); shelf.add_theme_constant_override("v_separation", 14); content.add_child(shelf)
	var achievements: Array=[]; if not game.data.get("history",[]).is_empty(): achievements.append(["FIRST RESULT","%d verified match result(s)" % game.data.history.size(),CYAN]); if _best_placement()<=8: achievements.append(["TOP EIGHT","Best placement #%d" % _best_placement(),GOLD]); if game.data.get("history",[]).any(func(match): return int(match.get("placement",99))==1): achievements.append(["MATCH WINNER","A verified first-place result",ACCENT]); if not game.data.get("season_history",[]).is_empty(): achievements.append(["SEASON VETERAN","%d archived season(s)" % game.data.season_history.size(),PURPLE]); if int(game.data.get("fans",0))>=10000: achievements.append(["FAN FAVORITE","%s supporters" % GameStateScript.money(int(game.data.fans)),CYAN]); if achievements.is_empty(): achievements.append(["CAREER IN PROGRESS","Complete matches to create verified milestones",MUTED])
	for i in achievements.size():
		var achievement: Array = achievements[i]; var card := _panel(achievement[0], PANEL); card.custom_minimum_size = Vector2(300, 150); card.add_child(_atlas_preview("legacy.achievement.badges", Rect2((i % 3) * 512, (i / 3) * 512, 512, 512), Vector2(86, 72))); card.add_child(_label(achievement[1], 13, MUTED)); shelf.add_child(card)
	var timeline := _panel("CAREER TIMELINE", PANEL_HIGH); content.add_child(timeline)
	timeline.add_child(_action_row("M01", "Organization founded", "%s entered the %s competition system" % [str(game.data.org_name), str(game.data.region)], ACCENT))
	for season_record in game.data.get("season_history",[]): timeline.add_child(_action_row("S%d" % int(season_record.get("season",0)),"Season %d completed" % int(season_record.get("season",0)),"%d matches • best #%s • %d points" % [int(season_record.get("matches",0)),str(season_record.get("best_placement","—")),int(season_record.get("points",0))],GOLD))
	timeline.add_child(_action_row("NOW", "Current career state", "Best finish #%d • Reputation %d" % [_best_placement(), int(game.data.reputation)], GOLD))
	timeline.add_child(_action_row("DATA", "%d recorded matches" % game.data.get("history", []).size(), "Only completed career results appear in this timeline", MUTED))

func _add_phase_card(parent: HBoxContainer, number: String, title: String, options: Array, key: String, color: Color) -> void:
	var card := _panel(title, PANEL_HIGH)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	card.add_child(_label(number, 32, color))
	card.add_child(_label(str(game.data.tactics[key]), 18, TEXT))
	var choice := OptionButton.new()
	for option in options:
		choice.add_item(option)
	choice.select(options.find(game.data.tactics[key]))
	choice.item_selected.connect(_on_tactic_selected.bind(key, options))

func _coach_selector(parent: Container, key: String, title: String, options: Array, compact := false) -> void:
	var card: VBoxContainer
	if compact:
		card = VBoxContainer.new(); card.add_theme_constant_override("separation",2); card.add_child(_label(title,10,MUTED)); card.custom_minimum_size=Vector2(190,62)
	else:
		card = _panel(title, PANEL_HIGH); card.custom_minimum_size=Vector2(360,120)
	card.size_flags_horizontal=Control.SIZE_EXPAND_FILL; parent.add_child(card)
	var choice := OptionButton.new(); choice.custom_minimum_size=Vector2(180 if compact else 320,42)
	var selected := 0
	for i in options.size(): choice.add_item(str(options[i][1])); choice.set_item_metadata(i,str(options[i][0])); if str(game.data.coach_plan.get(key,""))==str(options[i][0]): selected=i
	choice.select(selected)
	choice.item_selected.connect(_on_coach_plan_selected.bind(key, options))
	card.add_child(choice)

func _on_scout_sort_selected(index: int, options: Array) -> void:
	scout_sort = str(options[index]); _show_page("transfer")

func _on_tactic_selected(index: int, key: String, options: Array) -> void:
	game.data.tactics[key] = str(options[index]); game.save_game(); _show_page("tactics")

func _on_coach_plan_selected(index: int, key: String, options: Array) -> void:
	game.set_coach_plan_values({key:str(options[index][0])}); _refresh_tactical_preview()

func _on_map_region_terrain_selected(index: int, region_index: int) -> void:
	var options := ["urban","forest","field","rock","industrial","water","road"]
	map_editor_data.regions[region_index].terrain = options[index]; _refresh_map_editor_preview()

func _on_map_point_type_selected(index: int, point_index: int) -> void:
	var options := ["house","compound","bridge","warehouse","tower","container","vehicle_spawn","airdrop"]
	map_editor_data.points[point_index].type = options[index]; _refresh_map_editor_preview()

func _candidate_card(p: Dictionary, index: int) -> Button:
	var grade := "S" if int(p.potential) >= 88 else "A" if int(p.potential) >= 78 else "B"
	var strength := "Clutch" if int(p.clutch) >= int(p.teamwork) else "Teamwork"
	var weakness := "Aim" if int(p.aim) < 65 else "Adaptability"
	var confidence := int(p.get("confidence", 0)); var confidence_text := "HIGH" if confidence >= 75 else "MEDIUM" if confidence >= 45 else "LOW"; var confidence_color := SUCCESS if confidence >= 75 else GOLD if confidence >= 45 else DANGER
	var b := Button.new(); b.custom_minimum_size = Vector2(360, 174); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.alignment = HORIZONTAL_ALIGNMENT_LEFT; b.icon = assets.texture(str(p.get("avatar_asset_id", "player.avatar.fallback"))); b.expand_icon = true; b.add_theme_constant_override("icon_max_width", 108); b.text = "%s  •  %s  •  AGE %d\n%s\nOVR %d   •   POTENTIAL %s\nSCOUT CONFIDENCE %d%%  •  %s\nVALUE $%s   •   SALARY $%s" % [p.region, p.role, p.age, p.name, p.get("overall", 0), grade, confidence, confidence_text, GameStateScript.money(int(p.value)), GameStateScript.money(int(p.salary))]; b.add_theme_font_size_override("font_size", 12); b.add_theme_color_override("font_color", TEXT); b.add_theme_color_override("font_hover_color", TEXT); var normal := _style(PANEL, 5, Color(confidence_color, 0.32), 0); normal.border_width_left = 3; b.add_theme_stylebox_override("normal", normal); b.add_theme_stylebox_override("hover", _style(Color("193143"), 5, ACCENT, 1)); b.tooltip_text = "Open full profile • Strength: %s • Risk: %s • Confidence %d%%" % [strength, weakness, confidence]; b.pressed.connect(func(): selected_profile_player = p.duplicate(true); _show_page("player_detail")); return b

func _fill_scout_report(card: VBoxContainer, p: Dictionary, index: int) -> void:
	card.add_child(_player_avatar(str(p.get("avatar_asset_id", "")), Vector2(116, 150))); card.add_child(_tag("%s  •  %s" % [p.region, p.role], CYAN)); card.add_child(_label(str(p.name), 29, TEXT)); card.add_child(_label("AGE %d  •  %s" % [p.age, p.trait], 13, MUTED)); card.add_child(_attribute("AIM", p.aim, DANGER)); card.add_child(_attribute("GAME SENSE", p.game_sense, CYAN)); card.add_child(_attribute("TEAMWORK", p.teamwork, ACCENT)); card.add_child(_attribute("CLUTCH", p.clutch, GOLD)); var confidence_color := SUCCESS if int(p.confidence) >= 75 else GOLD if int(p.confidence) >= 45 else DANGER; card.add_child(_label("SCOUT CONFIDENCE  %d%%" % int(p.confidence), 11, confidence_color)); card.add_child(_progress(p.confidence, confidence_color, 7)); card.add_child(_label("VALUE  $%s\nEXPECTED SALARY  $%s / MONTH" % [GameStateScript.money(int(p.value)), GameStateScript.money(int(p.salary))], 12, GOLD)); var profile := _button("OPEN DOSSIER", false); profile.pressed.connect(func(): selected_profile_player = p.duplicate(true); _show_page("player_detail")); card.add_child(profile); var negotiate := _button("MAKE OFFER", true); negotiate.tooltip_text="Creates an Inbox negotiation; no instant signing."; negotiate.pressed.connect(func(): var result:=game.create_transfer_offer(str(p.id),{"salary":int(p.salary),"months":24,"role":"ROTATION"}); _notify("Offer sent • check Inbox." if bool(result.get("ok",false)) else str(result.get("error","Offer unavailable."))); _show_page("inbox")); card.add_child(negotiate)

func _tactic_display_name(value: String) -> String:
	return {
		"Rotate sớm": "EARLY ROTATION",
		"Kiểm soát trung tâm": "CENTER CONTROL",
		"Fight for zone": "FIGHT FOR ZONE",
		"Đánh chủ động": "PROACTIVE FIGHTS",
		"Giữ vị trí": "HOLD POSITION",
		"Chơi an toàn": "PLAY SAFE"
	}.get(value, value.to_upper())

func _fill_player_profile(card: VBoxContainer, p: Dictionary) -> void:
	card.add_child(_player_avatar(str(p.get("avatar_asset_id", "")), Vector2(82, 82))); card.add_child(_tag("%s  •  %s" % [p.region, p.role], CYAN)); card.add_child(_label(str(p.name), 28, TEXT)); card.add_child(_label("@%s" % str(p.get("handle", "player")), 12, CYAN)); card.add_child(_label("AGE %d  •  %s" % [p.age, p.trait], 13, MUTED)); card.add_child(_label("%d" % p.overall, 48, ACCENT)); card.add_child(_label("OVERALL RATING", 11, MUTED)); card.add_child(_attribute("AIM", p.aim, DANGER)); card.add_child(_attribute("GAME SENSE", p.game_sense, CYAN)); card.add_child(_attribute("TEAMWORK", p.teamwork, ACCENT)); card.add_child(_attribute("CLUTCH", p.clutch, GOLD)); card.add_child(_mini_metric("FORM", int(p.form), GOLD)); card.add_child(_mini_metric("ENERGY", int(p.energy), _metric_color(int(p.energy)))); card.add_child(_label("%d-MONTH CONTRACT  •  $%s/MONTH" % [p.contract, GameStateScript.money(int(p.salary))], 12, MUTED))

func _fill_player_spotlight(card: VBoxContainer, p: Dictionary) -> void:
	card.add_child(_tag(str(p.role), CYAN)); card.add_child(_label(str(p.name), 24, TEXT)); card.add_child(_label("OVR %d  •  FORM %d  •  ENERGY %d%%" % [p.overall, p.form, p.energy], 14, ACCENT)); card.add_child(_progress(p.form, GOLD, 8)); card.add_child(_label("%s  •  POTENTIAL %d" % [p.trait, p.potential], 12, MUTED))

func _formation_board() -> Control:
	var board := Control.new(); board.custom_minimum_size = Vector2(990, 220); board.size_flags_horizontal = Control.SIZE_EXPAND_FILL; var bg := ColorRect.new(); bg.color = Color("0b2630"); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); board.add_child(bg)
	var positions := [Vector2(95, 96), Vector2(390, 48), Vector2(390, 150), Vector2(785, 96)]
	var route := Line2D.new(); route.width = 2.0; route.default_color = Color(ACCENT, 0.55); route.points = PackedVector2Array([Vector2(168, 112), Vector2(462, 64), Vector2(857, 112), Vector2(462, 166), Vector2(168, 112)]); board.add_child(route)
	for i in mini(4, game.data.roster.size()):
		var player: Dictionary = game.data.roster[i]
		var chip := _tag("@%s • %s" % [str(player.get("handle", player.get("name", "PLAYER"))), str(player.get("role", "FLEX")).to_upper()], [CYAN, DANGER, ACCENT, GOLD][i]); chip.position = positions[i]; chip.size = Vector2(145, 32); board.add_child(chip)
	var drop := _tag("DROP ZONE", GOLD); drop.position = Vector2(24, 18); board.add_child(drop); var hold := _tag("TEAM HOLD", DANGER); hold.position = Vector2(890, 18); board.add_child(hold)
	return board

func _rating_row(stat: Dictionary) -> Control:
	var rating := float(stat.get("rating", clampf(5.0 + int(stat.get("kills", 0)) * 0.55 + int(stat.get("damage", 0)) / 900.0 + int(stat.get("revives", 0)) * 0.35 + (0.6 if bool(stat.get("survived", false)) else 0.0), 1.0, 10.0)))
	var row := VBoxContainer.new(); row.add_child(_label("%s  •  %s" % [stat.get("name", "Unknown"), stat.get("role", "Player")], 14, TEXT)); var line := HBoxContainer.new(); line.add_child(_progress(rating * 10.0, GOLD, 7)); line.add_child(_label("%.1f" % rating, 17, GOLD)); row.add_child(line); row.add_child(_label("%d K  •  %d DMG  •  %d REV" % [stat.get("kills", 0), stat.get("damage", 0), stat.get("revives", 0)], 11, MUTED)); return row

func _tactical_replay(match_data: Dictionary) -> VBoxContainer:
	var replay := VBoxContainer.new(); replay.add_theme_constant_override("separation", 8); var map := _asset_preview(_map_asset(str(match_data.get("map", "Verdant Reach"))), Vector2(920, 300)); replay.add_child(map); var controls := HBoxContainer.new(); controls.add_theme_constant_override("separation", 6); replay.add_child(controls)
	var timeline: Array = match_data.get("timeline", [])
	var event_label := _label("No replay events recorded.", 12, MUTED); replay.add_child(event_label)
	var timer := Timer.new(); timer.wait_time = 0.8; replay.add_child(timer)
	var cursor := [maxi(0, timeline.size() - 1)]
	_replay_seek(event_label, timeline, cursor, 0, false)
	var specs := [["icons.replay.previous", "PREVIOUS"], ["icons.replay.play", "PLAY"], ["icons.replay.pause", "PAUSE"], ["icons.replay.next", "NEXT"], ["", "1X"], ["", "2X"], ["", "4X"], ["", "LIVE"]]
	for spec in specs:
		var b := _button(str(spec[1]) if str(spec[0]).is_empty() else "", false); b.custom_minimum_size.x = 58; b.tooltip_text = str(spec[1])
		if not str(spec[0]).is_empty(): b.icon = assets.texture(str(spec[0]))
		match str(spec[1]):
			"PREVIOUS": b.pressed.connect(_replay_seek.bind(event_label, timeline, cursor, -1, false))
			"PLAY": b.pressed.connect(func(): if not timeline.is_empty(): timer.start())
			"PAUSE": b.pressed.connect(timer.stop)
			"NEXT": b.pressed.connect(_replay_seek.bind(event_label, timeline, cursor, 1, false))
			"1X": b.pressed.connect(func(): replay_speed = 1; timer.wait_time = 0.8)
			"2X": b.pressed.connect(func(): replay_speed = 2; timer.wait_time = 0.4)
			"4X": b.pressed.connect(func(): replay_speed = 4; timer.wait_time = 0.2)
			"LIVE": b.pressed.connect(_replay_seek.bind(event_label, timeline, cursor, 0, true))
		controls.add_child(b)
	timer.timeout.connect(_replay_seek.bind(event_label, timeline, cursor, replay_speed, false))
	return replay

func _replay_seek(label: Label, timeline: Array, cursor: Array, delta: int, live: bool) -> void:
	if timeline.is_empty(): return
	cursor[0] = timeline.size() - 1 if live else clampi(int(cursor[0]) + delta, 0, timeline.size() - 1)
	var event: Dictionary = timeline[int(cursor[0])]
	var event_time := float(event.get("time", 0.0))
	label.text = "%02d:%02d  [%s]  %s  •  EVENT %d/%d" % [int(event_time) / 60, int(event_time) % 60, str(event.get("channel", event.get("type", "EVENT"))).to_upper(), str(event.get("text", event.get("reason", ""))), int(cursor[0]) + 1, timeline.size()]

func _header(title: String, subtitle: String, kicker: String = "") -> void:
	var breadcrumb := str(router.descriptor(active_page).get("breadcrumb", "")) if not game.data.is_empty() and UIRouterScript.ROUTES.has(active_page) else ""
	if not kicker.is_empty(): breadcrumb = "%s  •  %s" % [breadcrumb,kicker] if not breadcrumb.is_empty() else kicker
	content.add_child(UIComponentsScript.page_header(title,subtitle,breadcrumb))

func _observer_panel() -> VBoxContainer:
	var box:=UICardScript.new(); box.add_theme_constant_override("separation",7)
	var style:=_style(Color(0.035,0.075,0.105,0.84),4,Color.TRANSPARENT,0); style.content_margin_left=10; style.content_margin_right=10; style.content_margin_top=8; style.content_margin_bottom=8
	box.set_card_style(style)
	return box

func _icon_count(asset_id:String,value:String,tooltip:String)->VBoxContainer:
	var box:=VBoxContainer.new(); box.custom_minimum_size=Vector2(42,44); box.tooltip_text=tooltip; box.alignment=BoxContainer.ALIGNMENT_CENTER
	var icon:=_asset_preview(asset_id,Vector2(28,28)); icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; box.add_child(icon)
	var count:=_label(value,10,TEXT); count.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; box.add_child(count)
	return box

func _observer_weapon(weapon:String,scope:String,ammo:int,primary:bool)->HBoxContainer:
	var row:=HBoxContainer.new(); row.custom_minimum_size=Vector2(250,58); row.add_theme_constant_override("separation",8)
	var image:=_asset_preview(_weapon_asset(weapon,false),Vector2(86,48)); image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; image.tooltip_text=weapon; row.add_child(image)
	var data:=VBoxContainer.new(); data.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(data); data.add_child(_label(weapon,13,TEXT)); data.add_child(_label(("%d" % ammo) + ("  •  "+scope if not scope.is_empty() and scope!="—" else ""),11,GOLD if primary else MUTED))
	return row

func _weapon_asset(weapon:String,kill_feed:bool)->String:
	return assets.weapon_asset_id(weapon, "kill_feed" if kill_feed else "inventory")

func _killfeed_cause_asset(cause:String)->String:
	if cause=="BLUE": return "icons.replay.zone"
	if cause in ["RED_ZONE","RED ZONE"]: return "match.effects.explosion"
	if cause=="VEHICLE": return "icons.equipment.vehicle"
	if cause in ["FRAG","FRAG_CONFIRM"]: return "icons.utility.frag"
	if cause in ["FIRE","FIRE_CONFIRM"]: return "icons.utility.molotov"
	return _weapon_asset(cause,true)

func _killfeed_outcome_text(outcome:String,cause:String)->String:
	if cause=="BLUE": return "BLUE KNOCK" if outcome=="KNOCK" else "BLUE ELIMINATION"
	if cause in ["RED_ZONE","RED ZONE"]: return "RED ZONE KNOCK" if outcome=="KNOCK" else "RED ZONE ELIMINATION"
	if cause=="VEHICLE": return "VEHICLE KNOCK" if outcome=="KNOCK" else "VEHICLE KILL"
	if outcome=="FRAG_CONFIRM": return "FRAG CONFIRM"
	if outcome=="FIRE_CONFIRM": return "FIRE CONFIRM"
	match outcome:
		"KNOCK": return "KNOCK"
		"FLUSH": return "CONFIRMED"
		"BLEED OUT": return "BLEED OUT"
		"SQUAD WIPE": return "SQUAD WIPE"
		_: return outcome

func _short_weapon(weapon:String)->String:
	return "—" if weapon in ["","Unarmed","—"] else weapon

func _roman_level(value:String)->String:
	if "3" in value: return "III"
	if "2" in value: return "II"
	if "1" in value: return "I"
	return "—"

func _status_asset(status:String)->String:
	match status:
		"KNOCKED": return "match.markers.knocked"
		"DEAD": return "match.markers.death"
		"HEALING","REVIVING": return "icons.combat.heal"
		"DRIVING": return "icons.equipment.vehicle"
		"BOOSTING": return "icons.status.energy"
		"LOOTING": return "icons.replay.loot"
		_: return "match.markers.player"

func _status_symbol(status:String)->String:
	match status:
		"AIRBORNE": return "PARACHUTE"
		"DRIVING": return "VEHICLE"
		"HEALING": return "HEAL"
		"BOOSTING": return "BOOST"
		"REVIVING": return "REVIVE"
		"KNOCKED": return "DBNO"
		"DEAD": return "OUT"
		"LOOTING": return "LOOT"
		_: return "ACTIVE"

func _panel(title: String = "", color: Color = PANEL) -> VBoxContainer:
	var box := UICardScript.new()
	box.add_theme_constant_override("separation", SPACE_SM)
	box.set_card_style(_style(color, RADIUS_SM, Color.TRANSPARENT, 0))
	if not title.is_empty():
		var heading := _label("▰  " + title, 12, MUTED)
		heading.add_theme_color_override("font_color", MUTED)
		box.add_child(heading)
	return box

func _visual_stat(title: String, value: Variant, color: Color, note: String) -> VBoxContainer:
	var progress_value := float(value) if value is int or value is float else 0.0
	var card := _panel("", Color("09131a")); card.custom_minimum_size = Vector2(190, 104); card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(_label(title, 10, MUTED)); card.add_child(_label(str(value), 32, color))
	if progress_value > 0.0: card.add_child(_progress(progress_value, color, 5))
	card.add_child(_label(note, 10, MUTED))
	return card

func _status_module(title: String, value: String, color: Color, note: String) -> VBoxContainer:
	var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_theme_constant_override("separation", 2)
	box.add_child(_label(title, 10, MUTED)); box.add_child(_label(value, 32, color)); box.add_child(_label(note, 10, MUTED))
	return box

func _icon_value(icon_id: String, value: String, label: String, color: Color) -> VBoxContainer:
	var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_theme_constant_override("separation", 2)
	var icon := _small_icon(icon_id, 16)
	if icon != null:
		var art := TextureRect.new(); art.texture = icon; art.custom_minimum_size = Vector2(16,16); art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; art.modulate = color; box.add_child(art)
	box.add_child(_label(value, 21, color)); box.add_child(_label(label, 10, MUTED))
	return box

func _dashboard_art(asset_id: String, minimum: Vector2, color: Color) -> TextureRect:
	var art := TextureRect.new(); art.texture = _small_icon(asset_id, maxi(int(minimum.x), int(minimum.y)))
	art.custom_minimum_size = minimum; art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; art.modulate = color
	return art

func _dashboard_icon(asset_id: String, minimum: Vector2, color: Color) -> Control:
	if asset_id.begins_with("symbol."):
		var symbol := DashboardSymbolScript.new(); symbol.kind = asset_id.trim_prefix("symbol."); symbol.tone = color; symbol.custom_minimum_size = minimum; return symbol
	return _dashboard_art(asset_id, minimum, color)

func _dashboard_probability(value: int) -> Control:
	var box := Control.new(); box.custom_minimum_size = Vector2(172, 172)
	var ring := ProbabilityRingScript.new(); ring.value = value; ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); box.add_child(ring)
	var score := _label("%d%%" % value, 40, DANGER); score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; score.set_anchors_preset(Control.PRESET_CENTER); score.position = Vector2(-58, -35); score.size = Vector2(116, 52); box.add_child(score)
	var caption := _label("TOP 8\nCHANCE", 11, TEXT); caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; caption.set_anchors_preset(Control.PRESET_CENTER); caption.position = Vector2(-58, 15); caption.size = Vector2(116, 38); box.add_child(caption)
	return box

func _dashboard_stat(icon_id: String, value: String, caption: String, color: Color) -> VBoxContainer:
	var box := VBoxContainer.new(); box.custom_minimum_size.x = 92; box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.alignment = BoxContainer.ALIGNMENT_CENTER; box.add_theme_constant_override("separation", 3)
	var art := _dashboard_icon(icon_id, Vector2(34, 34), color); art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; box.add_child(art)
	var score := _label(value, 23 if value.length() < 12 else 14, color); score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(score)
	var title := _label(caption, 10, TEXT); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(title)
	return box

func _dashboard_signal(icon_id: String, headline: String, caption: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new(); row.custom_minimum_size.x = 220; row.add_theme_constant_override("separation", 9)
	row.add_child(_dashboard_icon(icon_id, Vector2(30, 30), color))
	var copy := VBoxContainer.new(); copy.custom_minimum_size = Vector2(170, 34); copy.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_child(copy)
	copy.add_child(_label(headline, 12, color)); copy.add_child(_label(caption, 11, TEXT))
	return row

func _dashboard_objective(number: String, title: String, state: String, icon_id: String, page: String) -> Button:
	var item := _button("%s     %s\n           %s                                      ›" % [number, title, state], false); _compact_dashboard_button(item); item.alignment = HORIZONTAL_ALIGNMENT_LEFT; item.custom_minimum_size.y = 27; item.icon = _small_icon(icon_id, 22); item.expand_icon = true; item.add_theme_constant_override("icon_max_width", 22); item.add_theme_color_override("font_color", TEXT); item.tooltip_text = "Open %s" % title; item.pressed.connect(_show_page.bind(page)); return item

func _dashboard_vital(icon_id: String, value: String, caption: String, color: Color, progress: float) -> HBoxContainer:
	var row := HBoxContainer.new(); row.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_theme_constant_override("separation", 9)
	row.add_child(_dashboard_icon(icon_id, Vector2(38, 38), color))
	var copy := VBoxContainer.new(); copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL; copy.add_theme_constant_override("separation", 1); row.add_child(copy)
	copy.add_child(_label(value, 28, TEXT)); copy.add_child(_label(caption, 10, MUTED)); copy.add_child(_progress_static(progress, color, 5))
	return row

func _dashboard_event_item(category: String, title: String, status: String, color: Color, page: String) -> Button:
	var item := _button("%s  %s\n%s" % [category, title, status], false); _compact_dashboard_button(item); item.alignment = HORIZONTAL_ALIGNMENT_LEFT; item.custom_minimum_size.y = 28; item.add_theme_color_override("font_color", color); item.tooltip_text = "Open related decision"; item.pressed.connect(_show_page.bind(page)); return item

func _compact_dashboard_button(button: Button) -> void:
	for state in ["normal", "hover", "pressed"]:
		var style := button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		style.content_margin_left = 14; style.content_margin_right = 14; style.content_margin_top = 5; style.content_margin_bottom = 5
		button.add_theme_stylebox_override(state, style)

func _segmented_gauge(value: int, color: Color) -> HBoxContainer:
	var gauge := HBoxContainer.new(); gauge.add_theme_constant_override("separation", 3)
	for index in 10:
		var segment := ColorRect.new(); segment.custom_minimum_size = Vector2(18, 5); segment.color = color if index < ceili(float(value) / 10.0) else Color("1b2b35"); gauge.add_child(segment)
	return gauge

func _dashboard_leaderboard_row(row: Dictionary) -> HBoxContainer:
	var line := HBoxContainer.new(); line.size_flags_horizontal = Control.SIZE_EXPAND_FILL; line.custom_minimum_size.y = 48; line.add_theme_constant_override("separation", 8)
	var rank := _tag("%02d" % int(row.get("rank", 0)), ACCENT if bool(row.get("is_player", false)) else MUTED); rank.custom_minimum_size.x = 40; line.add_child(rank)
	line.add_child(_team_logo(str(row.get("logo_asset_id", "")), str(row.get("name", "TM")).left(2).to_upper(), Vector2(34, 34)))
	var name := _label(str(row.get("name", "Team")), 14, TEXT); name.size_flags_horizontal = Control.SIZE_EXPAND_FILL; name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; line.add_child(name)
	var power := _label("%d POWER" % int(row.get("power", 0)), 12, CYAN); power.custom_minimum_size.x = 88; power.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; power.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; line.add_child(power)
	return line

func _role_color(role: String) -> Color:
	match role.to_upper():
		"FRAGGER": return DANGER
		"ANCHOR": return CYAN
		"SCOUT": return SUCCESS
		"SUPPORT": return CYAN
		"IGL": return GOLD
		_: return ACCENT

func _squad_summary_metric(caption: String, value: String, color: Color) -> VBoxContainer:
	var box := VBoxContainer.new(); box.custom_minimum_size.x = 150; box.add_theme_constant_override("separation", 1)
	box.add_child(_label(caption, 10, MUTED)); box.add_child(_label(value, 19, color)); return box

func _profile_info_cell(caption: String, value: String, color: Color) -> VBoxContainer:
	var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_theme_constant_override("separation", 3)
	box.add_child(_label(caption, 9, MUTED)); box.add_child(_label(value, 12, color)); return box

func _market_player_row(player: Dictionary) -> Button:
	var confidence:=int(player.get("confidence",0)); var tone:=SUCCESS if confidence>=75 else GOLD if confidence>=45 else DANGER
	var row:=_button("%s\n%s  •  AGE %d  •  OVR %d     VALUE $%s     SALARY $%s / MONTH     SCOUT %d%%"%[str(player.get("name","Player")),str(player.get("role","Flex")).to_upper(),int(player.get("age",0)),int(player.get("overall",0)),GameStateScript.money(int(player.get("value",0))),GameStateScript.money(int(player.get("salary",0))),confidence],false)
	row.alignment=HORIZONTAL_ALIGNMENT_LEFT; row.custom_minimum_size.y=76; row.icon=assets.texture(str(player.get("avatar_asset_id","player.avatar.fallback"))); row.expand_icon=true; row.add_theme_constant_override("icon_max_width",52); row.add_theme_color_override("font_color",TEXT); var normal:=_style(Color(PANEL,0.42),2,Color.TRANSPARENT,0); normal.border_width_left=3; normal.border_color=tone; row.add_theme_stylebox_override("normal",normal); row.tooltip_text="Open player dossier"; row.pressed.connect(func(): selected_profile_player=player; _show_page("player_detail")); return row

func _performance_player_row(player: Dictionary, team_average: int) -> HBoxContainer:
	var row:=HBoxContainer.new(); row.custom_minimum_size.y=78; row.add_theme_constant_override("separation",14)
	row.add_child(_player_avatar(str(player.get("avatar_asset_id","")),Vector2(54,64)))
	var identity:=VBoxContainer.new(); identity.custom_minimum_size.x=220; row.add_child(identity); identity.add_child(_label("@%s"%str(player.get("handle",player.get("name","player"))),15,TEXT)); identity.add_child(_label("%s  •  %s"%[str(player.get("name","Player")),str(player.get("role","Flex")).to_upper()],11,_role_color(str(player.get("role","Flex")))))
	var rating:=VBoxContainer.new(); rating.custom_minimum_size.x=105; row.add_child(rating); rating.add_child(_label(str(player.get("overall",0)),30,CYAN)); rating.add_child(_label("OVR  %s"%UIDataPresenterScript.metric_delta(int(player.get("overall",0)),team_average),10,SUCCESS if int(player.get("overall",0))>=team_average else DANGER))
	var form:=VBoxContainer.new(); form.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(form); form.add_child(_label("FORM  %d"%int(player.get("form",0)),11,GOLD)); form.add_child(_progress(int(player.get("form",0)),GOLD,6))
	var energy:=VBoxContainer.new(); energy.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(energy); energy.add_child(_label("ENERGY  %d%%"%int(player.get("energy",0)),11,_metric_color(int(player.get("energy",0))))); energy.add_child(_progress(int(player.get("energy",0)),_metric_color(int(player.get("energy",0))),6))
	var open:=_button("DOSSIER  →",false); open.custom_minimum_size.x=120; open.pressed.connect(func(): selected_profile_player=player; _show_page("player_detail")); row.add_child(open); return row

func _national_program_row(team: Dictionary, eligible_count: int) -> Button:
	var available:=eligible_count>=4; var row:=_button("%s\n%d ELIGIBLE PLAYERS  •  %s"%[str(team.get("name","National Team")),eligible_count,"AVAILABLE" if available else "ROSTER INCOMPLETE"],false); row.alignment=HORIZONTAL_ALIGNMENT_LEFT; row.custom_minimum_size.y=72; row.icon=assets.texture(str(team.get("logo_asset_id",""))); row.expand_icon=true; row.add_theme_constant_override("icon_max_width",58); row.disabled=not available; row.add_theme_color_override("font_color",TEXT if available else MUTED); row.tooltip_text="Accept national team role" if available else "Fewer than four eligible canonical players"; row.pressed.connect(func(): var result:=game.select_national_team(str(team.id)); if bool(result.get("ok",false)): _build_sidebar(); _show_page("national_team") else: _notify(str(result.get("error","Selection failed")))); return row

func _contract_command_row(player: Dictionary) -> HBoxContainer:
	var months := int(player.get("contract", 0))
	var status := "URGENT" if months <= 6 else "WARNING" if months <= 12 else "SAFE"
	var tone := DANGER if status == "URGENT" else GOLD if status == "WARNING" else SUCCESS
	var row := HBoxContainer.new(); row.custom_minimum_size.y = 62; row.add_theme_constant_override("separation", 8)
	var identity := HBoxContainer.new(); identity.custom_minimum_size.x = 250; identity.add_theme_constant_override("separation", 7); row.add_child(identity)
	identity.add_child(_player_avatar(str(player.get("avatar_asset_id", "")), Vector2(38, 44)))
	var copy := VBoxContainer.new(); copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL; identity.add_child(copy); copy.add_child(_label("@%s" % str(player.get("handle", player.get("name", "PLAYER"))), 12, TEXT)); copy.add_child(_label(str(player.get("name", "Player")), 10, MUTED))
	var role := _label(str(player.get("role", "FLEX")).to_upper(), 11, _role_color(str(player.get("role", "FLEX")))); role.custom_minimum_size.x = 100; role.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; row.add_child(role)
	var salary := _label("$%s" % GameStateScript.money(int(player.get("salary", 0))), 12, GOLD); salary.custom_minimum_size.x = 130; salary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; row.add_child(salary)
	var term := _label("%d MONTHS" % months, 11, tone); term.custom_minimum_size.x = 110; term.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; row.add_child(term)
	var badge := _tag(status if not bool(player.get("transfer_listed", false)) else "TRANSFER LISTED", tone if not bool(player.get("transfer_listed", false)) else DANGER); badge.custom_minimum_size.x = 150; row.add_child(badge)
	var review := _button("REVIEW  →", status == "URGENT"); review.custom_minimum_size.x = 130; review.pressed.connect(func(): selected_profile_player = player; _show_page("player_detail")); row.add_child(review)
	return row

func _action_group(title: String) -> VBoxContainer:
	var group := VBoxContainer.new(); group.add_theme_constant_override("separation", 6)
	group.add_child(_label(title, 10, MUTED))
	return group

func _command_button(title: String, description: String, icon_id: String, primary := false, variant := "secondary") -> Button:
	var button := _button(title + "\n" + description, primary)
	button.custom_minimum_size.y = 52
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 11)
	var icon := _small_icon(icon_id, 17)
	if icon != null: button.icon = icon
	if variant == "danger":
		button.add_theme_stylebox_override("normal", _style(Color(DANGER, 0.10), RADIUS_SM, Color(DANGER, 0.70), 1))
		button.add_theme_stylebox_override("hover", _style(Color(DANGER, 0.20), RADIUS_SM, DANGER, 1))
		button.add_theme_color_override("font_color", DANGER)
	return button

func _role_icon_kind(role: String) -> String:
	match role.to_upper():
		"FRAGGER": return "symbol.tactics"
		"ANCHOR": return "symbol.trophy"
		"SCOUT": return "symbol.location"
		"SUPPORT": return "icons.navigation.roster"
		"IGL": return "symbol.tactics"
		_: return "symbol.exchange"

func _role_badge(role: String, color: Color) -> VBoxContainer:
	var badge := VBoxContainer.new(); badge.custom_minimum_size.y = 34; badge.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon := _dashboard_icon(_role_icon_kind(role), Vector2(16, 16), color); icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; badge.add_child(icon)
	var caption := _label(role.to_upper(), 10, color); caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; badge.add_child(caption)
	return badge

func _squad_player_card(player: Dictionary, index: int, starter: bool) -> Button:
	var selected := index == selected_player
	var energy := int(player.get("energy", 0)); var listed := bool(player.get("transfer_listed", false)); var loaned := bool(player.get("loaned", false)); var low := energy < 60
	var card := _button("", false); card.custom_minimum_size = Vector2(220, 230 if starter else 128); card.size_flags_horizontal = Control.SIZE_EXPAND_FILL; card.tooltip_text = "Select @%s" % str(player.get("handle", player.get("name", "player")))
	var edge := ACCENT if selected else DANGER if listed else GOLD if low else LINE
	card.add_theme_stylebox_override("normal", _style(Color("18212a") if selected else Color("0d1720"), 3, edge, 2 if selected else 1))
	card.add_theme_stylebox_override("hover", _style(Color("1a2c35"), 3, ACCENT, 1))
	var body := VBoxContainer.new(); body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); body.mouse_filter = Control.MOUSE_FILTER_IGNORE; body.add_theme_constant_override("separation", 4); card.add_child(body)
	if starter:
		var portrait := _player_avatar(str(player.get("avatar_asset_id", "")), Vector2(92, 82)); portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; body.add_child(portrait)
	else:
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); body.add_child(row); row.add_child(_player_avatar(str(player.get("avatar_asset_id", "")), Vector2(48, 54))); var compact_copy := VBoxContainer.new(); compact_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(compact_copy); compact_copy.add_child(_label("@%s" % str(player.get("handle", player.get("name", "player"))), 15, TEXT)); compact_copy.add_child(_role_badge(str(player.get("role", "FLEX")), _role_color(str(player.get("role", "FLEX")))))
	var handle := _label("@%s" % str(player.get("handle", player.get("name", "player"))), 16 if starter else 12, TEXT); handle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if starter else HORIZONTAL_ALIGNMENT_LEFT; body.add_child(handle)
	if starter:
		var full_name := _label(str(player.get("name", "Player")), 10, MUTED); full_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; body.add_child(full_name)
	if starter: body.add_child(_role_badge(str(player.get("role", "FLEX")), _role_color(str(player.get("role", "FLEX")))))
	var score := _label("OVR  %d" % int(player.get("overall", 0)), 19 if starter else 13, ACCENT); score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if starter else HORIZONTAL_ALIGNMENT_LEFT; body.add_child(score)
	body.add_child(_label("FORM  %d     ENERGY  %d%%" % [int(player.get("form", 0)), energy], 10, MUTED)); body.add_child(_progress_static(energy, _metric_color(energy), 5))
	var state_text := "TRANSFER LISTED" if listed else "ON LOAN" if loaned else "LOW ENERGY" if low else "READY"
	var state_color := DANGER if listed else CYAN if loaned else GOLD if low else SUCCESS
	var state := _label("●  " + state_text, 10, state_color); state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if starter else HORIZONTAL_ALIGNMENT_LEFT; body.add_child(state)
	if selected and starter:
		var selected_tag := _label("SELECTED", 9, ACCENT); selected_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; body.add_child(selected_tag)
	card.pressed.connect(func(): selected_player = index; selected_profile_player.clear(); _show_page("roster"))
	return card

func _squad_metric_row(label_text: String, value: String, color: Color) -> VBoxContainer:
	var row := VBoxContainer.new(); row.custom_minimum_size.y = 26; row.add_theme_constant_override("separation", 1)
	row.add_child(_label("%s   %s" % [label_text, value], 11, color)); return row

func _player_stat_row(label_text: String, value: int, color: Color) -> VBoxContainer:
	var row := VBoxContainer.new(); row.add_theme_constant_override("separation", 2); row.add_child(_label("%s   %d" % [label_text, value], 10, color)); row.add_child(_progress_static(value, color, 4)); return row

func _mini_metric(title: String, value: int, color: Color) -> VBoxContainer:
	var box := VBoxContainer.new(); var line := HBoxContainer.new(); line.add_child(_label(title, 10, MUTED)); var fill := Control.new(); fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL; line.add_child(fill); line.add_child(_label("%d%%" % value, 11, color)); box.add_child(line); box.add_child(_progress(value, color, 5)); return box

func _attribute(title: String, value: int, color: Color) -> VBoxContainer:
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 3); var line := HBoxContainer.new(); line.custom_minimum_size.y = 18; var caption := _label(title, 11, MUTED); caption.custom_minimum_size.x = 120; line.add_child(caption); var fill := Control.new(); fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL; line.add_child(fill); var score := _label(str(value), 12, color); score.custom_minimum_size.x = 30; line.add_child(score); box.add_child(line); box.add_child(_progress(value, color, 5)); return box

func _action_row(code: String, title: String, note: String, color: Color) -> VBoxContainer:
	var row := VBoxContainer.new(); row.add_theme_constant_override("separation", 3)
	var line := HBoxContainer.new(); line.add_theme_constant_override("separation", 10); row.add_child(line)
	var badge := _tag(code, color); badge.custom_minimum_size.x = 54; line.add_child(badge)
	var copy := VBoxContainer.new(); copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL; line.add_child(copy)
	copy.add_child(_label(title, 14, TEXT)); copy.add_child(_label(note, 11, MUTED))
	return row

func _decision_signal(caption: String, value: String, color: Color) -> VBoxContainer:
	var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_theme_constant_override("separation", 2)
	box.add_child(_label(caption, 10, MUTED))
	var value_label := _label(value, 13, color); value_label.tooltip_text = "%s: %s" % [caption, value]; box.add_child(value_label)
	return box

func _empty_state(title:String, description:String) -> VBoxContainer:
	var box := VBoxContainer.new(); box.custom_minimum_size.y = 160; box.alignment = BoxContainer.ALIGNMENT_CENTER; box.add_theme_constant_override("separation", SPACE_SM)
	var title_label := _label(title, 16, TEXT); title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(title_label)
	var description_label := _label(description, 12, MUTED); description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(description_label)
	return box

func _progress(value: float, color: Color, height: int) -> ProgressBar:
	var bg_style := _style(Color("071018"), height / 2, Color.TRANSPARENT, 0); bg_style.content_margin_left = 0; bg_style.content_margin_right = 0; bg_style.content_margin_top = 0; bg_style.content_margin_bottom = 0
	var fill_style := _style(color, height / 2, Color.TRANSPARENT, 0); fill_style.content_margin_left = 0; fill_style.content_margin_right = 0; fill_style.content_margin_top = 0; fill_style.content_margin_bottom = 0
	var p := ProgressBar.new(); p.max_value = 100; p.value = 0; p.custom_minimum_size = Vector2(150, height); p.size_flags_horizontal = Control.SIZE_EXPAND_FILL; p.show_percentage = false; p.add_theme_stylebox_override("background", bg_style); p.add_theme_stylebox_override("fill", fill_style); p.set_meta("target_value", clampf(value, 0, 100)); p.ready.connect(_animate_progress.bind(p)); return p

func _progress_static(value:float,color:Color,height:int)->ProgressBar:
	var p:=_progress(value,color,height); p.value=clampf(value,0,100); p.set_meta("target_value",p.value); p.set_meta("animate",false); return p

func _tag(text_value: String, color: Color) -> Label:
	var l := _label(text_value, 10, color); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; l.custom_minimum_size = Vector2(maxi(72, text_value.length() * 7 + 18), 25); var s := _style(Color(color, 0.1), 5, Color(color, 0.45), 1); s.content_margin_left = 8; s.content_margin_right = 8; l.add_theme_stylebox_override("normal", s); return l

func _top_metric(caption: String, value: String, color: Color) -> VBoxContainer:
	var box := VBoxContainer.new(); box.custom_minimum_size.x = 92 if ResponsiveScript.is_compact(get_viewport_rect().size) else 142; box.size_flags_vertical = Control.SIZE_SHRINK_CENTER; box.add_theme_constant_override("separation", 0); box.add_child(_label(caption, 8, MUTED)); box.add_child(_label(value, 14, color)); return box

func _button(text_value: String, primary: bool) -> Button:
	var b := UIComponentsScript.button(text_value, "primary" if primary else "secondary")
	b.expand_icon = true; b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND; b.add_theme_font_size_override("font_size", 12)
	b.tooltip_text = text_value if b.tooltip_text.is_empty() else b.tooltip_text
	return b

func _button_variant(text_value:String, variant:String = "secondary") -> Button:
	var b := _button(text_value, variant == "primary")
	var tone := DANGER if variant == "danger" else GOLD if variant == "warning" else ACCENT
	if variant in ["danger", "warning"]:
		b.add_theme_stylebox_override("normal", _style(Color(tone, 0.12), RADIUS_SM, Color(tone, 0.65), 1))
		b.add_theme_stylebox_override("hover", _style(Color(tone, 0.22), RADIUS_SM, tone, 1))
		b.add_theme_color_override("font_color", tone)
		b.add_theme_color_override("font_hover_color", TEXT)
	elif variant == "tertiary":
		b.add_theme_stylebox_override("normal", _style(Color.TRANSPARENT, RADIUS_SM, Color.TRANSPARENT, 0))
		b.add_theme_color_override("font_color", MUTED)
	return b

func _critical_alert_count() -> int:
	if game.data.is_empty(): return 0
	var count := 0
	if _average("energy") < 55: count += 1
	if int(game.data.get("budget", 0)) < 100000: count += 1
	for player in game.data.get("roster", []):
		if int(player.get("contract", 99)) <= 3: count += 1; break
	return count

func _critical_alert_tooltip() -> String:
	var alerts:Array[String] = []
	if game.data.is_empty(): return "Finish the current week"
	if _average("energy") < 55: alerts.append("Squad energy is low")
	if int(game.data.get("budget", 0)) < 100000: alerts.append("The operating budget is at risk")
	for player in game.data.get("roster", []):
		if int(player.get("contract", 99)) <= 3: alerts.append("A player contract is close to expiry"); break
	return "Finish the current week" if alerts.is_empty() else "Resolve before advancing:\n• " + "\n• ".join(alerts)

func _label(value: String, size_value: int, color: Color) -> Label:
	return UIComponentsScript.label(value, size_value, color)

func _small_icon(asset_id: String, size_px := 18) -> Texture2D:
	var source := assets.texture(asset_id)
	if source == null: return null
	var image := source.get_image()
	if image == null or image.is_empty(): return source
	image.resize(size_px, size_px, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)

func _asset_preview(id: String, minimum: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = assets.texture(id)
	if t.texture == null:
		t.texture = assets.texture("ui.loading.tournament_fallback")
		t.tooltip_text = "Fallback: asset '%s' is not available" % id
	t.custom_minimum_size = minimum
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	return t

func _atlas_preview(id: String, region: Rect2, minimum: Vector2) -> TextureRect:
	var source := assets.texture(id)
	if source == null: return _asset_preview("ui.loading.tournament_fallback", minimum)
	var atlas := AtlasTexture.new(); atlas.atlas = source; atlas.region = region
	var preview := TextureRect.new(); preview.texture = atlas; preview.custom_minimum_size = minimum; preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return preview

func _team_logo(asset_id: String, fallback_text: String, minimum: Vector2) -> Control:
	var image := TextureRect.new()
	image.texture = assets.texture(asset_id)
	if image.texture == null:
		image.texture = assets.texture("team.mekong_reapers.logo")
	image.custom_minimum_size = minimum
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.tooltip_text = fallback_text
	return image

func _player_avatar(asset_id: String, minimum: Vector2) -> TextureRect:
	var image := TextureRect.new()
	image.texture = assets.texture(asset_id)
	if image.texture == null:
		image.texture = assets.texture("player.avatar.fallback")
	image.custom_minimum_size = minimum
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return image

func _brand() -> VBoxContainer:
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new(); icon.texture = assets.texture("branding.app_icon"); icon.custom_minimum_size = Vector2(56, 56); icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; box.add_child(icon)
	var title := _label("BATTLE ROYALE MANAGER", 13, TEXT); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(title)
	return box

func _style(color: Color, radius: int, border: Color, width: int) -> StyleBoxFlat:
	return DesignTokensScript.style(color, radius, border, width, 14)

func _training_schedule_display(value: String) -> String:
	return str({"Cân bằng":"BALANCED", "Cường độ cao":"HIGH INTENSITY", "Nghỉ & hồi phục":"RECOVERY"}.get(value, value.to_upper()))

func _training_tradeoff(activity: String, intensity: String) -> String:
	if activity == "Rest": return "Energy recovery; no skill growth"
	if activity == "Recovery": return "Energy and form recovery; minimal growth"
	if activity == "Scrim": return "Match readiness and fatigue"
	if intensity == "Intensive": return "High growth; high energy cost"
	if intensity == "Light": return "Low growth; low energy cost"
	return "Moderate growth and workload"

func _training_recommendation(player: Dictionary) -> String:
	var values := {"Aim":int(player.get("aim",50)),"Strategy":int(player.get("game_sense",50)),"Mental":int(player.get("clutch",50)),"Teamwork":int(player.get("teamwork",50)),"Recovery":mini(int(player.get("energy",50)),int(player.get("form",50)))}
	var result := "Aim"
	for focus in values:
		if int(values[focus]) < int(values[result]): result = str(focus)
	return result

func _compact_player_name(value: String) -> String:
	if value.length() <= 22: return value
	var words := value.split(" ", false)
	if words.size() < 2: return value
	var split_at := ceili(float(words.size()) / 2.0)
	return " ".join(words.slice(0, split_at)) + "\n" + " ".join(words.slice(split_at))

func _metric_color(value: int) -> Color: return SUCCESS if value >= 70 else GOLD if value >= 45 else DANGER

func _player_world_rank() -> int:
	var rank := game.career_world_rank()
	return rank if rank > 0 else 1

func _bench_selected_player() -> void:
	if selected_player < 0 or selected_player >= 4 or game.data.roster.size() <= 4: return
	var starter: Dictionary = game.data.roster[selected_player]
	var result := game.move_roster_player(str(starter.get("id", "")), false)
	if bool(result.get("ok",false)): selected_player = 4
	_notify("%s moved to substitutes." % str(starter.get("name", "Player")) if bool(result.get("ok",false)) else str(result.get("error","Lineup change failed.")))
	_show_page("roster")

func _promote_selected_player() -> void:
	if selected_player < 4 or selected_player >= game.data.roster.size(): return
	var reserve: Dictionary = game.data.roster[selected_player]
	var result := game.move_roster_player(str(reserve.get("id", "")), true)
	if bool(result.get("ok",false)): selected_player = 3
	_notify("%s promoted to main roster." % str(reserve.get("name", "Player")) if bool(result.get("ok",false)) else str(result.get("error","Lineup change failed.")))
	_show_page("roster")

func _refresh_tactical_preview() -> void:
	if not is_instance_valid(tactical_preview) or game.data.is_empty(): return
	var plan: Dictionary = game.data.get("coach_plan", {})
	var drop := str(plan.get("drop_policy", "ADAPTIVE"))
	var zone := str(plan.get("zone_macro", "CENTER"))
	var fight := str(plan.get("engagement", "SELECTIVE"))
	var drop_text := "DROP POLICY  •  %s" % drop.replace("_"," ")
	var zone_text := "ZONE MACRO  •  %s" % zone.replace("_"," ")
	var fight_text := "ENGAGEMENT  •  %s" % fight.replace("_"," ")
	tactical_preview.text = "%s\n%s\n%s" % [drop_text, zone_text, fight_text]
func _trend_text(value: int) -> String: return "↑ strong form" if value >= 75 else "→ stable" if value >= 55 else "↓ needs attention"
func _map_asset(map_name: String) -> String:
	return str({"Sunscorch Basin":"match.map.sunscorch_basin","sunscorch_basin":"match.map.sunscorch_basin","Verdant Reach":"match.map.verdant_reach","verdant_reach":"match.map.verdant_reach","Tactical Island":"match.map.astra","tactical_island":"match.map.astra","Frostline Valley":"match.map.frostline_valley","frostline_valley":"match.map.frostline_valley","Coastal Breakwater":"match.map.coastal_breakwater","coastal_breakwater":"match.map.coastal_breakwater","Highland Reserve":"match.map.highland_reserve","highland_reserve":"match.map.highland_reserve"}.get(map_name,"match.map.verdant_reach"))
func _favorite_weapon(p: Dictionary) -> String: return game.player_weapon_preference(str(p.get("id", "")))
func _featured_opponent() -> Dictionary: return game.featured_match_opponent()
func _opponent_rank(opponent: Dictionary) -> int: return clampi(30 - int(opponent.power) / 4, 1, 40)
func _build_tasks() -> Array:
	var tasks: Array = []
	var lowest: Dictionary = game.data.roster[0]
	var lowest_index := 0
	for i in game.data.roster.size():
		if int(game.data.roster[i].energy) < int(lowest.energy): lowest = game.data.roster[i]; lowest_index = i
	tasks.append({"level":"URGENT", "title":"%s has %d%% energy" % [lowest.name, lowest.energy], "note":"Recovery / training • expires this week", "color":DANGER, "page":"roster", "player":lowest_index})
	var contract_player: Dictionary = game.data.roster[0]
	var contract_index := 0
	for i in game.data.roster.size():
		if int(game.data.roster[i].contract) < int(contract_player.contract): contract_player = game.data.roster[i]; contract_index = i
	tasks.append({"level":"CONTRACT", "title":"%s has %d months remaining" % [contract_player.name, contract_player.contract], "note":"Player profile • expires in %d months" % contract_player.contract, "color":GOLD, "page":"player_detail", "player":contract_index})
	if not game.data.market.is_empty(): tasks.append({"level":"SCOUT", "title":"Promising %s identified" % game.data.market[0].role, "note":"Confidence %d%% • Potential %d" % [game.data.market[0].confidence, game.data.market[0].potential], "color":SUCCESS, "page":"transfer"})
	tasks.append({"level":"MATCH", "title":"Matchday is approaching", "note":"Tactical plan • prepare before matchday", "color":CYAN, "page":"match"})
	return tasks
func _task_row(task: Dictionary) -> Button:
	var row := _button("%s  %s\n%s" % [str(task.level), str(task.title), str(task.note)], false)
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT; row.custom_minimum_size.y = 66
	row.add_theme_color_override("font_color", task.color)
	row.tooltip_text = "Open related decision"
	row.pressed.connect(func():
		if task.has("player"): selected_player = int(task.player)
		_show_page(str(task.get("page", "dashboard"))))
	return row

func _pulse_row(label: String, title: String, note: String, color: Color, page: String) -> Button:
	var row := _button("       %s  %s\n       %s" % [label, title, note], false)
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT; row.custom_minimum_size.y = 62
	row.add_theme_color_override("font_color", color)
	row.tooltip_text = "Open %s" % title
	row.pressed.connect(_show_page.bind(page))
	var icon_kind := "symbol.exchange" if label == "TRANSFER" else "symbol.trophy" if label == "TOURNAMENT" else "symbol.graph"
	var symbol := _dashboard_icon(icon_kind, Vector2(26, 26), color); symbol.position = Vector2(12, 16); symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_child(symbol)
	return row

func _ranking_rows() -> Array:
	return game.competitive_rankings("CLUB").map(func(profile): return {"rank":profile.rank,"id":profile.id,"name":profile.name,"power":profile.ranking_points,"form":profile.form,"trend":profile.momentum,"tier":profile.tier,"region":profile.region,"logo_asset_id":profile.logo_asset_id,"is_player":str(profile.id)==str(game.data.get("organization_id",""))})
func _ranking_row(row: Dictionary) -> HBoxContainer:
	var line := HBoxContainer.new(); line.custom_minimum_size.y = 42; line.add_theme_constant_override("separation", 8)
	var compact := ResponsiveScript.is_compact(get_viewport_rect().size)
	var rank := _label("%02d" % row.rank, 14, GOLD if row.is_player else MUTED); rank.custom_minimum_size.x = 42; line.add_child(rank)
	var name := _button(str(row.name), false); name.alignment = HORIZONTAL_ALIGNMENT_LEFT; name.custom_minimum_size = Vector2(280 if compact else 430, 38); name.flat = true; name.tooltip_text = "Open Team Profile"; name.pressed.connect(func(): selected_world_team_id = str(row.get("id", "")); _show_page("team_profile")); line.add_child(name)
	var region := _label(str(row.region), 12, CYAN); region.custom_minimum_size.x = 110 if compact else 180; line.add_child(region)
	var power := _label(str(row.power), 14, GOLD); power.custom_minimum_size.x = 90 if compact else 120; line.add_child(power)
	var form_value := int(row.get("form", 0)); var form := _label(str(form_value), 14, SUCCESS if form_value >= 72 else GOLD); form.custom_minimum_size.x = 90 if compact else 120; line.add_child(form)
	var trend_value := int(row.get("trend", 0)); var trend := _label("STABLE" if trend_value == 0 else "+%d" % trend_value if trend_value > 0 else str(trend_value), 12, SUCCESS if trend_value > 0 else DANGER if trend_value < 0 else MUTED); trend.custom_minimum_size.x = 100 if compact else 140; line.add_child(trend)
	var tier:=_tag(str(row.get("tier","D")),ACCENT); tier.custom_minimum_size.x=70; line.add_child(tier)
	return line

func _ranking_podium_card(row: Dictionary) -> Button:
	var tone:=GOLD if int(row.rank)==1 else CYAN if int(row.rank)==2 else ORANGE
	var card:=_button("",false); card.custom_minimum_size=Vector2(300,150); card.size_flags_horizontal=Control.SIZE_EXPAND_FILL; card.add_theme_stylebox_override("normal",_style(Color(tone,0.07),3,Color.TRANSPARENT,0)); card.add_theme_stylebox_override("hover",_style(Color(tone,0.14),3,tone,1)); card.pressed.connect(func(): selected_world_team_id=str(row.get("id","")); _show_page("team_profile"))
	var body:=HBoxContainer.new(); body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); body.mouse_filter=Control.MOUSE_FILTER_IGNORE; body.add_theme_constant_override("separation",14); card.add_child(body)
	body.add_child(_team_logo(str(row.get("logo_asset_id","")),str(row.name).left(2).to_upper(),Vector2(78,78)))
	var copy:=VBoxContainer.new(); copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL; body.add_child(copy); copy.add_child(_label("#%02d" % int(row.rank),28,tone)); copy.add_child(_label(str(row.name),18,TEXT)); copy.add_child(_label("RP %s  •  FORM %s  •  TIER %s" % [str(row.power),str(row.form),str(row.get("tier","D"))],11,MUTED))
	return card
func _best_placement() -> int:
	var best := game.career_best_placement()
	return best if best > 0 else 20
func _average(key: String) -> int:
	return GamePresenterScript.average(game.data.get("roster", []).slice(0, mini(4, game.data.get("roster", []).size())), key)

func _update_nav() -> void:
	for key in nav_buttons:
		var b: Button = nav_buttons[key]; var selected: bool = str(key) == active_page
		var normal:=_style(Color("21170e") if selected else Color.TRANSPARENT, 1, Color.TRANSPARENT, 0); normal.border_width_left=3 if selected else 0; normal.border_color=ACCENT
		var hover:=_style(Color("101b23"),1,Color.TRANSPARENT,0); hover.border_width_left=2; hover.border_color=Color(ACCENT,0.7)
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_color_override("font_color", ACCENT if selected else TEXT)

func _animate_page() -> void:
	content.modulate.a = 0.0; content.position.x = 12.0; var tween := create_tween().set_parallel(true); tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT); tween.tween_property(content, "modulate:a", 1.0, 0.2); tween.tween_property(content, "position:x", 0.0, 0.24)

func _animate_progress(bar: ProgressBar) -> void:
	if not is_instance_valid(bar): return
	if not bool(bar.get_meta("animate",true)): bar.value=float(bar.get_meta("target_value",0)); return
	create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT).tween_property(bar, "value", float(bar.get_meta("target_value", 0)), 0.55)

func _style_label(l: Label, font_size: int, color: Color) -> void: l.add_theme_font_size_override("font_size", font_size); l.add_theme_color_override("font_color", color)
func _clear(node: Node) -> void:
	for child in node.get_children():
		_queue_option_popups(child)
		if child is CanvasItem: child.visible = false
		child.queue_free()

func _queue_option_popups(node: Node) -> void:
	if node is OptionButton:
		var popup: PopupMenu = node.get_popup()
		if is_instance_valid(popup): popup.queue_free()
	for child in node.get_children(): _queue_option_popups(child)

func _advance_day() -> void:
	if week_transition_active: return
	week_transition_active = true
	var overlay := ColorRect.new(); overlay.color = Color("061019f2"); overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.z_index = 100; add_child(overlay)
	var center := VBoxContainer.new(); center.set_anchors_preset(Control.PRESET_CENTER); center.position = Vector2(-260, -130); center.size = Vector2(520, 260); center.alignment = BoxContainer.ALIGNMENT_CENTER; center.add_theme_constant_override("separation", 14); overlay.add_child(center)
	var previous_date := str(game.data.current_date); var week_label := _label("%s → NEXT DAY" % previous_date, 30, TEXT); week_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; center.add_child(week_label)
	var stage := _label("PROCESSING CALENDAR", 16, ACCENT); stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; center.add_child(stage)
	var bar := _progress(100, ACCENT, 8); center.add_child(bar)
	var result := game.advance_day()
	stage.text = "ACTION REQUIRED • %s" % str(result.get("date",game.data.current_date)) if bool(result.get("stopped",false)) else "DAY READY • %s" % str(game.data.current_date); stage.add_theme_color_override("font_color", GOLD if bool(result.get("stopped",false)) else ACCENT)
	await get_tree().create_timer(0.4).timeout
	var fade := create_tween(); fade.tween_property(overlay, "modulate:a", 0.0, 0.22); await fade.finished
	overlay.queue_free(); week_transition_active = false
	_build_sidebar()
	if bool(result.get("stopped",false)) and not result.get("events",[]).is_empty():
		var event: Dictionary = result.events[0]; var event_type := str(event.get("type","")); var destination := "match" if event_type == "match" else "training" if event_type == "training" else "facility_detail" if event_type == "facility" else "inbox"; if event_type == "facility": selected_facility = str(event.get("facility",selected_facility)); _show_page(destination); _notify("Action required: %s" % str(event.get("tournament",event.get("type","Event"))))
	else:
		_show_page(active_page)
		var consequences: Array=result.get("consequences",[]); _notify("%s • %s" % [str(consequences[0].get("title","Advanced to %s" % str(game.data.current_date))),str(consequences[0].get("detail",""))] if not consequences.is_empty() else "Advanced to %s." % str(game.data.current_date))
func _notify(message: String) -> void:
	toast.text = message; toast.visible = true; toast.modulate.a = 0.0; create_tween().tween_property(toast, "modulate:a", 1.0, 0.15); get_tree().create_timer(2.5).timeout.connect(func(): if is_instance_valid(toast): toast.visible = false)
