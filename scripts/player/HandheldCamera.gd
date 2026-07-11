extends Camera2D

# Adjust these values in the Inspector to change the feel of the shake.
@export var shake_speed: float = 1.0  # How fast the camera moves.
@export var shake_strength: float = 4.0  # How far the camera moves from the center.

# We will create and assign this noise resource in the editor.
@export var noise: FastNoiseLite

# A variable to track our position in the noise map over time.
var noise_time: float = 0.0

func _ready():
	# It's good practice to ensure noise has been assigned.
	if not noise:
		print("ERROR: Noise resource not assigned to HandheldCamera.gd")
		return
	
	# Optional: Randomize the noise seed so the shake is different every time you run the game.
	noise.seed = randi()

func _process(delta: float):
	if not noise:
		return

	# Increment our time variable.
	noise_time += delta * shake_speed
	
	# Get two different noise values for the x and y axes.
	# We use different points in the 2D noise space to ensure x and y are not correlated.
	# The noise function returns a value between -1 and 1.
	var x_offset = noise.get_noise_2d(noise_time, 0)
	var y_offset = noise.get_noise_2d(0, noise_time)
	
	# Apply the shake by setting the camera's offset.
	# We multiply by shake_strength to control the intensity.
	self.offset = Vector2(x_offset, y_offset) * shake_strength
