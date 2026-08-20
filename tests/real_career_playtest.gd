extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const GameDatabaseScript = preload("res://scripts/game_database.gd")
const MatchRuntimeScript = preload("res://scripts/match_runtime.gd")
const PriorityScript = preload("res://scripts/ui/presenters/career_priority_presenter.gd")
const SAVE_PATH := "user://codex_real_career_playtest.json"

var game
var checks := 0
var failures := 0
var matches_played := 0
var weekly_cycles := 0
var reloads := 0
var captured_match_result: Dictionary = {}
var initial_state: Dictionary = {}
var final_state: Dictionary = {}
var balance_report: Dictionary = {}

func _init() -> void:
	_run_playthrough()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if failures > 0:
		push_error("REAL_CAREER_PLAYTEST_FAILED checks=%d failures=%d matches=%d weeks=%d reloads=%d" % [checks, failures, matches_played, weekly_cycles, reloads])
		quit(1)
	else:
		print("REAL_CAREER_PLAYTEST_OK checks=%d matches=%d weeks=%d reloads=%d" % [checks, matches_played, weekly_cycles, reloads])
		print("REAL_CAREER_INITIAL %s" % JSON.stringify(initial_state))
		print("REAL_CAREER_FINAL %s" % JSON.stringify(final_state))
		print("REAL_CAREER_BALANCE %s" % JSON.stringify(balance_report))
		quit(0)

