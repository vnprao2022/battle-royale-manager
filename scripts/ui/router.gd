class_name UIRouter
extends RefCounted

signal route_changed(route: Dictionary)

const ALIASES := {"transfer":"scouting", "meta_report":"analytics", "facility_detail":"facilities"}
const ROUTES := {
	"dashboard":{"title":"COMMAND CENTER","group":"COMMAND","breadcrumb":"Organization / Command Center"},
	"roster":{"title":"SQUAD & LINEUP","group":"TEAM","breadcrumb":"Team / Squad & Lineup"},
	"player_detail":{"title":"PLAYER PROFILE","group":"TEAM","breadcrumb":"Team / Player Profile"},
	"contracts":{"title":"PLAYER CONTRACTS","group":"TEAM","breadcrumb":"Team / Contracts"},
	"training":{"title":"TRAINING CENTER","group":"TEAM","breadcrumb":"Team / Training"},
	"tactics":{"title":"TACTICS ROOM","group":"TEAM","breadcrumb":"Team / Tactics"},
	"scouting":{"title":"PLAYER DISCOVERY","group":"PLAYERS & SCOUTING","breadcrumb":"Players & Scouting / Discovery"},
	"transfers":{"title":"TRANSFER CENTER","group":"PLAYERS & SCOUTING","breadcrumb":"Players & Scouting / Transfers"},
	"analytics":{"title":"TEAM ANALYSIS","group":"PLAYERS & SCOUTING","breadcrumb":"Team / Analysis"},
	"player_stats":{"title":"PLAYER PERFORMANCE","group":"PLAYERS & SCOUTING","breadcrumb":"Team / Player Performance"},
	"match":{"title":"MATCH CENTER","group":"MATCHES & EVENTS","breadcrumb":"Matches & Events / Match Center"},
	"match_lab":{"title":"MATCH OBSERVER","group":"MATCHES & EVENTS","breadcrumb":"Matches & Events / Live Observer"},
	"map_manager":{"title":"MAP MANAGER","group":"SYSTEM","breadcrumb":"Sandbox / Map Manager"},
	"calendar":{"title":"SCHEDULE","group":"MATCHES & EVENTS","breadcrumb":"Matches & Events / Schedule"},
	"tournament":{"title":"TOURNAMENTS","group":"MATCHES & EVENTS","breadcrumb":"Matches & Events / Tournaments"},
	"competition_detail":{"title":"TOURNAMENT DETAIL","group":"MATCHES & EVENTS","breadcrumb":"Tournaments / Detail"},
	"rankings":{"title":"WORLD RANKING","group":"MATCHES & EVENTS","breadcrumb":"Matches & Events / World Ranking"},
	"team_profile":{"title":"TEAM PROFILE","group":"MATCHES & EVENTS","breadcrumb":"World / Team Profile"},
	"facilities":{"title":"PERFORMANCE CAMPUS","group":"ORGANIZATION","breadcrumb":"Organization / Performance Campus"},
	"finance":{"title":"FINANCE & PARTNERS","group":"ORGANIZATION","breadcrumb":"Organization / Finance & Partners"},
	"national_team":{"title":"NATIONAL TEAM","group":"ORGANIZATION","breadcrumb":"Organization / National Team"},
	"trophies":{"title":"CAREER HISTORY","group":"CAREER","breadcrumb":"Career / History"},
	"inbox":{"title":"INBOX","group":"SYSTEM","breadcrumb":"System / Inbox"},
	"media":{"title":"WORLD FEED","group":"SYSTEM","breadcrumb":"System / World Feed"},
	"settings":{"title":"SETTINGS & PROFILE","group":"SYSTEM","breadcrumb":"System / Settings & Profile"},
	"developer":{"title":"DEVELOPER MODE","group":"SYSTEM","breadcrumb":"Sandbox / Developer Mode"}
}

var current_id := "dashboard"
var current_params: Dictionary = {}
var history: Array[Dictionary] = []

func resolve(route_id: String) -> String:
	return str(ALIASES.get(route_id, route_id))

func navigate(route_id: String, params := {}) -> Dictionary:
	var resolved := resolve(route_id)
	if not ROUTES.has(resolved): resolved = "dashboard"
	if current_id != resolved or current_params != params:
		history.append({"id":current_id,"params":current_params.duplicate(true)})
	current_id = resolved; current_params = params.duplicate(true)
	var route := descriptor(resolved); route["params"] = current_params
	route_changed.emit(route)
	return route

func descriptor(route_id := current_id) -> Dictionary:
	var resolved := resolve(route_id)
	var result: Dictionary = ROUTES.get(resolved, ROUTES.dashboard).duplicate(true)
	result["id"] = resolved
	return result

func go_back() -> Dictionary:
	if history.is_empty(): return navigate("dashboard")
	var previous: Dictionary = history.pop_back()
	current_id = str(previous.id); current_params = previous.params
	var route := descriptor(); route["params"] = current_params; route_changed.emit(route)
	return route
