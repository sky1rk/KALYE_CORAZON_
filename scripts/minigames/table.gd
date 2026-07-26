extends Node2D

const PUZZLE_MINIGAME_SCENE_PATH := "res://scenes/minigames/minigame_puzzle.tscn"
const TABLE_SCENE_PATH := "res://scenes/minigames/table.tscn"
const CALLE_REAL_SCENE_PATH := "res://scenes/levels/level2_callereal.tscn"
const CALLE_REAL_TABLE_RETURN_POSITION := Vector2(-143, 620)
const CALLE_REAL_TABLE_FRONT_POSITION := Vector2(-83, 689)
const TABLE_PLAYER_CENTER_POSITION := Vector2(1080, 704)
const TABLE_PUZZLE_STARTED_FLAG := "table_puzzle_started"
const TABLE_PUZZLE_FINISHED_FLAG := "table_puzzle_finished"
const LEVEL2_PUNDONG_REWARD_COLLECTED_FLAG := "level2_pundong_reward_collected"
const PUZZLE_INTRO_TRIGGER_ID := "puzzle_intro_table"
const STACKED_PHOTOS_DIALOGUE_DISTANCE := 240.0
const ARTIFACT_2_SCENE := preload("res://scenes/minigames/artifact_2.tscn")
const CONGRATS_SCENE := preload("res://scenes/minigames/congrats.tscn")
const POPUP_OPEN_DURATION := 0.18
const POPUP_START_SCALE := 0.88
const REWARD_BACKDROP_ALPHA := 0.55
const REWARD_BACKDROP_FADE_DURATION := 0.18

@onready var scene_camera: Camera2D = $Camera2D
@onready var player: CharacterBody2D = get_node_or_null("player") as CharacterBody2D
@onready var player_camera: Camera2D = get_node_or_null("player/Camera2D") as Camera2D
@onready var vendor: Node2D = get_node_or_null("vendor") as Node2D
@onready var vendor_area: Area2D = get_node_or_null("vendor/EncounterArea") as Area2D
@onready var vendor_prompt: Label = get_node_or_null("vendor/Label") as Label
@onready var stacked_photos: Node2D = $stackedphotos
@onready var stacked_photos_sprite: Sprite2D = $stackedphotos/photos/Sprite2D
@onready var stacked_photos_area: Area2D = $stackedphotos/photos/Area2D
@onready var stacked_photos_collision: CollisionShape2D = $stackedphotos/photos/Area2D/CollisionShape2D
@onready var balloon = preload("res://dialogue/balloon.tscn").instantiate()

var dialogue_res: DialogueResource = preload("res://dialogue/main.dialogue")
var stacked_photos_sprite_base_scale := Vector2.ONE
var stacked_photos_tween: Tween = null
var opening_puzzle := false
var returning_to_calle_real := false
var return_to_calle_real_after_dialogue := false
var vendor_interaction_active := false
var vendor_interaction_pending := false
var vendor_choice_open := false
var visible_pundong: Node2D = null
var hovered_pundong: Node2D = null
var pundong_base_scales: Dictionary = {}
var pundong_tween: Tween = null
var active_artifact_2: Node2D = null
var active_congrats: Node2D = null
var active_reward_backdrop: ColorRect = null
var reward_popup_layer: CanvasLayer = null
var stacked_photos_hovered := false
var stacked_photos_dialogue_active := false
var stacked_photos_near_player := false
var vendor_intro_active := false
var vendor_intro_finished := false


func _ready() -> void:
	if player_camera:
		player_camera.enabled = false

	if scene_camera:
		scene_camera.enabled = true
		scene_camera.make_current()
		scene_camera.zoom = Vector2.ONE
		scene_camera.global_position = Vector2(960, 540)

	_setup_stacked_photos_interaction()
	_setup_vendor_interaction()
	_connect_dialogue_mutations()
	_update_pundong_visibility()
	_setup_pundong_interactions()
	_play_pundong_animations()
	_place_player_after_table_puzzle()

	add_child(balloon)
	if not GameState.get_story_flag(TABLE_PUZZLE_STARTED_FLAG):
		call_deferred("_start_vendor_intro_dialogue")
	else:
		vendor_intro_finished = true


func _exit_tree() -> void:
	if not opening_puzzle and not active_congrats:
		_stop_stacked_photos_cultural_echo_if_waiting()

	if DialogueManager.mutated.is_connected(_on_dialogue_mutated):
		DialogueManager.mutated.disconnect(_on_dialogue_mutated)
	if DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.disconnect(_on_dialogue_ended)
	if DialogueManager.dialogue_ended.is_connected(_on_vendor_leave_dialogue_ended):
		DialogueManager.dialogue_ended.disconnect(_on_vendor_leave_dialogue_ended)


