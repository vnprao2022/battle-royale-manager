extends SceneTree

const GameStateScript=preload("res://scripts/game_state.gd")
const MapCatalogScript=preload("res://scripts/map_catalog.gd")
const SAVE_PATH:="user://codex_redesign_systems_test.json"
var checks:=0
var failures:=0

func _init()->void:
	var game=GameStateScript.new(); game.save_path=SAVE_PATH
	game.new_career("Northstar Academy","Coach Linh","SEA",{"slot_id":3,"team_mode":"new","journey_mode":"story","roster_source":"custom","difficulty":"Director","logo_asset_id":"logo.pattern.shield","custom_players":[{"name":"Nguyen An","handle":"An","role":"IGL"}]})
	_check(str(game.data.get("manager_name",""))=="Coach Linh","Manager identity was not persisted")
	_check(str(game.data.get("journey_mode",""))=="story" and str(game.data.get("team_mode",""))=="new","Story career path was not created")
	_check(game.data.get("roster",[]).size()==6 and game.data.get("academy_pool",[]).size()>=10,"Tier D roster or generated academy pool is incomplete")
	_check(str(game.data.roster[0].get("handle",""))=="An" and int(game.data.roster[0].get("overall",99))<=59,"Custom player did not respect the Tier D cap")
	_check(ResourceLoader.exists("res://assets/branding/logo_patterns/shield.png"),"PNG logo pattern is missing")

	var map_catalog=MapCatalogScript.new()
	for map_id in ["verdant_reach","sunscorch_basin","tactical_island","frostline_valley","coastal_breakwater","highland_reserve"]:
		var map_data:Dictionary=map_catalog.load_map(map_id); _check(str(map_data.get("id",""))==map_id and map_catalog.validate(map_data),"Map is unavailable or invalid: %s"%map_id)

	game.data.budget=5000000
	var assignment:=game.start_scout_assignment({"role":"ALL","age_band":"ANY","priority":"POTENTIAL","max_value":0})
	_check(bool(assignment.get("ok",false)) and str(game.active_scout_assignment().get("status",""))=="ACTIVE","Scout assignment did not start")
	game._process_scout_assignments(str(assignment.get("assignment",{}).get("due_date","9999-01-01")))
	var report:Dictionary=game.latest_scout_report(); _check(int(report.get("count",0))>=3 and int(report.get("count",0))<=7,"Scout report did not return the facility-scaled 3-7 players")

	game.data.week=3; game.data.days_elapsed=14; game.data.current_date=game._add_days(GameStateScript.SEASON_START_DATE,14)
	var contracted:Array=game.data.market.filter(func(player): return not str(player.get("team_id","")).is_empty() and str(player.get("squad_role",""))!="free_agent")
	if not contracted.is_empty(): _check(not bool(game.create_transfer_offer(str(contracted[0].id)).get("ok",false)),"Contracted player was approachable outside the transfer window")
	else: _check(false,"No contracted transfer target was available for the window test")
	var free_agents:Array=game.data.market.filter(func(player): return str(player.get("team_id","")).is_empty() or str(player.get("squad_role",""))=="free_agent")
	_check(not free_agents.is_empty(),"No free agent was available for negotiation test")
	if not free_agents.is_empty():
		free_agents[0].confidence=100; var free_offer:=game.create_transfer_offer(str(free_agents[0].id),{"salary":int(free_agents[0].salary)+3000}); _check(bool(free_offer.get("ok",false)) and int(free_offer.get("offer",{}).get("fee",-1))==0,"Free-agent negotiation was not available year-round with zero transfer fee")

	_check(bool(game.apply_training_program("MECHANICAL").get("ok",false)),"Training program was not applied")
	_check(bool(game.set_training_day(1,"Mental","Light").get("ok",false)) and str(game.data.get("training_program",""))=="CUSTOM","Manual weekly training edit was not persisted")
	game.advance_week(true)
	_check(not game.data.get("recent_training_impact",{}).is_empty() and game.data.get("training_history",[]).size()>0,"Weekly training did not produce a traceable impact report")

	game.data.current_date="2026-12-31"; game._simulate_background_tournaments()
	_check(game.data.get("background_tournament_results",[]).size()>0,"Independent tournament simulation produced no results")
	var clubs:=game.competitive_rankings("CLUB"); var nations:=game.competitive_rankings("NATIONAL")
	_check(not clubs.is_empty() and clubs.all(func(row): return str(row.get("team_type",""))=="CLUB"),"Club ranking contains invalid entities")
	_check(not nations.is_empty() and nations.all(func(row): return str(row.get("team_type",""))=="NATIONAL"),"National ranking contains invalid entities")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if failures>0: push_error("REDESIGN_SYSTEMS_TEST_FAILED checks=%d failures=%d"%[checks,failures]); quit(1)
	else: print("REDESIGN_SYSTEMS_TEST_OK checks=%d"%checks); quit(0)

func _check(condition:bool,message:String)->void:
	checks+=1
	if not condition: failures+=1; push_error("CHECK FAILED: "+message)
