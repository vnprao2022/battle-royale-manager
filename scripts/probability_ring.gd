extends Control

var value := 0
var accent := Color("ff244c")

func _ready() -> void:
	custom_minimum_size = Vector2(170, 170)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.42
	var base := Color("27313a")
	draw_arc(center, radius, 0.0, TAU, 72, base, 8.0, true)
	draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * clampf(float(value) / 100.0, 0.0, 1.0), 72, accent, 8.0, true)
	draw_circle(center, radius - 9.0, Color("081017"))
	for index in 12:
		var angle := -PI * 0.5 + TAU * float(index) / 12.0
		var inner := center + Vector2.from_angle(angle) * (radius + 7.0)
		var outer := center + Vector2.from_angle(angle) * (radius + 11.0)
		draw_line(inner, outer, Color("59636b", 0.45), 1.0, true)
