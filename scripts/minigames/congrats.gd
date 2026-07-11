extends Node2D

signal artifact_closed

const CALLE_REAL_SCENE_PATH := "res://scenes/levels/level2_callereal.tscn"

@onready var click_area: Area2D = $collect/Area2D
@onready var click_collision_shape: CollisionShape2D = $collect/Area2D/CollisionShape2D
@onready var congrats_sprite: AnimatedSprite2D = $congrats
@onready var confirm_sprite: AnimatedSprite2D = $collect/confirm

var redirecting_to_calle_real := false


func _ready() -> void:
	if click_area:
		click_area.input_pickable = true

	if click_area and not click_area.input_event.is_connected(_on_click_area_input_event):
		click_area.input_event.connect(_on_click_area_input_event)

	congrats_sprite.visible = true
	congrats_sprite.play()

	if not congrats_sprite.animation_finished.is_connected(_on_congrats_animation_finished):
		congrats_sprite.animation_finished.connect(_on_congrats_animation_finished)

	confirm_sprite.visible = false
	confirm_sprite.stop()


func _input(event: InputEvent) -> void:
	if event is not InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	if not confirm_sprite.visible:
		return

	if _is_mouse_inside_confirm_area():
		_activate_confirm()


func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is not InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	if not confirm_sprite.visible:
		return

	_activate_confirm()


func _activate_confirm() -> void:
	if redirecting_to_calle_real:
		return

	redirecting_to_calle_real = true
	get_viewport().set_input_as_handled()
	GameState.level1_cultural_echo_active = false
	GameState.stop_cultural_echo_bgm()
	artifact_closed.emit()
	get_tree().change_scene_to_file(CALLE_REAL_SCENE_PATH)


func _is_mouse_inside_confirm_area() -> bool:
	if not click_area or not click_collision_shape:
		return false

	var rectangle_shape := click_collision_shape.shape as RectangleShape2D
	if not rectangle_shape:
		return false

	var local_mouse_position := click_area.to_local(get_global_mouse_position()) - click_collision_shape.position
	var half_size := rectangle_shape.size * 0.5
	return abs(local_mouse_position.x) <= half_size.x and abs(local_mouse_position.y) <= half_size.y


func _on_congrats_animation_finished() -> void:
	confirm_sprite.visible = true
	confirm_sprite.play()


func _on_area_2d_mouse_entered() -> void:
	pass # Replace with function body.
