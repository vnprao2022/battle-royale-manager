class_name SaveMigrations
extends RefCounted

static func migrate(source: Dictionary, current_version: int) -> Dictionary:
	var migrated := source.duplicate(true)
	var from_version := maxi(1, int(migrated.get("save_version", 1)))
	if from_version > current_version:
		return {"ok":false, "error_code":"SAVE_VERSION_UNSUPPORTED", "message":"Save was created by a newer game version.", "data":{}}
	var version := from_version
	while version < current_version:
		match version:
			9: _v9_to_v10(migrated)
			10: _v10_to_v11(migrated)
		version += 1
		migrated.save_version = version
	return {"ok":true, "from_version":from_version, "to_version":current_version, "data":migrated}

static func _v9_to_v10(state: Dictionary) -> void:
	if not state.has("season_start_budget"): state.season_start_budget = int(state.get("budget", 0))
	if not state.has("next_record_sequence"): state.next_record_sequence = state.get("inbox", []).size() + state.get("finance_ledger", []).size() + state.get("progression_log", []).size() + 1
	for event in state.get("pending_events", []):
		if str(event.get("type", "")) == "inbound_transfer_offer": event.blocks_progression = false

static func _v10_to_v11(state: Dictionary) -> void:
	if not state.has("domain_audit_log"): state.domain_audit_log = []
	if not state.has("season_start_days_elapsed"): state.season_start_days_elapsed = maxi(0, int(state.get("days_elapsed", 0)) - maxi(0, int(state.get("week", 1)) - 1) * 7)
	for event in state.get("pending_events", []): _normalize_event(event, "PENDING", state)
	for event in state.get("event_history", []):
		var terminal := "EXPIRED" if str(event.get("status", "")).to_lower() == "expired" else "CANCELLED" if str(event.get("status", "")).to_lower() == "cancelled" else "RESOLVED"
		_normalize_event(event, terminal, state)

static func _normalize_event(event: Dictionary, lifecycle: String, state: Dictionary) -> void:
	event.lifecycle_status = str(event.get("lifecycle_status", lifecycle)).to_upper()
	if not event.has("type"): event.type = "legacy_event"
	if not event.has("context"): event.context = {}
	if not event.has("created_date"): event.created_date = str(state.get("current_date", ""))
	if event.lifecycle_status != "PENDING" and not event.has("resolved_date"): event.resolved_date = str(state.get("current_date", ""))
