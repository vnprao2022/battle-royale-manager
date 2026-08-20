extends Control

var kind := "warning"
var tone := Color("ffb52e")

func _ready() -> void:
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var u := minf(size.x, size.y) / 32.0
	match kind:
		"warning":
			var triangle := PackedVector2Array([c + Vector2(0, -13) * u, c + Vector2(14, 12) * u, c + Vector2(-14, 12) * u])
			draw_polyline(triangle + PackedVector2Array([triangle[0]]), tone, 2.4 * u, true)
			draw_line(c + Vector2(0, -5) * u, c + Vector2(0, 4) * u, tone, 2.5 * u, true)
			draw_circle(c + Vector2(0, 8) * u, 1.6 * u, tone)
		"tactics":
			for radius in [5.0, 10.0]: draw_arc(c, radius * u, 0, TAU, 32, tone, 1.7 * u, true)
			draw_line(c + Vector2(-15, 0) * u, c + Vector2(15, 0) * u, tone, 1.5 * u, true)
			draw_line(c + Vector2(0, -15) * u, c + Vector2(0, 15) * u, tone, 1.5 * u, true)
			draw_circle(c, 2.5 * u, tone)
		"trophy":
			draw_rect(Rect2(c + Vector2(-8, -11) * u, Vector2(16, 13) * u), tone, false, 2.5 * u)
			draw_line(c + Vector2(-8, -8) * u, c + Vector2(-14, -5) * u, tone, 2.2 * u)
			draw_line(c + Vector2(-14, -5) * u, c + Vector2(-10, 2) * u, tone, 2.2 * u)
			draw_line(c + Vector2(8, -8) * u, c + Vector2(14, -5) * u, tone, 2.2 * u)
			draw_line(c + Vector2(14, -5) * u, c + Vector2(10, 2) * u, tone, 2.2 * u)
			draw_line(c + Vector2(0, 2) * u, c + Vector2(0, 9) * u, tone, 2.4 * u)
			draw_line(c + Vector2(-9, 12) * u, c + Vector2(9, 12) * u, tone, 2.8 * u)
		"flame":
			var flame := PackedVector2Array([c + Vector2(0, -14) * u, c + Vector2(7, -5) * u, c + Vector2(5, 1) * u, c + Vector2(11, 6) * u, c + Vector2(5, 14) * u, c + Vector2(-4, 13) * u, c + Vector2(-10, 6) * u, c + Vector2(-6, -2) * u])
			draw_colored_polygon(flame, tone)
		"location":
			draw_arc(c + Vector2(0, -3) * u, 8 * u, PI, TAU, 18, tone, 2.2 * u, true)
			draw_arc(c + Vector2(0, -3) * u, 8 * u, 0, PI, 18, tone, 2.2 * u, true)
			draw_circle(c + Vector2(0, -3) * u, 2.3 * u, tone)
			draw_line(c + Vector2(-5, 4) * u, c + Vector2(0, 14) * u, tone, 2.3 * u)
			draw_line(c + Vector2(5, 4) * u, c + Vector2(0, 14) * u, tone, 2.3 * u)
		"exchange":
			draw_line(c + Vector2(-13, -6) * u, c + Vector2(11, -6) * u, tone, 2.2 * u)
			draw_line(c + Vector2(11, -6) * u, c + Vector2(6, -11) * u, tone, 2.2 * u)
			draw_line(c + Vector2(11, -6) * u, c + Vector2(6, -1) * u, tone, 2.2 * u)
			draw_line(c + Vector2(13, 6) * u, c + Vector2(-11, 6) * u, tone, 2.2 * u)
			draw_line(c + Vector2(-11, 6) * u, c + Vector2(-6, 1) * u, tone, 2.2 * u)
			draw_line(c + Vector2(-11, 6) * u, c + Vector2(-6, 11) * u, tone, 2.2 * u)
		"graph":
			draw_line(c + Vector2(-13, 11) * u, c + Vector2(-5, 3) * u, tone, 2.4 * u)
			draw_line(c + Vector2(-5, 3) * u, c + Vector2(1, 7) * u, tone, 2.4 * u)
			draw_line(c + Vector2(1, 7) * u, c + Vector2(13, -11) * u, tone, 2.4 * u)
			draw_line(c + Vector2(13, -11) * u, c + Vector2(6, -9) * u, tone, 2.4 * u)
			draw_line(c + Vector2(13, -11) * u, c + Vector2(12, -4) * u, tone, 2.4 * u)
