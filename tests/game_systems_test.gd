extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const GameDatabaseScript = preload("res://scripts/game_database.gd")
const PriorityScript = preload("res://scripts/ui/presenters/career_priority_presenter.gd")
const MatchRuntimeScript = preload("res://scripts/match_runtime.gd")
const SAVE_PATH := "user://codex_game_systems_test.json"
const DESTRUCTIVE_PATH := "user://codex_game_systems_destructive.json"
const MIGRATION_PATH := "user://codex_game_systems_migration.json"

var checks := 0
var failures := 0
var captured_match_result: Dictionary = {}

func _init() -> void:
	_run_system_journey()
	_run_destructive_contract_branch()
	_run_migration_branch()
	for path in [SAVE_PATH, DESTRUCTIVE_PATH, MIGRATION_PATH]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures > 0:
		push_error("GAME_SYSTEMS_TEST_FAILED checks=%d failures=%d" % [checks,failures]); quit(1)
	else:
		print("GAME_SYSTEMS_TEST_OK checks=%d" % checks); quit(0)

func _run_system_journey() -> void:
	var game = GameStateScript.new(); game.save_path = SAVE_PATH; game.new_career("System Journey", "Manager", "SEA", {"difficulty":"Normal"})
	game.data.budget = 5000000; game.data.reputation = 100
	while game.data.roster.size() < 6:
		var signed := false
		for index in range(game.data.market.size()-1,-1,-1):
			if game.sign_player(index).begins_with("Signed"): signed=true; break
		if not signed: break
	_check(game.data.get("roster", []).size() >= 5, "Real database career did not provide roster depth")
	_check(game.save_game(), "New career did not save")

	# Squad ownership, promotion, role and recovery.
	var promoted_id := str(game.data.roster[4].get("id", "")); _check(bool(game.move_roster_player(promoted_id, true).get("ok", false)), "Promotion failed")
	_check(str(game.data.roster[3].get("id", "")) == promoted_id, "Promotion did not replace a starter")
	_check(str(game.data.roster[3].get("squad_role", "")) == "starter", "Starter role was not normalized")
	_check(bool(game.set_player_role(promoted_id, "IGL").get("ok", false)), "Role assignment failed")
	game.data.roster[3].energy = 40; var recovered := game.recover_player(promoted_id); _check(recovered.contains("recovered"), "Recovery failed"); _check(int(game.data.roster[3].energy) > 40, "Recovery did not change energy")

	# Training config and a real weekly consequence.
	_check(bool(game.set_team_training_schedule("Cường độ cao").get("ok", false)), "Training schedule failed")
	_check(bool(game.set_individual_training(promoted_id, "Aim").get("ok", false)), "Individual training failed")
	var energy_before := _average(game.data.roster, "energy"); var week_before := int(game.data.week); var weekly := game.advance_week(true)
	_check(int(game.data.week) == week_before + 1, "Weekly progression did not advance the week")
	_check(_average(game.data.roster, "energy") < energy_before, "Aggressive training did not create its energy cost")
	_check(not weekly.get("consequences", []).is_empty(), "Weekly progression did not expose consequences")

	# Contracts and salary update use the owned roster and affect persistence/finance.
	game.data.budget = 5000000
	var contract_player: Dictionary = game.data.roster[0]; var contract_before := int(contract_player.contract); var ledger_before: int = game.data.finance_ledger.size()
	_check(game.renew_contract(str(contract_player.id), 12).begins_with("Renewed"), "Contract renewal failed")
	_check(int(contract_player.contract) == contract_before + 12, "Contract duration did not change")
	_check(game.data.finance_ledger.size() >= ledger_before, "Renewal was not represented in finance")
	var salary_target := int(contract_player.salary) + 700; _check(bool(game.set_player_salary(str(contract_player.id), salary_target).get("ok", false)), "Salary update failed"); _check(int(contract_player.salary) == salary_target, "Salary state did not change")

	# Outbound recruitment: offer -> pending event -> accepted -> roster/finance.
	game.data.reputation = 100
	var market_player: Dictionary = game.data.market[0]; market_player.confidence = 100; var fee := int(market_player.value); var roster_before_signing: int = game.data.roster.size(); var budget_before_signing := int(game.data.budget)
	var outbound := game.create_transfer_offer(str(market_player.id), {"salary":int(market_player.salary)+2000,"months":24,"starter_guarantee":true})
	_check(bool(outbound.get("ok", false)), "Outbound offer was not created")
	var outbound_event: Dictionary = game.data.pending_events.filter(func(event): return str(event.get("type", "")) == "transfer_offer")[0]
	var accepted_choice := "accept" if str(outbound.offer.response) == "ACCEPT" else "counter"
	_check(bool(game.resolve_event(str(outbound_event.id), accepted_choice).get("ok", false)), "Outbound negotiation did not resolve")
	_check(game.data.roster.size() == roster_before_signing + 1, "Signed player did not join roster")
	_check(int(game.data.budget) == budget_before_signing - fee, "Transfer fee was not deducted")
	for index in game.data.roster.size(): _check(str(game.data.roster[index].get("squad_role", "")) == ("starter" if index < 4 else "substitute"), "Starter-guarantee signing left stale squad-role state")

	# Inbound offer: listed owned player -> deterministic buyer -> Inbox -> accepted sale.
	var sale_player: Dictionary = game.data.roster[0]; _check(bool(game.set_transfer_listed(str(sale_player.id), true).get("ok", false)), "Transfer listing failed")
	var generated := game.generate_inbound_offers(true); _check(not generated.is_empty(), "Forced deterministic inbound generation produced no offer")
	var inbound_event: Dictionary = game.data.pending_events.filter(func(event): return str(event.get("type", "")) == "inbound_transfer_offer")[0]
	_check(not bool(inbound_event.get("blocks_progression", true)), "Inbound offer incorrectly freezes daily progression before its deadline")
	var sale_amount := int(inbound_event.context.amount); var budget_before_sale := int(game.data.budget); var roster_before_sale: int = game.data.roster.size()
	_check(bool(game.resolve_event(str(inbound_event.id), "accept").get("ok", false)), "Inbound sale did not resolve")
	_check(game.data.roster.size() == roster_before_sale - 1, "Accepted inbound offer did not remove player")
	_check(int(game.data.budget) == budget_before_sale + sale_amount, "Inbound sale income was not recorded")
	for index in game.data.roster.size(): _check(str(game.data.roster[index].get("squad_role", "")) == ("starter" if index < 4 else "substitute"), "Selling a starter left stale lineup roles")

	# Loan lifecycle: destination/dates/salary coverage, unavailable roster, automatic return.
	var loan_player: Dictionary = game.data.roster[4]; var loan_player_id := str(loan_player.id); var roster_before_loan: int = game.data.roster.size()
	var loan := game.create_loan(loan_player_id, "", 4, 50); _check(bool(loan.get("ok", false)), "Loan creation failed")
	_check(game.data.roster.size() == roster_before_loan - 1 and game.data.loaned_players.size() == 1, "Loan did not move player out of active roster")
	for week in 4: game.advance_week(true)
	_check(game.data.loaned_players.is_empty(), "Loan player did not return automatically")
	_check(game.data.roster.any(func(player): return str(player.get("id", "")) == loan_player_id), "Returned player was not restored to roster")
	_check(str(game.data.loan_records[0].status) == "RETURNED", "Loan record did not reach RETURNED")

	# Facility project and real benefit.
	game.data.budget = 5000000; var medical_before := int(game.data.facilities["Medical Room"]); var upgrade_result := game.upgrade_facility("Medical Room"); _check(upgrade_result.contains("upgrade started"), "Facility project did not start")
	game.advance_week(true); _check(int(game.data.facilities["Medical Room"]) == medical_before + 1, "Facility did not complete after its due date")
	_check(game.facility_benefit_summary("Medical Room").contains("weekly energy"), "Facility has no truthful benefit summary")

	# Sponsor/finance recurring processing.
	game.data.active_sponsor_id = ""; game.data.reputation = 100; var sponsor_id := str(game.data.sponsors[0].id); _check(game.accept_sponsor(sponsor_id).begins_with("Signed"), "Sponsor signing failed")
	var sponsor_income := int(game.data.sponsors[0].weekly_income); game.advance_week(true)
	_check(game.data.finance_ledger.any(func(entry): return str(entry.get("label", "")) == "Sponsor activation" and int(entry.get("amount",0)) == sponsor_income), "Weekly sponsor income was not recorded")
	_check(game.data.finance_ledger.any(func(entry): return str(entry.get("label", "")) == "Player payroll" and int(entry.get("amount",0)) < 0), "Payroll was not recorded")

	# National appointment/call-up/release uses real database identities without club transfer.
	var database = GameDatabaseScript.new(); _check(database.load_all().is_empty(), "GameDatabase failed validation")
	var national_teams: Array = database.teams.filter(func(team): return str(team.get("team_type", "")) == "NATIONAL")
	_check(not national_teams.is_empty(), "No national team exists in the real database")
	_check(bool(game.select_national_team(str(national_teams[0].id)).get("ok", false)), "National appointment failed")
	var eligible := game.eligible_national_players(str(national_teams[0].id)); _check(not eligible.is_empty(), "No eligible national player exists")
	var national_player_id := str(eligible[0].id); _check(bool(game.call_up_player(national_player_id).get("ok", false)), "National call-up failed"); _check(bool(game.release_national_player(national_player_id).get("ok", false)), "National release failed")

	# Media story is persistent and single-answer.
	var story := game.current_media_story(); var media := game.record_media_response("POSITIVE", "Prepared statement", str(story.id)); _check(bool(media.get("ok", false)), "Media response failed")
	_check(not bool(game.record_media_response("POSITIVE", "Duplicate", str(story.id)).get("ok", false)), "Duplicate media response was accepted")
	_check(str(game.current_media_story().status) == "ANSWERED", "Media story did not persist ANSWERED state")
	game.advance_week(true); var weekly_story_id := str(game.current_media_story().id); _check(game.data.media_stories.any(func(item): return str(item.get("id", "")) == weekly_story_id), "Weekly boundary did not create the new media story")
	var media_count_before_reload: int = game.data.media_stories.size(); _check(game.save_game(), "Weekly media checkpoint did not save"); var media_loaded = GameStateScript.new(); media_loaded.save_path = SAVE_PATH; _check(media_loaded.load_game(), "Weekly media checkpoint did not load"); _check(media_loaded.data.media_stories.size() == media_count_before_reload, "Reload lazily created gameplay media state")

	# Tournament registration round trip uses the actual tournament catalog/calendar.
	_check(bool(game.set_management_context("CLUB").get("ok", false)), "Club management context could not be restored")
	var registered_id := ""
	for tournament_id in game.data.get("tournament_registrations", {}).keys():
		if not game.get_competition(str(tournament_id)).is_empty(): registered_id = str(tournament_id); break
	_check(not registered_id.is_empty(), "No real registered tournament was available")
	_check(bool(game.unregister_tournament(registered_id).get("ok", false)), "Tournament unregister failed")
	var registration_tournament: Dictionary=game.get_competition(registered_id); var registration_start:=str(registration_tournament.get("start_date","")); var registration_end:=str(registration_tournament.get("end_date",registration_start))
	for calendar_event in game.data.calendar_events:
		var event_date:=str(calendar_event.get("date","")); if event_date>=registration_start and event_date<=registration_end and str(calendar_event.get("tournament_id",""))!=registered_id: calendar_event.status="completed"; calendar_event.completed=true
	var registration_result := game.register_tournament(registered_id)
	_check(bool(registration_result.get("ok", false)), "Tournament register failed: %s" % JSON.stringify(registration_result))
	_check(game.data.calendar_events.any(func(event): return str(event.get("tournament_id", "")) == registered_id), "Tournament registration did not create schedule")
	var registered_events: Array = game.data.calendar_events.filter(func(event): return str(event.get("tournament_id", "")) == registered_id and str(event.get("status", "scheduled")) == "scheduled")
	_check(not registered_events.is_empty(), "Registered tournament has no playable schedule")
	if not registered_events.is_empty():
		var match_event: Dictionary = registered_events[0]
		match_event.date = str(game.data.current_date)
		_check(bool(game.prepare_match_context(match_event).get("ok", false)), "Real tournament match context could not be prepared")
		game.data.active_match_event_id = str(match_event.get("id", ""))
		captured_match_result.clear()
		var runtime = MatchRuntimeScript.new()
		runtime.match_finished.connect(_capture_match_result)
		runtime.start_match(game.data, str(match_event.get("map", "verdant_reach")), game.effective_match_plan(), 90210)
		for tick_index in 4000:
			if not captured_match_result.is_empty(): break
			runtime.tick(5.0)
		_check(not captured_match_result.is_empty(), "Frozen MatchRuntime did not produce a deterministic tournament result")
		if not captured_match_result.is_empty():
			_check(bool(game.apply_match_runtime_result(captured_match_result, match_event).get("ok", false)), "Real MatchRuntime tournament result did not commit")
			var own_standings: Array = game.get_tournament_standings(registered_id).filter(func(row): return bool(row.get("is_player", false)))
			_check(not own_standings.is_empty() and int(own_standings[0].get("matches", 0)) == 1, "Committed tournament result did not update standings")

	# Priority presenter uses current real state.
	var priorities := PriorityScript.build(game.data, game.get_next_match(true)); _check(not priorities.is_empty(), "Command Center priority service returned no action")
	_check(priorities[0].has("reason") and priorities[0].has("target_route"), "Priority lacks reason/route")

	# Season transition archives actual career state before opening the next season.
	var season_before := int(game.data.season); game.data.week = 12; game.advance_week(true)
	_check(int(game.data.season) == season_before + 1, "Season transition did not advance season")
	_check(not game.data.season_history.is_empty() and int(game.data.season_history[0].season) == season_before, "Season summary was not archived")
	_check(str(game.data.season_transition.get("status", "")) == "AVAILABLE" and game.data.season_transition.has("financial_result") and int(game.data.season_transition.get("world_rank", 0)) > 0, "Season summary lacks real presentation data")
	_check(game.data.pending_events.is_empty(), "Season transition retained temporary pending events")
	_check(not game.data.media_stories.any(func(story): return int(story.get("season", 0)) == season_before and int(story.get("week", 0)) > 12), "Season transition created a week-13 media story")
	_check(bool(game.acknowledge_season_transition().get("ok", false)) and not bool(game.acknowledge_season_transition().get("ok", false)), "Season summary acknowledgement is not single-use")

	# Mandatory save/reload verification for all major persistent domains.
	game.set_team_training_schedule("Nghỉ & hồi phục"); game.set_coach_plan_values({"engagement":"AGGRESSIVE"}); _check(game.save_game(), "Final journey save failed")
	var expected := {"season":game.data.season,"roster_ids":game.data.roster.map(func(player): return str(player.get("id",""))),"salary":int(game.data.roster[0].salary),"schedule":str(game.data.schedule),"tactics":str(game.data.coach_plan.engagement),"medical":int(game.data.facilities["Medical Room"]),"budget":int(game.data.budget),"national_team":str(game.data.national_team_id),"media_status":str(game.data.media_stories[0].status),"loan_status":str(game.data.loan_records[0].status),"inbound_status":str(game.data.inbound_offers[0].status)}
	var loaded = GameStateScript.new(); loaded.save_path = SAVE_PATH; _check(loaded.load_game(), "Saved journey did not reload")
	_check(int(loaded.data.season) == int(expected.season), "Season was lost on reload")
	_check(loaded.data.roster.map(func(player): return str(player.get("id",""))) == expected.roster_ids, "Roster was lost on reload")
	_check(int(loaded.data.roster[0].salary) == int(expected.salary), "Contract salary was lost on reload")
	_check(str(loaded.data.schedule) == str(expected.schedule) and str(loaded.data.coach_plan.engagement) == str(expected.tactics), "Training/tactics were lost on reload")
	_check(int(loaded.data.facilities["Medical Room"]) == int(expected.medical), "Facility state was lost on reload")
	_check(int(loaded.data.budget) == int(expected.budget), "Finance state was lost on reload")
	_check(str(loaded.data.national_team_id) == str(expected.national_team), "National state was lost on reload")
	_check(str(loaded.data.media_stories[0].status) == str(expected.media_status), "Media state was lost on reload")
	_check(str(loaded.data.loan_records[0].status) == str(expected.loan_status), "Loan state was lost on reload")
	_check(str(loaded.data.inbound_offers[0].status) == str(expected.inbound_status), "Inbound offer state was lost on reload")

