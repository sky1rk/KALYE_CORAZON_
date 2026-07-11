extends Node2D

@onready var balloon = preload("res://dialogue/balloon.tscn").instantiate()
var dialogue_res = preload("res://dialogue/main.dialogue")

# Main office nodes used for camera movement, bookshelf input, and player return.
@onready var bookshelf_trigger: Area2D = $officebg/bookshelf/Area2D
@onready var office_camera: Camera2D = $Camera2D
@onready var bookshelf_focus_point: Marker2D = $officebg/bookshelf/FocusPoint
@onready var player: CharacterBody2D = $player
@onready var paper_instance: Node2D = $officebg/Node2D
@onready var exit_choice_area: Area2D = $exit/Area2D
@onready var books_instance: Node2D = $books

# Faculty is controlled by the office scene so he can leave once and stay gone.
@onready var faculty: CharacterBody2D = $officebg/Faculty

# Area that detects when Caleb is close enough to inspect the bookshelf papers.
@onready var bookshelf_near_area: Area2D = $officebg/bookshelf/NearArea

# Scene paths used when the office sends the player to another scene.
const OFFICE_SCENE_PATH := "res://scenes/minigames/office.tscn"
const QUESTONHALL_SCENE_PATH := "res://scenes/levels/level1_questonhall.tscn"
const PERSEVERE_MINIGAME_SCENE_PATH := "res://scenes/minigames/minigame_persevere.tscn"
const ARTIFACT_1_SCENE := preload("res://scenes/minigames/artifact_1.tscn")
const CONGRATS_SCENE := preload("res://scenes/minigames/congrats.tscn")
const POPUP_OPEN_DURATION := 2.0
const POPUP_START_SCALE := 0.15
const REWARD_BACKDROP_ALPHA := 0.62
const REWARD_BACKDROP_FADE_DURATION := 0.2

# Faculty leave animation settings.
const FACULTY_LEAVE_WALK_DISTANCE := 1400.0
const FACULTY_LEAVE_WALK_DURATION := 4.0

# Story flags and dialogue titles that keep the office sequence from repeating.
const OFFICE_FACULTY_LEAVE_COMPLETED_FLAG := "office_faculty_leave_completed"
const FACULTY_ESCORT_PAUSE_DIALOGUE_TITLE := "faculty_escort_pause"
const FACULTY_LEAVE_DIALOGUE_TITLE := "faculty_leave"

# Dialogue shown when Caleb gets close enough to the bookshelf papers.
const BOOKSHELF_INTRO_DIALOGUE_TITLE := "bookshelf_papers_intro"
const BOOKSHELF_INTRO_TRIGGER_ID := "office_bookshelf_papers_intro"
const BOOKSHELF_INTRO_AFTER_MINIGAME_TRIGGER_ID := "office_bookshelf_papers_intro_after_minigame"

# Bookshelf interaction bounds and camera zoom values.
const BOOKSHELF_NEAR_AREA_POSITION := Vector2(200.0, -10.0)
const BOOKSHELF_NEAR_AREA_SIZE := Vector2(900.0, 634.0)
const BOOKSHELF_ZOOM_IN := Vector2(2.0, 2.0)
const BOOKSHELF_ZOOM_DURATION := 1.6

# Tracks which dialogue flow currently owns the office.
var active_office_dialogue_mode: String = ""
var bookshelf_zoomed: bool = false

# Tracks Caleb's proximity and cursor state for the bookshelf papers.
var caleb_near_bookshelf: bool = false
var mouse_over_bookshelf_mess: bool = false
var active_artifact_1: Node2D = null
var active_congrats: Node2D = null
var clicked_reward_amphora: Node2D = null
var active_reward_backdrop: ColorRect = null
var bookshelf_echo_waiting_for_minigame_click := false
var bookshelf_echo_continuing_to_minigame := false

