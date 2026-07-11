# drop_zone.gd
extends Area2D

# We will set this ID in the Godot editor for each drop zone.
# This tells the zone which letter tile it should accept (e.g., "PE", "R", "SE").
@export var correct_letter_id: String = ""

# This variable will hold a reference to the letter tile that is correctly placed here.
var current_letter: Node2D = null


func is_drop_zone() -> bool:
	return true