func _run_playthrough() -> void:
	game = GameStateScript.new()
	game.save_path = SAVE_PATH
	game.new_career("Real Career QA", "Career playtester", "SEA", {"difficulty":"Normal", "starting_tier":"C"})
	initial_state = _career_snapshot()
	balance_report.starting_budget = int(game.data.budget)
	balance_report.starting_payroll = _weekly_payroll()
	balance_report.starting_average_energy = _average("energy")
	_validate_initial_career()
	_checkpoint("fresh career")
	_resolve_current_blockers()

	# Commercial baseline and duplicate-signing protection.
	var eligible_sponsors: Array = game.data.sponsors.filter(func(sponsor): return int(sponsor.get("reputation_required", 0)) <= int(game.data.reputation))
	_check(not eligible_sponsors.is_empty(), "Fresh career has no eligible sponsor")
	if not eligible_sponsors.is_empty():
		var sponsor_id := str(eligible_sponsors[0].id)
		var budget_before_sponsor := int(game.data.budget)
		var bonus := int(eligible_sponsors[0].signing_bonus)
		_check(game.accept_sponsor(sponsor_id).begins_with("Signed"), "Eligible sponsor could not be signed")
		_check(int(game.data.budget) == budget_before_sponsor + bonus, "Sponsor signing bonus was not applied exactly once")
		_check(not game.accept_sponsor(sponsor_id).begins_with("Signed"), "Sponsor contract could be signed twice")

	# Real squad actions on the canonical owned roster.
	if game.data.roster.size() >= 5:
		var substitute_id := str(game.data.roster[4].id)
		var replaced_id := str(game.data.roster[3].id)
		_check(bool(game.move_roster_player(substitute_id, true).get("ok", false)), "Substitute promotion failed")
		_check(str(game.data.roster[3].id) == substitute_id and str(game.data.roster[4].id) == replaced_id, "Lineup swap did not preserve both players")
		_check(bool(game.set_player_role(substitute_id, "IGL").get("ok", false)), "Owned-player role change failed")
		game.data.roster[3].energy = 48
		_check(game.recover_player(substitute_id).contains("recovered"), "Manual player recovery failed")
		_validate_roster("after squad management")
	_checkpoint("squad management")

	# Three distinct training choices must produce different weekly energy behavior.
	var high_before := _average("energy")
	_check(bool(game.set_team_training_schedule("Cường độ cao").get("ok", false)), "High workload selection failed")
	_check(bool(game.set_individual_training(str(game.data.roster[0].id), "Aim").get("ok", false)), "Individual training selection failed")
	_advance_days(7)
	var high_after := _average("energy")
	balance_report.high_training_energy_delta = high_after - high_before
	_check(high_after < high_before, "High workload had no meaningful energy cost")
	_checkpoint("high training")
	var recovery_before := _average("energy")
	_check(bool(game.set_team_training_schedule("Nghỉ & hồi phục").get("ok", false)), "Recovery workload selection failed")
	_check(bool(game.set_individual_training(str(game.data.roster[0].id), "Recovery").get("ok", false)), "Individual recovery focus failed")
	_advance_days(7)
	var recovery_after := _average("energy")
	balance_report.recovery_energy_delta = recovery_after - recovery_before
	_check(recovery_after > recovery_before, "Recovery workload did not restore average energy")
	_check(bool(game.set_team_training_schedule("Cân bằng").get("ok", false)), "Balanced workload selection failed")
	_advance_days(7)

	# Contract renewal/salary/payroll and destructive removal in a controlled depth-safe state.
	var contract_player: Dictionary = game.data.roster[0]
	var contract_before := int(contract_player.contract)
	var salary_before := int(contract_player.salary)
	_check(game.renew_contract(str(contract_player.id), 12).begins_with("Renewed"), "Important player renewal failed")
	_check(int(contract_player.contract) == contract_before + 12, "Renewal duration was incorrect")
	_check(bool(game.set_player_salary(str(contract_player.id), salary_before + 500).get("ok", false)), "Salary change failed")
	_checkpoint("contract and salary")

	# Full real outbound recruitment workflow through a pending Inbox event.
	var affordable: Array = game.data.market.filter(func(player): return int(player.get("value", 0)) <= int(game.data.budget))
	_check(not affordable.is_empty(), "Career economy cannot afford any transfer prospect")
	if not affordable.is_empty() and game.organization_player_count() < 7:
		var candidate: Dictionary = affordable[0]
		var roster_before_signing: int = game.data.roster.size()
		var budget_before_signing := int(game.data.budget)
		var offer: Dictionary = game.create_transfer_offer(str(candidate.id), {"salary":int(candidate.salary) + 7200, "months":24, "starter_guarantee":true})
		_check(bool(offer.get("ok", false)), "Outbound transfer offer was not created")
		if bool(offer.get("ok", false)):
			var event: Dictionary = game.data.pending_events.filter(func(item): return str(item.get("type", "")) == "transfer_offer" and str(item.get("context", {}).get("offer_id", "")) == str(offer.offer.id))[0]
			var action := "accept" if str(offer.offer.response) == "ACCEPT" else "counter" if str(offer.offer.response) == "COUNTER" else "reject"
			_check(action != "reject", "Affordable high-value recruitment terms were still rejected")
			_check(bool(game.resolve_event(str(event.id), action).get("ok", false)), "Outbound Inbox negotiation failed")
			_check(game.data.roster.size() == roster_before_signing + 1, "Signed player did not become owned roster data")
			var applied_fee:=int(offer.get("offer",{}).get("fee",-1))
			_check(int(game.data.budget) == budget_before_signing - applied_fee, "Transfer spending was not applied exactly once")
			balance_report.outbound_transfer_fee = applied_fee
			_check(not bool(game.resolve_event(str(event.id), action).get("ok", false)), "Resolved transfer event could be accepted twice")
	_validate_roster("after outbound transfer")
	if game.data.roster.size() >= 5:
		var promoted_id := str(game.data.roster[4].id)
		var replaced_id := str(game.data.roster[3].id)
		_check(bool(game.move_roster_player(promoted_id, true).get("ok", false)), "Post-recruitment substitute promotion failed")
		_check(str(game.data.roster[3].id) == promoted_id and str(game.data.roster[4].id) == replaced_id, "Post-recruitment lineup swap lost a player")
		_check(bool(game.set_player_role(promoted_id, "IGL").get("ok", false)), "Post-recruitment role change failed")
		game.data.roster[3].energy = 48
		_check(game.recover_player(promoted_id).contains("recovered"), "Post-recruitment manual rest failed")
		_validate_roster("after recruited-player squad management")
	_checkpoint("outbound transfer")

	# Inbound reject, counter/accept, and expiration without freezing time.
	if game.data.roster.size() > 4:
		var rejected_player_id := str(game.data.roster.back().id)
		game.set_transfer_listed(rejected_player_id, true)
		var rejected_offers: Array = game.generate_inbound_offers(true)
		_check(not rejected_offers.is_empty(), "Forced inbound offer was not generated")
		if not rejected_offers.is_empty():
			var rejected_offer_id := str(rejected_offers[0].id)
			var reject_event: Dictionary = game.data.pending_events.filter(func(item): return str(item.get("context", {}).get("offer_id", "")) == rejected_offer_id)[0]
			_check(bool(game.resolve_event(str(reject_event.id), "reject").get("ok", false)), "Inbound rejection failed")
			_check(not bool(game.resolve_inbound_offer(rejected_offer_id, "reject").get("ok", false)), "Rejected inbound offer could resolve twice")
		game.set_transfer_listed(rejected_player_id, false)
		var sale_player_id := str(game.data.roster[0].id)
		game.set_transfer_listed(sale_player_id, true)
		var sale_offers: Array = game.generate_inbound_offers(true)
		_check(not sale_offers.is_empty(), "Counterable inbound offer was not generated")
		if not sale_offers.is_empty():
			var sale_offer_id := str(sale_offers[0].id)
			var sale_event: Dictionary = game.data.pending_events.filter(func(item): return str(item.get("context", {}).get("offer_id", "")) == sale_offer_id)[0]
			_check(bool(game.resolve_event(str(sale_event.id), "counter").get("ok", false)), "Inbound counter failed")
			var counter_event: Dictionary = game.data.pending_events.filter(func(item): return str(item.get("context", {}).get("offer_id", "")) == sale_offer_id)[0]
			var sale_budget_before := int(game.data.budget)
			var sale_roster_before: int = game.data.roster.size()
			_check(bool(game.resolve_event(str(counter_event.id), "accept").get("ok", false)), "Countered inbound sale could not complete")
			_check(game.data.roster.size() == sale_roster_before - 1 and int(game.data.budget) > sale_budget_before, "Inbound sale did not update roster and finance")
			balance_report.inbound_sale_income = int(game.data.budget) - sale_budget_before
	_checkpoint("inbound transfer")
	if game.organization_player_count() < 7:
		var second_affordable: Array = game.data.market.filter(func(player): return int(player.get("value", 0)) <= int(game.data.budget))
		_check(not second_affordable.is_empty(), "Inbound-sale proceeds could not fund any replacement candidate")
		if not second_affordable.is_empty():
			var replacement: Dictionary = second_affordable[0]
			var replacement_offer: Dictionary = game.create_transfer_offer(str(replacement.id), {"salary":int(replacement.salary)+7200,"months":24,"starter_guarantee":true})
			_check(bool(replacement_offer.get("ok", false)), "Replacement transfer offer failed")
			if bool(replacement_offer.get("ok", false)):
				var replacement_event: Dictionary = game.data.pending_events.filter(func(event): return str(event.get("context", {}).get("offer_id", "")) == str(replacement_offer.offer.id))[0]
				var replacement_action: String = "accept" if str(replacement_offer.offer.response) == "ACCEPT" else "counter"
				_check(bool(game.resolve_event(str(replacement_event.id), replacement_action).get("ok", false)), "Replacement signing did not complete")
				_validate_roster("after replacement signing")

	if game.data.roster.size() > 4:
		var expiring_player_id := str(game.data.roster.back().id)
		game.set_transfer_listed(expiring_player_id, true)
		var expiring_offers: Array = game.generate_inbound_offers(true)
		_check(not expiring_offers.is_empty(), "Expiring inbound offer was not generated")
		_checkpoint("pending inbound offer")
		if not expiring_offers.is_empty():
			var expiration_id := str(expiring_offers[0].id)
			_advance_days(15)
			var expired: Array = game.data.inbound_offers.filter(func(offer): return str(offer.get("id", "")) == expiration_id)
			_check(not expired.is_empty() and str(expired[0].status) == "EXPIRED", "Ignored inbound offer did not expire through normal time progression")
			_check(not game.data.pending_events.any(func(event): return str(event.get("context", {}).get("offer_id", "")) == expiration_id), "Expired inbound offer left a stale Inbox decision")

	# Two simultaneous facilities: exact costs, completion, and code-backed benefits.
	var facilities_to_upgrade := ["Training Room", "Medical Room"]
	var facility_levels: Dictionary = {}
	for facility in facilities_to_upgrade:
		facility_levels[facility] = int(game.data.facilities[facility])
		var before_cost := int(game.data.budget)
		var result: String = game.upgrade_facility(facility)
		_check(result.contains("upgrade started"), "%s upgrade could not start" % facility)
		_check(int(game.data.budget) < before_cost, "%s upgrade cost was not deducted" % facility)
		balance_report["%s_upgrade_cost" % facility.to_snake_case()] = before_cost - int(game.data.budget)
		_check(not game.upgrade_facility(facility).contains("upgrade started"), "%s duplicate project was accepted" % facility)
	_checkpoint("facility projects active")
	_advance_days(7)
	for facility in facilities_to_upgrade:
		_check(int(game.data.facilities[facility]) == int(facility_levels[facility]) + 1, "%s project did not complete once" % facility)
		_check(not game.facility_benefit_summary(facility).contains("No confirmed"), "%s has no real benefit" % facility)

	# Full loan lifecycle and mid-loan persistence.
	if game.data.roster.size() > 4:
		var loan_player_id := str(game.data.roster.back().id)
		var loan_contract := int(game.data.roster.back().contract)
		var roster_before_loan: int = game.data.roster.size()
		var loan: Dictionary = game.create_loan(loan_player_id, "", 4, 50)
		_check(bool(loan.get("ok", false)), "Loan lifecycle could not start")
		_check(game.data.roster.size() == roster_before_loan - 1 and game.data.loaned_players.size() == 1, "Loaned player remained active or disappeared")
		_checkpoint("active loan")
		_advance_days(28)
		_check(game.data.loaned_players.is_empty(), "Loan did not return automatically")
		var returned: Array = game.data.roster.filter(func(player): return str(player.get("id", "")) == loan_player_id)
		_check(returned.size() == 1, "Loan return created zero or duplicate owned players")
		_check(int(returned[0].contract) <= loan_contract, "Loan incorrectly increased the player contract")
		var returned_count: int = game.data.roster.size()
		_advance_days(1)
		_check(game.data.roster.size() == returned_count, "Loan return processed more than once")

	# National roster references must not alter club ownership.
	var database = GameDatabaseScript.new()
	_check(database.load_all().is_empty(), "Canonical database failed during career")
	var national_teams: Array = database.teams.filter(func(team): return str(team.get("team_type", "")) == "NATIONAL")
	if not national_teams.is_empty():
		var owned_ids: Array = game.data.roster.map(func(player): return str(player.id))
		_check(bool(game.select_national_team(str(national_teams[0].id)).get("ok", false)), "National appointment failed")
		var eligible: Array = game.eligible_national_players(str(national_teams[0].id))
		_check(not eligible.is_empty(), "National appointment has no eligible canonical players")
		if not eligible.is_empty():
			var national_player_id := str(eligible[0].id)
			_check(bool(game.call_up_player(national_player_id).get("ok", false)), "National call-up failed")
			_check(bool(game.release_national_player(national_player_id).get("ok", false)), "National release failed")
		_check(game.data.roster.map(func(player): return str(player.id)) == owned_ids, "National management changed club ownership")
		game.set_management_context("CLUB")

	# Media is single-use and priorities respond to real state.
	var story: Dictionary = game.current_media_story()
	var sentiment_before := int(game.data.fan_sentiment)
	_check(bool(game.record_media_response("POSITIVE", "Season playtest response", str(story.id)).get("ok", false)), "Media response failed")
	var sentiment_after := int(game.data.fan_sentiment)
	_check(sentiment_after == sentiment_before + 2, "Media consequence was not applied exactly once")
	_check(not bool(game.record_media_response("POSITIVE", "Duplicate", str(story.id)).get("ok", false)), "Media reward could be repeated")
	_check(int(game.data.fan_sentiment) == sentiment_after, "Rejected duplicate media response changed state")
	for starter in game.data.roster.slice(0, mini(4, game.data.roster.size())): starter.energy = 80
	var base_priorities := PriorityScript.build(game.data, game.get_next_match(true))
	game.data.roster[0].energy = 40
	var fatigue_priorities := PriorityScript.build(game.data, game.get_next_match(true))
	_check(base_priorities != fatigue_priorities and fatigue_priorities.any(func(item): return str(item.get("target_route", "")) == "roster"), "Command Center did not react to real fatigue")

	# Finish the real season through daily progression and every scheduled match.
	while int(game.data.season) == 1 and int(game.data.days_elapsed) < 120:
		_resolve_current_blockers()
		var budget_before_day := int(game.data.budget)
		var ledger_ids_before: Array = game.data.finance_ledger.map(func(entry): return str(entry.get("id", "")))
		var step: Dictionary = game.advance_day()
		if bool(step.get("weekly_update", false)):
			weekly_cycles += 1
			_check(_new_ledger_total(ledger_ids_before) == int(game.data.budget) - budget_before_day, "Weekly/season budget change does not reconcile with the finance ledger")
		if not bool(step.get("ok", false)) and not bool(step.get("stopped", false)):
			_check(false, "Calendar could not advance near season end")
			break
	_check(int(game.data.season) == 2, "Real daily career did not reach Season 2")
	_check(not game.data.season_history.is_empty(), "Season 1 was not archived")
	_check(not game.data.get("season_transition", {}).is_empty(), "Season transition summary was not persisted")
	_check(str(game.data.season_transition.get("status", "")) == "AVAILABLE", "Season summary was not presented as an available career moment")
	_check(not game.data.calendar_events.is_empty(), "New season calendar was not generated")
	_check(game.data.pending_events.is_empty(), "Season-specific pending events leaked into the new season")
	_check(not game.data.media_stories.any(func(story): return int(story.get("season", 0)) == 1 and int(story.get("week", 0)) > 12), "An impossible week-13 media story was created")
	_check(not game.data.roster.is_empty() and not game.data.facilities.is_empty(), "Permanent career data was reset at season end")
	_validate_roster("after season transition")
	_checkpoint("after season transition")
	_check(bool(game.acknowledge_season_transition().get("ok", false)), "Season summary could not be acknowledged")
	_check(not bool(game.acknowledge_season_transition().get("ok", false)), "Season summary could be acknowledged twice")
	for collection_name in ["inbox", "finance_ledger", "progression_log"]:
		var ids: Array = game.data.get(collection_name, []).map(func(item): return str(item.get("id", "")))
		_check(ids.size() == _unique_count(ids), "%s contains duplicate persistent IDs after a full season" % collection_name)
	final_state = _career_snapshot()
	balance_report.season_closing_budget = int(game.data.season_history[0].closing_budget)
	balance_report.season_financial_result = int(game.data.season_history[0].financial_result)
	balance_report.renewal_income = int(game.data.season_history[0].renewal_income)
	balance_report.new_season_budget = int(game.data.budget)
	balance_report.final_payroll = _weekly_payroll()
	balance_report.matches_played = matches_played

