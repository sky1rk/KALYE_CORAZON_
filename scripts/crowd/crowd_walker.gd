# crowd_walker.gd
extends Area2D

# These variables will be set by the spawner when the walker is created.
var speed: float = 100.0
var direction: Vector2 = Vector2.RIGHT # Default to moving right

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

func _ready():
	# Connect the notifier's 'screen_exited' signal to a function in this script.
	# This is the most efficient way to clean up nodes that are no longer visible.
	notifier.screen_exited.connect(_on_screen_exited)
	
	# Start the walking animation.
	animated_sprite.play("walk")
	
	# Flip the sprite horizontally if the direction is to the left.
	if direction.x < 0:
		# If it's moving left, flip the sprite horizontally.
		animated_sprite.flip_h = false
	else:
		# If it's moving right, ensure it's not flipped.
		animated_sprite.flip_h = true

func _process(delta: float) -> void:
	# Move the walker every frame.
	global_position += direction * speed * delta

# This function is called automatically by the signal when the walker leaves the screen.
func _on_screen_exited():
	# Deleting the node frees up memory.
	queue_free()
