# GameState.gd
extends Node

const CULTURAL_ECHO_BGM_PATH := "res://assets/bgm/cultural-echo-bgm.mp3"
const CULTURAL_ECHO_FADE_DURATION := 2.0

var player_return_position: Variant = null

var persevere_minigame_completed: bool = false
var persevere_minigame_dialogue_shown: bool = false
var persevere_minigame_return_scene: String = ""

var puzzle_minigame_completed: bool = false
var puzzle_minigame_return_scene: String = ""

var cat_is_following_globally: bool = false
var level_1_story_exit_completed: bool = false

# NEW: Track if cat dialogue has been encountered
var cat_dialogue_completed: bool = false

# NEW: Track which level we're returning from
var returning_from_level: String = ""

# NEW: Hold a dialogue title that should start on the next office scene load.
var pending_office_dialogue_title: String = ""

# NEW: Track whether the office should ask the player what to do after Persevere.
var office_post_minigame_choice_pending: bool = false
var office_leave_requested: bool = false
var office_visible_amphora_name: String = ""
var level1_visible_amphora_name: String = ""
var level1_amphora_unlocked: bool = false
var level1_cultural_echo_active: bool = false
var trigger_level1_minigame_on_return: bool = false

# NEW: Track story decisions made by interacting with NPCs or the environment.
var story_flags: Dictionary = {}

var triggered_dialogues = {}
var cultural_echo_player: AudioStreamPlayer = null
var cultural_echo_fade_tween: Tween = null
var cultural_echo_dialogue_fade_started := false

func _ready():
	print("GameState ready.")
	_prepare_cultural_echo_player()


func _prepare_cultural_echo_player() -> void:
	if cultural_echo_player:
		return

	cultural_echo_player = AudioStreamPlayer.new()
	cultural_echo_player.name = "CulturalEchoPlayer"
	cultural_echo_player.stream = _load_cultural_echo_stream()
	cultural_echo_player.volume_db = -2.0
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

	cultural_echo_player.volume_db = -2.0

	if cultural_echo_player.playing:
		return

	cultural_echo_player.play()


func stop_cultural_echo_bgm() -> void:
	if cultural_echo_fade_tween and cultural_echo_fade_tween.is_valid():
		cultural_echo_fade_tween.kill()

	cultural_echo_dialogue_fade_started = false

	if cultural_echo_player and cultural_echo_player.playing:
		cultural_echo_player.stop()

	if cultural_echo_player:
		cultural_echo_player.volume_db = -2.0


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

# Marks a dialogue trigger as having been activated.
func mark_dialogue_as_triggered(unique_trigger_id: String):
	if not triggered_dialogues.has(unique_trigger_id):
		triggered_dialogues[unique_trigger_id] = true
		print("Dialogue trigger marked as triggered: ", unique_trigger_id)

# Checks if a dialogue trigger has already been activated.
func is_dialogue_triggered(unique_trigger_id: String) -> bool:
	return triggered_dialogues.has(unique_trigger_id)


func set_story_flag(flag_name: String, value: bool = true) -> void:
	story_flags[flag_name] = value


func get_story_flag(flag_name: String) -> bool:
	return story_flags.get(flag_name, false)

# You could expand this later for full save/load functionality
# func save_game_state():
#     # Example: Save triggered_dialogues to a file
#     var file = FileAccess.open("user://save_game.dat", FileAccess.WRITE)
#     file.store_var(triggered_dialogues)
#     file.close()

# func load_game_state():
#     # Example: Load triggered_dialogues from a file
#     if FileAccess.file_exists("user://save_game.dat"):
#         var file = FileAccess.open("user://save_game.dat", FileAccess.READ)
#         triggered_dialogues = file.get_var()
#         file.close()
#         print("Loaded triggered dialogues: ", triggered_dialogues)
#     else:
#         print("No save file found for game state.")