func _validate_initial_career() -> void:
	_check(int(game.data.season) == 1 and int(game.data.week) == 1, "Fresh career season/week is invalid")
	_check(str(game.data.current_date) == GameStateScript.SEASON_START_DATE, "Fresh career date is invalid")
	_check(not str(game.data.organization_id).is_empty() and not str(game.data.org_name).is_empty(), "Fresh career has no canonical organization")
	_check(game.data.roster.size() >= 4, "Fresh career lacks a playable roster")
	_check(int(game.data.budget) >= 0, "Fresh career starts with unexplained negative cash")
	_check(game.data.roster.all(func(player): return int(player.get("contract", 0)) > 0), "Fresh career has an invalid owned-player contract")
	_check(game.data.facilities.keys().size() == 4, "Fresh career facility set is incomplete")
	_check(not game.data.calendar_events.is_empty() and not game.data.tournaments.is_empty(), "Fresh career calendar/tournaments are missing")
	_check(game.career_world_rank() > 0, "Fresh career ranking is missing")
	_check(not game.data.inbox.is_empty(), "Fresh career Inbox is empty")
	_validate_roster("fresh career")

func _validate_roster(stage: String) -> void:
	var active_ids: Array = game.data.roster.map(func(player): return str(player.get("id", "")))
	var loan_ids: Array = game.data.loaned_players.map(func(player): return str(player.get("id", "")))
	_check(active_ids.size() == _unique_count(active_ids), "%s has duplicate active players" % stage)
	_check(loan_ids.size() == _unique_count(loan_ids), "%s has duplicate loan players" % stage)
	_check(not active_ids.any(func(player_id): return player_id in loan_ids), "%s has a player both active and loaned" % stage)
	_check(game.data.roster.size() >= 4, "%s has an invalid active lineup" % stage)
	for index in game.data.roster.size():
		_check(str(game.data.roster[index].get("squad_role", "")) == ("starter" if index < 4 else "substitute"), "%s has stale squad-role state" % stage)