func _ready() -> void:
	# Add the dialogue balloon used by all office conversations.
	add_child(balloon)

	_prepare_office_books_sequence()

	# Make the office camera active when this scene loads.
	if office_camera:
		office_camera.make_current()

	# Put Caleb back where he stood before entering Persevere.
	if _has_saved_office_minigame_placement():
		_restore_office_minigame_placement()

	# Hide amphoras before Persevere, then reveal exactly one after Persevere.
	_refresh_office_amphoras()
	_refresh_office_paper_visibility()

	# Remove the faculty immediately if the story already says he left.
	var faculty_already_left := GameState.get_story_flag(OFFICE_FACULTY_LEAVE_COMPLETED_FLAG)
	if faculty_already_left:
		_remove_office_faculty()
		_clear_stale_faculty_dialogue()
	else:
		_hold_faculty_in_office()

	# Listen for dialogue mutation choices such as leaving or staying.
	if not DialogueManager.mutated.is_connected(_on_dialogue_mutated):
		DialogueManager.mutated.connect(_on_dialogue_mutated)

	# Prepare the bookshelf click target and hover cursor.
	if bookshelf_trigger:
		bookshelf_trigger.input_pickable = true
		bookshelf_trigger.collision_layer = 1
		bookshelf_trigger.collision_mask = 0

		if not bookshelf_trigger.input_event.is_connected(_on_bookshelf_trigger_input_event):
			bookshelf_trigger.input_event.connect(_on_bookshelf_trigger_input_event)

		if not bookshelf_trigger.mouse_entered.is_connected(_on_bookshelf_mess_mouse_entered):
			bookshelf_trigger.mouse_entered.connect(_on_bookshelf_mess_mouse_entered)

		if not bookshelf_trigger.mouse_exited.is_connected(_on_bookshelf_mess_mouse_exited):
			bookshelf_trigger.mouse_exited.connect(_on_bookshelf_mess_mouse_exited)

	# Prepare the bookshelf proximity area used before Caleb can start the minigame.
	if bookshelf_near_area:
		bookshelf_near_area.input_pickable = false
		bookshelf_near_area.collision_mask = 2
		bookshelf_near_area.monitoring = true
		bookshelf_near_area.monitorable = true
		_configure_bookshelf_near_area_shape()

		if not bookshelf_near_area.body_entered.is_connected(_on_bookshelf_near_area_body_entered):
			bookshelf_near_area.body_entered.connect(_on_bookshelf_near_area_body_entered)

		if not bookshelf_near_area.body_exited.is_connected(_on_bookshelf_near_area_body_exited):
			bookshelf_near_area.body_exited.connect(_on_bookshelf_near_area_body_exited)

		call_deferred("_refresh_bookshelf_near_area")

	# Prepare the office exit area so the leave/stay prompt appears when Caleb reaches it.
	if exit_choice_area:
		exit_choice_area.input_pickable = false
		exit_choice_area.collision_mask = 2
		exit_choice_area.monitoring = true
		exit_choice_area.monitorable = true

		if not exit_choice_area.body_entered.is_connected(_on_exit_choice_area_body_entered):
			exit_choice_area.body_entered.connect(_on_exit_choice_area_body_entered)

		call_deferred("_refresh_exit_choice_area")

	# Continue any faculty dialogue that was intentionally queued before this scene loaded.
	if not GameState.pending_office_dialogue_title.is_empty():
		if GameState.pending_office_dialogue_title == FACULTY_LEAVE_DIALOGUE_TITLE:
			active_office_dialogue_mode = "escort_leave"
		else:
			active_office_dialogue_mode = "escort_pause"

		call_deferred("_start_pending_office_dialogue")
		return

	# After Persevere, wait for the player to interact with the artifact or the exit area.
	if _is_post_minigame_office_active():
		return

	# Once the faculty has left, do not restart his office sequence on re-entry.
	if faculty_already_left:
		return

	# First office visit starts with the faculty pause dialogue.
	GameState.pending_office_dialogue_title = FACULTY_ESCORT_PAUSE_DIALOGUE_TITLE
	active_office_dialogue_mode = "escort_pause"
	call_deferred("_start_pending_office_dialogue")


