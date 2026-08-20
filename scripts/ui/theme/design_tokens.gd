class_name DesignTokens
extends RefCounted

const COLOR := {
	"background": Color("03070a"),
	"sidebar": Color("060b10"),
	"surface": Color("0a1219"),
	"surface_high": Color("0e1922"),
	"surface_interactive": Color("14232d"),
	"surface_hero": Color("0b1821"),
	"surface_tactical": Color("07161a"),
	"border": Color("29404d"),
	"border_soft": Color("172832"),
	"primary": Color("ff8a00"),
	"information": Color("16d8c1"),
	"positive": Color("35d07f"),
	"warning": Color("ffb52e"),
	"danger": Color("ff4b55"),
	"purple": Color("a78bfa"),
	"text": Color("f0f6f5"),
	"text_secondary": Color("8ea3ad"),
	"disabled": Color("5d6b76")
}

const SPACE := {"xs":4, "sm":8, "md":12, "lg":16, "xl":24, "xxl":32}
const RADIUS := {"sm":3, "md":5, "lg":7}
const TYPE := {"display":42, "page_title":30, "section":17, "body":13, "secondary":11, "metadata":10, "stat":32, "hero_stat":48}

static func color(name: String) -> Color:
	return COLOR.get(name, Color.MAGENTA)

static func style(fill: Color, radius := 5, border := Color.TRANSPARENT, width := 0, padding := 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.corner_radius_top_left = radius; box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius; box.corner_radius_bottom_right = radius
	box.border_color = border
	box.border_width_left = width; box.border_width_top = width
	box.border_width_right = width; box.border_width_bottom = width
	box.content_margin_left = padding; box.content_margin_right = padding
	box.content_margin_top = padding; box.content_margin_bottom = padding
	return box
