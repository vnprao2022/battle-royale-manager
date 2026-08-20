class_name CareerStateValidator
extends RefCounted

const VALID_SQUAD_ROLES := ["starter", "substitute"]
const VALID_EVENT_LIFECYCLES := ["PENDING", "RESOLVED", "EXPIRED", "CANCELLED"]

static func validate(state: Dictionary, current_version: int) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []
	if state.is_empty():
		_add(errors, "STATE_EMPTY", "", "Career state is empty.")
		return {"ok":false, "errors":errors, "warnings":warnings}
	_validate_required(state, current_version, errors)
	_validate_roster(state, errors)
	_validate_finance(state, errors, warnings)
	_validate_calendar(state, errors)
	_validate_tournaments(state, errors)
	_validate_relationships(state, errors)
	_validate_events(state, errors)
	return {"ok":errors.is_empty(), "errors":errors, "warnings":warnings}

static func _validate_required(state: Dictionary, current_version: int, errors: Array) -> void:
	for field in ["save_version", "career_id", "organization_id", "season", "week", "current_date", "roster", "market", "budget", "finance_ledger", "calendar_events", "pending_events", "event_history"]:
		if not state.has(field): _add(errors, "REQUIRED_FIELD_MISSING", field, "Required career field is missing.")
	var version := int(state.get("save_version", 0))
	if version < 1 or version > current_version:
		_add(errors, "SAVE_VERSION_INVALID", "save_version", "Save version is outside the supported range.", {"value":version, "current":current_version})

static func _validate_roster(state: Dictionary, errors: Array) -> void:
	var roster: Array = state.get("roster", [])
	var loaned: Array = state.get("loaned_players", [])
	var market: Array = state.get("market", [])
	var active_ids := _entity_ids(roster, "roster", errors)
	var loaned_ids := _entity_ids(loaned, "loaned_players", errors)
	var market_ids := _entity_ids(market, "market", errors)
	for player_id in active_ids:
		if loaned_ids.has(player_id): _add(errors, "PLAYER_ACTIVE_AND_LOANED", "roster", "Player exists in both active roster and loaned players.", {"player_id":player_id})
		if market_ids.has(player_id): _add(errors, "PLAYER_OWNED_AND_MARKET", "market", "Owned player also exists in the transfer market.", {"player_id":player_id})
	for player in roster:
		var player_id := str(player.get("id", ""))
		if int(player.get("contract", 0)) <= 0: _add(errors, "OWNED_CONTRACT_INVALID", "roster", "Active owned player has no valid contract.", {"player_id":player_id})
	for player in loaned:
		if int(player.get("contract", 0)) <= 0: _add(errors, "LOAN_CONTRACT_INVALID", "loaned_players", "Loaned player has no valid contract.", {"player_id":str(player.get("id", ""))})
	if not roster.is_empty() and roster.size() < 4: _add(errors, "STARTER_COUNT_INVALID", "roster", "An active career roster must contain at least four players.", {"count":roster.size()})
	for index in roster.size():
		var expected := "starter" if index < 4 else "substitute"
		var role := str(roster[index].get("squad_role", ""))
		if not role in VALID_SQUAD_ROLES or role != expected:
			_add(errors, "SQUAD_ROLE_INVALID", "roster", "Squad role does not match the authoritative roster order.", {"player_id":str(roster[index].get("id", "")), "expected":expected, "actual":role})

static func _validate_finance(state: Dictionary, errors: Array, warnings: Array) -> void:
	var budget = state.get("budget", null)
	if not budget is int and not budget is float: _add(errors, "BUDGET_TYPE_INVALID", "budget", "Budget must be numeric.")
	elif absf(float(budget)) > 2000000000.0: _add(errors, "BUDGET_RANGE_INVALID", "budget", "Budget exceeds the supported accounting range.", {"value":budget})
	elif int(budget) < 0: _add(warnings, "BUDGET_NEGATIVE", "budget", "Career cash is negative; insolvency consequences are not implemented.", {"value":budget})
	var ids: Dictionary = {}
	for entry in state.get("finance_ledger", []):
		var record_id := str(entry.get("id", ""))
		if record_id.is_empty(): _add(errors, "FINANCE_ID_MISSING", "finance_ledger", "Finance record has no stable ID.")
		elif ids.has(record_id): _add(errors, "FINANCE_ID_DUPLICATE", "finance_ledger", "Finance record ID is duplicated.", {"id":record_id})
		else: ids[record_id] = true
		var amount = entry.get("amount", null)
		if not amount is int and not amount is float: _add(errors, "FINANCE_AMOUNT_INVALID", "finance_ledger", "Finance record amount must be numeric.", {"id":record_id})