func _input(event: InputEvent) -> void:
	# Handles office clicks that might not arrive through Area2D input signals.
	if event is not InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	if _try_handle_amphora_click_at_mouse():
		return

	if _is_mouse_inside_bookshelf_trigger():
		_handle_bookshelf_mess_click()


func _on_bookshelf_trigger_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# Handles direct clicks on the bookshelf paper hitbox.
	if event is not InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	_handle_bookshelf_mess_click()


func _handle_bookshelf_mess_click() -> void:
	# Starts the bookshelf zoom and Persevere minigame when all story checks pass.
	if bookshelf_zoomed:
		return

	if not _can_click_bookshelf_mess():
		return

	bookshelf_echo_waiting_for_minigame_click = false
	bookshelf_echo_continuing_to_minigame = true
	bookshelf_zoomed = true
	GameState.office_post_minigame_choice_pending = true
	_refresh_office_paper_visibility()

	var target_position := _get_bookshelf_trigger_focus_position()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.parallel().tween_property(office_camera, "global_position", target_position, BOOKSHELF_ZOOM_DURATION)
	tween.parallel().tween_property(office_camera, "zoom", BOOKSHELF_ZOOM_IN, BOOKSHELF_ZOOM_DURATION)
	await tween.finished
	_launch_bookshelf_minigame()


func _can_click_bookshelf_mess() -> bool:
	# Keeps click checks readable for cursor updates and input handlers.
	return _get_bookshelf_click_block_reason().is_empty()


func _get_bookshelf_click_block_reason() -> String:
	# Returns a human-readable reason why the bookshelf cannot be clicked yet.
	if not caleb_near_bookshelf:
		return "Caleb/player is not near NearArea"

	if GameState.pending_office_dialogue_title != "":
		return "pending dialogue = %s" % GameState.pending_office_dialogue_title

	if active_office_dialogue_mode != "":
		return "active dialogue mode = %s" % active_office_dialogue_mode

	if GameState.office_post_minigame_choice_pending:
		return "office_post_minigame_choice_pending is true"

	if GameState.persevere_minigame_completed:
		return "persevere_minigame_completed is true"

	if bookshelf_zoomed:
		return "bookshelf is already zooming"

	return ""


func _on_bookshelf_mess_mouse_entered() -> void:
	# Tracks the mouse entering the bookshelf paper hitbox.
	mouse_over_bookshelf_mess = true
	_update_bookshelf_cursor()


func _on_bookshelf_mess_mouse_exited() -> void:
	# Tracks the mouse leaving the bookshelf paper hitbox.
	mouse_over_bookshelf_mess = false
	_update_bookshelf_cursor()


func _update_bookshelf_cursor() -> void:
	# Shows the hand cursor only when the bookshelf can actually be clicked.
	if mouse_over_bookshelf_mess and _can_click_bookshelf_mess():
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _has_saved_office_minigame_placement() -> bool:
	# Caleb has a saved return position only when Persevere was launched from this office.
	return GameState.persevere_minigame_return_scene == OFFICE_SCENE_PATH and GameState.player_return_position != null


func _save_office_minigame_placement() -> void:
	# Save Caleb's spot before switching to the Persevere minigame.
	if player:
		GameState.player_return_position = player.global_position


func _restore_office_minigame_placement() -> void:
	# Restore Caleb after Persevere without touching authored amphora positions.
	if player and GameState.player_return_position != null:
		player.global_position = GameState.player_return_position
		if player.has_method("set_input_enabled"):
			player.set_input_enabled(true)
		GameState.player_return_position = null


func _is_post_minigame_office_active() -> bool:
	# Post-Persevere office interactions are available only after returning here from the minigame.
	return GameState.office_post_minigame_choice_pending and GameState.persevere_minigame_completed and GameState.persevere_minigame_return_scene == OFFICE_SCENE_PATH


