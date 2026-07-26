# level_1_questonhall.gd
extends Node2D

@export var player: CharacterBody2D
@export var cat: CharacterBody2D

@onready var balloon = preload("res://dialogue/balloon.tscn").instantiate()
var dialogue_res = preload("res://dialogue/main.dialogue")
@onready var faculty = $"0/Faculty"

@onready var bgm = $BGMPlayer
var fade_time := 2.0  # Fade time for BGM in seconds

const ARTIFACT_1_SCENE := preload("res://scenes/minigames/artifact_1.tscn")
const CONGRATS_SCENE := preload("res://scenes/minigames/congrats.tscn")
const LEVEL1_AMPHORA_COLLECTED_FLAG := "level1_amphora_collected"
const LEVEL1_AMPHORA_CAT_OFFSET := Vector2(96, 28)
const LEVEL1_AMPHORA_CLICK_RADIUS := 120.0
const POPUP_OPEN_DURATION := 2.0
const POPUP_START_SCALE := 0.15
const REWARD_BACKDROP_ALPHA := 0.62
const REWARD_BACKDROP_FADE_DURATION := 0.2

# --- Faculty and Opening Hallway State ---
var faculty_bgm_paused: bool = false
var hallway_thoughts_started: bool = false
var hallway_faculty_spawn_pending: bool = false

# --- Cat and Minigame State ---
var cat_is_following: bool = false
var minigame_completed: bool = false
var active_artifact_1: Node2D = null
var active_congrats: Node2D = null
var clicked_reward_amphora: Node2D = null
var active_reward_backdrop: ColorRect = null
var reward_popup_layer: CanvasLayer = null

func _ready():
	var returning_from_office_before_minigame := GameState.trigger_level1_minigame_on_return and not GameState.persevere_minigame_completed

	# --- CRITICAL: Handle player positioning FIRST ---
	if GameState.returning_from_level == "level2":
		print("DEBUG: Returning from Level 2")
		GameState.returning_from_level = "" # Reset
		
		if GameState.player_return_position != null and player:
			player.global_position = GameState.player_return_position
			player.set_input_enabled(true)
			var camera = player.get_node_or_null("Camera2D")
			if camera:
				camera.zoom = Vector2.ONE
				camera.reset_smoothing()
			GameState.player_return_position = null
	
	elif GameState.player_return_position != null and (
		(GameState.persevere_minigame_completed and GameState.persevere_minigame_return_scene == "res://scenes/levels/level1_questonhall.tscn")
		or GameState.trigger_level1_minigame_on_return
	):
		if player:
			player.global_position = GameState.player_return_position
			player.set_input_enabled(true)
			var camera = player.get_node_or_null("Camera2D")
			if camera:
				camera.zoom = Vector2.ONE
				camera.reset_smoothing()
			GameState.player_return_position = null
	
	add_child(balloon)
	DialogueManager.mutated.connect(_on_dialogue_mutated)
	# Listen for dialogue completion so we can spawn faculty after hallway_thoughts.
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	if GameState.cat_dialogue_completed:
		GameState.level1_amphora_unlocked = true
	_refresh_level1_amphoras()

	if returning_from_office_before_minigame:
		GameState.trigger_level1_minigame_on_return = false
		GameState.mark_dialogue_as_triggered("hallway_thoughts")

	var hallway_thoughts_done := GameState.is_dialogue_triggered("hallway_thoughts")
	# Hide faculty only before the opening hallway thoughts have played.
	_prepare_faculty_with_books()
	if faculty and faculty.has_method("set_presence_enabled"):
		var should_show_faculty := hallway_thoughts_done and not GameState.get_story_flag("office_faculty_leave_completed")
		faculty.set_presence_enabled(should_show_faculty)
	
	var story_exit = $"0/LevelExitTrigger"
	story_exit.monitoring = false

	# --- HANDLE CAT FOLLOWING STATE ---
	if GameState.cat_is_following_globally:
		cat_is_following = true
		if cat and cat.has_method("start_following"):
			print("DEBUG: Making cat start following player")
			
			# --- NEW: Position cat next to player when returning from Level 2 ---
			if GameState.returning_from_level == "level2" or GameState.returning_from_level == "":
				# Get the FOLLOW_DISTANCE from the cat (same logic as Level 2)
				var cat_spawn_offset = Vector2(player.facing_direction * cat.FOLLOW_DISTANCE, 0)
				cat.global_position = player.global_position + cat_spawn_offset
				
				# Orient the cat correctly based on the player's facing direction
				if player.facing_direction < 0:
					cat.animated_sprite.flip_h = true
				else:
					cat.animated_sprite.flip_h = false
				
				print("DEBUG: Positioned cat at: ", cat.global_position, " (offset: ", cat_spawn_offset, ")")
			
			cat.start_following(player)
	
	# --- HANDLE MINIGAME COMPLETION CLEANUP ---
	if GameState.persevere_minigame_completed:
		$MinigameTrigger.get_child(0).call_deferred("set_disabled", true)
		$MinigameTrigger.call_deferred("set_monitoring", false)
		
		if not GameState.persevere_minigame_dialogue_shown:
			balloon.show()
			balloon.start(dialogue_res, "paper_minigame_success")
			GameState.persevere_minigame_dialogue_shown = true
	
	# --- HANDLE CAT DIALOGUE STATE ---
	if GameState.cat_dialogue_completed and cat:
		var encounter_area = cat.get_node_or_null("EncounterArea")
		if encounter_area:
			encounter_area.get_child(0).call_deferred("set_disabled", true)
			encounter_area.call_deferred("set_monitoring", false)

	# --- FADE IN BGM ---
	_start_familiar_place_bgm_if_needed()

