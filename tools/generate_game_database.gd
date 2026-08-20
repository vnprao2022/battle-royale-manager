extends SceneTree

const ROOT := "res://database"
const DATABASE_SCRIPT := preload("res://scripts/game_database.gd")
const TEAM_DEFS := [
	["mekong_reapers","Mekong Reapers","MR","Asia Pacific","Vietnam","A",22,73,"Rivergate","CENTER"],
	["crimson_owls","Crimson Owls","CO","Europe","Germany","S",4,88,"Central Depot","FAST"],
	["neon_tigers","Neon Tigers","NT","East Asia","Korea","S",7,86,"Ironworks","CENTER"],
	["astra_nine","Astra Nine","AN","Europe","Finland","A",13,81,"West Harbor","EDGE"],
	["iron_pulse","Iron Pulse","IP","Americas","USA","A",18,78,"East Quarry","LATE"],
	["silent_wave","Silent Wave","SW","Asia Pacific","Thailand","A",20,76,"Sunfield","EDGE"],
	["titan_forge","Titan Forge","TF","Europe","Turkey","B",29,70,"Moss Temple","CENTER"],
	["azure_foxes","Azure Foxes","AF","East Asia","Japan","A",16,79,"Cedar Camp","FAST"],
	["quantum_raid","Quantum Raid","QR","Americas","Brazil","B",31,69,"Northwatch","LATE"],
	["solar_vipers","Solar Vipers","SV","Asia Pacific","Indonesia","B",35,67,"Coastal Village","EDGE"],
	["night_lotus","Night Lotus","NL","East Asia","China","S",9,84,"Old Citadel","CENTER"],
	["vertex_guard","Vertex Guard","VG","Europe","United Kingdom","A",24,74,"South Docks","FAST"],
	["ember_crown","Ember Crown","EC","Americas","Canada","B",38,65,"West Harbor","LATE"],
	["polar_ace","Polar Ace","PA","Europe","Norway","A",27,72,"Rivergate","EDGE"],
	["orbit_seven","Orbit Seven","O7","Asia Pacific","Australia","B",41,63,"Sunfield","CENTER"],
	["rift_kings","RIX","RIX","East Asia","Taiwan","A",19,77,"Central Depot","FAST"]
]
const HANDLES := ["Kiro","Lynx","Mika","Jett","Valk","Raze","Nox","Eira","Haneul","Viper","Dawn","Kestrel","Ares","Morrow","Frost","Ivy","Colt","Rook","Nova","Dash","Siam","Mango","Cobra","Lotus","Forge","Rune","Blitz","Sage","Aki","Ren","Yuna","Kaze","Quark","Bolt","Flux","Rift","Sol","Echo","Pyre","Drake","Nyx","Lumen","Cinder","Halo","Vertex","Crow","Mistral","Gale","Ember","Polar","Argo","Vega","Orbit","Comet","Talon","Warden","Rex","Cipher","Khan","Rin","Zero","Pulse","Onyx","Zen"]
const ROLES := ["IGL","Entry","Support","Fragger"]

func _init() -> void:
	for dir in [ROOT,ROOT+"/core",ROOT+"/tournaments",ROOT+"/teams",ROOT+"/players",ROOT+"/rules"]: DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var players: Array=[]; var teams: Array=[]
	for ti in TEAM_DEFS.size():
		var d: Array=TEAM_DEFS[ti]; var roster_ids: Array=[]; var base:=int(d[7])
		for pi in 4:
			var player:=_player(ti,pi,base,str(d[0]),str(d[4]),str(d[5])); players.append(player); roster_ids.append(player.id)
		teams.append(_team(ti,d,roster_ids))
	var tournament:=_tournament(teams)
	_write(ROOT+"/players/players.json",{"schema_version":1,"entity":"players","count":players.size(),"players":players})
	_write(ROOT+"/teams/teams.json",{"schema_version":1,"entity":"teams","count":teams.size(),"teams":teams})
	_write(ROOT+"/tournaments/global_survival_invitational.json",tournament)
	_write(ROOT+"/rules/competitive_rules.json",_rules())
	_write(ROOT+"/core/manifest.json",{"schema_version":1,"database_version":"1.0.0","generated_at":"2026-08-04","collections":{"players":{"path":"res://database/players/players.json","count":64},"teams":{"path":"res://database/teams/teams.json","count":16},"tournaments":{"path":"res://database/tournaments/global_survival_invitational.json","count":1},"rules":{"path":"res://database/rules/competitive_rules.json","count":1}},"active_tournament_id":"gsi_2026_s1"})
	var database = DATABASE_SCRIPT.new()
	var validation_errors: PackedStringArray = database.load_all()
	var career_teams: Array = database.career_opponents()
	if career_teams.size() != 15:
		validation_errors.append("Career adapter must return 15 opponents")
	for career_team in career_teams:
		if not career_team.has("power") or int(career_team.power) <= 0:
			validation_errors.append("Career opponent missing valid power: %s" % career_team.get("database_id", "unknown"))
	if not validation_errors.is_empty():
		for validation_error in validation_errors: push_error(validation_error)
		quit(1)
		return
	print("DATABASE_GENERATED_AND_VALIDATED teams=%d players=%d tournament=%s" % [teams.size(),players.size(),tournament.id]); quit(0)