func _refresh_office_paper_visibility() -> void:
	# The loose paper disappears once the Persevere minigame flow has started.
	if paper_instance:
		paper_instance.visible = not (GameState.office_post_minigame_choice_pending or GameState.persevere_minigame_completed)


func _refresh_office_amphoras() -> void:
	# Hide every amphora before Persevere; after Persevere, reveal only one authored amphora.
	var amphora_nodes := _get_office_amphoras()
	if amphora_nodes.is_empty():
		GameState.office_visible_amphora_name = ""
		return

	if not GameState.persevere_minigame_completed:
		GameState.office_visible_amphora_name = ""
		for amphora_node in amphora_nodes:
			_set_amphora_enabled(amphora_node, false)
		return

	# Pick the visible amphora only once so it stays consistent while the office remains loaded.
	if GameState.office_visible_amphora_name.is_empty() or not _has_amphora_named(amphora_nodes, GameState.office_visible_amphora_name):
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var selected_amphora := amphora_nodes[rng.randi_range(0, amphora_nodes.size() - 1)] as Node2D
		GameState.office_visible_amphora_name = String(selected_amphora.name)

	for node in get_tree().get_nodes_in_group("office_amphora"):
		var amphora_node := node as Node2D
		if not amphora_node:
			continue

		_set_amphora_enabled(amphora_node, String(amphora_node.name) == GameState.office_visible_amphora_name)


func _get_office_amphoras() -> Array:
	# Finds every placed amphora instance in the office scene.
	var amphora_nodes := []
	for node in get_tree().get_nodes_in_group("office_amphora"):
		var amphora_node := node as Node2D
		if amphora_node:
			amphora_nodes.append(amphora_node)
	return amphora_nodes


func _has_amphora_named(amphora_nodes: Array, amphora_name: String) -> bool:
	# Checks whether the saved visible amphora still exists in this scene.
	for amphora_node in amphora_nodes:
		if String(amphora_node.name) == amphora_name:
			return true
	return false


func _set_amphora_enabled(amphora_node: Node2D, enabled: bool) -> void:
	# Toggles visibility and collision without changing the amphora's authored transform.
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
	# Shows the artifact only when the currently visible post-Persevere amphora is clicked.
	if not _is_post_minigame_office_active():
		return

	if active_office_dialogue_mode != "" or GameState.pending_office_dialogue_title != "":
		return

	if String(amphora_node.name) != GameState.office_visible_amphora_name:
		return

	if amphora_node.has_method("reset_hover_feedback"):
		amphora_node.reset_hover_feedback()

	clicked_reward_amphora = amphora_node
	_show_artifact_1()


func _try_handle_amphora_click_at_mouse() -> bool:
	# Backup click path in case the amphora Area2D does not emit input_event.
	if not _is_post_minigame_office_active():
		return false

	var clicked_amphora := _get_amphora_at_point(get_global_mouse_position())
	if not clicked_amphora:
		return false

	_on_amphora_clicked(clicked_amphora)
	return true


func _get_amphora_at_point(global_point: Vector2) -> Node2D:
	# Uses the physics world to find an enabled amphora Area2D under the mouse.
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


func _show_artifact_1() -> void:
	# Displays the artifact card in the office instead of opening the leave/stay dialogue.
	if active_artifact_1 and is_instance_valid(active_artifact_1):
		return

	_show_reward_backdrop()

	active_artifact_1 = ARTIFACT_1_SCENE.instantiate() as Node2D
	if not active_artifact_1:
		_hide_reward_backdrop()
		return

	add_child(active_artifact_1)
	active_artifact_1.z_index = 100
	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(false)

	if office_camera:
		active_artifact_1.global_position = office_camera.get_screen_center_position()
	else:
		active_artifact_1.global_position = player.global_position if player else Vector2.ZERO

	_play_popup_open_transition(active_artifact_1)

	if active_artifact_1.has_signal("artifact_closed"):
		active_artifact_1.connect("artifact_closed", Callable(self, "_on_artifact_1_closed"), CONNECT_ONE_SHOT)

	_show_congrats()


