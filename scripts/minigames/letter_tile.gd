# letter_tile.gd
extends Area2D

# We will set this in the editor for each letter (e.g., "PE", "R", "SE").
@export var letter_id: String = ""
@export var can_reposition_on_empty_drop: bool = false

# This signal will be sent to the main minigame script when this tile is dropped.
signal dropped_on_zone(letter_tile: Area2D, drop_zone: Area2D)

const ACTIVE_DRAG_TILE_META := &"active_drag_tile"

# --- State Variables ---
var is_dragging: bool = false
var return_position: Vector2 # The position to slide back to if the drop is invalid.
var last_valid_resting_position: Vector2
var drag_offset: Vector2 = Vector2.ZERO

func _ready():
	# Make the Area2D clickable.
	input_pickable = true
	# Store the starting position.
	return_position = global_position
	last_valid_resting_position = global_position


func _input_event(_viewport, event, _shape_idx):
	# This function is called automatically when the area is clicked.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _get_active_drag_tile() != null:
				return
			# Mouse button was pressed down: start dragging.
			is_dragging = true
			get_tree().root.set_meta(ACTIVE_DRAG_TILE_META, self)
			drag_offset = global_position - get_global_mouse_position()
		else:
			if not is_dragging:
				return
			# Mouse button was released: stop dragging and check for a drop.
			is_dragging = false
			_clear_active_drag_tile()
			check_for_drop_zone()


func _process(_delta):
	# While dragging, make the tile follow the mouse.
	if is_dragging:
		global_position = get_global_mouse_position() + drag_offset


func check_for_drop_zone():
	# Get a list of all areas this tile is overlapping with.
	var overlapping_areas = get_overlapping_areas()
	var drop_zone: Area2D = null
	var closest_distance := INF

	for area in overlapping_areas:
		if area.has_method("is_drop_zone"):
			var distance := global_position.distance_to(area.global_position)
			if distance < closest_distance:
				closest_distance = distance
				drop_zone = area

	if drop_zone != null:
		# Send a signal to the main game, telling it which tile was dropped on which zone.
		dropped_on_zone.emit(self, drop_zone)
	else:
		if can_reposition_on_empty_drop:
			set_resting_position(global_position)
		else:
			# Not dropped on any zone, so slide back to the return position.
			slide_back()


func set_resting_position(new_position: Vector2) -> void:
	last_valid_resting_position = new_position
	return_position = new_position


func _get_active_drag_tile() -> Area2D:
	if not get_tree().root.has_meta(ACTIVE_DRAG_TILE_META):
		return null

	var active_tile := get_tree().root.get_meta(ACTIVE_DRAG_TILE_META) as Area2D
	if not is_instance_valid(active_tile):
		get_tree().root.remove_meta(ACTIVE_DRAG_TILE_META)
		return null

	return active_tile


func _clear_active_drag_tile() -> void:
	if _get_active_drag_tile() == self:
		get_tree().root.remove_meta(ACTIVE_DRAG_TILE_META)


func fit_collision_to_sprite() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not sprite or not collision_shape or not sprite.texture:
		return

	var rectangle_shape := collision_shape.shape as RectangleShape2D
	if not rectangle_shape:
		return

	rectangle_shape = rectangle_shape.duplicate()
	rectangle_shape.size = sprite.texture.get_size()
	collision_shape.shape = rectangle_shape
	collision_shape.position = sprite.position
	collision_shape.scale = sprite.scale


func slide_back():
	# We use a Tween to create a smooth sliding animation.
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUINT) # This makes the slide look nice.
	tween.set_ease(Tween.EASE_OUT)
	# Animate the 'global_position' property from its current value back to the 'return_position'.
	return_position = last_valid_resting_position
	tween.tween_property(self, "global_position", return_position, 0.3)
