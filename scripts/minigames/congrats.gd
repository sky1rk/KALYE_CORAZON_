extends Node2D

signal artifact_closed

const CALLE_REAL_SCENE_PATH := "res://scenes/levels/level2_callereal.tscn"
const CONFIRM_HOVER_SCALE := 1.045
const CONFIRM_HOVER_TWEEN_SECONDS := 0.18

@onready var click_area: Area2D = $collect/Area2D
@onready var click_collision_shape: CollisionShape2D = $collect/Area2D/CollisionShape2D
@onready var congrats_sprite: AnimatedSprite2D = $congrats
@onready var confirm_sprite: AnimatedSprite2D = $collect/confirm

var redirecting_to_calle_real := false
var confirm_base_scale := Vector2.ONE
var confirm_hovered := false
var confirm_hover_tween: Tween = null


func _ready() -> void:
	if click_area:
		click_area.input_pickable = true

	if click_area and not click_area.input_event.is_connected(_on_click_area_input_event):
		click_area.input_event.connect(_on_click_area_input_event)

	congrats_sprite.visible = true
	congrats_sprite.play()
	confirm_base_scale = confirm_sprite.scale

	if not congrats_sprite.animation_finished.is_connected(_on_congrats_animation_finished):
		congrats_sprite.animation_finished.connect(_on_congrats_animation_finished)

	confirm_sprite.visible = false
	confirm_sprite.stop()


func _process(_delta: float) -> void:
	if redirecting_to_calle_real or not confirm_sprite.visible:
		_set_confirm_hovered(false)
		return

	_set_confirm_hovered(_is_mouse_inside_confirm_area())


func _exit_tree() -> void:
	if confirm_hovered:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


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
	_set_confirm_hovered(false)
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


func _set_confirm_hovered(should_hover: bool) -> void:
	if confirm_hovered == should_hover:
		return

	confirm_hovered = should_hover
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if confirm_hovered else Input.CURSOR_ARROW)
	_tween_confirm_scale(confirm_base_scale * (CONFIRM_HOVER_SCALE if confirm_hovered else 1.0))


func _tween_confirm_scale(target_scale: Vector2) -> void:
	if confirm_hover_tween and confirm_hover_tween.is_valid():
		confirm_hover_tween.kill()

	confirm_hover_tween = create_tween()
	confirm_hover_tween.tween_property(confirm_sprite, "scale", target_scale, CONFIRM_HOVER_TWEEN_SECONDS)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)


func _on_area_2d_mouse_entered() -> void:
	_set_confirm_hovered(confirm_sprite.visible and not redirecting_to_calle_real)
