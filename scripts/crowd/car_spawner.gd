# crowd_spawner.gd
extends Node2D

# Drag your crowd_walker.tscn file onto this slot in the Godot Inspector.
@export var crowd_walker_scene: PackedScene

# Set the range for the random speeds in the Inspector.
@export var min_speed: float = 50.0
@export var max_speed: float = 150.0

# Choose spawn direction in the Inspector: LEFT or RIGHT.
@export_enum("Left", "Right") var spawn_direction: String = "Right"

# Range for random spawn delay (in seconds).
@export var min_spawn_time: float = 1.0
@export var max_spawn_time: float = 3.0

var time_until_next_spawn: float = 0.0

func _ready():
	# Pick the first random delay
	_set_next_spawn_time()

func _process(delta: float):
	# Countdown to the next spawn
	time_until_next_spawn -= delta
	if time_until_next_spawn <= 0.0:
		_spawn_walker()
		_set_next_spawn_time()

func _set_next_spawn_time():
	time_until_next_spawn = randf_range(min_spawn_time, max_spawn_time)

func _spawn_walker():
	# 1. Get the current camera from the viewport.
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return

	# 2. Get the size of the screen.
	var viewport_size = get_viewport_rect().size

	# 3. Calculate the world coordinates of the camera's left and right edges.
	var camera_left_edge = camera.get_screen_center_position().x - (viewport_size.x / 2.0)
	var camera_right_edge = camera.get_screen_center_position().x + (viewport_size.x / 2.0)
	
	# 4. Create the walker instance.
	var walker = crowd_walker_scene.instantiate()

	# 5. Use the chosen spawn direction.
	var dir = Vector2.RIGHT if spawn_direction == "Right" else Vector2.LEFT

	# 6. Calculate the spawn coordinates in WORLD SPACE.
	var spawn_x = camera_left_edge - 50 if dir == Vector2.RIGHT else camera_right_edge + 50
	var spawn_y = self.global_position.y
	
	# 7. Set the walker's properties.
	walker.direction = dir
	walker.speed = randf_range(min_speed, max_speed)
	walker.global_position = Vector2(spawn_x, spawn_y)
	
	# 8. Add the walker to the scene.
	get_parent().add_child(walker)
