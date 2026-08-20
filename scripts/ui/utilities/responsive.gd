class_name ResponsiveUI
extends RefCounted

const COMPACT := 0
const STANDARD := 1
const WIDE := 2
const ULTRAWIDE := 3

static func classify(width: float) -> int:
	if width < 1440.0: return COMPACT
	if width < 1800.0: return STANDARD
	if width < 2400.0: return WIDE
	return ULTRAWIDE

static func is_compact(viewport_size: Vector2) -> bool:
	return classify(viewport_size.x) == COMPACT

static func sidebar_width(viewport_size: Vector2) -> int:
	return 176 if is_compact(viewport_size) else 206

static func page_margin(viewport_size: Vector2) -> int:
	return 14 if is_compact(viewport_size) else 22

static func columns(viewport_size: Vector2, wide := 4, standard := 3, compact := 2) -> int:
	match classify(viewport_size.x):
		COMPACT: return compact
		STANDARD: return standard
		_: return wide

static func content_width(viewport_size: Vector2) -> float:
	return maxf(720.0, viewport_size.x - sidebar_width(viewport_size) - page_margin(viewport_size) * 2.0)
