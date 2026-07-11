# crowd_spawner.gd
extends Node2D

# Drag your crowd_walker.tscn file onto this slot in the Godot Inspector.
@export var crowd_walker_scene: PackedScene

# Set the range for the random speeds in the Inspector.
@export var min_speed: float = 50.0
@export var max_speed: float = 150.0

@onready var spawn_timer: Timer = $Timer

func _ready():
	# Connect the timer's 'timeout' signal to our spawn function.
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)

func _on_spawn_timer_timeout():
	# --- THIS IS THE NEW, CORRECTED LOGIC ---

	# 1. Get the current camera from the viewport.
	var camera = get_viewport().get_camera_2d()
	if not camera:
		# If there's no camera, we can't do anything.
		return

	# 2. Get the size of the screen.
	var viewport_size = get_viewport_rect().size

	# 3. Calculate the world coordinates of the camera's left and right edges.
	var camera_left_edge = camera.get_screen_center_position().x - (viewport_size.x / 2.0)
	var camera_right_edge = camera.get_screen_center_position().x + (viewport_size.x / 2.0)
	
	# 4. Create the walker instance.
	var walker = crowd_walker_scene.instantiate()

	# 5. Decide on a random direction.
	var spawn_direction = Vector2.RIGHT if randf() > 0.5 else Vector2.LEFT
	
	# 6. Calculate the spawn coordinates in WORLD SPACE.
	var spawn_x = camera_left_edge - 50 if spawn_direction == Vector2.RIGHT else camera_right_edge + 50
	var spawn_y = self.global_position.y # The spawner's actual height in the world.
	
	# 7. Set the walker's properties.
	walker.direction = spawn_direction
	walker.speed = randf_range(min_speed, max_speed)
	# CRITICAL: We now set the walker's GLOBAL position, not its local position.
	walker.global_position = Vector2(spawn_x, spawn_y)
	
	# 8. Add the walker to the scene.
	get_parent().add_child(walker)