func _run_destructive_contract_branch() -> void:
	var game = GameStateScript.new(); game.save_path = DESTRUCTIVE_PATH; game.new_career("Contract Branch", "Manager", "SEA"); game.data.budget = 5000000
	game.data.reputation = 100
	while game.data.roster.size() < 5:
		var signed := false
		for index in range(game.data.market.size()-1,-1,-1):
			if game.sign_player(index).begins_with("Signed"): signed=true; break
		if not signed: break
	var roster_before: int = game.data.roster.size(); var player_id := str(game.data.roster.back().id); var budget_before := int(game.data.budget)
	_check(game.terminate_player_contract(player_id).begins_with("Contract terminated"), "Contract termination failed")
	_check(game.data.roster.size() == roster_before - 1 and int(game.data.budget) < budget_before, "Termination did not change roster/finance")

func _run_migration_branch() -> void:
	var game = GameStateScript.new(); game.save_path = MIGRATION_PATH; game.new_career("Migration Branch", "Manager", "SEA")
	for key in ["days_elapsed","progression_log","season_history","season_transition","season_start_budget","next_record_sequence","loaned_players","loan_records","inbound_offers","transferred_out_players","media_stories"]: game.data.erase(key)
	_check(game.save_game(), "Legacy-shaped save could not be written")
	var migrated = GameStateScript.new(); migrated.save_path = MIGRATION_PATH; _check(migrated.load_game(), "Legacy-shaped save did not migrate")
	for key in ["days_elapsed","progression_log","season_history","season_transition","season_start_budget","next_record_sequence","loaned_players","loan_records","inbound_offers","transferred_out_players","media_stories"]: _check(migrated.data.has(key), "Migration did not add %s" % key)

func _average(rows: Array, key: String) -> int:
	var total := 0
	for row in rows: total += int(row.get(key, 0))
	return roundi(float(total) / maxi(1, rows.size()))

func _capture_match_result(result: Dictionary) -> void:
	captured_match_result = result.duplicate(true)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("CHECK FAILED: %s" % message)
