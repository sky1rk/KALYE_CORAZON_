# dialogue_trigger.gd
extends Area2D

# --- Entry Direction ---
enum EntryDirection {
	ANY,    # Trigger regardless of entry direction
	LEFT,   # Trigger only if entering from the left side (moving right)
	RIGHT   # Trigger only if entering from the right side (moving left)
}

# --- Inspector Settings ---
@export var dialogue_resource: DialogueResource
@export var dialogue_title: String = ""
@export var unique_trigger_id: String = ""
@export var trigger_once: bool = true
@export var freeze_player: bool = true
@export var required_entry_direction: EntryDirection = EntryDirection.ANY

# --- Node References ---
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


# --- Scene Setup ---
func _ready():
	if trigger_once and unique_trigger_id.is_empty():
		unique_trigger_id = get_path()

	if trigger_once and GameState.is_dialogue_triggered(unique_trigger_id):
		print("DialogueTrigger '", unique_trigger_id, "' already triggered, disabling.")
		collision_shape.set_deferred("disabled", true)
		monitoring = false
	else:
		monitoring = true

	body_entered.connect(_on_body_entered)


# --- Trigger Handling ---
func _on_body_entered(body: Node2D):
	if not body.is_in_group("Player"):
		return

	if trigger_once and GameState.is_dialogue_triggered(unique_trigger_id):
		return

	var player_node = body as CharacterBody2D
	if not player_node or not player_node.has_method("get_velocity"):
		print("Warning: DialogueTrigger entered by non-CharacterBody2D or a CharacterBody2D without 'get_velocity'. Cannot check entry direction.")
		return


	if required_entry_direction != EntryDirection.ANY:
		var player_velocity_x = player_node.get_velocity().x
		var actual_entry_direction: EntryDirection

		if player_velocity_x > 0.1:
			actual_entry_direction = EntryDirection.LEFT
		elif player_velocity_x < -0.1:
			actual_entry_direction = EntryDirection.RIGHT
		else:
			actual_entry_direction = EntryDirection.ANY

		if required_entry_direction != actual_entry_direction:
			return


	if freeze_player and player_node and player_node.has_method("set_input_enabled"):
		player_node.set_input_enabled(false)

	var level_script = get_owner()
	if level_script and level_script.has_method("start_dialogue_balloon_from_trigger"):
		level_script.start_dialogue_balloon_from_trigger(dialogue_resource, dialogue_title)

		DialogueManager.dialogue_ended.connect(_on_dialogue_ended_from_this_trigger.bind(player_node), CONNECT_ONE_SHOT)

		if trigger_once:
			GameState.mark_dialogue_as_triggered(unique_trigger_id)
			collision_shape.set_deferred("disabled", true)
			call_deferred("set_monitoring", false)
	else:
		print("ERROR: DialogueTrigger could not find method 'start_dialogue_balloon_from_trigger' on owner.")
		if freeze_player and player_node and player_node.has_method("set_input_enabled"):
			player_node.set_input_enabled(true)


func _on_dialogue_ended_from_this_trigger(_resource: DialogueResource, player_node: CharacterBody2D):
	if freeze_player and player_node and player_node.has_method("set_input_enabled"):
		player_node.set_input_enabled(true)
