# minigame_persevere.gd
extends Node2D

const OFFICE_SCENE_PATH := "res://scenes/minigames/office.tscn"

# --- Node References ---
# We get references to the containers for easy access to the tiles and zones.
@onready var letter_tiles_container = $LetterTiles
@onready var drop_zones_container = $DropZones
@onready var success_screen = $SuccessScreen

@onready var bgm = $BGMPlayer
# How long the fade should take (in seconds)
var fade_time := 2.0  

# --- State Variables ---
var correctly_placed_count: int = 0
var total_zones_to_win: int = 0

func _ready():
	 # When the scene starts, fade IN its BGM
	if _launched_from_office():
		if bgm:
			bgm.stop()
		GameState.start_cultural_echo_bgm()
	elif bgm:
		bgm.volume_db = -40  # Start almost silent
		bgm.play()           # Start playing immediately
		var t = create_tween()
		# Fade volume from -40 dB to 0 dB (full volume) smoothly
		t.tween_property(
			bgm, "volume_db", 0, fade_time
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Hide the success screen at the start.
	success_screen.hide()

	# Count how many zones we need to fill to win.
	total_zones_to_win = drop_zones_container.get_child_count()

	# This is crucial: we must connect the 'dropped_on_zone' signal
	# from EVERY letter tile to a function in THIS script.
	for tile in letter_tiles_container.get_children():
		# The function _on_letter_tile_dropped will now be called for any tile.
		tile.dropped_on_zone.connect(_on_letter_tile_dropped)
		
# This function is called whenever the player is leaving the scene.
func _exit_tree():
	# When the scene is about to be removed, fade OUT its BGM
	if bgm and bgm.playing:
		var t = create_tween()
		# Fade volume down to -40 dB over fade_time
		t.tween_property(
			bgm, "volume_db", -40, fade_time
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		# Stop music only AFTER fade-out is complete
		t.finished.connect(func():
			bgm.stop())


func _launched_from_office() -> bool:
	return GameState.persevere_minigame_return_scene == OFFICE_SCENE_PATH

# This is the main logic function, called whenever any tile is dropped on any zone.
func _on_letter_tile_dropped(letter_tile: Area2D, drop_zone: Area2D):
	# Check 1: Is this drop zone already correctly filled?
	if drop_zone.current_letter != null:
		# The zone is occupied. Tell the tile to slide back.
		letter_tile.slide_back()
		return

	# Check 2: Does the tile's ID match the zone's required ID?
	if letter_tile.letter_id == drop_zone.correct_letter_id:
		# --- CORRECT DROP ---
		# Tell the zone it is now filled with this letter.
		drop_zone.current_letter = letter_tile

		# Snap the tile perfectly into the center of the zone.
		letter_tile.global_position = drop_zone.global_position

		# Make the tile non-draggable anymore.
		letter_tile.input_pickable = false

		# Update the tile's return position to its new locked spot.
		letter_tile.return_position = letter_tile.global_position

		# Increment our win counter.
		correctly_placed_count += 1

		# Check if the player has won.
		check_for_win()
	else:
		# --- INCORRECT DROP ---
		# The tile doesn't belong here. Tell it to slide back.
		letter_tile.slide_back()

func check_for_win():
	if correctly_placed_count == total_zones_to_win:
		# The player has won!
		print("MINIGAME WON!") # For debugging
		success_screen.show()
		# Optional: disable all remaining tiles to prevent interaction behind the UI
		for tile in letter_tiles_container.get_children():
			tile.input_pickable = false

func _on_button_pressed() -> void:
	GameState.persevere_minigame_completed = true
	var return_scene := GameState.persevere_minigame_return_scene
	if return_scene.is_empty():
		return_scene = "res://scenes/levels/level1_questonhall.tscn"
		GameState.persevere_minigame_return_scene = return_scene
		GameState.player_return_position = Vector2(-930, -240)
	if return_scene != OFFICE_SCENE_PATH:
		GameState.stop_cultural_echo_bgm()
	get_tree().change_scene_to_file(return_scene)