func _on_artifact_1_closed() -> void:
	active_artifact_1 = null
	_restore_player_input_after_artifact_popups()


func _show_congrats() -> void:
	if active_congrats and is_instance_valid(active_congrats):
		return

	_show_reward_backdrop()
	_hide_clicked_reward_amphora()

	active_congrats = CONGRATS_SCENE.instantiate() as Node2D
	if not active_congrats:
		_hide_reward_backdrop()
		return

	add_child(active_congrats)
	active_congrats.z_index = 101

	if office_camera:
		active_congrats.global_position = office_camera.get_screen_center_position()
	else:
		active_congrats.global_position = player.global_position if player else Vector2.ZERO

	_play_popup_open_transition(active_congrats)

	if active_congrats.has_signal("artifact_closed"):
		active_congrats.connect("artifact_closed", Callable(self, "_on_congrats_closed"), CONNECT_ONE_SHOT)


func _on_congrats_closed() -> void:
	active_congrats = null
	_restore_player_input_after_artifact_popups()


func _hide_clicked_reward_amphora() -> void:
	if not clicked_reward_amphora or not is_instance_valid(clicked_reward_amphora):
		return

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
	add_child(active_reward_backdrop)
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
	var backdrop_center := Vector2.ZERO

	if office_camera:
		backdrop_size /= office_camera.zoom
		backdrop_center = office_camera.get_screen_center_position()
	else:
		backdrop_center = player.global_position if player else Vector2.ZERO

	active_reward_backdrop.size = backdrop_size
	active_reward_backdrop.global_position = backdrop_center - backdrop_size * 0.5


func _get_amphora_from_collider(collider: Node) -> Node2D:
	# Walks up from the clicked Area2D to its office amphora instance.
	var current_node := collider
	while current_node:
		if current_node.is_in_group("office_amphora"):
			return current_node as Node2D
		current_node = current_node.get_parent()

	return null


func _is_mouse_inside_bookshelf_trigger() -> bool:
	# Extra rectangle check for clicks that pass through the general input route.
	if not bookshelf_trigger:
		return false

	var collision_shape := bookshelf_trigger.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not collision_shape:
		return false

	var rectangle_shape := collision_shape.shape as RectangleShape2D
	if not rectangle_shape:
		return false

	var local_mouse_position := collision_shape.to_local(get_global_mouse_position())
	var rectangle := Rect2(-rectangle_shape.size * 0.5, rectangle_shape.size)
	return rectangle.has_point(local_mouse_position)


func _get_bookshelf_trigger_focus_position() -> Vector2:
	# Chooses the best camera target for the bookshelf zoom.
	if not bookshelf_trigger:
		return bookshelf_focus_point.global_position if bookshelf_focus_point else Vector2.ZERO

	var collision_shape := bookshelf_trigger.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape:
		return collision_shape.global_position

	return bookshelf_focus_point.global_position if bookshelf_focus_point else bookshelf_trigger.global_position


func _configure_bookshelf_near_area_shape() -> void:
	# Keeps the bookshelf proximity area aligned with the authored office layout.
	var collision_shape := bookshelf_near_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not collision_shape:
		return

	collision_shape.position = BOOKSHELF_NEAR_AREA_POSITION

	var rectangle_shape := collision_shape.shape as RectangleShape2D
	if rectangle_shape:
		rectangle_shape.size = BOOKSHELF_NEAR_AREA_SIZE


func _is_player(body: Node) -> bool:
	# Accepts the player even if the scene uses a different casing or node name.
	return body.is_in_group("Player") or body.is_in_group("player") or body.name == "Caleb" or body.name == "player"


func _refresh_bookshelf_near_area() -> void:
	# Checks if Caleb already overlaps the bookshelf area when the office scene finishes loading.
	await get_tree().physics_frame

	if not bookshelf_near_area:
		return

	for body in bookshelf_near_area.get_overlapping_bodies():
		if _is_player(body):
			caleb_near_bookshelf = true
			_update_bookshelf_cursor()

			if _can_start_bookshelf_intro_dialogue():
				_start_bookshelf_intro_dialogue()

			return


