# dialogue_trigger.gd
extends Area2D

# --- NEW: ENUM for Entry Direction ---
enum EntryDirection {
	ANY,    # Trigger regardless of entry direction
	LEFT,   # Trigger only if entering from the left side (moving right)
	RIGHT   # Trigger only if entering from the right side (moving left)
	# You could add TOP, BOTTOM later if needed for vertical triggers
}

# --- EXPORTED PROPERTIES (Configurable in Inspector) ---

# 1. Connection to specific dialogue
# Drag your main.dialogue file here in the Inspector.
@export var dialogue_resource: DialogueResource
# Type the exact title of the dialogue you want to play (e.g., "hallway_thoughts").
@export var dialogue_title: String = ""

# NEW: A unique identifier for this specific trigger instance.
# This is crucial for distinguishing between different 'trigger_once' instances
# across scene changes. Each 'trigger_once' DialogueTrigger in your game
# must have a unique ID in the Inspector!
@export var unique_trigger_id: String = ""


# 2. Can be either triggerable once or anytime you go inside of it
@export var trigger_once: bool = true
# (The 'triggered_already' state is now managed by GameState singleton)


# 3. Can either stop the character from moving, or can not
@export var freeze_player: bool = true

# NEW: Required direction for the player to enter this trigger.
@export var required_entry_direction: EntryDirection = EntryDirection.ANY


# --- INTERNAL NODE REFERENCES ---
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready():
	# IMPORTANT: Ensure a unique_trigger_id is set if trigger_once is true.
	if trigger_once and unique_trigger_id.is_empty():
		# Fallback to node path if unique_trigger_id is not set.
		# This is less robust across scene instance changes (e.g., if you
		# duplicate scenes or rename nodes). Explicitly setting unique_trigger_id
		# in the inspector is strongly recommended for 'trigger_once' nodes.
		unique_trigger_id = get_path()

	# Initial setup: check GameState if this trigger has been activated before.
	if trigger_once and GameState.is_dialogue_triggered(unique_trigger_id):
		print("DialogueTrigger '", unique_trigger_id, "' already triggered, disabling.")
		collision_shape.set_deferred("disabled", true)
		monitoring = false
	else:
		monitoring = true # Ensure it's active by default if not triggered

	# Connect the Area2D's body_entered signal to our handler.
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D):
	# Check if the body that entered is the player (assuming player is in "Player" group).
	if not body.is_in_group("Player"):
		return

	# If trigger_once is true and it's already been triggered (checked via GameState), do nothing.
	if trigger_once and GameState.is_dialogue_triggered(unique_trigger_id):
		return

	var player_node = body as CharacterBody2D
	# Ensure the body is a CharacterBody2D and has a velocity property
	if not player_node or not player_node.has_method("get_velocity"): # Using get_velocity for robustness
		print("Warning: DialogueTrigger entered by non-CharacterBody2D or a CharacterBody2D without 'get_velocity'. Cannot check entry direction.")
		return # Cannot determine entry direction, so abort.


	# --- NEW: Check Entry Direction ---
	if required_entry_direction != EntryDirection.ANY:
		var player_velocity_x = player_node.get_velocity().x
		var actual_entry_direction: EntryDirection

		# Determine the general direction of horizontal movement
		if player_velocity_x > 0.1: # Moving right significantly
			# If player is moving right, they are entering from the LEFT boundary of the trigger
			actual_entry_direction = EntryDirection.LEFT
		elif player_velocity_x < -0.1: # Moving left significantly
			# If player is moving left, they are entering from the RIGHT boundary of the trigger
			actual_entry_direction = EntryDirection.RIGHT
		else:
			# Player is not moving horizontally, or moving very slowly
			# This case won't satisfy a specific LEFT/RIGHT requirement
			actual_entry_direction = EntryDirection.ANY

		if required_entry_direction != actual_entry_direction:
			# The player's entry direction does not match the required direction, so do not trigger.
			# print("DialogueTrigger '", unique_trigger_id, "' skipped due to incorrect entry direction. Required: ",
			#       EntryDirection.keys()[required_entry_direction], ", Actual: ", EntryDirection.keys()[actual_entry_direction])
			return


	# --- Freeze Player (if configured) ---
	if freeze_player and player_node and player_node.has_method("set_input_enabled"):
		player_node.set_input_enabled(false)

	# --- Start Dialogue ---
	var level_script = get_owner()
	if level_script and level_script.has_method("start_dialogue_balloon_from_trigger"):
		level_script.start_dialogue_balloon_from_trigger(dialogue_resource, dialogue_title)

		# Connect to DialogueManager's signal to handle ending actions.
		# Pass the player_node so it can be unfrozen.
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended_from_this_trigger.bind(player_node), CONNECT_ONE_SHOT)

		# Mark as triggered if it's a one-time trigger AFTER dialogue starts successfully.
		if trigger_once:
			GameState.mark_dialogue_as_triggered(unique_trigger_id)
			# Disable the collision so it doesn't trigger again in the current scene.
			collision_shape.set_deferred("disabled", true)
			call_deferred("set_monitoring", false) # Ensure this is deferred
	else:
		print("ERROR: DialogueTrigger could not find method 'start_dialogue_balloon_from_trigger' on owner.")
		if freeze_player and player_node and player_node.has_method("set_input_enabled"):
			player_node.set_input_enabled(true)


func _on_dialogue_ended_from_this_trigger(_resource: DialogueResource, player_node: CharacterBody2D):
	# Unfreeze player (if they were frozen).
	if freeze_player and player_node and player_node.has_method("set_input_enabled"):
		player_node.set_input_enabled(true)
