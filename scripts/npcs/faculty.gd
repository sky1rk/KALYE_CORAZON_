extends CharacterBody2D

# --- Inspector Settings ---
@export var move_speed: float = 400.0
@export var left_transition_zone_name: String = "GFLeft"
@export var right_transition_zone_name: String = "GFRight"
@export var spawn_offset_x: float = 0.0
@export var end_offset_x: float = 0.0
@export var dialogue_title: String = "faculty_intro"
@export var escort_follow_distance: float = 140.0
@export var dash_speed: float = 520.0
@export var dash_spawn_margin: float = 80.0
@export var dash_warning_distance: float = 180.0
@export var dash_hit_distance: float = 48.0
@export var dash_warning_dialogue_title: String = "faculty_dash_warning"

# Story flag used to remember when Caleb has already declined the faculty's help request.
const DECLINED_FACULTY_HELP_FLAG := "declined_faculty_help"

# --- Movement Bounds and Interaction State ---
var walk_start_x: float
var walk_end_x: float
var dash_target_x: float
var dash_intro_player: CharacterBody2D = null
var dash_warning_triggered := false
var is_dashing_to_player := false
var is_paused_for_dash_warning := false
var presence_enabled := true
var player_in_range: CharacterBody2D = null
var is_conversing := false
var is_escorting := false
var escort_player: CharacterBody2D = null
var pause_sfx_player: AudioStreamPlayer
var idle_animation_name := "idle"
var walk_animation_name := "walking"

# --- Child Node References ---
@onready var animated_sprite: AnimatedSprite2D = $CharacterBody2D
@onready var encounter_area: Area2D = $EncounterArea


func _ready() -> void:
	# Prepare escort limits, and initial idle state when the NPC is added.
	_resolve_walk_bounds()
	if global_position.x > walk_start_x:
		global_position.x = walk_start_x
	_disable_interaction()
	play_idle_animation()


func _physics_process(_delta: float) -> void:
	# Skip all behavior while the level has intentionally hidden the faculty.
	if not presence_enabled:
		velocity.x = 0.0
		return

	# Dash intro pauses briefly for a warning line before the faculty reaches Caleb.
	if is_paused_for_dash_warning:
		velocity.x = 0.0
		play_idle_animation()
		move_and_slide()
		return

	# Conversation pauses movement and keeps the player focused on dialogue.
	if is_conversing:
		velocity.x = 0.0
		if player_in_range:
			face_player_for_interaction(player_in_range)
		play_idle_animation()
		move_and_slide()
		return

	# Escort behavior takes over after Caleb agrees to help.
	if is_escorting:
		lead_the_way()
		move_and_slide()
		return

	# Opening hallway beat rushes the faculty toward Caleb before starting dialogue.
	if is_dashing_to_player:
		dash_toward_player()
		move_and_slide()
		return

	# The faculty now stays put unless the scripted dash or escort is active.
	velocity.x = 0.0
	play_idle_animation()
	move_and_slide()

	if velocity.x > 0:
		animated_sprite.flip_h = true
	elif velocity.x < 0:
		animated_sprite.flip_h = false


func set_presence_enabled(enabled: bool) -> void:
	# Let the level hide/show the faculty without deleting the scene instance.
	presence_enabled = enabled
	visible = enabled
	velocity.x = 0.0
	if not enabled:
		is_dashing_to_player = false
		is_paused_for_dash_warning = false
		dash_intro_player = null
		player_in_range = null
	_disable_interaction()


func spawn_at_hallway_center(center_x: float, lane_y: float, camera_half_width: float = 0.0, player_node: CharacterBody2D = null) -> void:
	# Spawn just outside the left camera edge and dash right toward Caleb.
	var half_width = camera_half_width
	if half_width <= 0.0:
		half_width = 640.0

	dash_intro_player = player_node
	dash_target_x = player_node.global_position.x if player_node else center_x
	global_position = Vector2(center_x - half_width - dash_spawn_margin, lane_y)
	dash_warning_triggered = false
	is_dashing_to_player = true
	is_paused_for_dash_warning = false
	player_in_range = player_node
	set_presence_enabled(true)
	face_direction(sign(dash_target_x - global_position.x))
	play_walk_animation()


func dash_toward_player() -> void:
	# Rush toward Caleb, pause once for a warning, then trigger the normal intro on contact.
	if dash_intro_player:
		dash_target_x = dash_intro_player.global_position.x

	var distance_to_target = abs(dash_target_x - global_position.x)
	var dash_direction = sign(dash_target_x - global_position.x)
	if dash_direction == 0.0:
		dash_direction = 1.0

	if not dash_warning_triggered and distance_to_target <= dash_warning_distance:
		start_dash_warning_dialogue()
		return

	if distance_to_target <= dash_hit_distance:
		finish_dash_intro()
		return

	velocity.x = dash_direction * dash_speed
	face_direction(dash_direction)
	play_walk_animation()


