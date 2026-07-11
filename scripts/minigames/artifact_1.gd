extends Node2D

signal artifact_closed

@onready var click_area: Area2D = $Area2D


func _ready() -> void:
	if click_area:
		click_area.input_pickable = true

	if click_area and not click_area.input_event.is_connected(_on_click_area_input_event):
		click_area.input_event.connect(_on_click_area_input_event)


func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is not InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	get_viewport().set_input_as_handled()
	artifact_closed.emit()
	queue_free()
