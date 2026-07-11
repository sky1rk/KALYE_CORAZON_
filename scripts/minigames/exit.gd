extends Node2D

@onready var exit_area: Area2D = $Area2D


func _ready() -> void:
	if not exit_area:
		return

	exit_area.input_pickable = false
	exit_area.collision_mask = 2
	exit_area.monitoring = true
	exit_area.monitorable = true

	if not exit_area.body_entered.is_connected(_on_exit_area_body_entered):
		exit_area.body_entered.connect(_on_exit_area_body_entered)


func _on_exit_area_body_entered(body: Node2D) -> void:
	var office_scene := get_owner()
	if not office_scene or not office_scene.has_method("start_office_exit_choice_dialogue_from_trigger"):
		return

	office_scene.start_office_exit_choice_dialogue_from_trigger(body)