func start_dash_warning_dialogue() -> void:
	# Briefly interrupt the dash with a pre-hit dialogue beat.
	dash_warning_triggered = true
	is_paused_for_dash_warning = true
	velocity.x = 0.0
	play_idle_animation()
	if dash_intro_player:
		face_player_for_interaction(dash_intro_player)
		if dash_intro_player.has_method("set_input_enabled"):
			dash_intro_player.set_input_enabled(false)

	var level_script = get_owner()
	if level_script and level_script.has_method("start_dialogue_balloon_from_trigger"):
		var dialogue_resource = preload("res://dialogue/main.dialogue")
		DialogueManager.dialogue_ended.connect(_on_dash_warning_dialogue_ended, CONNECT_ONE_SHOT)
		level_script.start_dialogue_balloon_from_trigger(dialogue_resource, dash_warning_dialogue_title)
	else:
		is_paused_for_dash_warning = false


func _on_dash_warning_dialogue_ended(_resource: DialogueResource) -> void:
	# Resume the dash after the warning line closes.
	is_paused_for_dash_warning = false
	is_dashing_to_player = true
	play_walk_animation()


func finish_dash_intro() -> void:
	# Stop next to Caleb and hand off to the existing faculty_intro conversation.
	is_dashing_to_player = false
	is_paused_for_dash_warning = false
	velocity.x = 0.0
	if dash_intro_player:
		player_in_range = dash_intro_player
		var arrival_side = sign(global_position.x - dash_intro_player.global_position.x)
		if arrival_side == 0.0:
			arrival_side = 1.0
		global_position.x = dash_intro_player.global_position.x + (dash_hit_distance * arrival_side)
		face_player_for_interaction(dash_intro_player)
	start_conversation()


func face_direction(direction: float) -> void:
	# Match the faculty sprite flip to the direction they should face.
	if direction > 0.0:
		animated_sprite.flip_h = true
	elif direction < 0.0:
		animated_sprite.flip_h = false


func face_player_for_interaction(player_node: CharacterBody2D) -> void:
	# Make Caleb and the faculty face each other during dialogue.
	var direction_to_player = sign(player_node.global_position.x - global_position.x)
	if direction_to_player == 0.0:
		direction_to_player = 1.0

	face_direction(direction_to_player)
	var player_idle_animation := "idle_books" if GameState.get_story_flag("helped_faculty") else "idle"
	set_player_facing(player_node, -direction_to_player, player_idle_animation)


func face_escort_direction(player_animation_name: String = "walking_books") -> void:
	# Keep both characters looking toward the escort destination.
	var escort_direction = get_escort_direction()

	face_direction(escort_direction)
	if escort_player:
		set_player_facing(escort_player, escort_direction, player_animation_name)


func set_player_facing(player_node: CharacterBody2D, direction: float, animation_name: String = "") -> void:
	# Caleb's movement script is disabled during dialogue/escort, so update his sprite here.
	if direction == 0.0:
		return

	var player_facing_direction = 1 if direction > 0.0 else -1
	player_node.set("facing_direction", player_facing_direction)

	var player_sprite := player_node.get_node_or_null("Sprite2D") as AnimatedSprite2D
	if not player_sprite:
		return

	player_sprite.flip_h = player_facing_direction > 0
	if animation_name != "" and player_sprite.animation != animation_name:
		player_sprite.play(animation_name)


func lead_the_way() -> void:
	# Escort Caleb toward the target end point after the faculty conversation.
	if global_position.x < walk_end_x:
		velocity.x = move_speed
		face_escort_direction()
		play_walk_animation()
		if escort_player and escort_player.has_method("set_input_enabled"):
			var escort_direction = get_escort_direction()
			escort_player.global_position = Vector2(global_position.x - (escort_follow_distance * escort_direction), escort_player.global_position.y)
	else:
		velocity.x = 0.0
		face_escort_direction("idle")
		play_idle_animation()
		finish_escort()


func play_escort_pause_sound() -> void:
	# Play the alert sound and pause the level music during the escort beat.
	if pause_sfx_player:
		pause_sfx_player.play()
	var level_script = get_owner()
	if level_script and level_script.has_method("_pause_bgm_for_faculty"):
		level_script._pause_bgm_for_faculty()