func _player(ti:int,pi:int,base:int,team_id:String,country:String,tier:String)->Dictionary:
	var index:=ti*4+pi; var overall:=clampi(base+[2,1,-1,0][pi],50,95); var potential:=clampi(overall+3+(index%8),55,99)
	var s:=func(offset:int,spread:=6): return clampi(overall+offset+((index*7+offset*3)%int(spread*2+1))-spread,30,97)
	return {"id":"player_%03d"%(index+1),"handle":HANDLES[index],"display_name":"%s %s"%[HANDLES[index],["Nguyen","Kim","Tan","Park","Smith","Silva","Chen","Sato"][index%8]],"team_id":team_id,"status":"active","tier":tier,"role":ROLES[pi],"secondary_role":["Scout","Flex","Anchor","Entry"][pi],"age":18+(index*3)%11,"nationality":country,"contract":{"months_remaining":12+(index*5)%25,"monthly_salary":5500+overall*140,"market_value":overall*overall*140,"release_clause":overall*overall*220},"ratings":{"overall":overall,"potential":potential,"form":60+(index*7)%31,"energy":72+(index*5)%25,"morale":64+(index*4)%30},"combat":{"aim":s.call(2),"recoil_control":s.call(0),"close_range":s.call(3 if pi==1 else 0),"mid_range":s.call(1),"long_range":s.call(2 if pi==3 else -1),"weapon_swap":s.call(0),"throwable_accuracy":s.call(2 if pi==2 else -1),"utility_timing":s.call(4 if pi==2 else 0),"survival":s.call(1),"clutch":s.call(2)},"awareness":{"vision":s.call(3 if pi==0 else 0),"hearing":s.call(1),"game_sense":s.call(4 if pi==0 else 0),"reaction":s.call(4 if pi==1 else 1),"enemy_tracking":s.call(2),"information_memory":s.call(3 if pi==0 else 0)},"teamplay":{"communication":s.call(5 if pi==0 else 1),"teamwork":s.call(2),"leadership":s.call(7 if pi==0 else -2),"discipline":s.call(2),"composure":s.call(2),"trust":s.call(1),"trade_timing":s.call(3 if pi in [1,3] else 0),"revive_judgement":s.call(4 if pi==2 else 0)},"macro":{"zone_reading":s.call(6 if pi==0 else 0),"rotation":s.call(4 if pi==0 else 1),"pathfinding":s.call(3),"driving":s.call(1),"loot_efficiency":s.call(2),"risk_assessment":s.call(4 if pi==0 else 0),"scouting":s.call(4 if pi==0 else 0)},"physical":{"stamina":s.call(0),"fatigue_resistance":s.call(1),"stress_recovery":s.call(2)},"stealth":{"concealment":s.call(0),"movement_noise":s.call(1),"prone_control":s.call(0),"ambush_timing":s.call(2)},"preferred":{"primary":["M416","Beryl M762","AKM","Mini14"][pi],"secondary":["SLR","UMP45","Mini14","M24"][pi],"scope":["4x","Red Dot","3x","6x"][pi],"drop_role":["caller","first_land","loot_support","overwatch"][pi]},"career":{"matches":40+(index*13)%170,"kills":55+(index*17)%330,"damage":18000+(index*2900)%92000,"knocks":70+(index*19)%360,"assists":20+(index*11)%120,"revives":8+(index*5)%65,"titles":index%4,"earnings":12000+overall*overall*20}}