func _start_vendor_intro_dialogue() -> void:
	vendor_intro_active = true
	vendor_intro_finished = false
	vendor_interaction_active = false
	vendor_interaction_pending = false
	vendor_choice_open = false
	_set_vendor_prompt_visible(false)
	balloon.show()
	balloon.start(dialogue_res, "calle_real_vendor_intro")


func _connect_dialogue_mutations() -> void:
	if not DialogueManager.mutated.is_connected(_on_dialogue_mutated):
		DialogueManager.mutated.connect(_on_dialogue_mutated)
	if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended)


func _on_dialogue_mutated(data: Dictionary) -> void:
	match data.get("mutation", ""):
		"accept_vendor_offer":
			# Stay in the table scene so the player can inspect the photos.
			vendor_interaction_pending = true
			return
		"explore_calle_real":
			vendor_interaction_pending = false
			_return_to_calle_real_when_dialogue_ends()


func _process(_delta: float) -> void:
	_update_pundong_hover()
	_update_stacked_photos_hover()
	_update_stacked_photos_proximity()

	if not vendor_interaction_active or vendor_choice_open or not vendor_area:
		return

	if Input.is_action_just_pressed("interact") and vendor_prompt and vendor_prompt.visible:
		_open_vendor_choice_dialogue()
func _input(event: InputEvent) -> void:
	if opening_puzzle or not _is_left_click(event):
		return

	var clicked_pundong := _get_visible_pundong_at_mouse()
	if clicked_pundong:
		_open_pundong_reward(clicked_pundong)
		return

	if not GameState.puzzle_minigame_completed and _is_mouse_over_stacked_photos():
		_open_puzzle_minigame()


func _setup_stacked_photos_interaction() -> void:
	stacked_photos_sprite_base_scale = stacked_photos_sprite.scale
	if GameState.puzzle_minigame_completed:
		stacked_photos_area.input_pickable = false
		return

	stacked_photos_area.input_pickable = true

	if not stacked_photos_area.mouse_entered.is_connected(_on_stacked_photos_mouse_entered):
		stacked_photos_area.mouse_entered.connect(_on_stacked_photos_mouse_entered)
	if not stacked_photos_area.mouse_exited.is_connected(_on_stacked_photos_mouse_exited):
		stacked_photos_area.mouse_exited.connect(_on_stacked_photos_mouse_exited)
	if not stacked_photos_area.input_event.is_connected(_on_stacked_photos_input_event):
		stacked_photos_area.input_event.connect(_on_stacked_photos_input_event)


func _on_stacked_photos_mouse_entered() -> void:
	_set_stacked_photos_hovered(true)


func _on_stacked_photos_mouse_exited() -> void:
	_set_stacked_photos_hovered(false)


func _on_stacked_photos_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if opening_puzzle or GameState.puzzle_minigame_completed or not _is_left_click(event):
		return

	_open_puzzle_minigame()


func _open_puzzle_minigame() -> void:
	if GameState.puzzle_minigame_completed:
		return

	opening_puzzle = true
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	get_viewport().set_input_as_handled()
	GameState.set_story_flag(TABLE_PUZZLE_STARTED_FLAG, true)
	GameState.level1_cultural_echo_active = true
	GameState.start_cultural_echo_bgm()
	GameState.puzzle_minigame_completed = true
	GameState.puzzle_minigame_return_scene = TABLE_SCENE_PATH
	GameState.player_return_position = null
	get_tree().change_scene_to_file(PUZZLE_MINIGAME_SCENE_PATH)


func _place_player_after_table_puzzle() -> void:
	if not GameState.get_story_flag(TABLE_PUZZLE_FINISHED_FLAG):
		return

	var table_player := get_node_or_null("player") as CharacterBody2D
	if not table_player:
		return

	table_player.global_position = TABLE_PLAYER_CENTER_POSITION
	if table_player.has_method("set_input_enabled"):
		table_player.set_input_enabled(true)


func _update_pundong_visibility() -> void:
	var pundong_nodes := _get_pundong_nodes()
	for pundong_node in pundong_nodes:
		pundong_node.hide()

	if GameState.get_story_flag(LEVEL2_PUNDONG_REWARD_COLLECTED_FLAG):
		return

	if not GameState.get_story_flag(TABLE_PUZZLE_FINISHED_FLAG) or pundong_nodes.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var random_index := rng.randi_range(0, pundong_nodes.size() - 1)
	visible_pundong = pundong_nodes[random_index]
	visible_pundong.show()


