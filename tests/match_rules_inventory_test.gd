extends SceneTree

const MatchRuntimeScript=preload("res://scripts/match_runtime.gd")
var checks:=0
var failures:=0

func _init()->void:
	var runtime=MatchRuntimeScript.new(); runtime.start_match(_game_data(),"verdant_reach",{},24680)
	_check(runtime.WEAPONS.size()==40,"Weapon inventory count changed")
	for category in ["SHOTGUN","SMG","AR","LMG","DMR","SR","PISTOL"]:
		var rule:Dictionary=runtime.WEAPON_RANGE_RULES.get(category,{}); _check(float(rule.get("optimal_m",0))>0 and float(rule.get("max_m",0))>float(rule.get("optimal_m",0)) and float(rule.get("falloff_floor",0))>0,"Missing range rule for "+category)
	_check(is_equal_approx(runtime._weapon_damage_at_distance("M416",180.0),1.0),"AR optimal-range damage changed")
	var midpoint:=runtime._weapon_damage_at_distance("M416",315.0); _check(midpoint<1.0 and midpoint>0.52,"AR falloff interpolation is not active")
	_check(is_equal_approx(runtime._weapon_damage_at_distance("M416",450.0),0.52),"AR maximum-range falloff floor changed")
	_check(runtime.display_ammo_for_weapon("M416",2)==60 and runtime.display_ammo_for_weapon("M24",2)==10,"UI ammo conversion changed internal shot units")
	_check(runtime._can_equip_attachment("M416","Vertical Grip") and not runtime._can_equip_attachment("P92","8x"),"Attachment compatibility rules changed")
	var body:Array=[_target({"vest":"Lv.1","vest_durability":50.0})]; var first:=runtime._apply_damage(body,0,40.0,"WEAPON","Tester","T","M416",false,100.0); _check(int(first.absorbed)==40 and int(body[0].health)==100,"Vest did not act as virtual HP")
	var second:=runtime._apply_damage(body,0,30.0,"WEAPON","Tester","T","M416",false,100.0); _check(int(second.absorbed)==10 and int(body[0].health)==80 and str(body[0].loadout.vest)=="Broken","Vest durability/destruction formula changed")
	var head:Array=[_target({"helmet":"Lv.1","helmet_durability":35.0})]; var head_result:=runtime._apply_damage(head,0,50.0,"WEAPON","Tester","T","M24",true,300.0); _check(int(head_result.absorbed)==35 and int(head[0].health)==85,"Helmet did not absorb head damage as virtual HP")
	runtime._push_kill_feed("Nova","Ghost","M416","ELIMINATED",184.4); _check(int(runtime.kill_feed[0].distance_m)==184 and str(runtime.kill_feed[0].weapon)=="M416","Kill-feed weapon/distance telemetry changed")
	_check(runtime.zone_number==0,"Zone should not exist before reveal")
	runtime.elapsed=80.0; runtime._update_zone_state(); _check(runtime.zone_number==1 and is_equal_approx(runtime.blue_radius,0.78) and runtime.blue_damage==1,"Zone 1 reveal state changed")
	runtime.elapsed=195.0; runtime._update_zone_state(); _check(is_equal_approx(runtime.blue_radius,0.58),"Zone 1 midpoint interpolation changed")
	runtime.elapsed=450.0; runtime._update_zone_state(); _check(runtime.zone_number==3 and runtime.blue_damage==4,"Zone 3 reveal/damage changed")
	runtime.elapsed=900.0; runtime._update_zone_state(); _check(runtime.zone_number==5 and is_equal_approx(runtime.blue_radius,0.0) and runtime.blue_damage==18,"Final zone closure changed")
	var river:Dictionary=runtime.catalog.terrain_profile_at(runtime.map_data,Vector2(0.5,0.5)); _check(str(river.terrain)=="water" and is_equal_approx(float(river.movement_multiplier),0.5),"Normalized river runtime modifier is not connected")
	if failures>0: push_error("MATCH_RULES_INVENTORY_TEST_FAILED checks=%d failures=%d"%[checks,failures]); quit(1)
	else: print("MATCH_RULES_INVENTORY_TEST_OK checks=%d"%checks); quit(0)

func _game_data()->Dictionary:
	return {"active_match_event_id":"rules-test","season":1,"active_match_team_count":2,"roster":[{"id":"1","name":"A","role":"IGL","energy":100},{"id":"2","name":"B","role":"Entry","energy":100},{"id":"3","name":"C","role":"Support","energy":100},{"id":"4","name":"D","role":"Sniper","energy":100}],"teams":[{"name":"Enemy"}]}

func _target(loadout_overrides:Dictionary)->Dictionary:
	var loadout:Dictionary={"helmet":"None","helmet_durability":0.0,"vest":"None","vest_durability":0.0}
	for key in loadout_overrides: loadout[key]=loadout_overrides[key]
	return {"name":"Target","state":"ALIVE","health":100,"health_float":100.0,"dbno":0.0,"loadout":loadout}

func _check(condition:bool,message:String)->void:
	checks+=1
	if not condition: failures+=1; push_error("CHECK FAILED: "+message)
