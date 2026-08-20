extends SceneTree

const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const SAVE_PATH := "user://codex_interaction_state_audit.json"
const OUTPUT_DIR := "res://tests/output/interactions"

var captures := 0
var controls_tested := 0

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for viewport_size in SIZES:
		await _audit_size(viewport_size)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	print("INTERACTION_STATE_AUDIT_OK sizes=%d captures=%d controls=%d" % [SIZES.size(), captures, controls_tested])
	quit(0)

func _audit_size(viewport_size: Vector2i) -> void:
	DisplayServer.window_set_size(viewport_size)
	root.content_scale_size = viewport_size
	root.size = viewport_size
	await _settle(2)
	var scene = load("res://main.tscn").instantiate()
	scene.game.save_path = SAVE_PATH
	root.add_child(scene)
	await _settle(2)
	scene.game.new_career("Interaction Audit", "State tester", "SEA")
	scene._enter_game()
	await _settle()

	# Commercial and campus actions mutate the real isolated career state.
	scene._show_page("finance")
	await _press(scene, "SIGN PARTNER")
	assert(not str(scene.game.data.get("active_sponsor_id", "")).is_empty(), "Sponsor action did not persist")
	await _capture(viewport_size, "finance_sponsor_active")
	scene._show_page("facilities")
	await _press(scene, "UPGRADE  •")
	assert(not scene.game.data.get("facility_projects", []).is_empty(), "Facility upgrade did not create a project")
	await _capture(viewport_size, "campus_project_active")

	# Media response state and its recorded consequence.
	scene._show_page("media")
	var media_events_before: int = scene.game.data.get("event_history", []).size()
	await _press(scene, "POSITIVE")
	assert(scene.game.data.get("event_history", []).size() == media_events_before + 1, "Media response was not recorded")
	assert(str(scene.game.current_media_story().get("status", "")) == "ANSWERED", "Media story did not enter ANSWERED state")
	assert(_find_button(scene, "POSITIVE") == null, "Answered media story still exposed response controls")
	await _capture(viewport_size, "media_response_recorded")

	# Create real substitutes so loan and promotion can be audited independently.
	scene.game.data.budget = 5000000
	while scene.game.data.roster.size() < 6:
		var signed := false
		for market_index in range(scene.game.data.market.size() - 1, -1, -1):
			if scene.game.sign_player(market_index).begins_with("Signed"):
				signed = true
				break
		assert(signed, "Could not create substitute depth through the transfer system")
	assert(scene.game.data.roster.size() > 5, "Could not create enough substitutes for the state audit")
	scene._show_page("roster")
	await _press(scene, "SUBSTITUTES")
	assert(scene.roster_filter == "SUBSTITUTES", "Roster filter did not change")
	await _capture(viewport_size, "roster_substitutes")
	scene.selected_player = 5
	scene.selected_profile_player.clear()
	scene._show_page("player_detail")
	await _press(scene, "CAREER", true)
	assert(scene.player_profile_tab == "CAREER", "Player profile tab did not change")
	await _capture(viewport_size, "player_career_tab")
	await _press(scene, "LOAN OUT")
	await _press(scene, "CONFIRM LOAN", true)
	assert(scene.game.data.get("loan_records", []).any(func(record): return str(record.get("status", "")) == "ACTIVE"), "Confirmed loan did not create an active lifecycle record")
	await _capture(viewport_size, "loan_active")
	var promoted_id := str(scene.game.data.roster[4].get("id", ""))
	scene.selected_player = 4
	scene.selected_profile_player.clear()
	scene._show_page("player_detail")
	await _settle()
	await _press(scene, "MOVE TO MAIN")
	await _press(scene, "CONFIRM MOVE", true)
	assert(str(scene.game.data.roster[3].get("id", "")) == promoted_id, "Confirmed promotion did not swap the lineup")
	await _capture(viewport_size, "roster_promotion_confirmed")

	# A listed owned player can receive and resolve a real inbound transfer offer.
	var listed_player_id := str(scene.game.data.roster[4].get("id", ""))
	assert(bool(scene.game.set_transfer_listed(listed_player_id, true).get("ok", false)), "Owned player could not be transfer-listed")
	assert(not scene.game.generate_inbound_offers(true).is_empty(), "Inbound transfer interest was not generated")
	assert(scene.game.data.pending_events.any(func(event): return str(event.get("type", "")) == "inbound_transfer_offer" and not bool(event.get("blocks_progression", true))), "Inbound offer was not configured as an asynchronous non-blocking decision")
	scene._show_page("inbox")
	await _settle()
	assert(_find_button(scene, "Reject offer", true) != null, "Inbound offer choices were not rendered in Inbox")
	await _capture(viewport_size, "inbox_inbound_offer")
	await _press(scene, "Reject offer", true)
	assert(scene.game.data.get("inbound_offers", []).any(func(offer): return str(offer.get("player_id", "")) == listed_player_id and str(offer.get("status", "")) == "REJECTED"), "Inbound offer rejection did not persist")

	# External profiles must not expose owned-roster management controls.
	scene._show_page("scouting")
	await _press(scene, "FRAGGER", true)
	assert(scene.scout_filter == "FRAGGER", "Scouting filter did not change")
	await _capture(viewport_size, "scouting_fragger")
	var external_profile: Dictionary = scene.game.data.market[0]
	assert(not external_profile.is_empty(), "No external database profile was available")
	scene.selected_profile_player = external_profile
	scene._show_page("player_detail")
	await _settle()
	assert(_find_button(scene, "REST PLAYER") == null, "External profile exposed roster management")
	assert(_find_button(scene, "BACK TO PLAYER DISCOVERY", true) != null, "External profile scope was not explained")
	assert(_find_button(scene, "MAKE TRANSFER OFFER", true) != null, "Market player did not expose verified recruitment")
	await _capture(viewport_size, "external_player_scope")
	var offers_before: int = scene.game.data.get("transfer_offers", []).size()
	await _press(scene, "MAKE TRANSFER OFFER", true)
	assert(scene.game.data.get("transfer_offers", []).size() == offers_before + 1, "Transfer offer did not create a negotiation")
	assert(scene.active_page == "inbox", "Transfer offer did not route to Inbox")
	await _capture(viewport_size, "inbox_transfer_negotiation")

	# Screen tabs and filters are pressed through their actual controls.
	scene._show_page("training")
	await _press(scene, "RECOVERY")
	assert(str(scene.game.data.schedule) == "Nghỉ & hồi phục", "Training schedule did not change")
	await _capture(viewport_size, "training_recovery")
	scene._show_page("tactics")
	await _press(scene, "AGGRESSIVE EARLY", true)
	assert(str(scene.game.data.coach_plan.engagement) == "AGGRESSIVE", "Tactical preset did not persist")
	await _capture(viewport_size, "tactics_aggressive")
	scene._show_page("calendar")
	await _press(scene, "WEEK", true)
	assert(scene.calendar_view == "WEEK", "Calendar view did not change")
	await _capture(viewport_size, "calendar_week")
	scene._show_page("rankings")
	await _press(scene, "COMPETITION", true)
	assert(scene.ranking_mode == "COMPETITION", "Ranking mode did not change")
	await _capture(viewport_size, "rankings_competition")
	scene._show_page("inbox")
	await _press(scene, "MEDIA", true)
	assert(scene.inbox_channel == "MEDIA", "Inbox channel did not change")
	await _capture(viewport_size, "inbox_media")

	# National appointment and one real call-up.
	scene._show_page("national_team")
	await _press(scene, "ACCEPT NATIONAL ROLE")
	assert(not str(scene.game.data.get("national_team_id", "")).is_empty(), "National appointment failed")
	await _capture(viewport_size, "national_appointed")
	await _press(scene, "CALL UP")
	assert(not scene.game.data.get("national_roster_ids", []).is_empty(), "National call-up failed")
	await _capture(viewport_size, "national_called_up")

	# A completed season creates a real summary moment and single-use continuation.
	scene.game.data.week = 12
	scene.game.advance_week(true)
	scene._build_sidebar()
	scene._show_page("dashboard")
	await _settle()
	assert(_find_button(scene, "BEGIN SEASON 2") != null, "Season transition summary was not rendered on Command Center")
	assert(_find_label(scene, "SEASON 2  •  WEEK 1") != null, "Sidebar retained stale season/week state")
	await _capture(viewport_size, "season_summary")
	await _press(scene, "BEGIN SEASON 2")
	assert(str(scene.game.data.get("season_transition", {}).get("status", "")) == "ACKNOWLEDGED", "Season summary continuation did not persist")

	# A normal career can enter the live observer, but cannot expose developer Lab controls.
	scene.match_runtime.start_match(scene.game.data)
	scene.match_ui_mode = "observer"
	scene._show_page("match_lab")
	await _settle(8)
	assert(_find_button(scene, "OBSERVER", true) != null, "Observer control was not built")
	assert(_find_button(scene, "LAB", true) == null, "Developer Lab leaked into a normal career")
	await _capture(viewport_size, "match_observer_live")

	scene.assets.clear_cache()
	scene.queue_free()
	await _settle(4)

