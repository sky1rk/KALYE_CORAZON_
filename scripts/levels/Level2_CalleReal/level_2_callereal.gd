# level2_callereal.gd
extends Node2D

@export var player_scene: PackedScene
@export var cat_scene: PackedScene

const CALLE_REAL_SCENE_PATH := "res://scenes/levels/level2_callereal.tscn"
const PUZZLE_MINIGAME_SCENE_PATH := "res://scenes/minigames/minigame_puzzle.tscn"
const PUZZLE_MINIGAME_RETURN_POSITION := Vector2(57.5433, 614.273)
const CALLE_REAL_TABLE_FRONT_POSITION := Vector2(-83, 689)
const LEVEL2_PUNDONG_REWARD_COLLECTED_FLAG := "level2_pundong_reward_collected"
const ARTIFACT_2_SCENE := preload("res://scenes/minigames/artifact_2.tscn")
const CONGRATS_SCENE := preload("res://scenes/minigames/congrats.tscn")
const POPUP_OPEN_DURATION := 0.18
const POPUP_START_SCALE := 0.88
const REWARD_BACKDROP_ALPHA := 0.55
const REWARD_BACKDROP_FADE_DURATION := 0.18

@onready var bgm = $BGMPlayer
var fade_time := 2.0  # seconds for fade-in/out

var player_instance: CharacterBody2D = null
var cat_instance: CharacterBody2D = null
var visible_pundong: Node2D = null
var pundong_base_scales: Dictionary = {}
var pundong_tween: Tween = null
var active_artifact_2: Node2D = null
var active_congrats: Node2D = null
var active_reward_backdrop: ColorRect = null
var reward_popup_layer: CanvasLayer = null

@onready var balloon = preload("res://dialogue/balloon.tscn").instantiate()
var dialogue_res = preload("res://dialogue/main.dialogue")

func _ready():
	print("DEBUG: Entered Level 2 (Calle Real)!")
	GameState.level1_cultural_echo_active = false
	GameState.stop_cultural_echo_bgm()
	
	# --- LOAD SCENES IF NOT ASSIGNED IN INSPECTOR ---
	if player_scene == null:
		player_scene = preload("res://scenes/player/caleb.tscn") # TODO: update path
	if cat_scene == null:
		cat_scene = preload("res://scenes/npcs/cat.tscn")       # TODO: update path
	
	# --- PLAYER INSTANTIATION AND POSITIONING ---
	player_instance = player_scene.instantiate()
	if get_node_or_null("0"):
		get_node("0").add_child(player_instance)
	else:
		add_child(player_instance)
	
	# Apply player return position or default to Level 2 start
	if GameState.player_return_position != null:
		player_instance.global_position = GameState.player_return_position
		player_instance.set_input_enabled(true)
		var camera = player_instance.get_node_or_null("Camera2D")
		if camera:
			camera.zoom = Vector2.ONE
			camera.reset_smoothing()
		GameState.player_return_position = null
	else:
		player_instance.global_position = Vector2(1394, 683)
		player_instance.set_input_enabled(true)
	
	# --- CAT SPAWNING LOGIC ---
	if GameState.cat_is_following_globally:
		print("DEBUG: Cat is following. Spawning cat in Level 2.")
		cat_instance = cat_scene.instantiate()
		
		if get_node_or_null("0"):
			get_node("0").add_child(cat_instance)
		else:
			add_child(cat_instance)
		
		var cat_spawn_offset = Vector2(player_instance.facing_direction * cat_instance.FOLLOW_DISTANCE, 0)
		cat_instance.global_position = player_instance.global_position + cat_spawn_offset
		
		if player_instance.facing_direction < 0:
			cat_instance.animated_sprite.flip_h = true
		else:
			cat_instance.animated_sprite.flip_h = false
		
		if cat_instance.has_method("start_following"):
			cat_instance.start_following(player_instance)
	else:
		print("DEBUG: Cat is NOT following in Level 2.")
	
	# --- ADD THE DIALOGUE BALLOON TO THE SCENE TREE ---
	add_child(balloon) # <--- THIS IS THE MISSING LINE!
	DialogueManager.mutated.connect(_on_dialogue_mutated) # Connect this here as well for consistency

	# --- Transition Zones ---
	call_deferred("_setup_transition_connections")
	_setup_minigame_trigger()
	_update_pundong_visibility()
	_setup_pundong_interactions()
	
	# --- BGM Fade In ---
	if bgm:
		bgm.volume_db = -40  # Start nearly silent
		bgm.play()
		var t = create_tween()
		t.tween_property(bgm, "volume_db", 0, fade_time)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)

# --- Transition Back to Level 1 ---
func _on_level1_transition_triggered(transition_data: Dictionary):
	print("DEBUG: _on_level1_transition_triggered called!")
	GameState.returning_from_level = "level2"
	GameState.player_return_position = Vector2(-1764, 689)
	print("DEBUG: Set player_return_position to: ", GameState.player_return_position)

func _setup_transition_connections():
	print("DEBUG: Setting up transition connections")
	for zone in get_tree().get_nodes_in_group("TransitionZones"):
		print("DEBUG: Found TransitionZone with target_scene_path: ", zone.target_scene_path)
		if zone.target_scene_path == "uid://20l8s8unujh4":
			print("DEBUG: Connecting to Level 1 transition zone")
			zone.player_entered_zone.connect(_on_level1_transition_triggered)
			break