func _on_bookshelf_near_area_body_entered(body: Node2D) -> void:
	# Marks Caleb as close enough to inspect the bookshelf papers.
	if not _is_player(body):
		return

	caleb_near_bookshelf = true
	_update_bookshelf_cursor()

	if _can_start_bookshelf_intro_dialogue():
		_start_bookshelf_intro_dialogue()


func _on_bookshelf_near_area_body_exited(body: Node2D) -> void:
	# Removes bookshelf click access once Caleb walks away.
	if not _is_player(body):
		return

	caleb_near_bookshelf = false
	_update_bookshelf_cursor()
	_stop_bookshelf_echo_if_minigame_was_not_clicked()


func _try_start_bookshelf_intro_if_caleb_is_near() -> void:
	# Starts the bookshelf intro after the faculty leaves if Caleb is already standing nearby.
	await get_tree().physics_frame

	if not caleb_near_bookshelf:
		return

	if not _can_start_bookshelf_intro_dialogue():
		return

	_start_bookshelf_intro_dialogue()


func _can_start_bookshelf_intro_dialogue() -> bool:
	# Prevents the bookshelf intro from interrupting another office sequence.
	if GameState.pending_office_dialogue_title != "":
		return false

	if active_office_dialogue_mode != "":
		return false

	if GameState.persevere_minigame_completed or _is_post_minigame_office_active():
		return false

	return true


func _get_bookshelf_intro_trigger_id() -> String:
	if GameState.office_post_minigame_choice_pending or _is_post_minigame_office_active():
		return BOOKSHELF_INTRO_AFTER_MINIGAME_TRIGGER_ID

	if GameState.persevere_minigame_completed and GameState.persevere_minigame_return_scene == OFFICE_SCENE_PATH:
		return BOOKSHELF_INTRO_AFTER_MINIGAME_TRIGGER_ID

	return BOOKSHELF_INTRO_TRIGGER_ID


func _start_bookshelf_intro_dialogue() -> void:
	# Opens the dialogue that points Caleb toward the bookshelf papers.
	active_office_dialogue_mode = "bookshelf_near_intro"
	bookshelf_echo_waiting_for_minigame_click = false
	bookshelf_echo_continuing_to_minigame = false
	_connect_dialogue_ended_once()
	GameState.start_cultural_echo_bgm()
	balloon.show()
	balloon.start(dialogue_res, BOOKSHELF_INTRO_DIALOGUE_TITLE)


func _start_pending_office_dialogue() -> void:
	# Opens a faculty dialogue that was queued before the office loaded.
	if GameState.pending_office_dialogue_title.is_empty():
		return

	if GameState.pending_office_dialogue_title == FACULTY_ESCORT_PAUSE_DIALOGUE_TITLE:
		_set_player_input_enabled(false)
		_face_player_right()
		_play_player_animation("idle_books")

	_connect_dialogue_ended_once()

	balloon.show()
	balloon.start(dialogue_res, GameState.pending_office_dialogue_title)


func _start_post_minigame_choice_dialogue() -> void:
	# Opens the leave/stay choice when Caleb reaches the office exit.
	_connect_dialogue_ended_once()

	balloon.show()
	balloon.start(dialogue_res, "office_post_minigame_choice")


func _connect_dialogue_ended_once() -> void:
	# Ensures only one office dialogue-ended callback is active at a time.
	if DialogueManager.dialogue_ended.is_connected(_on_office_dialogue_ended):
		DialogueManager.dialogue_ended.disconnect(_on_office_dialogue_ended)

	DialogueManager.dialogue_ended.connect(_on_office_dialogue_ended, CONNECT_ONE_SHOT)


