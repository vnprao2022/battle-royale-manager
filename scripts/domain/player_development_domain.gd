class_name PlayerDevelopmentDomain
extends RefCounted

static func growth_chance(player: Dictionary, state: Dictionary, base_chance: float, facility_level: int, coach_bonus: float, difficulty_bonus: float) -> Dictionary:
	var age := int(player.get("age", 22)); var potential_gap := maxi(0, int(player.get("potential", 60)) - int(player.get("overall", 60)))
	var age_modifier := 0.08 if age <= 19 else 0.05 if age <= 22 else 0.01 if age <= 26 else -0.03 if age <= 29 else -0.07
	var potential_modifier := minf(0.10, potential_gap * 0.005)
	var morale := int(player.get("morale", player.get("happiness", 60)))
	var morale_modifier := clampf((morale - 60) / 500.0, -0.05, 0.07)
	var opportunity_modifier := 0.025 if str(player.get("squad_role", "substitute")) == "starter" else -0.025
	var form_modifier := 0.035 if int(player.get("form", 60)) >= 75 else -0.035 if int(player.get("form", 60)) < 45 else 0.0
	var player_trait := str(player.get("trait", "")); var personality_modifier := 0.02 if player_trait in ["Professional", "Tactical"] else 0.01 if player_trait in ["Ambitious", "Big Game Player"] else 0.0
	var development_dna := int(state.get("organization_dna", {}).get("development", 50)); var identity_modifier := clampf((development_dna - 50) / 1000.0, -0.03, 0.03)
	var total := clampf(base_chance + facility_level * 0.04 + coach_bonus + difficulty_bonus + age_modifier + potential_modifier + morale_modifier + opportunity_modifier + form_modifier + personality_modifier + identity_modifier, 0.03, 0.90)
	return {"chance":total, "age":age_modifier, "potential":potential_modifier, "morale":morale_modifier, "opportunity":opportunity_modifier, "form":form_modifier, "personality":personality_modifier, "organization":identity_modifier}

static func energy_change(player: Dictionary, schedule: String, recovery_level: int) -> int:
	var fatigue_resistance := int(player.get("fatigue_resistance", 60))
	return 7 + recovery_level * 2 if schedule == "Nghỉ & hồi phục" else (-8 + fatigue_resistance / 25 if schedule == "Cường độ cao" else 1 + recovery_level)

static func apply_week(player: Dictionary, state: Dictionary, context: Dictionary) -> Dictionary:
	var before := {"overall":int(player.get("overall", 0)), "energy":int(player.get("energy", 0)), "form":int(player.get("form", 0)), "morale":int(player.get("morale", player.get("happiness", 0)))}
	var schedule := str(state.get("schedule", "Cân bằng")); var recovery_level := int(context.get("recovery_level", 1)); var mental_bonus := int(context.get("mental_bonus", 0))
	player.energy = clampi(int(player.get("energy", 0)) + energy_change(player, schedule, recovery_level) + randi_range(-1, 1), 15, 100)
	var profile := growth_chance(player, state, 0.34 if schedule == "Cường độ cao" else 0.16, int(context.get("training_level", 1)), float(context.get("head_coach_bonus", 0.0)), float(context.get("difficulty_bonus", 0.0)))
	var grew := false; var growth_stat := ""
	if randf() < float(profile.chance) and int(player.get("overall", 0)) < int(player.get("potential", 0)) and int(player.energy) > 40:
		growth_stat = str(context.get("focus_stat", "game_sense")); player[growth_stat] = clampi(int(player.get(growth_stat, player.overall)) + 1, 1, int(player.potential))
		var core_average := (int(player.aim) + int(player.game_sense) + int(player.teamwork) + int(player.clutch)) / 4
		player.overall = mini(int(player.potential), maxi(int(player.overall), roundi(core_average * 0.65 + int(player.overall) * 0.35))); grew = true
	player.form = clampi(int(player.form) + (2 if schedule == "Cường độ cao" and int(player.energy) > 55 else -1 if int(player.energy) < 35 else 0), 25, 99)
	var individual_focus := str(state.get("individual_training", {}).get(str(player.get("id", "")), ""))
	if not individual_focus.is_empty():
		var focus_stat: String = str({"Aim":"aim","Strategy":"game_sense","Mental":"clutch","Recovery":"energy","Teamwork":"teamwork"}.get(individual_focus,"aim"))
		player[focus_stat] = clampi(int(player.get(focus_stat, 50)) + 1, 1, 99); player.energy = clampi(int(player.energy) - (2 if individual_focus != "Recovery" else -mental_bonus), 15, 100)
	player.happiness = clampi(int(player.get("happiness", 60)) + roundi(float(mental_bonus) / 3.0), 0, 100)
	player.morale = clampi(roundi((int(player.get("morale", player.happiness)) * 2 + int(player.happiness)) / 3.0), 0, 100)
	return {"player_id":str(player.get("id", "")), "before":before, "after":{"overall":int(player.overall), "energy":int(player.energy), "form":int(player.form), "morale":int(player.morale)}, "grew":grew, "growth_stat":growth_stat, "growth_profile":profile}