func _input(event: InputEvent) -> void:
	if event is not InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	_try_handle_amphora_click_at_mouse()

func _exit_tree():
	# --- FADE OUT BGM ---
	if bgm and bgm.playing:
		var t = create_tween()
		t.tween_property(bgm, "volume_db", -40, fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.finished.connect(func(): bgm.stop())

func _on_dialogue_mutated(data: Dictionary):
	# Route dialogue mutations into level state changes and scene transitions.
	if data.get("mutation") == "follow_cat":
		print("Player chose to follow the cat!")
		cat_is_following = true
		GameState.cat_is_following_globally = true
		if cat and cat.has_method("start_following"):
			cat.start_following(player)
	elif data.get("mutation") == "help_faculty":
		print("Player chose to help the faculty.")
		GameState.set_story_flag("helped_faculty", true)
		_apply_help_faculty_sprite_swap()
	elif data.get("mutation") == "faculty_pause_sound_start":
		_pause_bgm_for_faculty()
		if faculty and faculty.has_method("play_escort_pause_sound"):
			faculty.play_escort_pause_sound()
	elif data.get("mutation") == "faculty_pause_sound_stop":
		if faculty and faculty.has_method("stop_escort_pause_sound"):
			faculty.stop_escort_pause_sound()
		_resume_bgm_after_faculty()
	elif data.get("mutation") == "level1_cat_cultural_echo_start":
		_switch_from_familiar_place_to_cultural_echo()
	elif data.get("mutation") == "start_minigame":
		get_tree().change_scene_to_file("res://scenes/minigames/minigame_persevere.tscn")
	elif data.get("mutation") == "proceed_to_level2":
		print("DEBUG: Player chose to proceed to Level 2. Initiating animated exit.")
		GameState.level_1_story_exit_completed = true
		GameState.player_return_position = Vector2(1394, 683)
		
		player.scene_to_load_after_transition = "res://scenes/levels/level2_callereal.tscn"
		player.transition_data = { "exit_direction": -1 }
		player.is_in_transition = true
		player.start_transition()
	elif data.get("mutation") == "stay_in_level1":
		print("DEBUG: Player chose to stay in Level 1.")
		player.set_input_enabled(true)
		$"0/LevelExitTrigger".monitoring = true


func _start_hallway_thoughts() -> void:
	# Prevent replay if this scene has already started the hallway opening dialogue.
	if hallway_thoughts_started:
		return
	if GameState.is_dialogue_triggered("hallway_thoughts"):
		return

	hallway_thoughts_started = true
	hallway_faculty_spawn_pending = true
	GameState.mark_dialogue_as_triggered("hallway_thoughts")
	balloon.show()
	balloon.start(dialogue_res, "hallway_thoughts")


func start_opening_dialogue() -> void:
	if GameState.is_dialogue_triggered("hallway_thoughts"):
		return
	_start_hallway_thoughts()


func _on_dialogue_ended(_resource: DialogueResource) -> void:
	# Spawn faculty only when the pending hallway intro dialogue is the one that just ended.
	if not hallway_faculty_spawn_pending:
		return
	hallway_faculty_spawn_pending = false
	_spawn_faculty_at_hallway_center()


func _spawn_faculty_at_hallway_center() -> void:
	# Tell the faculty where the camera is so he can dash in from just outside view.
	if not faculty:
		return

	var camera = player.get_node_or_null("Camera2D")
	var center_x = player.global_position.x
	var camera_half_width = 0.0
	if camera:
		center_x = camera.get_screen_center_position().x
		camera_half_width = (get_viewport_rect().size.x * 0.5) / camera.zoom.x

	# Preserve the faculty's designed Y lane while aiming the dash at Caleb.
	_prepare_faculty_with_books()
	if faculty.has_method("spawn_at_hallway_center"):
		faculty.spawn_at_hallway_center(center_x, faculty.global_position.y, camera_half_width, player)


func _prepare_faculty_with_books() -> void:
	if faculty and faculty.has_method("set_idle_animation"):
		faculty.set_idle_animation("idle_w_books")
	elif faculty and faculty.has_method("play_animation"):
		faculty.play_animation("idle_w_books")

	if faculty and faculty.has_method("set_walk_animation"):
		faculty.set_walk_animation("walking_w_books")


func _apply_help_faculty_sprite_swap() -> void:
	if faculty and faculty.has_method("set_idle_animation"):
		faculty.set_idle_animation("idle")
	elif faculty and faculty.has_method("play_animation"):
		faculty.play_animation("idle")

	if faculty and faculty.has_method("set_walk_animation"):
		faculty.set_walk_animation("walking")

	if player:
		var player_sprite := player.get_node_or_null("Sprite2D") as AnimatedSprite2D
		if not player_sprite:
			return

		player_sprite.play("idle_books")

func start_cat_dialogue():
	# Start the cat encounter dialogue with a small camera zoom.
	var camera = player.get_node_or_null("Camera2D")
	if camera:
		var tween_in = create_tween()
		tween_in.set_trans(Tween.TRANS_SINE)
		tween_in.tween_property(camera, "zoom", Vector2(1.2, 1.2), 1.0)
	
	DialogueManager.dialogue_ended.connect(_on_cat_dialogue_ended, CONNECT_ONE_SHOT)
	balloon.show()
	balloon.start(dialogue_res, "cat_encounter")

func _on_cat_dialogue_ended(_resource: DialogueResource):
	# Restore the camera and unlock the story exit after the cat conversation.
	GameState.cat_dialogue_completed = true
	GameState.level1_amphora_unlocked = true
	_refresh_level1_amphoras()
	
	var camera = player.get_node_or_null("Camera2D")
	if camera:
		var tween_out = create_tween()
		tween_out.set_trans(Tween.TRANS_SINE)
		tween_out.tween_property(camera, "zoom", Vector2.ONE, 0.5)
	
	if not GameState.level_1_story_exit_completed:
		$"0/LevelExitTrigger".monitoring = true
		print("DEBUG: LevelExitTrigger is now active.")

func _on_level_exit_trigger_body_entered(body):
	# Ask whether Caleb proceeds to level 2 or stays in the hallway.
	if body != player: return
	player.set_input_enabled(false)
	var choice_dialogue_title = "follow_cat_exit_choices" if cat_is_following else "resist_urge_exit_choices"
	balloon.show()
	balloon.start(dialogue_res, choice_dialogue_title)
	print("DEBUG: Exit choice dialogue started: ", choice_dialogue_title)

func _on_minigame_trigger_body_entered(body):
	# Start the paper minigame, or route the faculty escort into the office scene.
	if body != player or minigame_completed: return
	if faculty and faculty.is_escorting:
		_disable_minigame_trigger()
		GameState.pending_office_dialogue_title = "faculty_escort_pause"
		GameState.persevere_minigame_return_scene = "res://scenes/minigames/office.tscn"
		GameState.player_return_position = null
		get_tree().change_scene_to_file("res://scenes/minigames/office.tscn")
		return
	elif not GameState.get_story_flag("helped_faculty"):
		_start_paper_minigame_intro()
		return

	_start_paper_minigame_intro()


func _start_paper_minigame_intro() -> void:
	player.set_input_enabled(false)

	var trigger_camera = player.get_node_or_null("Camera2D")
	if trigger_camera:
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.tween_property(trigger_camera, "zoom", Vector2(1.2, 1.2), 1.0)

	balloon.show()
	balloon.start(dialogue_res, "paper_minigame_start")
	GameState.persevere_minigame_return_scene = "res://scenes/levels/level1_questonhall.tscn"
	GameState.player_return_position = player.global_position if player else null
	_disable_minigame_trigger()

func _on_minigame_completed():
	# Disable repeat minigame entry and return control to the player.
	minigame_completed = true
	$MinigameTrigger.get_child(0).set_disabled(true)
	player.set_input_enabled(true)
	
func start_dialogue_balloon_from_trigger(resource: DialogueResource, title: String):
	# Shared helper used by NPCs and triggers to open the dialogue balloon.
	if title == "cat_first_see":
		_switch_from_familiar_place_to_cultural_echo()
	balloon.show()
	balloon.start(resource, title)


func _pause_bgm_for_faculty() -> void:
	# Temporarily pause hallway BGM during faculty sound/dialogue moments.
	if bgm and bgm.playing and not bgm.stream_paused:
		bgm.stream_paused = true
		faculty_bgm_paused = true


func _resume_bgm_after_faculty() -> void:
	# Resume hallway BGM after the faculty moment has ended.
	if bgm and faculty_bgm_paused and not GameState.level1_cultural_echo_active:
		bgm.stream_paused = false
		faculty_bgm_paused = false


func _start_familiar_place_bgm_if_needed() -> void:
	if GameState.level1_cultural_echo_active:
		if bgm:
			bgm.stop()
		GameState.start_cultural_echo_bgm()
		return

	if bgm:
		bgm.volume_db = -40
		bgm.play()
		var t = create_tween()
		t.tween_property(bgm, "volume_db", 0, fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _switch_from_familiar_place_to_cultural_echo() -> void:
	GameState.level1_cultural_echo_active = true
	faculty_bgm_paused = false
	if bgm:
		bgm.stream_paused = false
		bgm.stop()
	GameState.start_cultural_echo_bgm()


func _disable_minigame_trigger() -> void:
	# Prevent the same minigame trigger from firing again.
	$MinigameTrigger.get_child(0).call_deferred("set_disabled", true)
	$MinigameTrigger.call_deferred("set_monitoring", false)


func _refresh_level1_amphoras() -> void:
	var amphora_nodes := _get_level1_amphoras()
	if amphora_nodes.is_empty():
		print("DEBUG LEVEL1 AMPHORA: no amphora nodes found")
		GameState.level1_visible_amphora_name = ""
		return

	if not GameState.level1_amphora_unlocked or GameState.get_story_flag(LEVEL1_AMPHORA_COLLECTED_FLAG):
		print("DEBUG LEVEL1 AMPHORA: hidden. unlocked=", GameState.level1_amphora_unlocked, " collected=", GameState.get_story_flag(LEVEL1_AMPHORA_COLLECTED_FLAG))
		for amphora_node in amphora_nodes:
			_set_amphora_enabled(amphora_node, false)
		return

	if GameState.level1_visible_amphora_name.is_empty() or not _has_amphora_named(amphora_nodes, GameState.level1_visible_amphora_name):
		var selected_amphora := _pick_level1_reward_amphora(amphora_nodes)
		GameState.level1_visible_amphora_name = String(selected_amphora.name)

	for amphora_node in amphora_nodes:
		var is_visible_reward := String(amphora_node.name) == GameState.level1_visible_amphora_name
		if is_visible_reward:
			_position_level1_reward_amphora(amphora_node)
			print("DEBUG LEVEL1 AMPHORA: showing ", amphora_node.name, " at ", amphora_node.global_position)
		_set_amphora_enabled(amphora_node, is_visible_reward)


func _get_level1_amphoras() -> Array:
	var amphora_nodes := []
	for node in get_tree().get_nodes_in_group("office_amphora"):
		var amphora_node := node as Node2D
		if amphora_node and is_ancestor_of(amphora_node):
			amphora_nodes.append(amphora_node)
	return amphora_nodes


func _pick_level1_reward_amphora(amphora_nodes: Array) -> Node2D:
	var selected_amphora := amphora_nodes[0] as Node2D
	var target_position := cat.global_position if cat else (player.global_position if player else selected_amphora.global_position)
	var closest_distance := selected_amphora.global_position.distance_squared_to(target_position)

	for node in amphora_nodes:
		var amphora_node := node as Node2D
		if not amphora_node:
			continue

		var distance := amphora_node.global_position.distance_squared_to(target_position)
		if distance < closest_distance:
			selected_amphora = amphora_node
			closest_distance = distance

	return selected_amphora


func _position_level1_reward_amphora(amphora_node: Node2D) -> void:
	if cat:
		amphora_node.global_position = cat.global_position + LEVEL1_AMPHORA_CAT_OFFSET
	elif player:
		amphora_node.global_position = player.global_position + LEVEL1_AMPHORA_CAT_OFFSET


func _has_amphora_named(amphora_nodes: Array, amphora_name: String) -> bool:
	for amphora_node in amphora_nodes:
		if String(amphora_node.name) == amphora_name:
			return true
	return false


func _set_amphora_enabled(amphora_node: Node2D, enabled: bool) -> void:
	amphora_node.visible = enabled
	if not enabled and amphora_node.has_method("reset_hover_feedback"):
		amphora_node.reset_hover_feedback()

	if amphora_node.has_signal("amphora_clicked"):
		var clicked_callable := Callable(self, "_on_amphora_clicked")
		if not amphora_node.is_connected("amphora_clicked", clicked_callable):
			amphora_node.connect("amphora_clicked", clicked_callable)

	var area := amphora_node.get_node_or_null("Area2D") as Area2D
	if area:
		area.monitoring = enabled
		area.monitorable = enabled
		area.input_pickable = enabled

		for child in area.get_children():
			var collision_shape := child as CollisionShape2D
			if collision_shape:
				collision_shape.set_deferred("disabled", not enabled)


func _on_amphora_clicked(amphora_node: Node2D) -> void:
	print("DEBUG LEVEL1 AMPHORA: clicked ", amphora_node.name if amphora_node else "<null>", " unlocked=", GameState.level1_amphora_unlocked, " collected=", GameState.get_story_flag(LEVEL1_AMPHORA_COLLECTED_FLAG))
	if not GameState.level1_amphora_unlocked:
		return
	if GameState.get_story_flag(LEVEL1_AMPHORA_COLLECTED_FLAG):
		return
	if active_artifact_1 and is_instance_valid(active_artifact_1):
		return
	if active_congrats and is_instance_valid(active_congrats):
		return
	if String(amphora_node.name) != GameState.level1_visible_amphora_name:
		if not amphora_node.visible:
			return
		GameState.level1_visible_amphora_name = String(amphora_node.name)

	if amphora_node.has_method("reset_hover_feedback"):
		amphora_node.reset_hover_feedback()

	clicked_reward_amphora = amphora_node
	_show_artifact_1()


func handle_level1_amphora_clicked(amphora_node: Node2D) -> void:
	_on_amphora_clicked(amphora_node)


func _try_handle_amphora_click_at_mouse() -> bool:
	if not GameState.level1_amphora_unlocked or GameState.get_story_flag(LEVEL1_AMPHORA_COLLECTED_FLAG):
		return false

	var clicked_amphora := _get_amphora_at_point(get_global_mouse_position())
	if not clicked_amphora:
		clicked_amphora = _get_visible_level1_amphora_near_mouse()
	if not clicked_amphora:
		print("DEBUG LEVEL1 AMPHORA: click missed visible amphora at mouse ", get_global_mouse_position())
		return false

	get_viewport().set_input_as_handled()
	_on_amphora_clicked(clicked_amphora)
	return true


func _get_amphora_at_point(global_point: Vector2) -> Node2D:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = global_point
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 0xFFFFFFFF

	for result in space_state.intersect_point(query, 32):
		var collider := result.get("collider") as Node
		var amphora_node := _get_amphora_from_collider(collider)
		if amphora_node and amphora_node.visible:
			return amphora_node

	return null


func _get_visible_level1_amphora_near_mouse() -> Node2D:
	var mouse_position := get_global_mouse_position()
	var closest_amphora: Node2D = null
	var closest_distance := LEVEL1_AMPHORA_CLICK_RADIUS * LEVEL1_AMPHORA_CLICK_RADIUS

	for node in _get_level1_amphoras():
		var amphora_node := node as Node2D
		if not amphora_node or not amphora_node.visible:
			continue

		var distance := amphora_node.global_position.distance_squared_to(mouse_position)
		if distance <= closest_distance:
			closest_amphora = amphora_node
			closest_distance = distance

	return closest_amphora


func _get_amphora_from_collider(collider: Node) -> Node2D:
	var current_node := collider
	while current_node:
		if current_node.is_in_group("office_amphora") and is_ancestor_of(current_node):
			return current_node as Node2D
		current_node = current_node.get_parent()

	return null


func _show_artifact_1() -> void:
	print("DEBUG LEVEL1 AMPHORA: opening artifact_1")
	if active_artifact_1 and is_instance_valid(active_artifact_1):
		return

	_show_reward_backdrop()
	active_artifact_1 = ARTIFACT_1_SCENE.instantiate() as Node2D
	if not active_artifact_1:
		print("DEBUG LEVEL1 AMPHORA: artifact_1 failed to instantiate")
		_hide_reward_backdrop()
		return

	_get_reward_popup_layer().add_child(active_artifact_1)
	active_artifact_1.z_index = 100
	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(false)

	active_artifact_1.global_position = _get_popup_center_position()
	_play_popup_open_transition(active_artifact_1)

	if active_artifact_1.has_signal("artifact_closed"):
		active_artifact_1.connect("artifact_closed", Callable(self, "_on_artifact_1_closed"), CONNECT_ONE_SHOT)

	_show_congrats()


func _on_artifact_1_closed() -> void:
	active_artifact_1 = null
	_restore_player_input_after_artifact_popups()


func _show_congrats() -> void:
	print("DEBUG LEVEL1 AMPHORA: opening congrats")
	if active_congrats and is_instance_valid(active_congrats):
		return

	_show_reward_backdrop()
	_hide_clicked_reward_amphora()

	active_congrats = CONGRATS_SCENE.instantiate() as Node2D
	if not active_congrats:
		print("DEBUG LEVEL1 AMPHORA: congrats failed to instantiate")
		_hide_reward_backdrop()
		return

	_get_reward_popup_layer().add_child(active_congrats)
	active_congrats.z_index = 101
	active_congrats.global_position = _get_popup_center_position()
	_play_popup_open_transition(active_congrats)

	if active_congrats.has_signal("artifact_closed"):
		active_congrats.connect("artifact_closed", Callable(self, "_on_congrats_closed"), CONNECT_ONE_SHOT)


func _on_congrats_closed() -> void:
	active_congrats = null
	_restore_player_input_after_artifact_popups()


func _hide_clicked_reward_amphora() -> void:
	if not clicked_reward_amphora or not is_instance_valid(clicked_reward_amphora):
		return

	GameState.set_story_flag(LEVEL1_AMPHORA_COLLECTED_FLAG, true)
	_set_amphora_enabled(clicked_reward_amphora, false)
	clicked_reward_amphora = null


func _restore_player_input_after_artifact_popups() -> void:
	if active_artifact_1 and is_instance_valid(active_artifact_1):
		return
	if active_congrats and is_instance_valid(active_congrats):
		return

	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(true)

	_hide_reward_backdrop()


func _play_popup_open_transition(popup: Node2D) -> void:
	var target_scale := popup.scale
	popup.scale = target_scale * POPUP_START_SCALE

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "scale", target_scale, POPUP_OPEN_DURATION)


func _show_reward_backdrop() -> void:
	if active_reward_backdrop and is_instance_valid(active_reward_backdrop):
		_position_reward_backdrop()
		return

	active_reward_backdrop = ColorRect.new()
	active_reward_backdrop.name = "RewardBackdrop"
	active_reward_backdrop.color = Color(0, 0, 0, 0)
	active_reward_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	active_reward_backdrop.z_index = 99
	_get_reward_popup_layer().add_child(active_reward_backdrop)
	_position_reward_backdrop()

	var tween := create_tween()
	tween.tween_property(active_reward_backdrop, "color", Color(0, 0, 0, REWARD_BACKDROP_ALPHA), REWARD_BACKDROP_FADE_DURATION)


func _hide_reward_backdrop() -> void:
	if not active_reward_backdrop or not is_instance_valid(active_reward_backdrop):
		active_reward_backdrop = null
		return

	active_reward_backdrop.queue_free()
	active_reward_backdrop = null


func _position_reward_backdrop() -> void:
	if not active_reward_backdrop:
		return

	var backdrop_size := get_viewport_rect().size
	var backdrop_center := _get_popup_center_position()

	active_reward_backdrop.size = backdrop_size
	active_reward_backdrop.position = backdrop_center - backdrop_size * 0.5


func _get_popup_center_position() -> Vector2:
	return get_viewport_rect().size * 0.5


func _get_reward_popup_layer() -> CanvasLayer:
	if reward_popup_layer and is_instance_valid(reward_popup_layer):
		return reward_popup_layer

	reward_popup_layer = CanvasLayer.new()
	reward_popup_layer.name = "RewardPopupLayer"
	reward_popup_layer.layer = 100
	add_child(reward_popup_layer)
	return reward_popup_layer


func _get_level_camera() -> Camera2D:
	if not player:
		return null
	return player.get_node_or_null("Camera2D") as Camera2D


func _on_office_trigger_body_entered(_body: Node2D) -> void:
	pass # Replace with function body.
