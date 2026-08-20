extends Control

func _ready() -> void:
	custom_minimum_size = Vector2(58, 58)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var gold := Color("efb94a")
	var deep_gold := Color("9d681c")
	var c := size * 0.5
	var scale := minf(size.x, size.y) / 58.0
	var cup := PackedVector2Array([c + Vector2(-12, -16) * scale, c + Vector2(12, -16) * scale, c + Vector2(8, 2) * scale, c + Vector2(3, 8) * scale, c + Vector2(3, 14) * scale, c + Vector2(11, 18) * scale, c + Vector2(-11, 18) * scale, c + Vector2(-3, 14) * scale, c + Vector2(-3, 8) * scale, c + Vector2(-8, 2) * scale])
	draw_colored_polygon(cup, gold)
	draw_line(c + Vector2(-12, -13) * scale, c + Vector2(-22, -8) * scale, gold, 3.0 * scale)
	draw_line(c + Vector2(-22, -8) * scale, c + Vector2(-17, 2) * scale, gold, 3.0 * scale)
	draw_line(c + Vector2(12, -13) * scale, c + Vector2(22, -8) * scale, gold, 3.0 * scale)
	draw_line(c + Vector2(22, -8) * scale, c + Vector2(17, 2) * scale, gold, 3.0 * scale)
	draw_line(c + Vector2(-13, 22) * scale, c + Vector2(13, 22) * scale, deep_gold, 3.0 * scale)
	for side in [-1.0, 1.0]:
		for index in 3:
			var origin := c + Vector2(side * (18 + index * 4), 3 - index * 8) * scale
			draw_circle(origin, 2.0 * scale, gold)
