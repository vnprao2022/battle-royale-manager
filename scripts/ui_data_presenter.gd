class_name UIDataPresenter
extends RefCounted

# Shared presentation rules for the programmatic Godot UI.  Screen builders pass
# the project's own constructors/styles in, so this layer does not duplicate data
# or hold gameplay state.

static func rating_color(value: int, success: Color, warning: Color, danger: Color) -> Color:
	return success if value >= 70 else warning if value >= 45 else danger

static func status_word(value: int, good: String, watch: String, risk: String) -> String:
	return good if value >= 70 else watch if value >= 45 else risk

static func contract_state(months: int) -> String:
	return "URGENT" if months <= 6 else "WATCH" if months <= 12 else "SAFE"

static func metric_delta(current: int, benchmark: int) -> String:
	var delta := current - benchmark
	return "+%d" % delta if delta >= 0 else str(delta)
