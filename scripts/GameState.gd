# GameState.gd
extends Node

const CULTURAL_ECHO_BGM_PATH := "res://assets/bgm/cultural-echo-bgm.mp3"
const CULTURAL_ECHO_FADE_DURATION := 2.0
const CULTURAL_ECHO_VOLUME_DB := 0.0
const CULTURAL_ECHO_START_OFFSET_SECONDS := 20.0
const GAMEON_ARTIFACT_1_FLAG := "level1_amphora_collected"
const GAMEON_NOTIFICATION_DISPLAY_SECONDS := 3.0
const GAMEON_NOTIFICATION_FADE_SECONDS := 0.25

# --- Scene Return State ---
var player_return_position: Variant = null

var persevere_minigame_completed: bool = false
var persevere_minigame_dialogue_shown: bool = false
var persevere_minigame_return_scene: String = ""

var puzzle_minigame_completed: bool = false
var puzzle_minigame_return_scene: String = ""

var cat_is_following_globally: bool = false
var level_1_story_exit_completed: bool = false
var cat_dialogue_completed: bool = false
var returning_from_level: String = ""
var pending_office_dialogue_title: String = ""

var office_post_minigame_choice_pending: bool = false
var office_leave_requested: bool = false
var office_visible_amphora_name: String = ""
var level1_visible_amphora_name: String = ""
var level1_amphora_unlocked: bool = false
var level1_cultural_echo_active: bool = false
var trigger_level1_minigame_on_return: bool = false

# --- Story and Unlock State ---
var story_flags: Dictionary = {}
var gameon_unlock_pending: bool = false
var gameon_unlock_requested: bool = false
var gameon_artifact_unlocked: bool = false

# --- Runtime Services ---
var triggered_dialogues = {}
var cultural_echo_player: AudioStreamPlayer = null
var cultural_echo_fade_tween: Tween = null
var cultural_echo_dialogue_fade_started := false
var gameon_notification_layer: CanvasLayer = null
var gameon_notification_panel: Panel = null
var gameon_notification_label: Label = null
var gameon_notification_tween: Tween = null
var gameon_notification_sequence: int = 0

# --- Scene Lifecycle ---
func _ready():
	print("GameState ready.")
	_prepare_cultural_echo_player()
	_prepare_gameon_notification()
	_connect_gameon_signals()


# --- Run Reset ---
func reset_for_new_run() -> void:
	var gameon_portal := _get_gameon_portal()
	if gameon_portal:
		gameon_portal.set("is_authorized", true)
		if gameon_portal.has_signal("authorization_status_changed"):
			gameon_portal.authorization_status_changed.emit("authorized")

	player_return_position = null
	persevere_minigame_completed = false
	persevere_minigame_dialogue_shown = false
	persevere_minigame_return_scene = ""
	puzzle_minigame_completed = false
	puzzle_minigame_return_scene = ""
	cat_is_following_globally = false
	level_1_story_exit_completed = false
	cat_dialogue_completed = false
	returning_from_level = ""
	pending_office_dialogue_title = ""
	office_post_minigame_choice_pending = false
	office_leave_requested = false
	office_visible_amphora_name = ""
	level1_visible_amphora_name = ""
	level1_amphora_unlocked = false
	level1_cultural_echo_active = false
	trigger_level1_minigame_on_return = false
	story_flags.clear()
	gameon_unlock_pending = false
	gameon_unlock_requested = false
	gameon_artifact_unlocked = false
	triggered_dialogues.clear()
	stop_cultural_echo_bgm()
	if gameon_notification_layer:
		gameon_notification_layer.queue_free()
		gameon_notification_layer = null
		gameon_notification_panel = null
		gameon_notification_label = null


# --- Cultural Echo Audio ---
func _prepare_cultural_echo_player() -> void:
	if cultural_echo_player:
		return

	cultural_echo_player = AudioStreamPlayer.new()
	cultural_echo_player.name = "CulturalEchoPlayer"
	cultural_echo_player.stream = _load_cultural_echo_stream()
	cultural_echo_player.volume_db = CULTURAL_ECHO_VOLUME_DB
	add_child(cultural_echo_player)


func start_cultural_echo_bgm() -> void:
	if not cultural_echo_player:
		_prepare_cultural_echo_player()

	if not cultural_echo_player.stream:
		cultural_echo_player.stream = _load_cultural_echo_stream()

	if not cultural_echo_player.stream:
		push_warning("Could not play cultural echo BGM. Check that %s is a valid MP3 and reimport it in Godot." % CULTURAL_ECHO_BGM_PATH)
		return

	if cultural_echo_fade_tween and cultural_echo_fade_tween.is_valid():
		cultural_echo_fade_tween.kill()

	cultural_echo_dialogue_fade_started = false

	cultural_echo_player.volume_db = CULTURAL_ECHO_VOLUME_DB

	if cultural_echo_player.playing:
		return

	cultural_echo_player.play(CULTURAL_ECHO_START_OFFSET_SECONDS)