func _press(scene: Node, text_fragment: String, exact := false) -> void:
	var button := _find_button(scene, text_fragment, exact)
	assert(button != null, "Control not found: %s" % text_fragment)
	assert(not button.disabled, "Control unexpectedly disabled: %s" % text_fragment)
	button.pressed.emit()
	controls_tested += 1
	await _settle()

func _find_button(node: Node, text_fragment: String, exact := false) -> Button:
	if node is Button and node.is_visible_in_tree():
		var button := node as Button
		if (button.text == text_fragment if exact else button.text.contains(text_fragment)):
			return button
	for child in node.get_children():
		var found := _find_button(child, text_fragment, exact)
		if found != null: return found
	return null

func _find_label(node: Node, text_fragment: String) -> Label:
	if node is Label and node.is_visible_in_tree() and str(node.text).contains(text_fragment): return node as Label
	for child in node.get_children():
		var found := _find_label(child, text_fragment)
		if found != null: return found
	return null

func _dismiss_popups(node: Node) -> void:
	for child in node.get_children():
		if child is PopupPanel: child.queue_free()
		else: _dismiss_popups(child)

func _capture(viewport_size: Vector2i, state_name: String) -> void:
	await _settle(4)
	if state_name != "media_response_recorded":
		var scene = root.get_child(root.get_child_count() - 1)
		if scene.get("toast") != null: scene.toast.visible = false
		await _settle(2)
	var image := root.get_viewport().get_texture().get_image()
	if image.get_size() != viewport_size:
		image.resize(viewport_size.x, viewport_size.y, Image.INTERPOLATE_LANCZOS)
	var filename := "%dx%d_%s.png" % [viewport_size.x, viewport_size.y, state_name]
	assert(image.save_png(OUTPUT_DIR + "/" + filename) == OK, "Could not save %s" % filename)
	captures += 1

func _settle(frame_count := 4) -> void:
	for frame in frame_count: await process_frame
