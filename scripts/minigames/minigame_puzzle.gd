extends Node2D

const CALLE_REAL_SCENE_PATH := "res://scenes/levels/level2_callereal.tscn"
const TABLE_SCENE_PATH := "res://scenes/minigames/table.tscn"
const TABLE_PUZZLE_FINISHED_FLAG := "table_puzzle_finished"
const DEFAULT_CALLE_REAL_RETURN_POSITION := Vector2(57.5433, 614.273)

@onready var puzzle_pieces_container: Node2D = $PuzzlePieces
@onready var drop_zones_container: Node2D = $DropZones
@onready var success_screen: CanvasLayer = get_node_or_null("SuccessScreen") as CanvasLayer
@onready var bgm: AudioStreamPlayer = get_node_or_null("BGMPlayer") as AudioStreamPlayer

var fade_time := 2.0
var correctly_placed_count: int = 0
var total_zones_to_win: int = 0
var returning_to_calle_real: bool = false


func _ready() -> void:
	if GameState.level1_cultural_echo_active:
		if bgm:
			bgm.stop()
	elif bgm:
		bgm.volume_db = -40
		bgm.play()
		var tween := create_tween()
		tween.tween_property(bgm, "volume_db", 0, fade_time)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)

	if success_screen:
		success_screen.hide()

	_setup_puzzle_pairs()
	_hide_drop_zone_borders()

	total_zones_to_win = drop_zones_container.get_child_count()

	for piece in puzzle_pieces_container.get_children():
		if piece.has_signal("dropped_on_zone"):
			piece.dropped_on_zone.connect(_on_puzzle_piece_dropped)


func _exit_tree() -> void:
	if bgm and bgm.playing:
		var tween := create_tween()
		tween.tween_property(bgm, "volume_db", -40, fade_time)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
		tween.finished.connect(func(): bgm.stop())


func _setup_puzzle_pairs() -> void:
	var pair_count = min(puzzle_pieces_container.get_child_count(), drop_zones_container.get_child_count())

	for index in range(pair_count):
		var pair_id := str(index + 1)
		var puzzle_piece := puzzle_pieces_container.get_child(index)
		var drop_zone := drop_zones_container.get_child(index)

		puzzle_piece.set("letter_id", pair_id)
		puzzle_piece.set("can_reposition_on_empty_drop", true)
		if puzzle_piece.has_method("fit_collision_to_sprite"):
			puzzle_piece.fit_collision_to_sprite()
		drop_zone.set("correct_letter_id", pair_id)


func _hide_drop_zone_borders() -> void:
	for drop_zone in drop_zones_container.get_children():
		var border_sprite := drop_zone.get_node_or_null("Sprite2D") as Sprite2D
		if border_sprite:
			border_sprite.hide()


func _on_puzzle_piece_dropped(puzzle_piece: Area2D, drop_zone: Area2D) -> void:
	if not drop_zone or not drop_zone.has_method("is_drop_zone"):
		_hide_drop_zone_borders()
		puzzle_piece.slide_back()
		return

	if drop_zone.current_letter != null:
		_set_drop_zone_border_visible(drop_zone, false)
		puzzle_piece.slide_back()
		return

	if puzzle_piece.letter_id == drop_zone.correct_letter_id:
		drop_zone.current_letter = puzzle_piece
		puzzle_piece.global_position = drop_zone.global_position
		puzzle_piece.input_pickable = false
		if puzzle_piece.has_method("set_resting_position"):
			puzzle_piece.set_resting_position(puzzle_piece.global_position)
		else:
			puzzle_piece.return_position = puzzle_piece.global_position
		correctly_placed_count += 1
		_check_for_win()
	else:
		_set_drop_zone_border_visible(drop_zone, false)
		puzzle_piece.slide_back()


func _set_drop_zone_border_visible(drop_zone: Area2D, is_visible: bool) -> void:
	var border_sprite := drop_zone.get_node_or_null("Sprite2D") as Sprite2D
	if border_sprite:
		border_sprite.visible = is_visible


func _check_for_win() -> void:
	if correctly_placed_count != total_zones_to_win:
		return

	for piece in puzzle_pieces_container.get_children():
		piece.input_pickable = false

	if success_screen:
		success_screen.show()
	else:
		await get_tree().create_timer(0.8).timeout
		_return_to_calle_real()


func _on_button_pressed() -> void:
	_return_to_calle_real()


func _return_to_calle_real() -> void:
	if returning_to_calle_real:
		return

	returning_to_calle_real = true
	GameState.puzzle_minigame_completed = true

	var return_scene := GameState.puzzle_minigame_return_scene
	if return_scene.is_empty():
		return_scene = CALLE_REAL_SCENE_PATH
		GameState.puzzle_minigame_return_scene = return_scene

	if return_scene == TABLE_SCENE_PATH:
		GameState.set_story_flag(TABLE_PUZZLE_FINISHED_FLAG, true)

	if GameState.player_return_position == null:
		GameState.player_return_position = DEFAULT_CALLE_REAL_RETURN_POSITION

	get_tree().change_scene_to_file(return_scene)