func stop_cultural_echo_bgm() -> void:
	if cultural_echo_fade_tween and cultural_echo_fade_tween.is_valid():
		cultural_echo_fade_tween.kill()

	cultural_echo_dialogue_fade_started = false

	if cultural_echo_player and cultural_echo_player.playing:
		cultural_echo_player.stop()

	if cultural_echo_player:
		cultural_echo_player.volume_db = CULTURAL_ECHO_VOLUME_DB


func begin_cultural_echo_dialogue_fade() -> void:
	if cultural_echo_dialogue_fade_started:
		return

	cultural_echo_dialogue_fade_started = true
	if not cultural_echo_player or not cultural_echo_player.playing:
		return

	if cultural_echo_fade_tween and cultural_echo_fade_tween.is_valid():
		cultural_echo_fade_tween.kill()

	cultural_echo_fade_tween = create_tween()
	cultural_echo_fade_tween.set_trans(Tween.TRANS_SINE)
	cultural_echo_fade_tween.set_ease(Tween.EASE_IN_OUT)
	cultural_echo_fade_tween.tween_property(cultural_echo_player, "volume_db", -40.0, CULTURAL_ECHO_FADE_DURATION)


func wait_for_cultural_echo_dialogue_fade() -> void:
	if cultural_echo_fade_tween and cultural_echo_fade_tween.is_valid():
		await cultural_echo_fade_tween.finished

	if cultural_echo_dialogue_fade_started:
		stop_cultural_echo_bgm()


func _load_cultural_echo_stream() -> AudioStream:
	var imported_stream := load(CULTURAL_ECHO_BGM_PATH) as AudioStream
	if imported_stream:
		return imported_stream

	var file := FileAccess.open(CULTURAL_ECHO_BGM_PATH, FileAccess.READ)
	if not file:
		return null

	var stream := AudioStreamMP3.new()
	stream.data = file.get_buffer(file.get_length())
	return stream


# --- Dialogue and Story Flags ---
func mark_dialogue_as_triggered(unique_trigger_id: String):
	if not triggered_dialogues.has(unique_trigger_id):
		triggered_dialogues[unique_trigger_id] = true
		print("Dialogue trigger marked as triggered: ", unique_trigger_id)


func clear_dialogue_trigger(unique_trigger_id: String) -> void:
	if triggered_dialogues.has(unique_trigger_id):
		triggered_dialogues.erase(unique_trigger_id)


func is_dialogue_triggered(unique_trigger_id: String) -> bool:
	return triggered_dialogues.has(unique_trigger_id)


func set_story_flag(flag_name: String, value: bool = true) -> void:
	story_flags[flag_name] = value


func get_story_flag(flag_name: String) -> bool:
	return story_flags.get(flag_name, false)


# --- GameOn Unlocks ---
func check_gameon_unlock() -> void:
	var artifact_1_collected := get_story_flag(GAMEON_ARTIFACT_1_FLAG)
	print("[GAMEON TEST] %s=%s" % [GAMEON_ARTIFACT_1_FLAG, artifact_1_collected])

	if gameon_artifact_unlocked or gameon_unlock_requested:
		return
	if not artifact_1_collected:
		return

	_show_gameon_notification("Saving Amphora to GameOn...", 0.0)

	var gameon_portal := _get_gameon_portal()
	if not gameon_portal:
		print("[GAMEON TEST] is_authorized=false")
		gameon_unlock_pending = true
		return
	var is_gameon_authorized := bool(gameon_portal.get("is_authorized"))
	print("[GAMEON TEST] is_authorized=%s" % is_gameon_authorized)
	if not is_gameon_authorized:
		gameon_unlock_pending = true
		return

	gameon_unlock_pending = false
	gameon_unlock_requested = true
	print("[GAMEON TEST] GameOnPortal.unlock_artifact() called")
	gameon_portal.unlock_artifact()


func _connect_gameon_signals() -> void:
	var gameon_portal := _get_gameon_portal()
	if not gameon_portal:
		return

	var status_callable := Callable(self, "_on_gameon_authorization_status_changed")
	if gameon_portal.has_signal("authorization_status_changed") and not gameon_portal.is_connected("authorization_status_changed", status_callable):
		gameon_portal.connect("authorization_status_changed", status_callable)

	var unlocked_callable := Callable(self, "_on_gameon_artifact_unlocked")
	if gameon_portal.has_signal("artifact_unlocked") and not gameon_portal.is_connected("artifact_unlocked", unlocked_callable):
		gameon_portal.connect("artifact_unlocked", unlocked_callable)

	var error_callable := Callable(self, "_on_gameon_error")
	if gameon_portal.has_signal("game_on_error") and not gameon_portal.is_connected("game_on_error", error_callable):
		gameon_portal.connect("game_on_error", error_callable)


