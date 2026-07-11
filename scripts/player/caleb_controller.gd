extends CharacterBody2D
const SPEED = 200.0
const FRICTION = 0.1	
var facing_direction: int = 1
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# --- TRANSITION STATE VARIABLES ---
var can_transition: bool = false
var is_in_transition: bool = false
var transition_data: Dictionary = {}
var scene_to_load_after_transition: String = ""

# --- UPDATED NODE REFERENCE ---
@onready var animated_sprite: AnimatedSprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func set_input_enabled(is_enabled: bool):
	is_in_transition = not is_enabled
	if not is_enabled:
		velocity = Vector2.ZERO

func _ready():
	for zone in get_tree().get_nodes_in_group("TransitionZones"):
		zone.player_entered_zone.connect(on_player_entered_transition_zone)
		zone.player_exited_zone.connect(on_player_exited_transition_zone)

func on_player_entered_transition_zone(data: Dictionary):
	can_transition = true
	transition_data = data
	
	# --- DEBUG PRINT ---
	print("DEBUG Controller: Received transition data: ", transition_data)

func on_player_exited_transition_zone():
	can_transition = false
	transition_data = {}

func _physics_process(delta):
	if is_in_transition:
		return
		
	if can_transition and Input.is_action_just_pressed(transition_data.action):
		start_transition()
		return

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	var direction = Input.get_axis("ui_left", "ui_right")
	
	if direction != 0:
		velocity.x = direction * SPEED
		
		if animated_sprite.animation != "move":
			animated_sprite.play("move")
			
		if direction > 0:
			facing_direction = 1
		else:
			facing_direction = -1
	else:
		velocity.x = lerp(velocity.x, 0.0, FRICTION)
		
		if animated_sprite.animation != "idle":
			animated_sprite.play("idle")

	# Sprite flipping logic
	if facing_direction > 0:
		animated_sprite.flip_h = true
	else:
		animated_sprite.flip_h = false
		
	move_and_slide()

func start_transition():
	is_in_transition = true
	can_transition = false
	
	var tween = create_tween()
	var exit_direction = transition_data.exit_direction
	var exit_distance = 800.0
	
	animated_sprite.play("move")
	
	if exit_direction > 0:
		animated_sprite.flip_h = true
	else:
		animated_sprite.flip_h = false
		
	tween.tween_property(self, "global_position", global_position + Vector2(exit_distance * exit_direction, 0), 2.0).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(teleport_player)

func teleport_player():
	# --- Check both methods: scene_to_load_after_transition (for level script) and transition_data (for TransitionZones) ---
	if scene_to_load_after_transition != "":
		print("DEBUG: Changing scene via level script to: ", scene_to_load_after_transition)
		get_tree().change_scene_to_file(scene_to_load_after_transition)
		scene_to_load_after_transition = "" # Reset for next use
	elif transition_data.has("target_scene") and transition_data.target_scene != "":
		print("DEBUG: Changing scene via TransitionZone to: ", transition_data.target_scene)
		get_tree().change_scene_to_file(transition_data.target_scene)
	else:
		# Local teleport
		print("DEBUG: Local teleport to: ", transition_data.target_position)
		self.global_position = transition_data.target_position
		is_in_transition = false
		velocity.x = 0
	
	# Clear transition data
	transition_data = {}
	can_transition = false