# --- Fade Out BGM on Exit ---
func _exit_tree():
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if bgm and bgm.playing:
		var t = create_tween()
		t.tween_property(bgm, "volume_db", -40, fade_time)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
		t.finished.connect(func():
			bgm.stop())


func _input(event: InputEvent) -> void:
	if not _is_left_click(event):
		return

	var clicked_pundong := _get_visible_pundong_at_mouse()
	if clicked_pundong:
		_open_pundong_reward(clicked_pundong)


func _setup_minigame_trigger() -> void:
	var minigame_trigger := get_node_or_null("MinigameTrigger") as Area2D
	if not minigame_trigger:
		return

	if not minigame_trigger.body_entered.is_connected(_on_minigame_trigger_body_entered):
		minigame_trigger.body_entered.connect(_on_minigame_trigger_body_entered)

	if GameState.puzzle_minigame_completed:
		_disable_minigame_trigger()


func _on_minigame_trigger_body_entered(body: Node2D) -> void:
	if GameState.puzzle_minigame_completed:
		_disable_minigame_trigger()
		return
	if body != player_instance and not body.is_in_group("Player"):
		return

	if player_instance and player_instance.has_method("set_input_enabled"):
		player_instance.set_input_enabled(false)

	GameState.puzzle_minigame_completed = true
	GameState.puzzle_minigame_return_scene = CALLE_REAL_SCENE_PATH
	GameState.player_return_position = PUZZLE_MINIGAME_RETURN_POSITION
	_disable_minigame_trigger()
	get_tree().change_scene_to_file(PUZZLE_MINIGAME_SCENE_PATH)


func _disable_minigame_trigger() -> void:
	var minigame_trigger := get_node_or_null("MinigameTrigger") as Area2D
	if not minigame_trigger:
		return

	minigame_trigger.call_deferred("set_monitoring", false)
	for child in minigame_trigger.get_children():
		if child is CollisionShape2D:
			child.call_deferred("set_disabled", true)


func _update_pundong_visibility() -> void:
	var pundong_nodes := _get_pundong_nodes()
	for pundong_node in pundong_nodes:
		pundong_node.hide()

	if GameState.get_story_flag(LEVEL2_PUNDONG_REWARD_COLLECTED_FLAG):
		return

	if not GameState.puzzle_minigame_completed or pundong_nodes.is_empty():
		return

	var random_index := randi_range(0, pundong_nodes.size() - 1)
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

		var sprite := pundong_node.get_node_or_null("Sprite2D") as Sprite2D
		if sprite:
			pundong_base_scales[pundong_node] = sprite.scale


func _on_pundong_input_event(_viewport: Node, event: InputEvent, _shape_idx: int, pundong_node: Node2D) -> void:
	if not pundong_node.visible or active_artifact_2 or active_congrats:
		return
	if not _is_left_click(event):
		return

	_open_pundong_reward(pundong_node)


func _on_pundong_mouse_entered(pundong_node: Node2D) -> void:
	if not pundong_node.visible or active_artifact_2 or active_congrats:
		return

	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	_tween_pundong_scale(pundong_node, 1.035)


func _on_pundong_mouse_exited(pundong_node: Node2D) -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_tween_pundong_scale(pundong_node, 1.0)


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
	for node_path in ["0/pundong1", "0/pundong", "0/pundong2", "0/pundong3"]:
		var pundong_node := get_node_or_null(node_path) as Node2D
		if pundong_node:
			nodes.append(pundong_node)

	return nodes


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
		var half_size := rectangle_shape.size * 0.5
		if abs(local_mouse_position.x) <= half_size.x and abs(local_mouse_position.y) <= half_size.y:
			return pundong_node

	return null


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

	if player_instance and player_instance.has_method("set_input_enabled"):
		player_instance.set_input_enabled(false)

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
	GameState.player_return_position = CALLE_REAL_TABLE_FRONT_POSITION
	active_congrats = null
	_restore_player_input_after_reward_popups()


func _restore_player_input_after_reward_popups() -> void:
	if active_artifact_2 and is_instance_valid(active_artifact_2):
		return
	if active_congrats and is_instance_valid(active_congrats):
		return

	if player_instance and player_instance.has_method("set_input_enabled"):
		player_instance.set_input_enabled(true)

	_hide_reward_backdrop()


func _play_popup_open_transition(popup: Node2D) -> void:
	var target_scale := popup.scale
	popup.scale = target_scale * POPUP_START_SCALE

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "scale", target_scale, POPUP_OPEN_DURATION)


func _tween_pundong_scale(pundong_node: Node2D, scale_multiplier: float) -> void:
	var sprite := pundong_node.get_node_or_null("Sprite2D") as Sprite2D
	if not sprite:
		return

	if pundong_tween and pundong_tween.is_valid():
		pundong_tween.kill()

	var base_scale: Vector2 = pundong_base_scales.get(pundong_node, sprite.scale)
	pundong_tween = create_tween()
	pundong_tween.tween_property(sprite, "scale", base_scale * scale_multiplier, 0.16)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)


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


func _is_left_click(event: InputEvent) -> bool:
	if event is not InputEventMouseButton:
		return false

	var mouse_event := event as InputEventMouseButton
	return mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed


func start_dialogue_balloon_from_trigger(resource: DialogueResource, title: String):
	balloon.show()
	balloon.start(resource, title)


# You might also want to add an _on_dialogue_mutated function if you handle mutations in Level 2
func _on_dialogue_mutated(data: Dictionary):
	# Handle any specific mutations for Level 2 here
	print("DEBUG: Level 2 Dialogue mutated: ", data)