static func _validate_calendar(state: Dictionary, errors: Array) -> void:
	var season := int(state.get("season", 0)); var week := int(state.get("week", 0)); var days := int(state.get("days_elapsed", 0)); var season_start_days := int(state.get("season_start_days_elapsed", 0))
	if season < 1: _add(errors, "SEASON_INVALID", "season", "Season must be positive.", {"value":season})
	if week < 1 or week > 12: _add(errors, "WEEK_INVALID", "week", "Week must remain inside the 1..12 season boundary.", {"value":week})
	if days < season_start_days: _add(errors, "SEASON_DAY_RANGE_INVALID", "days_elapsed", "Elapsed days cannot precede the current season boundary.", {"days_elapsed":days,"season_start_days_elapsed":season_start_days})
	elif days - season_start_days < 84 and week != int((days - season_start_days) / 7) + 1: _add(errors, "WEEK_DAY_MISMATCH", "week", "Week is inconsistent with the current season elapsed-day counter.", {"week":week, "days_elapsed":days,"season_start_days_elapsed":season_start_days})
	if Time.get_unix_time_from_datetime_string(str(state.get("current_date", "")) + "T00:00:00") <= 0: _add(errors, "DATE_INVALID", "current_date", "Current career date is malformed.")
	var ids: Dictionary = {}
	for event in state.get("calendar_events", []):
		var event_id := str(event.get("id", ""))
		if event_id.is_empty(): _add(errors, "CALENDAR_ID_MISSING", "calendar_events", "Calendar event has no ID.")
		elif ids.has(event_id): _add(errors, "CALENDAR_ID_DUPLICATE", "calendar_events", "Calendar event ID is duplicated.", {"id":event_id})
		else: ids[event_id] = true
		if str(event.get("status", "scheduled")) == "completed" and not bool(event.get("completed", false)):
			_add(errors, "CALENDAR_COMPLETION_MISMATCH", "calendar_events", "Completed calendar event is missing its completion flag.", {"id":event_id})

static func _validate_tournaments(state: Dictionary, errors: Array) -> void:
	var tournament_ids: Dictionary = {}
	for tournament in state.get("tournaments", []): tournament_ids[str(tournament.get("id", ""))] = true
	var result_events: Dictionary = {}
	for tournament_id in state.get("tournament_results", {}):
		if not tournament_ids.has(str(tournament_id)): _add(errors, "TOURNAMENT_RESULT_ORPHANED", "tournament_results", "Results reference an unknown tournament.", {"tournament_id":tournament_id})
		for result in state.tournament_results[tournament_id]:
			var event_id := str(result.get("event_id", ""))
			if event_id.is_empty(): _add(errors, "TOURNAMENT_RESULT_ID_MISSING", "tournament_results", "Tournament result has no event ID.")
			elif result_events.has(event_id): _add(errors, "TOURNAMENT_RESULT_DUPLICATE", "tournament_results", "Tournament event result was committed more than once.", {"event_id":event_id})
			else: result_events[event_id] = true

static func _validate_relationships(state: Dictionary, errors: Array) -> void:
	for key in state.get("relationships", {}):
		var record: Dictionary = state.relationships[key]
		var player_a := str(record.get("player_a", "")); var player_b := str(record.get("player_b", ""))
		if player_a.is_empty() or player_b.is_empty() or player_a == player_b: _add(errors, "RELATIONSHIP_PAIR_INVALID", "relationships", "Relationship pair is empty or self-referential.", {"key":key})
		var canonical := player_a + "|" + player_b if player_a < player_b else player_b + "|" + player_a
		if str(key) != canonical: _add(errors, "RELATIONSHIP_KEY_NONCANONICAL", "relationships", "Relationship key is not canonical.", {"key":key, "expected":canonical})
		var value := int(record.get("value", 0))
		if value < -100 or value > 100: _add(errors, "RELATIONSHIP_RANGE_INVALID", "relationships", "Relationship value is outside -100..100.", {"key":key, "value":value})

static func _validate_events(state: Dictionary, errors: Array) -> void:
	var pending_ids: Dictionary = {}
	for event in state.get("pending_events", []):
		var event_id := str(event.get("id", "")); var lifecycle := str(event.get("lifecycle_status", "PENDING"))
		if event_id.is_empty(): _add(errors, "EVENT_ID_MISSING", "pending_events", "Pending event has no stable ID.")
		elif pending_ids.has(event_id): _add(errors, "EVENT_ID_DUPLICATE", "pending_events", "Pending event ID is duplicated.", {"id":event_id})
		else: pending_ids[event_id] = true
		if str(event.get("type", "")).is_empty(): _add(errors, "EVENT_TYPE_MISSING", "pending_events", "Pending event has no type.", {"id":event_id})
		if lifecycle != "PENDING": _add(errors, "EVENT_PENDING_STATE_INVALID", "pending_events", "Only PENDING events may remain in pending_events.", {"id":event_id, "status":lifecycle})
	for event in state.get("event_history", []):
		var lifecycle := str(event.get("lifecycle_status", "RESOLVED"))
		if not lifecycle in VALID_EVENT_LIFECYCLES or lifecycle == "PENDING": _add(errors, "EVENT_HISTORY_STATE_INVALID", "event_history", "Historical event must be terminal.", {"id":str(event.get("id", "")), "status":lifecycle})

static func _entity_ids(rows: Array, path: String, errors: Array) -> Dictionary:
	var ids: Dictionary = {}
	for row in rows:
		var entity_id := str(row.get("id", ""))
		if entity_id.is_empty(): _add(errors, "PLAYER_ID_MISSING", path, "Player has no stable ID.")
		elif ids.has(entity_id): _add(errors, "PLAYER_ID_DUPLICATE", path, "Player ID is duplicated.", {"player_id":entity_id})
		else: ids[entity_id] = true
	return ids

static func _add(target: Array, code: String, path: String, message: String, details: Dictionary = {}) -> void:
	target.append({"error_code":code, "path":path, "message":message, "details":details})