func stop_escort_pause_sound() -> void:
	# Stop the alert sound and let the level restore the background music.
	if pause_sfx_player:
		pause_sfx_player.stop()
	var level_script = get_owner()
	if level_script and level_script.has_method("_resume_bgm_after_faculty"):
		level_script._resume_bgm_after_faculty()


func start_conversation() -> void:
	# Open the faculty dialogue and temporarily lock player movement.
	if is_conversing:
		return
	if GameState.get_story_flag(DECLINED_FACULTY_HELP_FLAG):
		if player_in_range and player_in_range.has_method("set_input_enabled"):
			player_in_range.set_input_enabled(true)
		return

	is_conversing = true
	velocity.x = 0.0
	play_idle_animation()
	if player_in_range:
		face_player_for_interaction(player_in_range)

	if player_in_range and player_in_range.has_method("set_input_enabled"):
		player_in_range.set_input_enabled(false)

	var level_script = get_owner()
	if level_script and level_script.has_method("start_dialogue_balloon_from_trigger"):
		var dialogue_resource = preload("res://dialogue/main.dialogue")
		DialogueManager.dialogue_ended.connect(_on_faculty_dialogue_ended.bind(player_in_range), CONNECT_ONE_SHOT)
		level_script.start_dialogue_balloon_from_trigger(dialogue_resource, dialogue_title)
	else:
		is_conversing = false
		if player_in_range and player_in_range.has_method("set_input_enabled"):
			player_in_range.set_input_enabled(true)


func _on_faculty_dialogue_ended(_resource: DialogueResource, player_node: CharacterBody2D) -> void:
	# Decide whether Caleb escorts the faculty or simply regains control.
	is_conversing = false
	if GameState.get_story_flag("helped_faculty"):
		begin_escort(player_node)
	else:
		# Once Caleb declines, prevent this prompt from returning in later visits.
		GameState.set_story_flag(DECLINED_FACULTY_HELP_FLAG, true)
		_disable_interaction()
		if player_node and player_node.has_method("set_input_enabled"):
			player_node.set_input_enabled(true)


func begin_escort(player_node: CharacterBody2D) -> void:
	# Switch from hallway pacing/interacting into the existing escort sequence.
	is_escorting = true
	escort_player = player_node
	player_in_range = null
	if escort_player and escort_player.has_method("set_input_enabled"):
		escort_player.set_input_enabled(false)
	if escort_player:
		var escort_direction = get_escort_direction()
		escort_player.global_position = Vector2(global_position.x - (escort_follow_distance * escort_direction), escort_player.global_position.y)
		set_player_facing(escort_player, escort_direction, "walking_books")
	face_escort_direction()
	play_walk_animation()


func finish_escort() -> void:
	# Give player control back once the faculty reaches the escort end point.
	is_escorting = false
	if escort_player and escort_player.has_method("set_input_enabled"):
		set_player_facing(escort_player, get_escort_direction(), "idle")
		escort_player.set_input_enabled(true)
	escort_player = null


func _resolve_walk_bounds() -> void:
	# Use level transition zones for the escort destination.
	var left_zone: Node = null
	var right_zone: Node = null
	var parent_node := get_parent()

	if parent_node:
		left_zone = parent_node.get_node_or_null("TransitionZones/%s" % left_transition_zone_name)
		right_zone = parent_node.get_node_or_null("TransitionZones/%s" % right_transition_zone_name)

	if left_zone and right_zone:
		walk_start_x = left_zone.global_position.x + spawn_offset_x
		walk_end_x = right_zone.global_position.x - end_offset_x
	else:
		walk_start_x = global_position.x
		walk_end_x = global_position.x


func get_escort_direction() -> float:
	# Use the full escort path direction so facing does not flip at the endpoint.
	var escort_direction = sign(walk_end_x - walk_start_x)
	if escort_direction == 0.0:
		escort_direction = 1.0
	return escort_direction


func play_animation(animation_name: String) -> void:
	# Avoid restarting an animation that is already playing.
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)


func play_idle_animation() -> void:
	play_animation(idle_animation_name)


func play_walk_animation() -> void:
	play_animation(walk_animation_name)


func set_idle_animation(animation_name: String) -> void:
	idle_animation_name = animation_name
	play_idle_animation()


func set_walk_animation(animation_name: String) -> void:
	walk_animation_name = animation_name


func _disable_interaction() -> void:
	# Turn off the old manual interaction area and prompt.
	player_in_range = null
	if encounter_area:
		encounter_area.monitoring = false
		encounter_area.monitorable = false
		var collision_shape := encounter_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision_shape:
			collision_shape.set_deferred("disabled", true)
