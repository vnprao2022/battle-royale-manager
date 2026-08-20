class_name UICard
extends VBoxContainer

var card_style: StyleBox

func set_card_style(value: StyleBox) -> void:
	card_style = value
	queue_redraw()

func _draw() -> void:
	if card_style:
		draw_style_box(card_style, Rect2(Vector2.ZERO, size))
