extends Control

@export var scene1: PackedScene
var scene1_instance: Node = null
@onready var overlay: CanvasLayer = $CanvasLayer
@onready var logo: TextureRect = $CanvasLayer/TextureRect
@onready var start_button: Node2D = $CanvasLayer/start
@onready var start_sprite: Sprite2D = $CanvasLayer/start/Sprite2D
@onready var start_area: Area2D = $CanvasLayer/start/Area2D
var bobble_tween: Tween
var fade_tween: Tween
var start_hover_tween: Tween
var is_fading := false
var start_sprite_base_scale := Vector2.ONE
var start_button_hovered := false

# --- Scene Setup ---
func _ready():
	if scene1:
		scene1_instance = scene1.instantiate()
		add_child(scene1_instance)
		move_child(scene1_instance, 0)  # background at index 0
		_set_scene_player_input_enabled(false)
	overlay.layer = 100  # ensure start screen is always in front
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_sprite_base_scale = start_sprite.scale
	start_area.input_pickable = true
	start_area.collision_layer = 0
	start_area.collision_mask = 0
	start_area.monitoring = false
	start_area.monitorable = false
	if not start_area.input_event.is_connected(_on_start_area_input_event):
		start_area.input_event.connect(_on_start_area_input_event)

	_start_bobble()


# --- Input and Hover ---
func _input(event: InputEvent) -> void:
	if is_fading:
		return
	if event is not InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if not _is_mouse_over_start_button(mouse_event.position):
		return

	get_viewport().set_input_as_handled()
	_handle_start_pressed()

func _process(_delta: float) -> void:
	if is_fading:
		_set_start_button_hovered(false)
		return
	_set_start_button_hovered(_is_mouse_over_start_button(get_viewport().get_mouse_position()))

func _start_bobble():
	if bobble_tween:
		bobble_tween.kill()
	bobble_tween = create_tween()
	if not bobble_tween:
		return
	bobble_tween.set_loops()  # infinite loop

	# Gentle scale up (1.5s)
	bobble_tween.tween_property(logo, "scale", Vector2(1.03, 1.03), 1.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Gentle scale down (1.5s)
	bobble_tween.tween_property(logo, "scale", Vector2.ONE, 1.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_start_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if is_fading:
		return
	if event is not InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	get_viewport().set_input_as_handled()
	_handle_start_pressed()

func _set_start_button_hovered(should_hover: bool) -> void:
	if start_button_hovered == should_hover:
		return

	start_button_hovered = should_hover
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if start_button_hovered else Input.CURSOR_ARROW)
	_tween_start_button_scale(start_sprite_base_scale * (1.035 if start_button_hovered else 1.0))

func _tween_start_button_scale(target_scale: Vector2) -> void:
	if start_hover_tween and start_hover_tween.is_valid():
		start_hover_tween.kill()

	start_hover_tween = create_tween()
	if not start_hover_tween:
		return
	var scale_tweener := start_hover_tween.tween_property(start_sprite, "scale", target_scale, 0.22)
	if scale_tweener:
		scale_tweener.set_trans(Tween.TRANS_SINE)
		scale_tweener.set_ease(Tween.EASE_IN_OUT)

func _is_mouse_over_start_button(mouse_position: Vector2) -> bool:
	if not start_sprite or not start_sprite.texture:
		return false

	var local_position := start_sprite.to_local(mouse_position)
	var half_size := start_sprite.texture.get_size() * 0.5
	return abs(local_position.x) <= half_size.x and abs(local_position.y) <= half_size.y


# --- Start Transition ---
func _start_fade_out():
	is_fading = true
	start_area.input_pickable = false
	if bobble_tween:
		bobble_tween.kill()  # stop bobble
	fade_tween = create_tween()
	if not fade_tween:
		return
	fade_tween.set_parallel(true)
	var logo_fade_tweener := fade_tween.tween_property(logo, "modulate:a", 0.0, 1.5)
	if logo_fade_tweener:
		logo_fade_tweener.set_trans(Tween.TRANS_SINE)
		logo_fade_tweener.set_ease(Tween.EASE_IN_OUT)  # fade over 1.5s
	var button_fade_tweener := fade_tween.tween_property(start_button, "modulate:a", 0.0, 1.5)
	if button_fade_tweener:
		button_fade_tweener.set_trans(Tween.TRANS_SINE)
		button_fade_tweener.set_ease(Tween.EASE_IN_OUT)  # fade over 1.5s
	fade_tween.finished.connect(_on_fade_done)

func _on_fade_done():
	logo.visible = false
	start_button.visible = false
	_set_scene_player_input_enabled(true)
	if scene1_instance and scene1_instance.has_method("start_opening_dialogue"):
		scene1_instance.start_opening_dialogue()

func _handle_start_pressed() -> void:
	_start_fade_out()

func _set_scene_player_input_enabled(enabled: bool) -> void:
	if not scene1_instance:
		return

	var player := scene1_instance.get_node_or_null("0/player")
	if not player:
		player = scene1_instance.get_node_or_null("player")
	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(enabled)