func _resolve_current_blockers() -> void:
	var safety := 0
	while not game.actionable_events().is_empty() and safety < 40:
		safety += 1
		var event: Dictionary = game.actionable_events()[0]
		if str(event.get("type", "")) == "match":
			_play_match(event)
		elif game.data.pending_events.any(func(item): return str(item.get("id", "")) == str(event.get("id", ""))):
			var choices: Array = event.get("choices", [])
			_check(not choices.is_empty(), "Pending event has no resolvable choice")
			if not choices.is_empty(): game.resolve_event(str(event.id), str(choices.back().id))
		else:
			game.acknowledge_calendar_event(str(event.id))
	_check(safety < 40, "Career became stuck in an actionable-event loop")

func _advance_days(count: int) -> void:
	for day in count:
		_resolve_current_blockers()
		var budget_before_day := int(game.data.budget)
		var ledger_ids_before: Array = game.data.finance_ledger.map(func(entry): return str(entry.get("id", "")))
		var result: Dictionary = game.advance_day()
		_check(bool(result.get("ok", false)), "Next Day failed during real career progression")
		if bool(result.get("weekly_update", false)):
			weekly_cycles += 1
			_check(_new_ledger_total(ledger_ids_before) == int(game.data.budget) - budget_before_day, "Weekly budget change does not reconcile with finance ledger entries")
		_validate_roster("day %d" % int(game.data.days_elapsed))

