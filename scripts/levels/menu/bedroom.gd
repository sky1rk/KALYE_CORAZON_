extends Node2D

@onready var balloon = preload("res://dialogue/balloon.tscn").instantiate()
@onready var animation_player = $AnimationPlayer
var dialogue_res = preload("res://dialogue/main.dialogue")

func _ready() -> void:
	add_child(balloon)
	balloon.hide()

	# Play the opening transition
	animation_player.play("intro_transition")
	await animation_player.animation_finished

	# Start the bedroom dialogue
	balloon.show()
	balloon.start(dialogue_res, "intro_bedroom")

	# Wait for the dialogue to finish
	await DialogueManager.dialogue_ended

	# Fade to black
	animation_player.play("outro_transition")
	await animation_player.animation_finished

	get_tree().change_scene_to_file("res://scenes/levels/reflection.tscn")
