extends Node2D

# Tells the office scene when this amphora has been clicked.
signal amphora_clicked(amphora_node: Node2D)

# The clickable area belongs to the amphora scene so each placed amphora can report its own click.
@onready var click_area: Area2D = $Area2D

const HOVER_SCALE_MULTIPLIER := 1.06
const HOVER_TWEEN_DURATION := 0.12

var base_scale: Vector2
var hover_tween: Tween = null


func _ready() -> void:
	base_scale = scale

	# Keep the area ready for mouse input; the office scene decides when it is visible/enabled.
	if click_area and not click_area.input_event.is_connected(_on_click_area_input_event):
		click_area.input_event.connect(_on_click_area_input_event)

	if click_area and not click_area.mouse_entered.is_connected(_on_click_area_mouse_entered):
		click_area.mouse_entered.connect(_on_click_area_mouse_entered)

	if click_area and not click_area.mouse_exited.is_connected(_on_click_area_mouse_exited):
		click_area.mouse_exited.connect(_on_click_area_mouse_exited)


func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# Only the primary mouse button should activate the found amphora.
	if event is not InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	get_viewport().set_input_as_handled()
	amphora_clicked.emit(self)
	_try_notify_level_reward_handler()


func reset_hover_feedback() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_tween_to_scale(base_scale)


func _on_click_area_mouse_entered() -> void:
	if not _is_clickable():
		return

	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	_tween_to_scale(base_scale * HOVER_SCALE_MULTIPLIER)


func _on_click_area_mouse_exited() -> void:
	reset_hover_feedback()


func _is_clickable() -> bool:
	return visible and click_area != null and click_area.input_pickable


func _try_notify_level_reward_handler() -> void:
	var current_node := get_parent()
	while current_node:
		if current_node.has_method("handle_level1_amphora_clicked"):
			current_node.handle_level1_amphora_clicked(self)
			return
		current_node = current_node.get_parent()


func _tween_to_scale(target_scale: Vector2) -> void:
	if hover_tween and hover_tween.is_valid():
		hover_tween.kill()

	hover_tween = create_tween()
	hover_tween.set_trans(Tween.TRANS_SINE)
	hover_tween.set_ease(Tween.EASE_OUT)
	hover_tween.tween_property(self, "scale", target_scale, HOVER_TWEEN_DURATION)