func _play_match(event: Dictionary) -> void:
	_check(bool(game.prepare_match_context(event).get("ok", false)), "Scheduled tournament match could not prepare")
	game.data.active_match_event_id = str(event.id)
	game.set_match_decision("EARLY", "ROTATE")
	game.set_match_decision("MID", "HOLD")
	game.set_match_decision("END", "FIGHT")
	captured_match_result.clear()
	var runtime = MatchRuntimeScript.new()
	runtime.match_finished.connect(_capture_match_result)
	runtime.start_match(game.data, str(event.get("map", "verdant_reach")), game.effective_match_plan(), 7000 + matches_played)
	for tick_index in 4000:
		if not captured_match_result.is_empty(): break
		runtime.tick(5.0)
	_check(not captured_match_result.is_empty(), "Frozen MatchRuntime did not finish a scheduled career match")
	if captured_match_result.is_empty(): return
	var history_before: int = game.data.history.size()
	_check(bool(game.apply_match_runtime_result(captured_match_result, event).get("ok", false)), "Match result did not commit into career state")
	_check(game.data.history.size() == history_before + 1, "Match result history was not added exactly once")
	_check(bool(game.apply_match_runtime_result(captured_match_result, event).get("duplicate", false)), "Duplicate MatchRuntime result was not idempotent")
	matches_played += 1

