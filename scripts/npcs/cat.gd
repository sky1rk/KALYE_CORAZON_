# cat.gd (Updated for AnimatedSprite2D with Falloff Movement)

extends CharacterBody2D

# --- Constants ---
const SPEED = 400.0
const FOLLOW_DISTANCE = 200.0
const POSITION_THRESHOLD = 20.0  # Increased threshold for better idle detection
const FALLOFF_DISTANCE = 80.0    # Distance at which cat starts slowing down

# --- State Machine ---
enum State { IDLE, LEADING, REPOSITIONING }
var current_state = State.IDLE

# --- Node References ---
var player_ref: CharacterBody2D = null
# UPDATED: Changed from Sprite2D to AnimatedSprite2D.
# Make sure your node in the scene is named "AnimatedSprite2D".
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var encounter_area: Area2D = $EncounterArea

# --- Physics Variables ---
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")


func _ready():
	encounter_area.body_entered.connect(_on_encounter_area_body_entered)
	# NEW: Set the starting animation.
	animated_sprite.play("idle")


func start_following(player_node: CharacterBody2D):
	player_ref = player_node
	current_state = State.REPOSITIONING


func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

	match current_state:
		State.IDLE:
			velocity.x = lerp(velocity.x, 0.0, 0.1)
			# NEW: Ensure idle animation is playing when idle.
			play_animation("idle")
		State.LEADING:
			lead_the_player()
		State.REPOSITIONING:
			reposition_in_front()

	move_and_slide()
	
	# UPDATED: Flip the AnimatedSprite2D.
	if velocity.x > 1:
		animated_sprite.flip_h = false
	elif velocity.x < -1:
		animated_sprite.flip_h = true


# NEW: Helper function to avoid resetting the animation every frame.
func play_animation(anim_name: String):
	if animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)


# --- State Logic Functions ---

func lead_the_player():
	if not player_ref: 
		return

	# 1. Check if the player has changed direction
	var player_direction = player_ref.facing_direction
	var cat_to_player_direction = sign(player_ref.global_position.x - self.global_position.x)
	
	if player_direction != cat_to_player_direction and cat_to_player_direction != 0:
		current_state = State.REPOSITIONING
		return

	# 2. Calculate target position and distance
	var target_position = player_ref.global_position + Vector2(player_direction * FOLLOW_DISTANCE, 0)
	var distance_to_target = global_position.distance_to(target_position)
	var horizontal_distance = abs(target_position.x - global_position.x)

	# 3. Check player movement state
	var is_player_moving = abs(player_ref.velocity.x) > 10.0  # Increased threshold for better detection

	# 4. Determine if cat should move or be idle
	if horizontal_distance <= POSITION_THRESHOLD:
		# Cat is close enough to target position
		if is_player_moving:
			# Player is moving, so cat should move to maintain distance
			var move_speed = calculate_falloff_speed(horizontal_distance)
			var direction = sign(target_position.x - global_position.x)
			velocity.x = lerp(velocity.x, direction * move_speed, 0.15)
			
			if abs(velocity.x) > 5.0:  # Only play walk if actually moving
				play_animation("walk")
			else:
				play_animation("idle")
		else:
			# Player stopped and cat is in position - go idle
			velocity.x = lerp(velocity.x, 0.0, 0.2)
			play_animation("idle")
	else:
		# Cat is too far from target position, need to move
		var move_speed = calculate_falloff_speed(horizontal_distance)
		var direction = sign(target_position.x - global_position.x)
		velocity.x = lerp(velocity.x, direction * move_speed, 0.1)
		play_animation("walk")


# NEW: Calculate speed with falloff as cat approaches target
func calculate_falloff_speed(distance_to_target: float) -> float:
	if distance_to_target <= POSITION_THRESHOLD:
		# Very close to target, move very slowly
		return SPEED * 0.1
	elif distance_to_target <= FALLOFF_DISTANCE:
		# Within falloff range, gradually reduce speed
		var falloff_ratio = (distance_to_target - POSITION_THRESHOLD) / (FALLOFF_DISTANCE - POSITION_THRESHOLD)
		return SPEED * (0.1 + falloff_ratio * 0.6)  # Speed ranges from 10% to 70% of max
	else:
		# Far from target, move at full speed
		return SPEED * 0.8


func reposition_in_front():
	if not player_ref: 
		return
	
	var target_position = player_ref.global_position + Vector2(player_ref.facing_direction * FOLLOW_DISTANCE, 0)
	var horizontal_distance = abs(target_position.x - global_position.x)

	if horizontal_distance > POSITION_THRESHOLD:
		# Calculate speed with falloff
		var move_speed = calculate_falloff_speed(horizontal_distance)
		var horizontal_direction = sign(target_position.x - global_position.x)
		velocity.x = horizontal_direction * move_speed * 1.2  # Slightly faster when repositioning
		# NEW: Play walk animation when repositioning.
		play_animation("walk")
	else:
		velocity.x = lerp(velocity.x, 0.0, 0.3)  # Smooth stop
		current_state = State.LEADING
		# NEW: Play idle animation when it arrives.
		play_animation("idle")


# --- Signal Handling ---

func _on_encounter_area_body_entered(body):
	# We only need to check if the body that entered is the player.
	# We no longer need to check the 'cat_can_be_encountered' flag.
	if body.is_in_group("Player"): # It's slightly better practice to check for a group.
		var level_script = get_owner()
		if level_script and level_script.has_method("start_cat_dialogue"):
			level_script.start_cat_dialogue()
		
		# Disable the encounter area so it only happens once.
		encounter_area.get_child(0).call_deferred("set_disabled", true)