func _launch_bookshelf_minigame() -> void:
	# Saves the office return point, then switches to Persevere.
	_save_office_minigame_placement()
	GameState.persevere_minigame_return_scene = OFFICE_SCENE_PATH
	get_tree().change_scene_to_file(PERSEVERE_MINIGAME_SCENE_PATH)


func _on_office_dialogue_ended(_resource: DialogueResource) -> void:
	# Advances whichever office dialogue sequence just finished.
	if active_office_dialogue_mode == "bookshelf_near_intro":
		active_office_dialogue_mode = ""
		bookshelf_echo_waiting_for_minigame_click = true
		if not caleb_near_bookshelf:
			_stop_bookshelf_echo_if_minigame_was_not_clicked()
		_update_bookshelf_cursor()
		return

	if active_office_dialogue_mode == "escort_pause":
		GameState.pending_office_dialogue_title = FACULTY_LEAVE_DIALOGUE_TITLE
		active_office_dialogue_mode = "escort_leave"
		call_deferred("_start_pending_office_dialogue")
		return

	if active_office_dialogue_mode == "escort_leave":
		GameState.pending_office_dialogue_title = ""
		active_office_dialogue_mode = ""
		GameState.set_story_flag(OFFICE_FACULTY_LEAVE_COMPLETED_FLAG, true)
		_animate_faculty_leave()
		_set_player_input_enabled(true)

		call_deferred("_try_start_bookshelf_intro_if_caleb_is_near")
		call_deferred("_refresh_exit_choice_area")

		return

	if active_office_dialogue_mode == "return_choice":
		active_office_dialogue_mode = ""

		if GameState.office_leave_requested:
			GameState.office_leave_requested = false
			GameState.office_post_minigame_choice_pending = false
			GameState.stop_cultural_echo_bgm()
			if not GameState.persevere_minigame_completed:
				GameState.trigger_level1_minigame_on_return = true
				GameState.persevere_minigame_return_scene = QUESTONHALL_SCENE_PATH
				GameState.player_return_position = Vector2(1230, -180)
			get_tree().change_scene_to_file(QUESTONHALL_SCENE_PATH)

		return


func _on_exit_choice_area_body_entered(body: Node2D) -> void:
	# Replays the leave/stay prompt every time Caleb walks into the office exit area.
	if not _is_player(body):
		return

	if not _can_start_exit_choice_dialogue():
		return

	active_office_dialogue_mode = "return_choice"
	_start_post_minigame_choice_dialogue()


func _on_area_2d_body_entered(body: Node2D) -> void:
	# Matches the editor-connected signal on exit/Area2D.
	_on_exit_choice_area_body_entered(body)


func _refresh_exit_choice_area() -> void:
	# Starts the exit choice if Caleb is already overlapping the exit after scene load.
	await get_tree().physics_frame

	if not exit_choice_area:
		return

	for body in exit_choice_area.get_overlapping_bodies():
		if _is_player(body):
			_on_exit_choice_area_body_entered(body)
			return


func start_office_exit_choice_dialogue_from_trigger(body: Node2D) -> void:
	_on_exit_choice_area_body_entered(body)


func _can_start_exit_choice_dialogue() -> bool:
	if not GameState.get_story_flag(OFFICE_FACULTY_LEAVE_COMPLETED_FLAG):
		return false

	if active_artifact_1 and is_instance_valid(active_artifact_1):
		return false

	if GameState.pending_office_dialogue_title != "":
		return false

	if active_office_dialogue_mode != "":
		return false

	return true


func _on_dialogue_mutated(data: Dictionary) -> void:
	# Records the player's leave/stay choice from the dialogue file.
	if data.get("mutation") == "office_leave":
		GameState.office_leave_requested = true
	elif data.get("mutation") == "office_stay":
		GameState.office_leave_requested = false
	elif data.get("mutation") == "faculty_cultural_echo_start":
		GameState.start_cultural_echo_bgm()
	elif data.get("mutation") == "faculty_pause_sound_stop":
		_show_books_after_faculty_instruction()


