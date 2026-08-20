class_name ScreenView
extends VBoxContainer

var route_params: Dictionary = {}
var app_context: Dictionary = {}

func setup(context: Dictionary, params := {}) -> void:
	app_context = context
	route_params = params.duplicate(true)
	build()

func build() -> void:
	pass

func refresh_view() -> void:
	for child in get_children(): child.queue_free()
	build()

