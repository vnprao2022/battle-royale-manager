class_name PerformanceCampusScreen
extends VBoxContainer

const UI = preload("res://scripts/ui/components/ui_components.gd")
const Tokens = preload("res://scripts/ui/theme/design_tokens.gd")
const Responsive = preload("res://scripts/ui/utilities/responsive.gd")

var route_params: Dictionary = {}
var app_context: Dictionary = {}

func setup(context: Dictionary, params := {}) -> void:
	app_context=context; route_params=params.duplicate(true); build()

func build() -> void:
	var game = app_context.game
	var assets = app_context.assets
	var money: Callable = app_context.money
	var notify: Callable = app_context.notify
	var reload: Callable = app_context.reload
	var definitions: Dictionary = game.data.get("facility_definitions", {})
	var active_projects: Dictionary = {}
	for project in game.data.get("facility_projects", []): active_projects[str(project.get("facility",""))] = project
	var summary := HBoxContainer.new(); summary.add_theme_constant_override("separation",Tokens.SPACE.md); add_child(summary)
	summary.add_child(_stat("FACILITIES",str(game.data.get("facilities",{}).size()),Tokens.color("information"),"Operational sites"))
	summary.add_child(_stat("ACTIVE PROJECTS",str(game.data.get("facility_projects",[]).filter(func(p): return str(p.get("status",""))=="UPGRADING").size()),Tokens.color("warning"),"Construction queue"))
	summary.add_child(_stat("AVAILABLE BALANCE","$%s" % money.call(int(game.data.get("budget",0))),Tokens.color("primary"),"Career funds"))
	var grid := GridContainer.new(); grid.columns=Responsive.columns(get_viewport_rect().size,4,3,2); grid.add_theme_constant_override("h_separation",Tokens.SPACE.md); grid.add_theme_constant_override("v_separation",Tokens.SPACE.md); add_child(grid)
	for facility_name in game.data.get("facilities", {}):
		var name := str(facility_name); var definition: Dictionary = definitions.get(name, {}); var level := int(game.data.facilities[name]); var levels: Array = definition.get("levels",[]); var max_level := int(definition.get("max_level",levels.size())); var cost := int(definition.get("base_upgrade_cost",0))*(level+1)
		var card := UI.panel(str(definition.get("display_name",name)),true); card.custom_minimum_size=Vector2(300,310); card.size_flags_horizontal=Control.SIZE_EXPAND_FILL; grid.add_child(card)
		var art := TextureRect.new(); art.texture=assets.texture(str(definition.get("asset_id",""))); art.custom_minimum_size=Vector2(260,112); art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED; card.add_child(art)
		card.add_child(UI.badge("LEVEL %d / %d" % [level,max_level],Tokens.color("information")))
		var description := UI.label(str(definition.get("description","No facility description available.")),Tokens.TYPE.secondary,Tokens.color("text_secondary")); description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; card.add_child(description)
		card.add_child(UI.label("CURRENT BENEFIT",Tokens.TYPE.metadata,Tokens.color("text_secondary")))
		card.add_child(UI.label(game.facility_benefit_summary(name,level),Tokens.TYPE.body,Tokens.color("positive")))
		if active_projects.has(name) and str(active_projects[name].get("status",""))=="UPGRADING":
			var project: Dictionary=active_projects[name]; card.add_child(UI.badge("UPGRADING • %s" % str(project.get("completion_date","DATE UNAVAILABLE")),Tokens.color("warning")))
		elif level < max_level:
			card.add_child(UI.label("NEXT  •  %s" % game.facility_benefit_summary(name,level+1),Tokens.TYPE.secondary,Tokens.color("warning")))
			var duration := maxi(2,3+level*2); var action := UI.button("UPGRADE  •  $%s  •  %d DAYS" % [money.call(cost),duration],"primary"); action.disabled=int(game.data.get("budget",0))<cost; action.tooltip_text="Starts a dated construction project and adds its completion to the schedule."; action.pressed.connect(func(): notify.call(game.upgrade_facility(name)); reload.call()); card.add_child(action)
		else: card.add_child(UI.badge("MAX LEVEL",Tokens.color("positive")))
	if definitions.is_empty(): add_child(UI.empty_state("FACILITY DATA UNAVAILABLE","No facility definitions were loaded for this career.",true))

func _stat(title: String, value: String, tone: Color, note: String) -> VBoxContainer:
	var card := UI.panel("",false); card.size_flags_horizontal=Control.SIZE_EXPAND_FILL; card.add_child(UI.label(value,Tokens.TYPE.stat,tone)); card.add_child(UI.label(title,Tokens.TYPE.metadata,Tokens.color("text"))); card.add_child(UI.label(note,Tokens.TYPE.metadata,Tokens.color("text_secondary"))); return card