func _hold_faculty_in_office() -> void:
	# Freezes the faculty instance so only the office script controls his sequence.
	if not faculty:
		return

	faculty.set_physics_process(false)
	_hide_office_faculty_prompt()

	if faculty.has_method("play_animation"):
		faculty.play_animation("idle")


func _prepare_office_books_sequence() -> void:
	var faculty_books_already_placed := GameState.get_story_flag(OFFICE_FACULTY_LEAVE_COMPLETED_FLAG)
	if books_instance:
		books_instance.visible = faculty_books_already_placed

	if not faculty_books_already_placed and not GameState.persevere_minigame_completed:
		_set_player_input_enabled(false)
		_face_player_right()
		_play_player_animation("idle_books")
		call_deferred("_play_player_animation", "idle_books")


func _show_books_after_faculty_instruction() -> void:
	if active_office_dialogue_mode != "escort_pause":
		return

	_face_player_right()
	_play_player_animation("idle")

	if books_instance:
		books_instance.visible = true


func _stop_bookshelf_echo_if_minigame_was_not_clicked() -> void:
	if not bookshelf_echo_waiting_for_minigame_click:
		return

	if bookshelf_echo_continuing_to_minigame:
		return

	bookshelf_echo_waiting_for_minigame_click = false
	GameState.stop_cultural_echo_bgm()


func _play_player_animation(animation_name: String) -> void:
	if not player:
		return

	var player_sprite := player.get_node_or_null("Sprite2D") as AnimatedSprite2D
	if player_sprite and player_sprite.animation != animation_name:
		player_sprite.play(animation_name)


func _face_player_right() -> void:
	if not player:
		return

	player.set("facing_direction", 1)
	var player_sprite := player.get_node_or_null("Sprite2D") as AnimatedSprite2D
	if player_sprite:
		player_sprite.flip_h = true


func _set_player_input_enabled(enabled: bool) -> void:
	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(enabled)


func _remove_office_faculty() -> void:
	# Removes a newly loaded faculty instance after the story says he already left.
	if not faculty:
		return

	faculty.hide()
	faculty.set_physics_process(false)
	faculty.queue_free()


func _clear_stale_faculty_dialogue() -> void:
	# Clears queued faculty dialogue so it cannot replay after the faculty has left.
	if GameState.pending_office_dialogue_title == FACULTY_ESCORT_PAUSE_DIALOGUE_TITLE or GameState.pending_office_dialogue_title == FACULTY_LEAVE_DIALOGUE_TITLE:
		GameState.pending_office_dialogue_title = ""
		active_office_dialogue_mode = ""


func _hide_office_faculty_prompt() -> void:
	# Disables the faculty's normal NPC interaction prompt inside the office cutscene.
	var interaction_label := faculty.get_node_or_null("Label") as Label
	if interaction_label:
		interaction_label.hide()

	var encounter_area := faculty.get_node_or_null("EncounterArea") as Area2D
	if encounter_area:
		encounter_area.monitoring = false
		encounter_area.monitorable = false


func _animate_faculty_leave() -> void:
	# Plays the faculty walk-out and deletes him when the animation tween finishes.
	if not faculty:
		return

	if faculty.has_method("play_animation"):
		faculty.play_animation("walking")

	var animated_sprites := faculty.find_children("*", "AnimatedSprite2D", true, false)
	if animated_sprites.size() > 0:
		var animated_sprite := animated_sprites[0] as AnimatedSprite2D
		if animated_sprite:
			animated_sprite.flip_h = true

	var leave_tween := create_tween()
	leave_tween.set_trans(Tween.TRANS_SINE)
	leave_tween.set_ease(Tween.EASE_IN_OUT)
	leave_tween.tween_property(
		faculty,
		"global_position",
		faculty.global_position + Vector2(FACULTY_LEAVE_WALK_DISTANCE, 0.0),
		FACULTY_LEAVE_WALK_DURATION
	)

	leave_tween.finished.connect(faculty.queue_free, CONNECT_ONE_SHOT)