func _setup_pundong_interactions() -> void:
	for pundong_node in _get_pundong_nodes():
		var area := pundong_node.get_node_or_null("Area2D") as Area2D
		if not area:
			continue

		area.input_pickable = true
		var input_callable := _on_pundong_input_event.bind(pundong_node)
		var entered_callable := _on_pundong_mouse_entered.bind(pundong_node)
		var exited_callable := _on_pundong_mouse_exited.bind(pundong_node)
		if not area.input_event.is_connected(input_callable):
			area.input_event.connect(input_callable)
		if not area.mouse_entered.is_connected(entered_callable):
			area.mouse_entered.connect(entered_callable)
		if not area.mouse_exited.is_connected(exited_callable):
			area.mouse_exited.connect(exited_callable)

		pundong_base_scales[pundong_node] = pundong_node.scale


func _play_pundong_animations() -> void:
	for pundong_node in _get_pundong_nodes():
		var animated_sprite := pundong_node.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if animated_sprite:
			animated_sprite.visible = true
			animated_sprite.z_index = 1
			animated_sprite.play()


func _on_pundong_input_event(_viewport: Node, event: InputEvent, _shape_idx: int, pundong_node: Node2D) -> void:
	if not pundong_node.visible or active_artifact_2 or active_congrats:
		return
	if not _is_left_click(event):
		return

	_open_pundong_reward(pundong_node)


func _on_pundong_mouse_entered(pundong_node: Node2D) -> void:
	_set_hovered_pundong(pundong_node)


func _on_pundong_mouse_exited(pundong_node: Node2D) -> void:
	if hovered_pundong == pundong_node:
		_set_hovered_pundong(null)


func _open_pundong_reward(pundong_node: Node2D) -> void:
	if active_artifact_2 or active_congrats or not pundong_node or not is_instance_valid(pundong_node):
		return

	get_viewport().set_input_as_handled()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	visible_pundong = pundong_node
	_show_artifact_2()
	pundong_node.queue_free()


func _get_pundong_nodes() -> Array[Node2D]:
	var nodes: Array[Node2D] = []
	for node_path in ["pundong", "pundong2", "CanvasLayer/pundong1"]:
		var pundong_node := get_node_or_null(node_path) as Node2D
		if pundong_node:
			nodes.append(pundong_node)

	return nodes


func _show_artifact_2() -> void:
	if active_artifact_2 and is_instance_valid(active_artifact_2):
		return

	_show_reward_backdrop()
	active_artifact_2 = ARTIFACT_2_SCENE.instantiate() as Node2D
	if not active_artifact_2:
		_hide_reward_backdrop()
		return

	_get_reward_popup_layer().add_child(active_artifact_2)
	active_artifact_2.z_index = 100
	active_artifact_2.global_position = _get_popup_center_position()
	_play_popup_open_transition(active_artifact_2)

	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(false)

	if active_artifact_2.has_signal("artifact_closed"):
		active_artifact_2.connect("artifact_closed", Callable(self, "_on_artifact_2_closed"), CONNECT_ONE_SHOT)

	_show_congrats()


func _on_artifact_2_closed() -> void:
	active_artifact_2 = null
	_restore_player_input_after_reward_popups()


func _show_congrats() -> void:
	if active_congrats and is_instance_valid(active_congrats):
		return

	_show_reward_backdrop()
	active_congrats = CONGRATS_SCENE.instantiate() as Node2D
	if not active_congrats:
		_hide_reward_backdrop()
		return

	_get_reward_popup_layer().add_child(active_congrats)
	active_congrats.z_index = 101
	active_congrats.global_position = _get_popup_center_position()
	_play_popup_open_transition(active_congrats)

	if active_congrats.has_signal("artifact_closed"):
		active_congrats.connect("artifact_closed", Callable(self, "_on_congrats_closed"), CONNECT_ONE_SHOT)


func _on_congrats_closed() -> void:
	GameState.set_story_flag(LEVEL2_PUNDONG_REWARD_COLLECTED_FLAG, true)
	_mark_puzzle_intro_trigger_handled()
	GameState.player_return_position = CALLE_REAL_TABLE_FRONT_POSITION
	GameState.level1_cultural_echo_active = false
	GameState.stop_cultural_echo_bgm()
	active_congrats = null
	_restore_player_input_after_reward_popups()