func _checkpoint(label: String) -> void:
	_check(game.save_game(), "%s checkpoint could not save" % label)
	var before: Dictionary = _career_snapshot()
	var loaded = GameStateScript.new()
	loaded.save_path = SAVE_PATH
	_check(loaded.load_game(), "%s checkpoint could not reload" % label)
	game = loaded
	reloads += 1
	var after: Dictionary = _career_snapshot()
	if _canonical(after) != _canonical(before):
		for key in before:
			if _canonical(before[key]) != _canonical(after.get(key)):
				push_error("CHECKPOINT DIFF %s • %s\nBEFORE %s\nAFTER  %s" % [label, str(key), _canonical(before[key]), _canonical(after.get(key))])
	_check(_canonical(after) == _canonical(before), "%s checkpoint changed persistent career state" % label)

func _career_snapshot() -> Dictionary:
	return {
		"season":int(game.data.season), "week":int(game.data.week), "date":str(game.data.current_date), "days":int(game.data.days_elapsed),
		"team":str(game.data.organization_id), "roster":game.data.roster.map(func(player): return [str(player.id), int(player.contract), int(player.salary), str(player.squad_role)]),
		"loaned":game.data.loaned_players.map(func(player): return str(player.id)), "budget":int(game.data.budget), "facilities":game.data.facilities.duplicate(true),
		"projects":game.data.facility_projects.duplicate(true), "registrations":game.data.tournament_registrations.duplicate(true), "results":game.data.tournament_results.duplicate(true),
		"national_team":str(game.data.national_team_id), "national_roster":game.data.national_roster_ids.duplicate(), "pending":game.data.pending_events.duplicate(true),
		"media":game.data.media_stories.duplicate(true), "history":game.data.history.duplicate(true), "season_history":game.data.season_history.duplicate(true)
	}

