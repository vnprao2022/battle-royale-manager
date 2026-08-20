class_name GamePresenter
extends RefCounted

static func team_overview(data: Dictionary, team_power: float) -> Dictionary:
	var roster: Array = data.get("roster", [])
	return {"power":roundi(team_power), "form":average(roster,"form"), "energy":average(roster,"energy"), "morale":average(roster,"happiness"), "available":roster.filter(func(p): return int(p.get("energy",0))>=50).size(), "roster_size":roster.size()}

static func contract_overview(data: Dictionary) -> Dictionary:
	var roster: Array = data.get("roster", []); var payroll := 0
	for player in roster: payroll += int(player.get("salary",0))
	return {"payroll":payroll, "urgent":roster.filter(func(p): return int(p.get("contract",99))<=6), "watch":roster.filter(func(p): return int(p.get("contract",99))>6 and int(p.get("contract",99))<=12), "safe":roster.filter(func(p): return int(p.get("contract",0))>12)}

static func finance_overview(data: Dictionary) -> Dictionary:
	var contracts := contract_overview(data); var income := 0; var expenses := 0
	for entry in data.get("finance_ledger", []):
		var amount := int(entry.get("amount",0))
		if amount >= 0: income += amount
		else: expenses += absi(amount)
	return {"balance":int(data.get("budget",0)), "payroll":contracts.payroll, "recorded_income":income, "recorded_expenses":expenses, "profit_loss":income-expenses}

static func match_overview(data: Dictionary, event: Dictionary, team_power: float) -> Dictionary:
	return {"available":not event.is_empty(), "tournament":str(event.get("tournament","Unavailable")), "map":str(event.get("map","Unavailable")), "date":str(event.get("date","Unavailable")), "teams":int(event.get("teams",0)), "power":roundi(team_power), "readiness":average(data.get("roster",[]),"energy")}

static func player_overview(player: Dictionary) -> Dictionary:
	return {"id":str(player.get("id","")), "name":str(player.get("name",player.get("display_name","Unknown"))), "handle":str(player.get("handle","player")), "role":str(player.get("role","Flex")), "overall":int(player.get("overall",0)), "form":int(player.get("form",0)), "energy":int(player.get("energy",0)), "morale":int(player.get("morale",player.get("happiness",0))), "contract_months":int(player.get("contract",0)), "salary":int(player.get("salary",0)), "value":int(player.get("value",0))}

static func average(rows: Array, key: String) -> int:
	if rows.is_empty(): return 0
	var total := 0
	for row in rows: total += int(row.get(key,0))
	return roundi(float(total)/rows.size())