func _restore_player_input_after_reward_popups() -> void:
	if active_artifact_2 and is_instance_valid(active_artifact_2):
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


func _return_to_calle_real() -> void:
	if returning_to_calle_real:
		return

	returning_to_calle_real = true
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if GameState.get_story_flag(TABLE_PUZZLE_STARTED_FLAG) or GameState.get_story_flag(TABLE_PUZZLE_FINISHED_FLAG):
		_mark_puzzle_intro_trigger_handled()
	else:
		GameState.clear_dialogue_trigger(PUZZLE_INTRO_TRIGGER_ID)
	GameState.player_return_position = CALLE_REAL_TABLE_RETURN_POSITION
	get_tree().change_scene_to_file(CALLE_REAL_SCENE_PATH)


func _mark_puzzle_intro_trigger_handled() -> void:
	if not GameState.is_dialogue_triggered(PUZZLE_INTRO_TRIGGER_ID):
		GameState.mark_dialogue_as_triggered(PUZZLE_INTRO_TRIGGER_ID)


func _return_to_calle_real_when_dialogue_ends() -> void:
	if return_to_calle_real_after_dialogue:
		return

	return_to_calle_real_after_dialogue = true
	if DialogueManager.dialogue_ended.is_connected(_on_vendor_leave_dialogue_ended):
		return

	DialogueManager.dialogue_ended.connect(_on_vendor_leave_dialogue_ended, CONNECT_ONE_SHOT)


func _on_dialogue_ended(_resource: DialogueResource) -> void:
	if vendor_intro_active:
		vendor_intro_active = false
		vendor_intro_finished = true

	if return_to_calle_real_after_dialogue:
		return

	if vendor_choice_open:
		vendor_choice_open = false
		return

	if vendor_interaction_pending:
		vendor_interaction_pending = false
		_enable_vendor_interaction()


func _on_vendor_leave_dialogue_ended(_resource: DialogueResource) -> void:
	call_deferred("_return_to_calle_real")


func _setup_vendor_interaction() -> void:
	if not vendor or not vendor_area or not vendor_prompt:
		return

	vendor_prompt.hide()
	vendor_area.monitoring = true
	if not vendor_area.body_entered.is_connected(_on_vendor_body_entered):
		vendor_area.body_entered.connect(_on_vendor_body_entered)
	if not vendor_area.body_exited.is_connected(_on_vendor_body_exited):
		vendor_area.body_exited.connect(_on_vendor_body_exited)

	if GameState.get_story_flag(TABLE_PUZZLE_STARTED_FLAG):
		_enable_vendor_interaction()


func _on_vendor_body_entered(body: Node2D) -> void:
	if not vendor_interaction_active or not _is_player_body(body):
		return

	vendor_prompt.show()


func _on_vendor_body_exited(body: Node2D) -> void:
	if not _is_player_body(body):
		return

	_set_vendor_prompt_visible(false)


func _enable_vendor_interaction() -> void:
	if not vendor or not vendor_area or not vendor_prompt:
		return

	vendor_interaction_active = true
	vendor_area.monitoring = true
	call_deferred("_sync_vendor_prompt_state")


func _sync_vendor_prompt_state() -> void:
	if not vendor_interaction_active or not vendor_area or not vendor_prompt:
		return

	if player and vendor_area.overlaps_body(player):
		vendor_prompt.show()
	else:
		vendor_prompt.hide()


func _set_vendor_prompt_visible(should_show: bool) -> void:
	if not vendor_prompt:
		return

	if should_show and vendor_interaction_active:
		vendor_prompt.show()
	else:
		vendor_prompt.hide()


func _open_vendor_choice_dialogue() -> void:
	if vendor_choice_open:
		return

	vendor_choice_open = true
	balloon.show()
	balloon.start(dialogue_res, "calle_real_vendor_choice")


func _is_player_body(body: Node) -> bool:
	return body == player or body.is_in_group("Player") or body.is_in_group("player") or body.name == "player" or body.name == "Caleb"
func _tween_stacked_photos_scale(target_scale: Vector2) -> void:
	if stacked_photos_tween and stacked_photos_tween.is_valid():
		stacked_photos_tween.kill()

	stacked_photos_tween = create_tween()
	stacked_photos_tween.tween_property(stacked_photos_sprite, "scale", target_scale, 0.16)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)


