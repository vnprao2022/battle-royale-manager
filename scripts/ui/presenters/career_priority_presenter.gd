class_name CareerPriorityPresenter
extends RefCounted

static func build(data: Dictionary, next_match: Dictionary) -> Array:
	var priorities: Array = []
	var current_date := str(data.get("current_date", ""))
	for event in data.get("pending_events", []):
		if str(event.get("status", "response_required")) != "response_required": continue
		priorities.append({"priority":100,"title":_event_title(str(event.get("type", "decision"))),"reason":"A response is required before this decision can be closed.","action":"OPEN INBOX","target_route":"inbox","tone":"danger"})
	for event in data.get("calendar_events", []):
		if str(event.get("date", "")) != current_date or str(event.get("status", "scheduled")) == "completed" or not bool(event.get("requires_player_action", false)): continue
		var event_type := str(event.get("type", "event"))
		priorities.append({"priority":95,"title":str(event.get("round", event_type)).to_upper(),"reason":"Scheduled for today and blocks day progression until resolved.","action":"OPEN EVENT","target_route":_route_for_event(event_type),"tone":"warning"})
	var urgent_contracts: Array = data.get("roster", []).filter(func(player): return int(player.get("contract", 99)) <= 6)
	if not urgent_contracts.is_empty(): priorities.append({"priority":86,"title":"%d CONTRACT DECISION(S)" % urgent_contracts.size(),"reason":"These player contracts have six months or less remaining.","action":"REVIEW CONTRACTS","target_route":"contracts","tone":"warning"})
	var tired_starters: Array = data.get("roster", []).slice(0, mini(4, data.get("roster", []).size())).filter(func(player): return int(player.get("energy", 100)) < 60)
	if not tired_starters.is_empty(): priorities.append({"priority":82,"title":"%d STARTER(S) NEED RECOVERY" % tired_starters.size(),"reason":"Starter energy is below the 60 readiness threshold used by team management.","action":"MANAGE SQUAD","target_route":"roster","tone":"warning"})
	var projects: Array = data.get("facility_projects", []).filter(func(project): return str(project.get("status", "")) == "UPGRADING")
	if not projects.is_empty():
		var project: Dictionary = projects[0]
		priorities.append({"priority":64,"title":"%s UNDER CONSTRUCTION" % str(project.get("facility", "FACILITY")).to_upper(),"reason":"Completion is scheduled for %s." % str(project.get("completion_date", "an upcoming date")),"action":"VIEW CAMPUS","target_route":"facilities","tone":"information"})
	var weekly_payroll := 0
	for player in data.get("roster", []): weekly_payroll += int(player.get("salary", 0))
	for staff in data.get("staff", []): weekly_payroll += int(staff.get("salary", 0))
	if int(data.get("budget", 0)) < weekly_payroll * 4: priorities.append({"priority":78,"title":"FINANCE RUNWAY RISK","reason":"Current cash is below four recorded payroll cycles.","action":"REVIEW FINANCE","target_route":"finance","tone":"danger"})
	if not next_match.is_empty():
		var days := _days_between(current_date, str(next_match.get("date", current_date)))
		priorities.append({"priority":76 if days <= 3 else 55,"title":"PREPARE %s" % str(next_match.get("round", "NEXT MATCH")).to_upper(),"reason":"%s on %s • %s." % [str(next_match.get("tournament", "Competition")), str(next_match.get("date", "")), str(next_match.get("map", "Map unavailable"))],"action":"PREPARE MATCH","target_route":"match","tone":"primary"})
	if priorities.is_empty(): priorities.append({"priority":20,"title":"MANAGEMENT WINDOW OPEN","reason":"No required decision is blocking progression. Review training or advance the day.","action":"REVIEW TRAINING","target_route":"training","tone":"positive"})
	priorities.sort_custom(func(a, b): return int(a.get("priority", 0)) > int(b.get("priority", 0)))
	return priorities

static func _event_title(event_type: String) -> String:
	return {"transfer_offer":"TRANSFER NEGOTIATION","inbound_transfer_offer":"INBOUND CLUB OFFER","relationship_conflict":"SQUAD RELATIONSHIP DECISION","sponsor_pressure":"SPONSOR DECISION","post_match_media":"POST-MATCH RESPONSE"}.get(event_type, event_type.replace("_", " ").to_upper())

static func _route_for_event(event_type: String) -> String:
	return "match" if event_type == "match" else "training" if event_type == "training" else "facilities" if event_type == "facility" else "inbox"

static func _days_between(from_date: String, to_date: String) -> int:
	if from_date.is_empty() or to_date.is_empty(): return 999
	return roundi((Time.get_unix_time_from_datetime_string(to_date + "T00:00:00") - Time.get_unix_time_from_datetime_string(from_date + "T00:00:00")) / 86400.0)