func _get_gameon_portal() -> Node:
	return get_node_or_null("/root/GameOnPortal")


func _on_gameon_authorization_status_changed(status: String) -> void:
	match status:
		"connecting":
			_show_gameon_notification("Connecting to GameOn...", 0.0)
		"pending":
			_show_gameon_notification("GameOn sign-in opened. Complete sign-in in your browser.", 0.0)
		"authorized":
			_show_gameon_notification("Signed in to GameOn!")
		"expired":
			_show_gameon_notification("GameOn sign-in expired. Please try again.")
		"error":
			_show_gameon_notification("Could not sign in to GameOn. Please try again.")

	if status == "authorized" and gameon_unlock_pending:
		check_gameon_unlock()


func _on_gameon_artifact_unlocked(artifact_data: Dictionary, is_new_unlock: bool) -> void:
	print("[GAMEON TEST] artifact_unlocked emitted artifact_data=%s is_new_unlock=%s" % [artifact_data, is_new_unlock])
	gameon_artifact_unlocked = true
	gameon_unlock_pending = false
	gameon_unlock_requested = false

	if is_new_unlock:
		print("Amphora added to your GameOn collection")
		_show_gameon_notification("Amphora saved to your GameOn collection!")
	else:
		print("Amphora already exists in your GameOn collection")
		_show_gameon_notification("Amphora is already saved to GameOn.")


func _on_gameon_error(message: String) -> void:
	gameon_unlock_pending = false
	gameon_unlock_requested = false
	_show_gameon_notification(message)


# --- GameOn Notification UI ---
func _prepare_gameon_notification() -> void:
	if gameon_notification_layer:
		return

	gameon_notification_layer = CanvasLayer.new()
	gameon_notification_layer.name = "GameOnNotificationLayer"
	gameon_notification_layer.layer = 200
	add_child(gameon_notification_layer)

	gameon_notification_panel = Panel.new()
	gameon_notification_panel.name = "GameOnNotificationPanel"
	gameon_notification_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameon_notification_panel.custom_minimum_size = Vector2(420.0, 64.0)
	gameon_notification_panel.anchor_left = 0.5
	gameon_notification_panel.anchor_right = 0.5
	gameon_notification_panel.anchor_top = 0.0
	gameon_notification_panel.anchor_bottom = 0.0
	gameon_notification_panel.offset_left = -210.0
	gameon_notification_panel.offset_right = 210.0
	gameon_notification_panel.offset_top = 24.0
	gameon_notification_panel.offset_bottom = 88.0
	gameon_notification_panel.modulate.a = 0.0
	gameon_notification_panel.visible = false
	gameon_notification_layer.add_child(gameon_notification_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.88)
	style.border_color = Color(1.0, 0.82, 0.35, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	gameon_notification_panel.add_theme_stylebox_override("panel", style)

	gameon_notification_label = Label.new()
	gameon_notification_label.name = "MessageLabel"
	gameon_notification_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameon_notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gameon_notification_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gameon_notification_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gameon_notification_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.84, 1.0))
	gameon_notification_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gameon_notification_label.offset_left = 16.0
	gameon_notification_label.offset_right = -16.0
	gameon_notification_panel.add_child(gameon_notification_label)


func _show_gameon_notification(message: String, display_seconds: float = GAMEON_NOTIFICATION_DISPLAY_SECONDS) -> void:
	_prepare_gameon_notification()
	if not is_instance_valid(gameon_notification_panel) or not is_instance_valid(gameon_notification_label):
		return
	gameon_notification_sequence += 1
	var sequence := gameon_notification_sequence

	if gameon_notification_tween and gameon_notification_tween.is_valid():
		gameon_notification_tween.kill()

	gameon_notification_label.text = message
	gameon_notification_panel.visible = true
	gameon_notification_tween = create_tween()
	var fade_in_tweener := gameon_notification_tween.tween_property(gameon_notification_panel, "modulate:a", 1.0, GAMEON_NOTIFICATION_FADE_SECONDS)
	if fade_in_tweener:
		fade_in_tweener.set_trans(Tween.TRANS_SINE)
		fade_in_tweener.set_ease(Tween.EASE_OUT)

	if display_seconds <= 0.0:
		return

	await get_tree().create_timer(display_seconds).timeout
	if sequence != gameon_notification_sequence:
		return
	if not is_instance_valid(gameon_notification_panel):
		return

	gameon_notification_tween = create_tween()
	var fade_out_tweener := gameon_notification_tween.tween_property(gameon_notification_panel, "modulate:a", 0.0, GAMEON_NOTIFICATION_FADE_SECONDS)
	if fade_out_tweener:
		fade_out_tweener.set_trans(Tween.TRANS_SINE)
		fade_out_tweener.set_ease(Tween.EASE_IN)
	await gameon_notification_tween.finished
	if sequence == gameon_notification_sequence:
		gameon_notification_panel.visible = false