func _capture_match_result(result: Dictionary) -> void:
	captured_match_result = result.duplicate(true)

func _average(key: String) -> int:
	var total := 0
	for player in game.data.roster: total += int(player.get(key, 0))
	return roundi(float(total) / maxi(1, game.data.roster.size()))

func _weekly_payroll() -> int:
	var total := 0
	for player in game.data.roster: total += int(player.get("salary", 0))
	for staff in game.data.staff: total += int(staff.get("salary", 0))
	for loaned in game.data.loaned_players:
		var coverage := 0
		for record in game.data.loan_records:
			if str(record.get("player_id", "")) == str(loaned.get("id", "")) and str(record.get("status", "")) == "ACTIVE": coverage = int(record.get("salary_coverage", 0)); break
		total += roundi(int(loaned.get("salary", 0)) * (100 - coverage) / 100.0)
	return total

func _unique_count(values: Array) -> int:
	var unique: Dictionary = {}
	for value in values: unique[value] = true
	return unique.size()

func _new_ledger_total(previous_ids: Array) -> int:
	var total := 0
	for entry in game.data.finance_ledger:
		if not str(entry.get("id", "")) in previous_ids: total += int(entry.get("amount", 0))
	return total

func _canonical(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)))

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("PLAYTEST CHECK FAILED: %s" % message)
