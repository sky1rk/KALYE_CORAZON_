extends Area2D


func _ready() -> void:
	input_pickable = false
	collision_mask = 2
	monitoring = true
	monitorable = true

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	var office_scene := get_owner()
	if not office_scene or not office_scene.has_method("start_office_exit_choice_dialogue_from_trigger"):
		return

	office_scene.start_office_exit_choice_dialogue_from_trigger(body)
