# TransitionZone.gd
extends Area2D

# --- Inspector Settings ---
@export var target_position: Vector2 = Vector2.ZERO # Where the player will teleport/spawn.
@export var required_action: String = "ui_accept" # The input action to trigger the transition.
@export_file("*.tscn") var target_scene_path: String = ""

# --- Signals ---
signal player_entered_zone(transition_data: Dictionary)
signal player_exited_zone


# --- Zone Events ---
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		var transition_data = {
			"target_position": target_position,
			"action": required_action,
			"exit_direction": 1 if body.global_position.x < global_position.x else -1,
			"target_scene": target_scene_path
		}

		player_entered_zone.emit(transition_data)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_exited_zone.emit()
