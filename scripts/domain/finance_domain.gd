class_name FinanceDomain
extends RefCounted

static func weekly_operating_plan(state: Dictionary, payroll: int, economy_scale: float, has_next_match: bool) -> Dictionary:
	var streaming_level := int(state.get("facilities", {}).get("Streaming Room", 1))
	var merchandise := roundi((6500 + int(state.get("fans", 0)) / 18) * economy_scale)
	var video := roundi((4200 + streaming_level * 1700 + int(state.get("reputation", 0)) * 55) * economy_scale)
	var streaming := roundi((7800 + streaming_level * 3100) * economy_scale)
	var sponsor := 0
	for offer in state.get("sponsors", []):
		if str(offer.get("id", "")) == str(state.get("active_sponsor_id", "")): sponsor = int(offer.get("weekly_income", 0)); break
	var upkeep := 0
	for facility_level in state.get("facilities", {}).values(): upkeep += int(facility_level) * 850
	var scouting := 1800 + int(state.get("facilities", {}).get("Scouting Department", 1)) * 900
	var travel := 4500 if has_next_match else 0
	var entries: Array = [
		{"label":"Merchandise", "amount":merchandise}, {"label":"Video platforms", "amount":video}, {"label":"Streaming", "amount":streaming},
		{"label":"Player payroll", "amount":-payroll}, {"label":"Facility upkeep", "amount":-upkeep}, {"label":"Scouting operations", "amount":-scouting}
	]
	if sponsor > 0: entries.insert(3, {"label":"Sponsor activation", "amount":sponsor})
	if travel > 0: entries.append({"label":"Competition travel", "amount":-travel})
	return {"income":merchandise + video + streaming + sponsor, "expenses":payroll + upkeep + scouting + travel, "net":merchandise + video + streaming + sponsor - payroll - upkeep - scouting - travel, "entries":entries, "components":{"merchandise":merchandise,"video":video,"streaming":streaming,"sponsor":sponsor,"payroll":payroll,"facility_upkeep":upkeep,"scouting":scouting,"travel":travel}}

static func ledger_reconciliation(entries: Array) -> Dictionary:
	var seen: Dictionary = {}; var total := 0; var errors: Array = []
	for entry in entries:
		var record_id := str(entry.get("id", ""))
		if record_id.is_empty(): errors.append({"error_code":"FINANCE_ID_MISSING", "message":"Ledger record has no ID."})
		elif seen.has(record_id): errors.append({"error_code":"FINANCE_ID_DUPLICATE", "message":"Ledger record ID is duplicated.", "details":{"id":record_id}})
		else: seen[record_id] = true
		total += int(entry.get("amount", 0))
	return {"ok":errors.is_empty(), "recorded_total":total, "errors":errors}