func _update_stacked_photos_hover() -> void:
	_set_stacked_photos_hovered(not opening_puzzle and not GameState.puzzle_minigame_completed and _is_mouse_over_stacked_photos())


func _set_stacked_photos_hovered(should_hover: bool) -> void:
	if should_hover and (opening_puzzle or GameState.puzzle_minigame_completed):
		should_hover = false

	if stacked_photos_hovered == should_hover:
		return

	stacked_photos_hovered = should_hover
	if stacked_photos_hovered:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		_tween_stacked_photos_scale(stacked_photos_sprite_base_scale * 1.08)
	else:
		if not hovered_pundong:
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		_tween_stacked_photos_scale(stacked_photos_sprite_base_scale)


func _update_stacked_photos_proximity() -> void:
	if not player or opening_puzzle or GameState.puzzle_minigame_completed:
		return
	if GameState.get_story_flag(TABLE_PUZZLE_STARTED_FLAG):
		return
	if not vendor_intro_finished:
		return

	var is_near := player.global_position.distance_to(stacked_photos.global_position) <= STACKED_PHOTOS_DIALOGUE_DISTANCE
	if stacked_photos_near_player != is_near:
		stacked_photos_near_player = is_near
		if not stacked_photos_near_player:
			_stop_stacked_photos_cultural_echo_if_waiting()
			return

	if not stacked_photos_near_player:
		return
	if balloon.visible:
		return

	_start_stacked_photos_dialogue()


func _start_stacked_photos_dialogue() -> void:
	if stacked_photos_dialogue_active:
		return

	stacked_photos_dialogue_active = true
	GameState.level1_cultural_echo_active = true
	GameState.start_cultural_echo_bgm()
	balloon.show()
	balloon.start(dialogue_res, "puzzle_table_intro")


func _stop_stacked_photos_cultural_echo_if_waiting() -> void:
	if GameState.get_story_flag(TABLE_PUZZLE_STARTED_FLAG):
		return

	stacked_photos_dialogue_active = false
	GameState.level1_cultural_echo_active = false
	GameState.stop_cultural_echo_bgm()


func _tween_pundong_scale(pundong_node: Node2D, scale_multiplier: float) -> void:
	if pundong_tween and pundong_tween.is_valid():
		pundong_tween.kill()

	var base_scale: Vector2 = pundong_base_scales.get(pundong_node, pundong_node.scale)
	pundong_tween = create_tween()
	pundong_tween.tween_property(pundong_node, "scale", base_scale * scale_multiplier, 0.16)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)


func _update_pundong_hover() -> void:
	if active_artifact_2 or active_congrats:
		_set_hovered_pundong(null)
		return

	_set_hovered_pundong(_get_visible_pundong_at_mouse())


func _set_hovered_pundong(pundong_node: Node2D) -> void:
	if pundong_node and not pundong_node.visible:
		pundong_node = null

	if hovered_pundong == pundong_node:
		return

	if hovered_pundong and is_instance_valid(hovered_pundong):
		_tween_pundong_scale(hovered_pundong, 1.0)

	hovered_pundong = pundong_node

	if hovered_pundong:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		_tween_pundong_scale(hovered_pundong, 1.08)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _is_left_click(event: InputEvent) -> bool:
	if event is not InputEventMouseButton:
		return false

	var mouse_event := event as InputEventMouseButton
	return mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed


func _is_mouse_over_stacked_photos() -> bool:
	var rectangle_shape := stacked_photos_collision.shape as RectangleShape2D
	if not rectangle_shape:
		return false

	var local_mouse_position := stacked_photos_area.to_local(get_global_mouse_position()) - stacked_photos_collision.position
	var half_size := rectangle_shape.size * 0.5
	return abs(local_mouse_position.x) <= half_size.x and abs(local_mouse_position.y) <= half_size.y


func _get_visible_pundong_at_mouse() -> Node2D:
	for pundong_node in _get_pundong_nodes():
		if not pundong_node.visible:
			continue

		var area := pundong_node.get_node_or_null("Area2D") as Area2D
		var collision := pundong_node.get_node_or_null("Area2D/CollisionShape2D") as CollisionShape2D
		if not area or not collision:
			continue

		var rectangle_shape := collision.shape as RectangleShape2D
		if not rectangle_shape:
			continue

		var local_mouse_position := area.to_local(get_global_mouse_position()) - collision.position
		var half_size := rectangle_shape.size * 0.75
		if abs(local_mouse_position.x) <= half_size.x and abs(local_mouse_position.y) <= half_size.y:
			return pundong_node

	return null