func _team(ti:int,d:Array,roster_ids:Array)->Dictionary:
	return {"id":d[0],"name":d[1],"tag":d[2],"logo_asset_id":"team.%s.logo"%d[0],"status":"active","tier":d[5],"region":d[3],"country":d[4],"founded_year":2016+ti%9,"roster_ids":roster_ids,"substitute_ids":[],"coach":{"id":"coach_%02d"%(ti+1),"name":"Coach %s"%d[2],"tier":d[5],"tactical":60+int(d[7])/3,"leadership":62+int(d[7])/3,"development":58+(ti*3)%31},"ranking":{"world":d[6],"regional":1+ti%12,"power":d[7],"pgs_points":maxi(0,140-ti*7)},"economy":{"total_earnings":80000+int(d[7])*7500,"monthly_payroll":26000+int(d[7])*500,"sponsor_value":45000+int(d[7])*900},"performance":{"matches":60+ti*7,"wins":2+ti%8,"average_placement":snappedf(5.2+ti*0.28,0.1),"kills_per_match":snappedf(3.1+int(d[7])/25.0,0.1),"consistency":55+int(d[7])/3},"playbook":{"home_drop":d[8],"drop_policy":"ADAPTIVE" if ti%3 else "FIXED_SAFE","zone_macro":d[9],"formation":["TWO_TWO","ONE_THREE","STACK","ANCHOR_THREE"][ti%4],"engagement":["SELECTIVE","THIRD_PARTY","AGGRESSIVE","AVOID"][ti%4],"vehicle_policy":["preserve","vehicle_first","disposable"][ti%3],"airdrop_policy":["opportunistic","ignore","contest"][ti%3]},"map_mastery":{"verdant_reach":55+(ti*5)%40,"sunscorch_basin":58+(ti*7)%38},"achievements":[]}

func _tournament(teams:Array)->Dictionary:
	var ids:Array=[]; for t in teams: ids.append(t.id)
	return {"schema_version":1,"id":"gsi_2026_s1","name":"Global Survival Invitational","short_name":"GSI","tier":"A","status":"scheduled","organizer":"Global Survival Federation","region":"Global","season":1,"year":2026,"team_count":16,"player_count":64,"team_size":4,"team_ids":ids,"format":{"stage":"Grand Final","match_days":3,"matches_per_day":6,"total_matches":18,"maps":["verdant_reach","sunscorch_basin"],"map_rotation":["verdant_reach","sunscorch_basin","verdant_reach","sunscorch_basin","verdant_reach","sunscorch_basin"]},"schedule":{"start_date":"2026-03-20","end_date":"2026-03-22","timezone":"Asia/Bangkok","match_days":[{"day":1,"date":"2026-03-20","matches":6},{"day":2,"date":"2026-03-21","matches":6},{"day":3,"date":"2026-03-22","matches":6}]},"scoring":{"kill_point":1,"placement_points":{"1":10,"2":6,"3":5,"4":4,"5":3,"6":2,"7":1,"8":1,"9":0,"10":0,"11":0,"12":0,"13":0,"14":0,"15":0,"16":0},"tiebreakers":["total_wins","total_kills","last_match_placement","last_match_kills"]},"prize_pool":300000,"currency":"USD","prize_distribution":{"1":120000,"2":60000,"3":36000,"4":24000,"5-8":10000,"9-16":2500},"qualification":{"champion_to":"Global Series Qualifier","pgs_points":true},"rules_id":"pubg_pc_esports_v1","branding":{"logo_asset_id":"tournament.global_survival_circuit.logo","loading_asset_id":"ui.loading.tournament_fallback"}}

func _rules()->Dictionary:
	return {"schema_version":1,"id":"pubg_pc_esports_v1","name":"Battle Royale PC Esports Rules","tiers":{"S+":{"label":"World Championship","rating_min":92},"S":{"label":"Global Series","rating_min":84},"A":{"label":"International / Top Regional","rating_min":74},"B":{"label":"Regional Series","rating_min":64},"C":{"label":"Regional Qualifier","rating_min":54},"D":{"label":"Scrim / Community","rating_min":0}},"match":{"teams":16,"players_per_team":4,"players":64,"maps":["verdant_reach","sunscorch_basin"],"safe_zone_phases":5,"friendly_fire":true},"roster":{"active":4,"substitutes_max":2,"coach_required":true},"stat_range":{"minimum":1,"maximum":99,"development_cap":99}}

func _write(path:String,data:Dictionary)->void:
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(data,"  "))
