extends Node2D

@onready var animation_player = $AnimationPlayer

func _ready() -> void:
	# Play the opening transition
	animation_player.play("intro_transition")
	await animation_player.animation_finished

	# Start the bedroom dialogue
	DialogueManager.show_dialogue_balloon(
		preload("res://dialogue/main.dialogue"),
		"intro_bedroom"
	)

	# Wait for the dialogue to finish
	await DialogueManager.dialogue_ended

	# Fade to black
	animation_player.play("outro_transition")
	await animation_player.animation_finished

	get_tree().change_scene_to_file("res://scenes/levels/reflection.tscn")
