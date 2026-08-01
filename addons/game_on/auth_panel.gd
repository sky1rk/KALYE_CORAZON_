class_name AuthPanel
extends Control

signal authorized
signal dismissed

@export var scene1: PackedScene

@onready var _connect_button_node: Node2D = $CanvasLayer/ConnectButton
@onready var _logo: TextureRect = $CanvasLayer/TextureRect
@onready var _connect_sprite: Sprite2D = $CanvasLayer/ConnectButton/Sprite2D
@onready var _connect_area: Area2D = $CanvasLayer/ConnectButton/Area2D
@onready var _connect_button_fallback: Button = get_node_or_null("ConnectButton2") as Button

var close_as_overlay := false
var scene1_instance: Node = null
var _leaving_auth_panel := false
var _connect_enabled := true
var _logo_base_scale := Vector2.ONE
var _connect_sprite_base_scale := Vector2.ONE
var _connect_hovered := false
var _breathing_tween: Tween
var _connect_hover_tween: Tween


func _ready() -> void:
	if scene1:
		scene1_instance = scene1.instantiate()
		add_child(scene1_instance)
		move_child(scene1_instance, 0)
		_set_scene_player_input_enabled(false)

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_base_scale = _logo.scale
	_logo.pivot_offset = _logo.size * 0.5
	_connect_sprite_base_scale = _connect_sprite.scale
	_connect_area.input_pickable = true
	_connect_area.input_event.connect(_on_connect_area_input_event)

	if _connect_button_fallback:
		_connect_button_fallback.visible = false
		_connect_button_fallback.pressed.connect(_on_connect_pressed)

	var game_on_connect := get_node(^"/root/GameOnPortal") as GameOnConnect
	if not game_on_connect.authorization_status_changed.is_connected(_on_authorization_status_changed):
		game_on_connect.authorization_status_changed.connect(_on_authorization_status_changed)

	if game_on_connect.is_authorized:
		_update_ui_for_status("authorized")
		call_deferred("_leave_auth_panel")
	else:
		_update_ui_for_status("idle")

	_start_breathing_effect()


func _input(event: InputEvent) -> void:
	if _leaving_auth_panel:
		return
	if not _is_left_click_pressed(event):
		return

	var mouse_event := event as InputEventMouseButton
	if _connect_enabled and _is_mouse_over_sprite(_connect_sprite, mouse_event.position):
		get_viewport().set_input_as_handled()
		_on_connect_pressed()


func _process(_delta: float) -> void:
	if _leaving_auth_panel:
		_set_button_hovered("connect", false)
		return

	var mouse_position := get_viewport().get_mouse_position()
	_set_button_hovered("connect", _connect_enabled and _is_mouse_over_sprite(_connect_sprite, mouse_position))


func _on_connect_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not _is_left_click_pressed(event) or not _connect_enabled:
		return

	get_viewport().set_input_as_handled()
	_on_connect_pressed()


func _is_left_click_pressed(event: InputEvent) -> bool:
	if event is not InputEventMouseButton:
		return false

	var mouse_event := event as InputEventMouseButton
	return mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed


func _is_mouse_over_sprite(sprite: Sprite2D, mouse_position: Vector2) -> bool:
	if not sprite or not sprite.visible or not sprite.texture:
		return false

	var local_position := sprite.to_local(mouse_position)
	var half_size := sprite.texture.get_size() * 0.5
	return abs(local_position.x) <= half_size.x and abs(local_position.y) <= half_size.y


func _set_button_hovered(button_name: String, should_hover: bool) -> void:
	match button_name:
		"connect":
			if _connect_hovered == should_hover:
				return

			_connect_hovered = should_hover
			_tween_button_scale(_connect_sprite, _connect_sprite_base_scale * (1.035 if should_hover else 1.0), true)

	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if _connect_hovered else Input.CURSOR_ARROW)


func _start_breathing_effect() -> void:
	if _breathing_tween:
		_breathing_tween.kill()

	_breathing_tween = create_tween().set_loops()
	_breathing_tween.tween_property(_logo, "scale", _logo_base_scale * 1.03, 1.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	_breathing_tween.tween_property(_logo, "scale", _logo_base_scale, 1.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)


func _tween_button_scale(sprite: Sprite2D, target_scale: Vector2, _is_connect_button: bool) -> void:
	if _connect_hover_tween and _connect_hover_tween.is_valid():
		_connect_hover_tween.kill()

	_connect_hover_tween = create_tween()
	_connect_hover_tween.tween_property(sprite, "scale", target_scale, 0.22)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)


func _on_connect_pressed() -> void:
	if not _connect_enabled:
		return

	_set_connect_enabled(false)
	get_node(^"/root/GameOnPortal").connect_account()


func _on_authorization_status_changed(status: String) -> void:
	_update_ui_for_status(status)
	if status == "authorized":
		authorized.emit()
		await get_tree().create_timer(1.5).timeout
		_leave_auth_panel()


func _update_ui_for_status(status: String) -> void:
	match status:
		"idle":
			_set_connect_enabled(true)
		"connecting":
			_set_connect_enabled(false)
		"pending":
			_set_connect_enabled(false)
		"authorized":
			_set_connect_enabled(false)
			_connect_button_node.visible = false
			if _connect_button_fallback:
				_connect_button_fallback.visible = false
		"expired":
			_set_connect_enabled(true)
		"error":
			_set_connect_enabled(true)


func _set_connect_enabled(enabled: bool) -> void:
	_connect_enabled = enabled
	_connect_area.input_pickable = enabled
	if not enabled:
		_set_button_hovered("connect", false)
	if _connect_button_fallback:
		_connect_button_fallback.disabled = not enabled


func _leave_auth_panel() -> void:
	if _leaving_auth_panel:
		return

	_leaving_auth_panel = true
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if _breathing_tween:
		_breathing_tween.kill()
	if close_as_overlay:
		dismissed.emit()
		queue_free()
		return

	get_tree().change_scene_to_file("res://scenes/levels/startscreen.tscn")


func _set_scene_player_input_enabled(enabled: bool) -> void:
	if not scene1_instance:
		return

	var player := scene1_instance.get_node_or_null("0/player")
	if not player:
		player = scene1_instance.get_node_or_null("player")
	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(enabled)
