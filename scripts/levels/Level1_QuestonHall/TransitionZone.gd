# TransitionZone.gd (FINAL, CORRECTED VERSION for scene transitions)
extends Area2D

# We will set these values in the Godot Editor for each transition zone.
@export var target_position: Vector2 = Vector2.ZERO # Where the player will teleport/spawn.
@export var required_action: String = "ui_accept" # The input action to trigger the transition.

# --- NEW: This variable defines the target scene path ---
# If this is left empty, the TransitionZone will perform a local teleport.
# If this is set to a scene path, the TransitionZone will trigger a scene change.
@export_file("*.tscn") var target_scene_path: String = ""

# This signal will be sent to the player when they enter the zone.
signal player_entered_zone(transition_data: Dictionary)
# This signal is sent when the player leaves.
signal player_exited_zone


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		var transition_data = {
			"target_position": target_position,
			"action": required_action,
			"exit_direction": 1 if body.global_position.x < global_position.x else -1,
			# --- CRITICAL FIX: Include the target_scene_path in the data ---
			"target_scene": target_scene_path # This is what caleb_controller reads!
		}
		
		# --- DEBUG PRINT (Temporary - you can remove this after confirming it works) ---
		print("DEBUG TransitionZone: Player entered. Data: ", transition_data)
		
		player_entered_zone.emit(transition_data)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_exited_zone.emit()
