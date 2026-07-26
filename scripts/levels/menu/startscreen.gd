extends Control

@export var scene1: PackedScene
var scene1_instance: Node = null
@onready var logo = $CanvasLayer/TextureRect
var bobble_tween: Tween
var fade_tween: Tween
var is_fading := false

func _ready():
	if scene1:
		scene1_instance = scene1.instantiate()
		add_child(scene1_instance)
		move_child(scene1_instance, 0)  # background at index 0
	$CanvasLayer.layer = 100  # ensure logo is always in front

	_start_bobble()

func _process(delta):
	if not is_fading and (Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right")):
		_start_fade_out()

func _start_bobble():
	if bobble_tween:
		bobble_tween.kill()
	bobble_tween = create_tween().set_loops()  # infinite loop

	# Gentle scale up (1.5s)
	bobble_tween.tween_property(logo, "scale", Vector2(1.03, 1.03), 1.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Gentle scale down (1.5s)
	bobble_tween.tween_property(logo, "scale", Vector2.ONE, 1.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _start_fade_out():
	is_fading = true
	if bobble_tween:
		bobble_tween.kill()  # stop bobble
	fade_tween = create_tween()
	fade_tween.tween_property(logo, "modulate:a", 0.0, 1.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)  # fade over 1.5s
	fade_tween.finished.connect(_on_fade_done)

func _on_fade_done():
	logo.visible = false
	if scene1_instance and scene1_instance.has_method("start_opening_dialogue"):
		scene1_instance.start_opening_dialogue()
